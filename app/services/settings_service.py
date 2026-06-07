from __future__ import annotations

import json
import os
from copy import deepcopy
from pathlib import Path
from typing import Any

from app.core.settings import PATHS


DEFAULT_CONFIG: dict[str, Any] = {
    "ui": {
        "fontFamily": "Arial",
        "fontSize": 12,
    },
    "editor": {
        "fontFamily": "Menlo",
        "fontSize": 12,
        "lineSpacing": 6,
        "tabSize": 4,
        "wordWrap": False,
        "autoSave": {"enabled": False, "delayMs": 1200},
        "trimTrailingWhitespace": True,
        "insertFinalNewline": True,
        "rulers": [80, 100],
        "hoverDelayMs": 1000,
        "minimap": {"enabled": True, "width": 96, "diagnostics": True},
        "suggestions": {"auto": True, "delayMs": 260, "detailsOnSpace": True},
        "diagnostics": {"delayMs": 1600},
        "symbols": {"delayMs": 1400},
    },
    "workbench": {
        "activityBar": {"visible": True},
        "sidebar": {"visible": True, "width": 280},
        "panel": {"visible": False, "height": 240},
        "rightPanel": {"visible": False, "width": 320},
    },
    "terminal": {
        "shell": "",
        "cwdMode": "project",
        "fontFamily": "Menlo",
        "fontSize": 12,
        "cursorStyle": "block",
        "scrollback": 3000,
        "restoreSessions": True,
        "sessions": [],
        "activeSession": 0,
    },
    "files": {
        "formatOnSave": False,
        "restoreWorkspace": True,
        "watcher": {"enabled": True},
        "showHidden": False,
        "confirmDelete": True,
        "exclude": [
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
        ],
        "defaultFormatterByLanguage": {
            "python": "python.ruff-format",
            "rust": "rust.rustfmt",
        },
        "defaultFormatterByExtension": {
            ".py": "python.ruff-format",
            ".pyi": "python.ruff-format",
            ".rs": "rust.rustfmt",
        },
    },
    "appearance": {
        "theme": "Ember Dark",
        "providers": {
            "colors": "ember-default-theme",
            "editor": "ember-default-theme",
            "icons": "ember-default-theme",
            "fileIcons": "ember-file-icons",
            "fonts": "core",
            "borders": "ember-default-theme",
        },
        "themeOverrides": {},
        "tokenColorOverrides": {},
    },
    "language": {
        "lsp": {
            "enabled": True,
            "python": {"servers": ["ty", "ruff"]},
            "providers": {
                "python": ["python.ty", "python.ruff"],
            },
            "providerConfigs": {},
        },
        "formatOnSave": False,
        "diagnosticsOnType": True,
    },
    "ai": {
        "inlineSuggestions": True,
        "provider": "ollama",
        "model": "codellama:7b",
        "endpoint": "http://localhost:11434",
        "temperature": 0.2,
        "maxTokens": 1024,
        "cache": True,
        "contextChars": 4000,
        "providerConfigs": {
            "ollama": {
                "endpoint": "http://localhost:11434",
                "model": "codellama:7b",
                "temperature": 0.2,
                "maxTokens": 1024,
            },
            "openai": {
                "endpoint": "https://api.openai.com/v1",
                "model": "gpt-4.1-mini",
                "temperature": 0.2,
                "maxTokens": 1024,
            },
            "custom": {
                "endpoint": "",
                "model": "",
                "temperature": 0.2,
                "maxTokens": 1024,
            },
        },
    },
    "search": {
        "provider": "ember.search.ripgrep",
        "caseSensitive": False,
        "regex": False,
        "includeHidden": False,
        "maxResults": 500,
        "maxFileSize": 512000,
    },
    "extensions": {
        "enabled": True,
        "autoActivate": True,
        "allowUserPlugins": True,
        "allowNetworkInstall": False,
        "marketplace": {
            "enabled": True,
            "apiUrl": "http://127.0.0.1:9865/api/marketplace",
            "localSources": [],
        },
        "iconOverrides": {},
    },
    "keybindings": {
        "overrides": {},
        "custom": [],
    },
}


class SettingsService:
    def __init__(self, project_path: str = "") -> None:
        self._project_path = ""
        self.set_project_path(project_path)

    @property
    def project_path(self) -> str:
        return self._project_path

    @property
    def global_config_path(self) -> Path:
        return Path(PATHS["CONFIG_FILE"])

    @property
    def project_config_path(self) -> Path | None:
        if not self._project_path:
            return None
        return Path(self._project_path) / ".ember" / "config.json"

    def set_project_path(self, path: str) -> None:
        clean = os.path.abspath(os.path.expanduser(path)) if path else ""
        self._project_path = clean if clean and os.path.isdir(clean) else ""

    def load(self) -> dict[str, Any]:
        config = deepcopy(DEFAULT_CONFIG)
        config = deep_merge(config, self._read_json(self.global_config_path))
        project_path = self.project_config_path
        if project_path:
            config = deep_merge(config, self._read_json(project_path))
        self._normalize_appearance_providers(config)
        return config

    def save_global(self, patch: dict[str, Any]) -> dict[str, Any]:
        current = self._read_json(self.global_config_path)
        merged = deep_merge(current, patch)
        self._write_json(self.global_config_path, merged)
        return self.load()

    def save_project(self, patch: dict[str, Any]) -> dict[str, Any]:
        project_path = self.project_config_path
        if not project_path:
            return self.save_global(patch)
        current = self._read_json(project_path)
        merged = deep_merge(current, patch)
        self._write_json(project_path, merged)
        return self.load()

    def read_global(self) -> dict[str, Any]:
        return self._read_json(self.global_config_path)

    def read_project(self) -> dict[str, Any]:
        return self._read_json(self.project_config_path)

    def replace_global(self, data: dict[str, Any]) -> dict[str, Any]:
        self._write_json(self.global_config_path, data)
        return self.load()

    def replace_project(self, data: dict[str, Any]) -> dict[str, Any]:
        project_path = self.project_config_path
        if not project_path:
            return self.replace_global(data)
        self._write_json(project_path, data)
        return self.load()

    @staticmethod
    def get(config: dict[str, Any], dotted_key: str, default: Any = None) -> Any:
        value: Any = config
        for part in dotted_key.split("."):
            if not isinstance(value, dict) or part not in value:
                return default
            value = value[part]
        return value

    @staticmethod
    def patch_for(dotted_key: str, value: Any) -> dict[str, Any]:
        parts = dotted_key.split(".")
        root: dict[str, Any] = {}
        cursor = root
        for part in parts[:-1]:
            cursor[part] = {}
            cursor = cursor[part]
        cursor[parts[-1]] = value
        return root

    @staticmethod
    def _normalize_appearance_providers(config: dict[str, Any]) -> None:
        appearance = config.setdefault("appearance", {})
        if not isinstance(appearance, dict):
            return
        providers = appearance.setdefault("providers", {})
        if not isinstance(providers, dict):
            return
        if providers.get("fileIcons") == "ember-default-theme":
            providers["fileIcons"] = "ember-file-icons"

    @staticmethod
    def _read_json(path: Path | None) -> dict[str, Any]:
        if not path or not path.exists():
            return {}
        try:
            with path.open("r", encoding="utf-8") as file:
                data = json.load(file)
            return data if isinstance(data, dict) else {}
        except Exception as exc:
            print(f"[SettingsService] Could not read {path}: {exc}")
            return {}

    @staticmethod
    def _write_json(path: Path, data: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8") as file:
            json.dump(data, file, indent=2, ensure_ascii=False)
            file.write("\n")


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    result = deepcopy(base)
    for key, value in (override or {}).items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = deepcopy(value)
    return result
