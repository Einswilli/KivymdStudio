from __future__ import annotations

import asyncio
import os
import sys
from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class ToolInstallResult:
    ok: bool
    message: str
    command: list[str]
    stdout: str = ""
    stderr: str = ""


class ToolInstallerService:
    async def install(self, spec: dict[str, Any]) -> ToolInstallResult:
        strategy = str(spec.get("strategy") or "").strip()
        if strategy != "systemCommand":
            return ToolInstallResult(False, f"Unsupported install strategy: {strategy}", [])

        command = str(spec.get("command") or "").strip()
        args = [str(arg) for arg in (spec.get("args") or [])]
        if not command:
            return ToolInstallResult(False, "Install command is empty.", [])
        if not self._platform_allowed(spec):
            return ToolInstallResult(False, f"Install is not allowed on {sys.platform}.", [command, *args])

        full_command = [command, *args]
        if self._is_dangerous(full_command):
            return ToolInstallResult(False, "Install command is not allowed by safety policy.", full_command)

        try:
            process = await asyncio.create_subprocess_exec(
                *full_command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=os.getcwd(),
            )
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=180.0)
        except TimeoutError:
            return ToolInstallResult(False, "Install command timed out.", full_command)
        except FileNotFoundError:
            return ToolInstallResult(False, f"Install command not found: {command}", full_command)
        except Exception as exc:
            return ToolInstallResult(False, f"Install command failed: {exc}", full_command)

        out = stdout.decode("utf-8", errors="replace")
        err = stderr.decode("utf-8", errors="replace")
        if process.returncode != 0:
            return ToolInstallResult(
                False,
                f"Install exited with code {process.returncode}.",
                full_command,
                out,
                err,
            )
        return ToolInstallResult(True, "Tool installed.", full_command, out, err)

    @staticmethod
    def _platform_allowed(spec: dict[str, Any]) -> bool:
        platforms = [str(item).lower() for item in (spec.get("platforms") or [])]
        if not platforms:
            return True
        current = "windows" if sys.platform.startswith("win") else "darwin" if sys.platform == "darwin" else "linux"
        return current in platforms

    @staticmethod
    def _is_dangerous(command: list[str]) -> bool:
        forbidden = {"sh", "bash", "zsh", "fish", "cmd", "powershell", "pwsh", "curl", "wget"}
        executable = os.path.basename(command[0]).lower() if command else ""
        if executable in forbidden:
            return True
        joined = " ".join(command)
        return any(token in joined for token in ("|", "&&", ";", "`", "$("))
