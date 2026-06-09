from __future__ import annotations

import asyncio
import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(slots=True)
class GitFileStatus:
    path: str
    index: str
    worktree: str
    section: str


@dataclass(slots=True)
class GitStatus:
    root: str = ""
    branch: str = ""
    upstream: str = ""
    ahead: int = 0
    behind: int = 0
    files: list[GitFileStatus] | None = None
    error: str = ""


class GitService:
    def __init__(self, timeout: float = 8.0):
        self._timeout = timeout

    async def status(self, workspace: str) -> GitStatus:
        root = await self.find_root(workspace)
        if not root:
            return GitStatus(error="No Git repository")
        try:
            output = await self._git(root, "status", "--porcelain=v2", "--branch", "-z")
            return self._parse_status(root, output)
        except Exception as exc:
            return GitStatus(root=root, error=str(exc))

    async def find_root(self, workspace: str) -> str:
        if not workspace:
            return ""
        cwd = workspace if os.path.isdir(workspace) else os.path.dirname(workspace)
        if not cwd:
            return ""
        try:
            root = await self._git(cwd, "rev-parse", "--show-toplevel", text=True)
        except Exception:
            return ""
        return root.strip()

    async def stage(self, workspace: str, path: str) -> None:
        root = await self.find_root(workspace)
        if root and path:
            await self._git(root, "add", "--", self._to_repo_path(root, path))

    async def unstage(self, workspace: str, path: str) -> None:
        root = await self.find_root(workspace)
        if root and path:
            await self._git(root, "restore", "--staged", "--", self._to_repo_path(root, path))

    async def discard(self, workspace: str, path: str) -> None:
        root = await self.find_root(workspace)
        if root and path:
            repo_path = self._to_repo_path(root, path)
            await self._git(root, "restore", "--worktree", "--", repo_path)

    async def diff(self, workspace: str, path: str, staged: bool = False) -> str:
        root = await self.find_root(workspace)
        if not root or not path:
            return ""
        args = ["diff"]
        if staged:
            args.append("--cached")
        args.extend(["--", self._to_repo_path(root, path)])
        return await self._git(root, *args, text=True)

    async def _git(self, cwd: str, *args: str, text: bool = False) -> str | bytes:
        process = await asyncio.create_subprocess_exec(
            "git",
            *args,
            cwd=cwd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        try:
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=self._timeout)
        except asyncio.TimeoutError:
            process.kill()
            await process.wait()
            raise RuntimeError(f"git {' '.join(args)} timed out")
        if process.returncode != 0:
            message = stderr.decode("utf-8", "replace").strip()
            raise RuntimeError(message or f"git {' '.join(args)} failed")
        return stdout.decode("utf-8", "replace") if text else stdout

    def _parse_status(self, root: str, output: str | bytes) -> GitStatus:
        data = output if isinstance(output, bytes) else output.encode()
        entries = [item for item in data.split(b"\0") if item]
        status = GitStatus(root=root, files=[])
        for raw in entries:
            line = raw.decode("utf-8", "replace")
            if line.startswith("# branch.head "):
                status.branch = line.removeprefix("# branch.head ").strip()
            elif line.startswith("# branch.upstream "):
                status.upstream = line.removeprefix("# branch.upstream ").strip()
            elif line.startswith("# branch.ab "):
                parts = line.removeprefix("# branch.ab ").split()
                for part in parts:
                    if part.startswith("+"):
                        status.ahead = int(part[1:] or "0")
                    elif part.startswith("-"):
                        status.behind = int(part[1:] or "0")
            elif line.startswith("1 ") or line.startswith("2 "):
                parts = line.split(" ")
                xy = parts[1] if len(parts) > 1 else ".."
                path = parts[-1] if parts else ""
                self._append_file(status, path, xy[:1], xy[1:2])
            elif line.startswith("? "):
                self._append_file(status, line[2:], "?", "?")
            elif line.startswith("u "):
                parts = line.split(" ")
                xy = parts[1] if len(parts) > 1 else "UU"
                path = parts[-1] if parts else ""
                self._append_file(status, path, xy[:1], xy[1:2], "conflicts")
        status.files = status.files or []
        return status

    def _append_file(
        self,
        status: GitStatus,
        path: str,
        index: str,
        worktree: str,
        section: str | None = None,
    ) -> None:
        if not path:
            return
        if section is None:
            if index == "?" or worktree == "?":
                section = "untracked"
            elif index != ".":
                section = "staged"
            else:
                section = "unstaged"
        if status.files is None:
            status.files = []
        status.files.append(GitFileStatus(path=path, index=index, worktree=worktree, section=section))

    @staticmethod
    def _to_repo_path(root: str, path: str) -> str:
        path_obj = Path(path)
        if path_obj.is_absolute():
            try:
                return os.path.relpath(str(path_obj), root)
            except ValueError:
                return str(path_obj)
        return path
