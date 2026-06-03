from __future__ import annotations

import asyncio
import contextlib
import json
import os
import shutil
import fnmatch
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SearchOptions:
    max_results: int = 500
    max_file_size: int = 512_000
    context_chars: int = 96
    case_sensitive: bool = False
    include_hidden: bool = False
    regex: bool = False
    exclude: tuple[str, ...] = ()


class SearchService:
    EXTENSION_LANGUAGES = {
        ".py": "python",
        ".pyi": "python",
        ".rs": "rust",
        ".js": "javascript",
        ".jsx": "javascript",
        ".ts": "typescript",
        ".tsx": "typescript",
        ".qml": "qml",
        ".json": "json",
        ".toml": "toml",
        ".yaml": "yaml",
        ".yml": "yaml",
        ".md": "markdown",
        ".html": "html",
        ".css": "css",
        ".scss": "scss",
        ".sh": "shell",
        ".zsh": "shell",
        ".bash": "shell",
    }

    DEFAULT_EXCLUDES = {
        ".git",
        ".hg",
        ".svn",
        ".venv",
        "venv",
        "env",
        "__pycache__",
        "node_modules",
        "dist",
        "build",
        "target",
        ".mypy_cache",
        ".ruff_cache",
        ".pytest_cache",
        ".idea",
        ".vscode",
    }

    BINARY_EXTENSIONS = {
        ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".icns", ".pdf",
        ".zip", ".tar", ".gz", ".bz2", ".xz", ".7z", ".rar", ".dmg",
        ".so", ".dylib", ".dll", ".exe", ".bin", ".pyc", ".pyo",
        ".db", ".sqlite", ".sqlite3",
        ".ttf", ".otf", ".woff", ".woff2", ".mp3", ".mp4", ".mov",
    }

    async def search(
        self,
        root: str,
        query: str,
        *,
        options: SearchOptions | None = None,
        cancel_event: asyncio.Event | None = None,
    ) -> list[dict]:
        options = options or SearchOptions()
        root_path = Path(os.path.abspath(os.path.expanduser(root or "")))
        needle = query or ""
        if not needle or not root_path.is_dir():
            return []
        if options.regex:
            raise RuntimeError("Regex search requires the ripgrep provider.")
        return await asyncio.to_thread(
            self._search_sync,
            root_path,
            needle,
            options,
            cancel_event,
        )

    async def search_with_ripgrep(
        self,
        root: str,
        query: str,
        *,
        options: SearchOptions | None = None,
        command: str = "rg",
        args: list[str] | None = None,
        cancel_event: asyncio.Event | None = None,
    ) -> list[dict]:
        options = options or SearchOptions()
        root_path = Path(os.path.abspath(os.path.expanduser(root or "")))
        if not query or not root_path.is_dir():
            return []
        executable = shutil.which(command or "rg")
        if not executable:
            raise RuntimeError(f"Search provider command not found: {command or 'rg'}")
        search_args = [
            executable,
            "--json",
            "--line-number",
            "--column",
            "--max-count",
            str(options.max_results),
            "--max-filesize",
            str(options.max_file_size),
            "--glob",
            "!.git/**",
            "--glob",
            "!node_modules/**",
            "--glob",
            "!target/**",
            "--glob",
            "!dist/**",
            "--glob",
            "!build/**",
            "--glob",
            "!.venv/**",
        ]
        for pattern in options.exclude:
            pattern = str(pattern or "").strip()
            if pattern:
                search_args.extend(["--glob", f"!{pattern}/**" if "/" not in pattern else f"!{pattern}"])
        if not options.case_sensitive:
            search_args.append("--ignore-case")
        if not options.regex:
            search_args.append("--fixed-strings")
        if options.include_hidden:
            search_args.append("--hidden")
        search_args.extend(args or [])
        search_args.append(query)
        search_args.append(".")
        process = await asyncio.create_subprocess_exec(
            *search_args,
            cwd=str(root_path),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        communicate_task = asyncio.create_task(process.communicate())
        try:
            while not communicate_task.done():
                if cancel_event and cancel_event.is_set():
                    process.terminate()
                    await process.wait()
                    communicate_task.cancel()
                    with contextlib.suppress(asyncio.CancelledError):
                        await communicate_task
                    return []
                await asyncio.wait({communicate_task}, timeout=0.05)
            stdout, stderr = await communicate_task
        finally:
            if process.returncode is None:
                process.terminate()
                await process.wait()
        if process.returncode not in (0, 1):
            message = stderr.decode("utf-8", errors="ignore").strip()
            raise RuntimeError(message or f"ripgrep exited with {process.returncode}")
        return self._parse_ripgrep_json(root_path, stdout.decode("utf-8", errors="ignore"), options)

    def _parse_ripgrep_json(self, root: Path, payload: str, options: SearchOptions) -> list[dict]:
        results: list[dict] = []
        for line in payload.splitlines():
            if len(results) >= options.max_results:
                break
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("type") != "match":
                continue
            data = event.get("data") or {}
            path_text = ((data.get("path") or {}).get("text") or "").strip()
            lines_text = ((data.get("lines") or {}).get("text") or "").rstrip("\n")
            submatches = data.get("submatches") or [{}]
            first = submatches[0] if submatches else {}
            absolute = Path(path_text)
            if not absolute.is_absolute():
                absolute = root / absolute
            line_number = int(data.get("line_number") or 1)
            column = int(first.get("start") or 0) + 1
            end_column = int(first.get("end") or column) + 1
            results.append(
                self._result(
                    root,
                    absolute,
                    path_text,
                    line_number,
                    column,
                    end_column,
                    lines_text,
                    "ripgrep",
                    options,
                )
            )
        return results

    def _search_sync(
        self,
        root: Path,
        query: str,
        options: SearchOptions,
        cancel_event: asyncio.Event | None,
    ) -> list[dict]:
        results: list[dict] = []
        needle = query if options.case_sensitive else query.lower()
        for current_root, dirs, files in os.walk(root):
            if cancel_event and cancel_event.is_set():
                break
            dirs[:] = [
                item for item in dirs
                if self._should_enter_dir(item, options)
            ]
            for filename in files:
                if cancel_event and cancel_event.is_set():
                    break
                if len(results) >= options.max_results:
                    return results
                path = Path(current_root) / filename
                if not self._should_search_file(path, options):
                    continue
                results.extend(self._search_file(root, path, needle, query, options))
                if len(results) >= options.max_results:
                    return results[: options.max_results]
        return results

    def _should_enter_dir(self, name: str, options: SearchOptions) -> bool:
        if name in self.DEFAULT_EXCLUDES:
            return False
        if not options.include_hidden and name.startswith("."):
            return False
        if self._matches_exclude(name, options.exclude):
            return False
        return True

    def _should_search_file(self, path: Path, options: SearchOptions) -> bool:
        name = path.name
        if not options.include_hidden and name.startswith("."):
            return False
        if self._matches_exclude(name, options.exclude):
            return False
        if path.suffix.lower() in self.BINARY_EXTENSIONS:
            return False
        try:
            if path.stat().st_size > options.max_file_size:
                return False
        except OSError:
            return False
        return True

    @staticmethod
    def _matches_exclude(name: str, patterns: tuple[str, ...]) -> bool:
        return any(fnmatch.fnmatch(name, pattern) for pattern in patterns)

    def _search_file(
        self,
        root: Path,
        path: Path,
        needle: str,
        original_query: str,
        options: SearchOptions,
    ) -> list[dict]:
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            return []
        haystack = text if options.case_sensitive else text.lower()
        matches: list[dict] = []
        start = 0
        while True:
            index = haystack.find(needle, start)
            if index < 0:
                break
            line = text.count("\n", 0, index) + 1
            line_start = text.rfind("\n", 0, index) + 1
            line_end = text.find("\n", index)
            if line_end < 0:
                line_end = len(text)
            column = index - line_start + 1
            line_text = text[line_start:line_end]
            matches.append(
                self._result(
                    root,
                    path,
                    str(path.relative_to(root)),
                    line,
                    column,
                    column + len(original_query),
                    line_text,
                    "python",
                    options,
                )
            )
            start = index + max(1, len(needle))
        return matches

    def _result(
        self,
        root: Path,
        path: Path,
        relative_path: str,
        line: int,
        column: int,
        end_column: int,
        line_text: str,
        provider: str,
        options: SearchOptions,
    ) -> dict:
        column_zero = max(0, column - 1)
        length = max(1, end_column - column)
        preview, match_start, match_end = self._preview_parts(
            line_text,
            column_zero,
            length,
            options.context_chars,
        )
        return {
            "path": str(path),
            "relativePath": relative_path,
            "name": path.name,
            "line": line,
            "column": column,
            "endColumn": end_column,
            "language": self._language_for(path),
            "preview": preview,
            "previewBefore": preview[:match_start],
            "previewMatch": preview[match_start:match_end],
            "previewAfter": preview[match_end:],
            "provider": provider,
            "actions": ["open", "copyPath", "copyLink"],
        }

    def _language_for(self, path: Path) -> str:
        return self.EXTENSION_LANGUAGES.get(path.suffix.lower(), "text")

    @staticmethod
    def _preview_parts(
        line_text: str,
        column_zero: int,
        length: int,
        context_chars: int,
    ) -> tuple[str, int, int]:
        start = max(0, column_zero - context_chars // 2)
        end = min(len(line_text), column_zero + length + context_chars // 2)
        clipped = line_text[start:end].strip()
        leading_ellipsis = start > 0
        trailing_ellipsis = end < len(line_text)
        preview = ("…" if leading_ellipsis else "") + clipped + ("…" if trailing_ellipsis else "")
        stripped_left = len(line_text[start:end]) - len(line_text[start:end].lstrip())
        match_start = max(0, column_zero - start - stripped_left + (1 if leading_ellipsis else 0))
        match_end = min(len(preview), match_start + length)
        return preview, match_start, match_end

    @staticmethod
    def _preview(line_text: str, column_zero: int, length: int, context_chars: int) -> str:
        return SearchService._preview_parts(line_text, column_zero, length, context_chars)[0]
