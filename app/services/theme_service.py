from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path
from typing import Any

from app.core.settings import DEFAULT_THEME, PATHS
from app.services.settings_service import SettingsService, deep_merge


DEFAULT_TOKEN_COLORS: dict[str, str] = {
    "comment": "#6A9955",
    "string": "#CE9178",
    "number": "#B5CEA8",
    "keyword": "#569CD6",
    "function": "#DCDCAA",
    "class": "#4EC9B0",
    "decorator": "#C586C0",
    "type": "#4EC9B0",
    "tag": "#569CD6",
    "attribute": "#9CDCFE",
    "selector": "#D7BA7D",
    "value": "#CE9178",
    "operator": "#D4D4D4",
    "identifier": "#9CDCFE",
    "module": "#C586C0",
    "variable": "#9CDCFE",
    "parameter": "#9CDCFE",
    "property": "#9CDCFE",
    "builtin": "#DCDCAA",
    "default": "#D4D4D4",
}


BUILTIN_THEMES: list[dict[str, Any]] = [
    {
        **DEFAULT_THEME,
        "tokenColors": DEFAULT_TOKEN_COLORS,
    },
    {
        "name": "Ember Light",
        "type": "light",
        "colors": {
            "editor.background": "#FFFFFF",
            "editor.foreground": "#24292F",
            "editor.lineHighlight": "#F6F8FA",
            "editor.selection": "#BBDFFF",
            "editor.cursor": "#24292F",
            "editor.lineNumbers": "#8C959F",
            "editor.activeLineNumber": "#24292F",
            "sidebar.background": "#F6F8FA",
            "sidebar.foreground": "#24292F",
            "sidebar.selection": "#EAEEF2",
            "tab.activeBackground": "#FFFFFF",
            "tab.activeForeground": "#24292F",
            "tab.inactiveBackground": "#F6F8FA",
            "tab.inactiveForeground": "#6E7781",
            "titleBar.background": "#F6F8FA",
            "titleBar.foreground": "#24292F",
            "statusBar.background": "#0969DA",
            "statusBar.foreground": "#FFFFFF",
            "panel.background": "#FFFFFF",
            "panel.border": "#D0D7DE",
            "terminal.background": "#FFFFFF",
            "terminal.foreground": "#24292F",
            "button.primary": "#0969DA",
            "button.hover": "#218BFF",
            "scrollbar.background": "#FFFFFF",
            "scrollbar.thumb": "#D0D7DE",
            "scrollbar.hover": "#AFB8C1",
        },
        "tokenColors": {
            **DEFAULT_TOKEN_COLORS,
            "comment": "#6A737D",
            "string": "#032F62",
            "number": "#005CC5",
            "keyword": "#D73A49",
            "function": "#6F42C1",
            "class": "#22863A",
            "type": "#22863A",
            "module": "#005CC5",
            "builtin": "#005CC5",
            "default": "#24292F",
        },
    },
    {
        "name": "One Dark",
        "type": "dark",
        "colors": {
            **DEFAULT_THEME["colors"],
            "editor.background": "#282C34",
            "editor.foreground": "#ABB2BF",
            "editor.lineHighlight": "#2C313C",
            "editor.selection": "#3E4451",
            "sidebar.background": "#21252B",
            "tab.activeBackground": "#282C34",
            "tab.inactiveBackground": "#21252B",
            "titleBar.background": "#21252B",
            "panel.background": "#282C34",
            "panel.border": "#181A1F",
            "button.primary": "#61AFEF",
            "button.hover": "#528BFF",
        },
        "tokenColors": {
            **DEFAULT_TOKEN_COLORS,
            "comment": "#5C6370",
            "string": "#98C379",
            "number": "#D19A66",
            "keyword": "#C678DD",
            "function": "#61AFEF",
            "class": "#E5C07B",
            "type": "#E5C07B",
            "module": "#56B6C2",
            "builtin": "#56B6C2",
            "default": "#ABB2BF",
        },
    },
]


class ThemeService:
    def __init__(self, settings: SettingsService | None = None):
        self._settings = settings or SettingsService()

    def set_project_path(self, path: str) -> None:
        self._settings.set_project_path(path)

    def list_themes(self) -> list[str]:
        return [theme["name"] for theme in self._all_themes()]

    def resolve(self, config: dict[str, Any] | None = None) -> dict[str, Any]:
        effective = config or self._settings.load()
        name = SettingsService.get(effective, "appearance.theme", DEFAULT_THEME["name"])
        providers = SettingsService.get(effective, "appearance.providers", {}) or {}
        global_overrides = SettingsService.get(effective, "appearance.themeOverrides", {}) or {}
        token_overrides = SettingsService.get(effective, "appearance.tokenColorOverrides", {}) or {}
        theme = self.load_theme(name, providers.get("colors") or providers.get("editor"))
        colors = deep_merge(DEFAULT_THEME["colors"], theme.get("colors", {}))
        colors = deep_merge(colors, global_overrides)
        token_theme = self.load_theme(name, providers.get("editor") or providers.get("colors"))
        token_colors = deep_merge(DEFAULT_TOKEN_COLORS, token_theme.get("tokenColors", {}))
        token_colors = deep_merge(token_colors, token_overrides)
        return {
            "name": theme.get("name", DEFAULT_THEME["name"]),
            "type": theme.get("type", "dark"),
            "providers": providers,
            "colors": colors,
            "tokenColors": token_colors,
        }

    def load_theme(self, name: str | None = None, provider: str | None = None) -> dict[str, Any]:
        target = name or DEFAULT_THEME["name"]
        for theme in self._all_themes():
            if provider and theme.get("plugin") != provider:
                continue
            if theme.get("name") == target:
                return deepcopy(theme)
        if provider:
            for theme in self._all_themes():
                if theme.get("plugin") == provider:
                    return deepcopy(theme)
        return deepcopy(BUILTIN_THEMES[0])

    def save_to_file(self, theme: dict[str, Any]) -> None:
        if not theme.get("name"):
            raise ValueError("Theme must define a name.")
        path = Path(PATHS["THEME_CONFIG"])
        path.parent.mkdir(parents=True, exist_ok=True)
        themes = self._custom_themes()
        for index, existing in enumerate(themes):
            if existing.get("name") == theme["name"]:
                themes[index] = theme
                break
        else:
            themes.append(theme)
        path.write_text(json.dumps(themes, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    def _all_themes(self) -> list[dict[str, Any]]:
        themes: list[dict[str, Any]] = []
        existing: set[str] = set()
        for theme in [*self._plugin_themes(), *self._custom_themes(), *BUILTIN_THEMES]:
            name = theme.get("name")
            if name and name not in existing:
                themes.append(deepcopy(theme))
                existing.add(name)
        return themes

    @staticmethod
    def _plugin_themes() -> list[dict[str, Any]]:
        roots = [
            Path(PATHS["PLUGINS"]),
            Path.cwd() / "plugins",
            Path(PATHS["PLUGINS"]) / "python",
            Path.cwd() / "plugins" / "python",
        ]
        themes: list[dict[str, Any]] = []
        for root in roots:
            if not root.exists():
                continue
            for plugin_dir in root.iterdir():
                manifest_path = plugin_dir / "manifest.json"
                if not manifest_path.exists():
                    continue
                try:
                    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                except Exception:
                    continue
                for contribution in manifest.get("contributes", {}).get("themes", []):
                    theme_path = contribution.get("path", "")
                    if not theme_path:
                        continue
                    path = Path(theme_path)
                    if not path.is_absolute():
                        path = plugin_dir / theme_path
                    if not path.exists():
                        continue
                    try:
                        theme = json.loads(path.read_text(encoding="utf-8"))
                    except Exception as exc:
                        print(f"[ThemeService] Could not read plugin theme {path}: {exc}")
                        continue
                    if isinstance(theme, dict) and theme.get("name") and theme.get("colors"):
                        theme.setdefault("plugin", manifest.get("name", plugin_dir.name))
                        themes.append(theme)
        return themes

    @staticmethod
    def _custom_themes() -> list[dict[str, Any]]:
        path = Path(PATHS["THEME_CONFIG"])
        if not path.exists():
            return []
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            print(f"[ThemeService] Could not read {path}: {exc}")
            return []
        return data if isinstance(data, list) else []
