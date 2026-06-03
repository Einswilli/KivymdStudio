from __future__ import annotations

import os
import shutil
import subprocess
import fnmatch
from dataclasses import dataclass
from typing import Any

from PySide6.QtGui import QGuiApplication

from app.core.async_tasks import schedule
from app.core.events import EventBus


@dataclass
class FileOperationResult:
    ok: bool
    message: str = ""
    path: str = ""
    data: dict[str, Any] | None = None

    def to_dict(self) -> dict:
        payload = {"ok": self.ok, "message": self.message, "path": self.path}
        if self.data:
            payload.update(self.data)
        return payload


class FileOperationsService:
    def __init__(self, events: EventBus):
        self._events = events
        self._clipboard_path = ""
        self._clipboard_cut = False
        self._formatters: list[dict[str, Any]] = []
        self._default_formatter_by_language: dict[str, str] = {}
        self._default_formatter_by_extension: dict[str, str] = {}
        self._exclude_patterns: list[str] = []
        self._show_hidden = False

    def configure_listing(
        self,
        exclude_patterns: list[str] | None = None,
        show_hidden: bool = False,
    ) -> None:
        self._exclude_patterns = [str(item).strip() for item in (exclude_patterns or []) if str(item).strip()]
        self._show_hidden = bool(show_hidden)

    def configure_formatters(
        self,
        formatters: list[dict[str, Any]] | None = None,
        default_by_language: dict[str, str] | None = None,
        default_by_extension: dict[str, str] | None = None,
    ) -> None:
        self._formatters = [dict(item) for item in (formatters or [])]
        self._default_formatter_by_language = {
            str(key).lower(): str(value)
            for key, value in (default_by_language or {}).items()
            if value
        }
        self._default_formatter_by_extension = {
            self._normalize_extension(key): str(value)
            for key, value in (default_by_extension or {}).items()
            if value
        }

    def list_folder(self, path: str) -> list[dict]:
        folder = self.safe_path(path)
        if not os.path.isdir(folder):
            return []
        entries = []
        try:
            for entry in os.listdir(folder):
                if self._is_excluded(entry):
                    continue
                full = os.path.join(folder, entry)
                is_dir = os.path.isdir(full)
                entries.append({
                    "name": entry,
                    "path": full,
                    "isDir": is_dir,
                    "extension": entry.rsplit(".", 1)[-1] if not is_dir and "." in entry else "",
                })
        except PermissionError:
            return []
        return sorted(entries, key=lambda item: (not item["isDir"], item["name"].lower()))

    def _is_excluded(self, name: str) -> bool:
        if not self._show_hidden and name.startswith("."):
            return True
        return any(fnmatch.fnmatch(name, pattern) for pattern in self._exclude_patterns)

    def is_dir(self, path: str) -> bool:
        return os.path.isdir(self.safe_path(path))

    def read_file(self, path: str) -> str:
        try:
            with open(self.safe_path(path), "r", encoding="utf-8") as file:
                return file.read()
        except Exception:
            return ""

    def notify_file_opened(self, path: str) -> None:
        target = self.safe_path(path)
        if os.path.isfile(target):
            self._emit("file:opened", path=target, parent=os.path.dirname(target), name=os.path.basename(target))

    def create_file(self, parent: str, name: str) -> dict:
        parent = self.safe_path(parent)
        name = os.path.basename(name.strip())
        if not parent or not os.path.isdir(parent):
            return self._result(False, "Invalid parent folder").to_dict()
        if not name:
            return self._result(False, "File name is required").to_dict()
        path = os.path.join(parent, name)
        if os.path.exists(path):
            return self._result(False, "A file or folder already exists with this name", path).to_dict()
        payload = {"path": path, "parent": parent, "name": name, "type": "file"}
        blocked = self._will("file:willCreate", payload)
        if blocked:
            return blocked.to_dict()
        try:
            with open(path, "x", encoding="utf-8"):
                pass
            self._emit("file:created", **payload)
            return self._result(True, "File created", path).to_dict()
        except Exception as exc:
            self._emit("file:createFailed", **payload, error=str(exc))
            return self._result(False, str(exc), path).to_dict()

    def create_folder(self, parent: str, name: str) -> dict:
        parent = self.safe_path(parent)
        name = os.path.basename(name.strip())
        if not parent or not os.path.isdir(parent):
            return self._result(False, "Invalid parent folder").to_dict()
        if not name:
            return self._result(False, "Folder name is required").to_dict()
        path = os.path.join(parent, name)
        if os.path.exists(path):
            return self._result(False, "A file or folder already exists with this name", path).to_dict()
        payload = {"path": path, "parent": parent, "name": name, "type": "folder"}
        blocked = self._will("folder:willCreate", payload)
        if blocked:
            return blocked.to_dict()
        try:
            os.makedirs(path, exist_ok=False)
            self._emit("folder:created", **payload)
            return self._result(True, "Folder created", path).to_dict()
        except Exception as exc:
            self._emit("folder:createFailed", **payload, error=str(exc))
            return self._result(False, str(exc), path).to_dict()

    def rename_path(self, path: str, new_name: str) -> dict:
        source = self.safe_path(path)
        new_name = os.path.basename(new_name.strip())
        if not os.path.exists(source):
            return self._result(False, "Path does not exist", source).to_dict()
        if not new_name:
            return self._result(False, "New name is required", source).to_dict()
        destination = os.path.join(os.path.dirname(source), new_name)
        if os.path.exists(destination):
            return self._result(False, "A file or folder already exists with this name", destination).to_dict()
        is_folder = os.path.isdir(source) and not os.path.islink(source)
        base_event = "folder" if is_folder else "file"
        payload = {"oldPath": source, "path": destination, "name": new_name, "type": base_event}
        blocked = self._will(f"{base_event}:willRename", payload)
        if blocked:
            return blocked.to_dict()
        try:
            os.rename(source, destination)
            self._emit(f"{base_event}:renamed", **payload)
            self._emit("path:renamed", **payload)
            return self._result(True, "Renamed", destination).to_dict()
        except Exception as exc:
            self._emit(f"{base_event}:renameFailed", **payload, error=str(exc))
            return self._result(False, str(exc), source).to_dict()

    def delete_path(self, path: str) -> dict:
        target = self.safe_path(path)
        if not os.path.exists(target):
            return self._result(False, "Path does not exist", target).to_dict()
        is_folder = os.path.isdir(target) and not os.path.islink(target)
        base_event = "folder" if is_folder else "file"
        payload = {"path": target, "type": base_event, "name": os.path.basename(target)}
        blocked = self._will(f"{base_event}:willDelete", payload)
        if blocked:
            return blocked.to_dict()
        try:
            if is_folder:
                shutil.rmtree(target)
            else:
                os.remove(target)
            self._emit(f"{base_event}:deleted", **payload)
            self._emit("path:deleted", **payload)
            return self._result(True, "Deleted", target).to_dict()
        except Exception as exc:
            self._emit(f"{base_event}:deleteFailed", **payload, error=str(exc))
            return self._result(False, str(exc), target).to_dict()

    def copy_path(self, path: str) -> dict:
        source = self.safe_path(path)
        if not os.path.exists(source):
            return self._result(False, "Path does not exist", source).to_dict()
        self._clipboard_path = source
        self._clipboard_cut = False
        base_event = "file" if os.path.isfile(source) else "folder"
        self._emit(f"{base_event}:copied", path=source)
        self._emit("path:copied", path=source)
        return self._result(True, "Copied", source).to_dict()

    def cut_path(self, path: str) -> dict:
        source = self.safe_path(path)
        if not os.path.exists(source):
            return self._result(False, "Path does not exist", source).to_dict()
        self._clipboard_path = source
        self._clipboard_cut = True
        base_event = "file" if os.path.isfile(source) else "folder"
        self._emit(f"{base_event}:cut", path=source)
        self._emit("path:cut", path=source)
        return self._result(True, "Ready to move", source).to_dict()

    def paste_into(self, folder: str) -> dict:
        destination_folder = self.safe_path(folder)
        source = self._clipboard_path
        if not source or not os.path.exists(source):
            return self._result(False, "Clipboard is empty").to_dict()
        if not os.path.isdir(destination_folder):
            return self._result(False, "Paste target is not a folder", destination_folder).to_dict()
        destination = self.unique_destination(os.path.join(destination_folder, os.path.basename(source)))
        is_folder = os.path.isdir(source) and not os.path.islink(source)
        base_event = "folder" if is_folder else "file"
        event_name = "willMove" if self._clipboard_cut else "willPaste"
        payload = {"source": source, "path": destination, "parent": destination_folder, "type": base_event}
        blocked = self._will(f"{base_event}:{event_name}", payload)
        if blocked:
            return blocked.to_dict()
        try:
            was_cut = self._clipboard_cut
            if was_cut:
                shutil.move(source, destination)
                self._clipboard_path = ""
                self._clipboard_cut = False
            elif is_folder:
                shutil.copytree(source, destination)
            else:
                shutil.copy2(source, destination)
            final_event = "moved" if was_cut else "pasted"
            self._emit(f"{base_event}:{final_event}", **payload)
            self._emit("path:moved" if was_cut else "path:pasted", **payload)
            return self._result(True, "Pasted", destination).to_dict()
        except Exception as exc:
            self._emit(f"{base_event}:pasteFailed", **payload, error=str(exc))
            return self._result(False, str(exc), destination).to_dict()

    def move_path(self, path: str, folder: str) -> dict:
        source = self.safe_path(path)
        destination_folder = self.safe_path(folder)
        if not os.path.exists(source):
            return self._result(False, "Path does not exist", source).to_dict()
        if not os.path.isdir(destination_folder):
            return self._result(False, "Move target is not a folder", destination_folder).to_dict()
        destination = self.unique_destination(os.path.join(destination_folder, os.path.basename(source)))
        is_folder = os.path.isdir(source) and not os.path.islink(source)
        base_event = "folder" if is_folder else "file"
        payload = {"source": source, "path": destination, "parent": destination_folder, "type": base_event}
        blocked = self._will(f"{base_event}:willMove", payload)
        if blocked:
            return blocked.to_dict()
        try:
            shutil.move(source, destination)
            self._emit(f"{base_event}:moved", **payload)
            self._emit("path:moved", **payload)
            return self._result(True, "Moved", destination).to_dict()
        except Exception as exc:
            self._emit(f"{base_event}:moveFailed", **payload, error=str(exc))
            return self._result(False, str(exc), destination).to_dict()

    def copy_link(self, path: str) -> dict:
        target = self.safe_path(path)
        clipboard = QGuiApplication.clipboard()
        if clipboard:
            clipboard.setText(target)
            self._emit("path:linkCopied", path=target)
            return self._result(True, "Path copied", target).to_dict()
        return self._result(False, "Clipboard unavailable", target).to_dict()

    def format_path(self, path: str, cwd: str = "", emit_events: bool = True) -> dict:
        target = self.safe_path(path)
        if not os.path.isfile(target):
            return self._result(False, "Only files can be formatted", target).to_dict()
        formatter = self._select_formatter(target)
        if not formatter:
            return self._result(False, "No formatter configured for this file type", target).to_dict()
        provider = str(formatter.get("id") or formatter.get("name") or formatter.get("label") or "formatter")
        payload = {"path": target, "provider": provider, "formatter": formatter, "type": "file"}
        if emit_events:
            blocked = self._will("file:willFormat", payload)
            if blocked:
                return blocked.to_dict()
        try:
            command = self._formatter_command(formatter, target)
            completed = subprocess.run(
                command,
                cwd=cwd or os.path.dirname(target),
                env={**os.environ, **{str(k): str(v) for k, v in dict(formatter.get("env") or {}).items()}},
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            if completed.returncode == 0:
                if emit_events:
                    self._emit("file:formatted", **payload)
                return self._result(True, "Formatted", target).to_dict()
            message = completed.stderr.strip() or completed.stdout.strip() or "Formatter failed"
            if emit_events:
                self._emit("file:formatFailed", **payload, error=message)
            return self._result(False, message, target).to_dict()
        except FileNotFoundError:
            message = f"{formatter.get('command') or provider} is not installed or not available in PATH"
            if emit_events:
                self._emit("file:formatFailed", **payload, error=message)
            return self._result(False, message, target).to_dict()
        except Exception as exc:
            if emit_events:
                self._emit("file:formatFailed", **payload, error=str(exc))
            return self._result(False, str(exc), target).to_dict()

    @staticmethod
    def safe_path(path: str) -> str:
        return os.path.abspath(os.path.expanduser(path or ""))

    @staticmethod
    def unique_destination(destination: str) -> str:
        if not os.path.exists(destination):
            return destination
        base, ext = os.path.splitext(destination)
        counter = 1
        while True:
            candidate = f"{base} copy{counter if counter > 1 else ''}{ext}"
            if not os.path.exists(candidate):
                return candidate
            counter += 1

    def _select_formatter(self, path: str) -> dict[str, Any] | None:
        extension = self._normalize_extension(os.path.splitext(path)[1])
        language = self._language_for_extension(extension)
        candidates = [
            formatter for formatter in self._formatters
            if self._formatter_matches(formatter, language, extension)
        ]
        if not candidates:
            candidates = [
                formatter for formatter in self._fallback_formatters()
                if self._formatter_matches(formatter, language, extension)
            ]
        if not candidates:
            return None
        preferred_id = (
            self._default_formatter_by_extension.get(extension)
            or self._default_formatter_by_language.get(language)
        )
        if preferred_id:
            for formatter in candidates:
                if str(formatter.get("id") or formatter.get("name") or "") == preferred_id:
                    return formatter
        return sorted(candidates, key=lambda item: (-int(item.get("priority", 500)), str(item.get("id", ""))))[0]

    @staticmethod
    def _formatter_matches(formatter: dict[str, Any], language: str, extension: str) -> bool:
        languages = {str(item).lower() for item in formatter.get("languages", [])}
        extensions = {FileOperationsService._normalize_extension(item) for item in formatter.get("extensions", [])}
        return (not languages or language in languages) and (not extensions or extension in extensions)

    @staticmethod
    def _formatter_command(formatter: dict[str, Any], path: str) -> list[str]:
        command = str(formatter.get("command") or "").strip()
        args = [str(arg).replace("{file}", path) for arg in (formatter.get("args") or [])]
        if not any(path == arg or path in arg for arg in args):
            args.append(path)
        return [command, *args]

    @staticmethod
    def _fallback_formatters() -> list[dict[str, Any]]:
        return [
            {
                "id": "core.ruff-format",
                "label": "ruff format",
                "languages": ["python"],
                "extensions": [".py", ".pyi"],
                "command": "ruff",
                "args": ["format", "{file}"],
                "priority": 100,
            },
            {
                "id": "core.rustfmt",
                "label": "rustfmt",
                "languages": ["rust"],
                "extensions": [".rs"],
                "command": "rustfmt",
                "args": ["{file}"],
                "priority": 100,
            },
        ]

    @staticmethod
    def _language_for_extension(extension: str) -> str:
        return {
            ".py": "python",
            ".pyi": "python",
            ".rs": "rust",
            ".js": "javascript",
            ".jsx": "javascript",
            ".ts": "typescript",
            ".tsx": "typescript",
            ".json": "json",
            ".toml": "toml",
            ".yaml": "yaml",
            ".yml": "yaml",
            ".qml": "qml",
        }.get(extension, extension.lstrip("."))

    @staticmethod
    def _normalize_extension(extension: str) -> str:
        value = str(extension or "").strip().lower()
        if not value:
            return ""
        return value if value.startswith(".") else f".{value}"

    def _will(self, event: str, payload: dict[str, Any]) -> FileOperationResult | None:
        responses = self._events.emit_collect_now(event, **payload)
        for response in responses:
            if isinstance(response, dict) and response.get("ok") is False:
                return self._result(False, str(response.get("message") or "Operation blocked"), str(payload.get("path") or ""))
        return None

    def _emit(self, event: str, **payload) -> None:
        schedule(self._events.emit(event, **payload))

    @staticmethod
    def _result(ok: bool, message: str = "", path: str = "") -> FileOperationResult:
        return FileOperationResult(ok=ok, message=message, path=path)
