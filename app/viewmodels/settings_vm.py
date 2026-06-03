from __future__ import annotations

import json
import re
import shutil
from uuid import uuid4
from PySide6.QtCore import QObject, Signal, Slot, Property
from app.core.events import EventBus
from app.core.async_tasks import schedule
from app.services.settings_service import SettingsService
from app.services.theme_service import ThemeService
from app.services.tool_installer_service import ToolInstallerService


class SettingsViewModel(QObject):
    themeChanged = Signal("QVariantMap")
    fontChanged = Signal(str, int)
    editorMetricsChanged = Signal()
    workbenchChanged = Signal()
    keybindingsChanged = Signal()
    configChanged = Signal("QVariantMap")
    aiModelsChanged = Signal(str, "QVariantList")
    aiModelsRevisionChanged = Signal()
    toolInstallAuditsChanged = Signal()
    searchChanged = Signal()
    searchConfigChanged = Signal("QVariantMap")

    def __init__(self, events: EventBus, parent: QObject | None = None):
        super().__init__(parent)
        self._events = events
        self._settings = SettingsService()
        self._theme_service = ThemeService(self._settings)
        self._config = self._settings.load()
        self._resolved_theme = self._theme_service.resolve(self._config)
        self._current_theme = str(self._resolved_theme["name"])
        self._theme_colors: dict[str, str] = dict(self._resolved_theme["colors"])
        self._token_colors: dict[str, str] = dict(self._resolved_theme["tokenColors"])
        self._font_family = self._clean_font_family(str(self._get("editor.fontFamily", "Menlo")), "Menlo")
        self._font_size = int(self._get("editor.fontSize", 12))
        self._ui_font_family = self._clean_font_family(str(self._get("ui.fontFamily", "Arial")), "Arial")
        self._ui_font_size = int(self._get("ui.fontSize", 12))
        self._editor_line_spacing = int(self._get("editor.lineSpacing", 6))
        self._tab_size = int(self._get("editor.tabSize", 4))
        self._auto_save_enabled = bool(self._get("editor.autoSave.enabled", False))
        self._auto_save_delay_ms = int(self._get("editor.autoSave.delayMs", 1200))
        self._trim_trailing_whitespace = bool(self._get("editor.trimTrailingWhitespace", True))
        self._insert_final_newline = bool(self._get("editor.insertFinalNewline", True))
        self._rulers = list(self._get("editor.rulers", [80, 100]) or [])
        self._hover_delay_ms = int(self._get("editor.hoverDelayMs", 1000))
        self._minimap_enabled = bool(self._get("editor.minimap.enabled", True))
        self._minimap_width = int(self._get("editor.minimap.width", 96))
        self._minimap_diagnostics = bool(self._get("editor.minimap.diagnostics", True))
        self._word_wrap = bool(self._get("editor.wordWrap", False))
        self._suggestions_auto = bool(self._get("editor.suggestions.auto", True))
        self._suggestions_delay_ms = int(self._get("editor.suggestions.delayMs", 260))
        self._suggestions_details_on_space = bool(
            self._get("editor.suggestions.detailsOnSpace", True)
        )
        self._diagnostics_delay_ms = int(self._get("editor.diagnostics.delayMs", 1600))
        self._symbols_delay_ms = int(self._get("editor.symbols.delayMs", 1400))
        self._lsp_enabled = bool(self._get("language.lsp.enabled", True))
        self._diagnostics_on_type = bool(self._get("language.diagnosticsOnType", True))
        self._python_lsp_servers = list(self._get("language.lsp.python.servers", ["ty", "ruff"]))
        self._lsp_providers_by_language = dict(
            self._get("language.lsp.providers", {"python": ["python.ty", "python.ruff"]}) or {}
        )
        self._lsp_provider_configs = dict(self._get("language.lsp.providerConfigs", {}) or {})
        self._format_on_save = bool(
            self._get("files.formatOnSave", self._get("language.formatOnSave", False))
        )
        self._files_restore_workspace = bool(self._get("files.restoreWorkspace", True))
        self._files_watcher_enabled = bool(self._get("files.watcher.enabled", True))
        self._files_show_hidden = bool(self._get("files.showHidden", False))
        self._files_confirm_delete = bool(self._get("files.confirmDelete", True))
        self._files_exclude = list(self._get("files.exclude", []) or [])
        self._default_formatter_by_language = dict(
            self._get("files.defaultFormatterByLanguage", {}) or {}
        )
        self._default_formatter_by_extension = dict(
            self._get("files.defaultFormatterByExtension", {}) or {}
        )
        self._ai_inline_suggestions = bool(self._get("ai.inlineSuggestions", True))
        self._ai_provider = str(self._get("ai.provider", "ollama"))
        self._ai_model = str(self._get("ai.model", "codellama:7b"))
        self._ai_endpoint = str(self._get("ai.endpoint", "http://localhost:11434"))
        self._ai_temperature = float(self._get("ai.temperature", 0.2))
        self._ai_max_tokens = int(self._get("ai.maxTokens", 1024))
        self._ai_cache = bool(self._get("ai.cache", True))
        self._ai_context_chars = int(self._get("ai.contextChars", 4000))
        self._ai_provider_configs = dict(self._get("ai.providerConfigs", {}) or {})
        self._search_provider = str(self._get("search.provider", "ember.search.ripgrep"))
        self._search_case_sensitive = bool(self._get("search.caseSensitive", False))
        self._search_regex = bool(self._get("search.regex", False))
        self._search_include_hidden = bool(self._get("search.includeHidden", False))
        self._search_max_results = int(self._get("search.maxResults", 500))
        self._search_max_file_size = int(self._get("search.maxFileSize", 512000))
        self._extensions_enabled = bool(self._get("extensions.enabled", True))
        self._extensions_auto_activate = bool(self._get("extensions.autoActivate", True))
        self._extensions_allow_user_plugins = bool(self._get("extensions.allowUserPlugins", True))
        self._extensions_allow_network_install = bool(
            self._get("extensions.allowNetworkInstall", False)
        )
        self._extensions_marketplace_api_url = str(
            self._get(
                "extensions.marketplace.apiUrl",
                "http://127.0.0.1:9865/api/marketplace",
            )
        )
        self._extensions_marketplace_local_sources = list(
            self._get("extensions.marketplace.localSources", [])
        )
        self._activity_bar_visible = bool(self._get("workbench.activityBar.visible", True))
        self._sidebar_visible = bool(self._get("workbench.sidebar.visible", True))
        self._sidebar_width = int(self._get("workbench.sidebar.width", 280))
        self._panel_visible = bool(self._get("workbench.panel.visible", False))
        self._panel_height = int(self._get("workbench.panel.height", 240))
        self._right_panel_visible = bool(self._get("workbench.rightPanel.visible", False))
        self._right_panel_width = int(self._get("workbench.rightPanel.width", 320))
        self._available_themes: list[dict] = []
        self._ai_provider_models: dict[str, list[str]] = {}
        self._ai_models_revision = 0
        self._notification_vm = None
        self._tool_installer = ToolInstallerService()
        self._tool_install_audits: list[dict] = []

    def set_notification_vm(self, notification_vm) -> None:
        self._notification_vm = notification_vm

    @Property("QVariantMap", notify=configChanged)
    def config(self) -> dict:
        return dict(self._config)

    @Property(str, notify=configChanged)
    def globalConfigPath(self) -> str:
        return str(self._settings.global_config_path)

    @Property(str, notify=configChanged)
    def projectConfigPath(self) -> str:
        path = self._settings.project_config_path
        return str(path) if path else ""

    @property
    def settings_service(self) -> SettingsService:
        return self._settings

    @Slot(result="QVariantMap")
    def getConfig(self) -> dict:
        return dict(self._config)

    @Slot(result=str)
    def globalConfigJson(self) -> str:
        return json.dumps(self._settings.read_global(), indent=2, ensure_ascii=False)

    @Slot(result=str)
    def projectConfigJson(self) -> str:
        return json.dumps(self._settings.read_project(), indent=2, ensure_ascii=False)

    @Slot(result=str)
    def defaultConfigJson(self) -> str:
        from app.services.settings_service import DEFAULT_CONFIG

        return json.dumps(DEFAULT_CONFIG, indent=2, ensure_ascii=False)

    @Slot(str, result=str)
    def validateConfigJson(self, content: str) -> str:
        try:
            data = json.loads(content or "{}")
        except Exception as exc:
            return f"Invalid JSON: {exc}"
        if not isinstance(data, dict):
            return "Invalid config: root value must be a JSON object."
        return "Valid JSON object."

    @Slot(str, result=str)
    def saveGlobalConfigJson(self, content: str) -> str:
        try:
            data = json.loads(content or "{}")
            if not isinstance(data, dict):
                return "Invalid global config: root value must be a JSON object."
            self._config = self._settings.replace_global(data)
            self.reload()
            return "Global config saved."
        except Exception as exc:
            return f"Could not save global config: {exc}"

    @Slot(str, result=str)
    def saveProjectConfigJson(self, content: str) -> str:
        if not self._settings.project_config_path:
            return "No active workspace config. Open a project before saving project overrides."
        try:
            data = json.loads(content or "{}")
            if not isinstance(data, dict):
                return "Invalid project config: root value must be a JSON object."
            self._config = self._settings.replace_project(data)
            self.reload()
            return "Project config saved."
        except Exception as exc:
            return f"Could not save project config: {exc}"

    @Slot(str)
    def setProjectPath(self, path: str) -> None:
        self._settings.set_project_path(path)
        self._theme_service.set_project_path(path)
        self.reload()

    @Slot()
    def reload(self) -> None:
        self._config = self._settings.load()
        self._font_family = self._clean_font_family(str(self._get("editor.fontFamily", self._font_family)), "Menlo")
        self._font_size = int(self._get("editor.fontSize", self._font_size))
        self._ui_font_family = self._clean_font_family(str(self._get("ui.fontFamily", self._ui_font_family)), "Arial")
        self._ui_font_size = int(self._get("ui.fontSize", self._ui_font_size))
        self._editor_line_spacing = int(self._get("editor.lineSpacing", self._editor_line_spacing))
        self._tab_size = int(self._get("editor.tabSize", self._tab_size))
        self._auto_save_enabled = bool(
            self._get("editor.autoSave.enabled", self._auto_save_enabled)
        )
        self._auto_save_delay_ms = int(
            self._get("editor.autoSave.delayMs", self._auto_save_delay_ms)
        )
        self._trim_trailing_whitespace = bool(
            self._get("editor.trimTrailingWhitespace", self._trim_trailing_whitespace)
        )
        self._insert_final_newline = bool(
            self._get("editor.insertFinalNewline", self._insert_final_newline)
        )
        self._rulers = list(self._get("editor.rulers", self._rulers) or [])
        self._hover_delay_ms = int(self._get("editor.hoverDelayMs", self._hover_delay_ms))
        self._minimap_enabled = bool(self._get("editor.minimap.enabled", self._minimap_enabled))
        self._minimap_width = int(self._get("editor.minimap.width", self._minimap_width))
        self._minimap_diagnostics = bool(
            self._get("editor.minimap.diagnostics", self._minimap_diagnostics)
        )
        self._word_wrap = bool(self._get("editor.wordWrap", self._word_wrap))
        self._suggestions_auto = bool(
            self._get("editor.suggestions.auto", self._suggestions_auto)
        )
        self._suggestions_delay_ms = int(
            self._get("editor.suggestions.delayMs", self._suggestions_delay_ms)
        )
        self._suggestions_details_on_space = bool(
            self._get(
                "editor.suggestions.detailsOnSpace",
                self._suggestions_details_on_space,
            )
        )
        self._diagnostics_delay_ms = int(
            self._get("editor.diagnostics.delayMs", self._diagnostics_delay_ms)
        )
        self._symbols_delay_ms = int(self._get("editor.symbols.delayMs", self._symbols_delay_ms))
        self._lsp_enabled = bool(self._get("language.lsp.enabled", self._lsp_enabled))
        self._diagnostics_on_type = bool(
            self._get("language.diagnosticsOnType", self._diagnostics_on_type)
        )
        self._python_lsp_servers = list(
            self._get("language.lsp.python.servers", self._python_lsp_servers)
        )
        self._lsp_providers_by_language = dict(
            self._get("language.lsp.providers", self._lsp_providers_by_language) or {}
        )
        self._lsp_provider_configs = dict(
            self._get("language.lsp.providerConfigs", self._lsp_provider_configs) or {}
        )
        self._format_on_save = bool(
            self._get("files.formatOnSave", self._get("language.formatOnSave", self._format_on_save))
        )
        self._files_restore_workspace = bool(
            self._get("files.restoreWorkspace", self._files_restore_workspace)
        )
        self._files_watcher_enabled = bool(
            self._get("files.watcher.enabled", self._files_watcher_enabled)
        )
        self._files_show_hidden = bool(self._get("files.showHidden", self._files_show_hidden))
        self._files_confirm_delete = bool(
            self._get("files.confirmDelete", self._files_confirm_delete)
        )
        self._files_exclude = list(self._get("files.exclude", self._files_exclude) or [])
        self._default_formatter_by_language = dict(
            self._get("files.defaultFormatterByLanguage", self._default_formatter_by_language) or {}
        )
        self._default_formatter_by_extension = dict(
            self._get("files.defaultFormatterByExtension", self._default_formatter_by_extension) or {}
        )
        self._ai_inline_suggestions = bool(
            self._get("ai.inlineSuggestions", self._ai_inline_suggestions)
        )
        self._ai_provider = str(self._get("ai.provider", self._ai_provider))
        self._ai_model = str(self._get("ai.model", self._ai_model))
        self._ai_endpoint = str(self._get("ai.endpoint", self._ai_endpoint))
        self._ai_temperature = float(self._get("ai.temperature", self._ai_temperature))
        self._ai_max_tokens = int(self._get("ai.maxTokens", self._ai_max_tokens))
        self._ai_cache = bool(self._get("ai.cache", self._ai_cache))
        self._ai_context_chars = int(self._get("ai.contextChars", self._ai_context_chars))
        self._ai_provider_configs = dict(
            self._get("ai.providerConfigs", self._ai_provider_configs) or {}
        )
        self._search_provider = str(self._get("search.provider", self._search_provider))
        self._search_case_sensitive = bool(
            self._get("search.caseSensitive", self._search_case_sensitive)
        )
        self._search_regex = bool(self._get("search.regex", self._search_regex))
        self._search_include_hidden = bool(
            self._get("search.includeHidden", self._search_include_hidden)
        )
        self._search_max_results = int(self._get("search.maxResults", self._search_max_results))
        self._search_max_file_size = int(
            self._get("search.maxFileSize", self._search_max_file_size)
        )
        self._extensions_enabled = bool(self._get("extensions.enabled", self._extensions_enabled))
        self._extensions_auto_activate = bool(
            self._get("extensions.autoActivate", self._extensions_auto_activate)
        )
        self._extensions_allow_user_plugins = bool(
            self._get("extensions.allowUserPlugins", self._extensions_allow_user_plugins)
        )
        self._extensions_allow_network_install = bool(
            self._get("extensions.allowNetworkInstall", self._extensions_allow_network_install)
        )
        self._extensions_marketplace_api_url = str(
            self._get("extensions.marketplace.apiUrl", self._extensions_marketplace_api_url)
        )
        self._extensions_marketplace_local_sources = list(
            self._get(
                "extensions.marketplace.localSources",
                self._extensions_marketplace_local_sources,
            )
        )
        self._activity_bar_visible = bool(
            self._get("workbench.activityBar.visible", self._activity_bar_visible)
        )
        self._sidebar_visible = bool(self._get("workbench.sidebar.visible", self._sidebar_visible))
        self._sidebar_width = int(self._get("workbench.sidebar.width", self._sidebar_width))
        self._panel_visible = bool(self._get("workbench.panel.visible", self._panel_visible))
        self._panel_height = int(self._get("workbench.panel.height", self._panel_height))
        self._right_panel_visible = bool(
            self._get("workbench.rightPanel.visible", self._right_panel_visible)
        )
        self._right_panel_width = int(
            self._get("workbench.rightPanel.width", self._right_panel_width)
        )
        self._refresh_theme()
        self.configChanged.emit(self._config)
        self.themeChanged.emit(self._theme_colors)
        self.fontChanged.emit(self._font_family, self._font_size)
        self.editorMetricsChanged.emit()
        self.workbenchChanged.emit()
        self.keybindingsChanged.emit()

    @Slot(str, result=str)
    def getValueJson(self, key: str) -> str:
        return json.dumps(self._get(key, None))

    @Slot(str, str, bool)
    def setValueJson(self, key: str, value_json: str, project: bool = False) -> None:
        try:
            value = json.loads(value_json)
        except Exception:
            value = value_json
        patch = self._settings.patch_for(key, value)
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self.reload()

    @Slot(str, str, str, bool)
    def setKeybindingOverride(
        self,
        sequence: str,
        command: str,
        when: str = "global",
        project: bool = False,
    ) -> None:
        patch = {
            "keybindings": {
                "overrides": {
                    sequence.strip(): {
                        "command": command.strip(),
                        "when": when.strip() or "global",
                        "actionType": "command",
                    }
                }
            }
        }
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self.reload()

    @Slot(str, str, str, str, bool)
    def addCustomKeybinding(
        self,
        sequence: str,
        command: str,
        when: str = "global",
        title: str = "",
        project: bool = False,
    ) -> None:
        key = sequence.strip()
        command_id = command.strip()
        if not key or not command_id:
            return
        custom = list(self._get("keybindings.custom", []) or [])
        custom.append({
            "id": self._keybinding_id(key, command_id, when),
            "key": key,
            "command": command_id,
            "when": when.strip() or "global",
            "title": title.strip() or command_id,
            "actionType": "command",
            "payload": {},
            "disabled": False,
        })
        patch = {"keybindings": {"custom": custom}}
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self.reload()

    @Slot(str, bool, bool)
    def setCustomKeybindingDisabled(
        self,
        binding_id: str,
        disabled: bool,
        project: bool = False,
    ) -> None:
        custom = list(self._get("keybindings.custom", []) or [])
        changed = False
        for item in custom:
            if isinstance(item, dict) and str(item.get("id") or "") == binding_id:
                item["disabled"] = bool(disabled)
                changed = True
        if not changed:
            return
        patch = {"keybindings": {"custom": custom}}
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self.reload()

    @Slot(str, bool)
    def removeCustomKeybinding(self, binding_id: str, project: bool = False) -> None:
        custom = [
            item for item in (self._get("keybindings.custom", []) or [])
            if not isinstance(item, dict) or str(item.get("id") or "") != binding_id
        ]
        patch = {"keybindings": {"custom": custom}}
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self.reload()

    @Slot(str, bool)
    def clearKeybindingOverride(self, sequence: str, project: bool = False) -> None:
        overrides = dict(self._get("keybindings.overrides", {}) or {})
        overrides.pop(sequence.strip(), None)
        patch = {"keybindings": {"overrides": overrides}}
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self.reload()

    @staticmethod
    def _keybinding_id(sequence: str, command: str, when: str) -> str:
        slug = re.sub(r"[^a-zA-Z0-9]+", "-", f"{sequence}-{command}-{when}").strip("-").lower()
        return f"{slug[:48]}-{uuid4().hex[:8]}"

    def _get(self, key: str, default=None):
        return self._settings.get(self._config, key, default)

    @staticmethod
    def _clean_font_family(value: str, fallback: str) -> str:
        family = str(value or "").split(",")[0].strip().strip("\"'")
        if family.lower() in {"monospace", "serif", "sans", "sans-serif"}:
            return fallback
        return family or fallback

    @Slot(str, result="QVariant")
    def value(self, key: str):
        return self._get(key, None)

    @Slot(str, result="QVariant")
    def defaultValue(self, key: str):
        from app.services.settings_service import DEFAULT_CONFIG

        return self._settings.get(DEFAULT_CONFIG, key, None)

    # ── Theme management ──────────────────────────────────

    @Property("QVariantMap", notify=themeChanged)
    def themeColors(self) -> dict[str, str]:
        return self._theme_colors

    @Slot(result="QVariantList")
    def availableThemes(self) -> list[str]:
        return self._theme_service.list_themes()

    @Slot(str, result="QVariantMap")
    def applyTheme(self, name: str) -> dict[str, str]:
        self._config = self._settings.save_global({"appearance": {"theme": name}})
        self._refresh_theme()
        self.configChanged.emit(self._config)
        self.themeChanged.emit(self._theme_colors)
        return self._theme_colors

    @Slot(result="QVariantMap")
    def getThemeColors(self) -> dict[str, str]:
        return self._theme_colors

    @Slot(result="QVariantMap")
    def getTokenColors(self) -> dict[str, str]:
        return self._token_colors

    @Slot(result="QVariantMap")
    def getResolvedTheme(self) -> dict:
        return dict(self._resolved_theme)

    @Slot(result="QVariantMap")
    def getAppearanceProviders(self) -> dict:
        return dict(self._get("appearance.providers", {}))

    @Slot(str, str, bool)
    def setAppearanceProvider(self, aspect: str, plugin_name: str, project: bool = False) -> None:
        patch = {"appearance": {"providers": {aspect: plugin_name}}}
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self._refresh_theme()
        self.configChanged.emit(self._config)
        self.themeChanged.emit(self._theme_colors)

    @Slot(str, str, bool)
    def setThemeColorOverride(self, key: str, color: str, project: bool = False) -> None:
        patch = {"appearance": {"themeOverrides": {key: color}}}
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self._refresh_theme()
        self.configChanged.emit(self._config)
        self.themeChanged.emit(self._theme_colors)

    @Slot(str, str, bool)
    def setTokenColorOverride(self, key: str, color: str, project: bool = False) -> None:
        patch = {"appearance": {"tokenColorOverrides": {key: color}}}
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self._refresh_theme()
        self.configChanged.emit(self._config)
        self.themeChanged.emit(self._theme_colors)

    @Property(str, notify=themeChanged)
    def currentTheme(self) -> str:
        return self._current_theme

    @Property("QVariantMap", notify=themeChanged)
    def tokenColors(self) -> dict[str, str]:
        return self._token_colors

    def _refresh_theme(self) -> None:
        self._resolved_theme = self._theme_service.resolve(self._config)
        self._current_theme = str(self._resolved_theme["name"])
        self._theme_colors = dict(self._resolved_theme["colors"])
        self._token_colors = dict(self._resolved_theme["tokenColors"])

    # ── Font ─────────────────────────────────────────────

    @Slot(str, int)
    def setFont(self, family: str, size: int) -> None:
        family = self._clean_font_family(family, "Menlo")
        self._font_family = family
        self._font_size = size
        self._config = self._settings.save_global({"editor": {"fontFamily": family, "fontSize": int(size)}})
        self.reload()
        self.fontChanged.emit(family, size)

    @Property(str, notify=fontChanged)
    def fontFamily(self) -> str:
        return self._font_family

    @Property(int, notify=fontChanged)
    def fontSize(self) -> int:
        return self._font_size

    @Slot(str, int)
    def setUiFont(self, family: str, size: int) -> None:
        family = self._clean_font_family(family, "Arial")
        self._ui_font_family = family
        self._ui_font_size = int(size)
        self._config = self._settings.save_global({"ui": {"fontFamily": family, "fontSize": int(size)}})
        self.reload()
        self.fontChanged.emit(self._font_family, self._font_size)

    @Property(str, notify=fontChanged)
    def uiFontFamily(self) -> str:
        return self._ui_font_family

    @Property(int, notify=fontChanged)
    def uiFontSize(self) -> int:
        return self._ui_font_size

    @Slot(int)
    def setEditorLineSpacing(self, value: int) -> None:
        self._editor_line_spacing = max(2, min(16, int(value)))
        self._config = self._settings.save_global({"editor": {"lineSpacing": self._editor_line_spacing}})
        self.reload()

    @Property(int, notify=editorMetricsChanged)
    def editorLineSpacing(self) -> int:
        return self._editor_line_spacing

    @Slot(int)
    def setTabSize(self, value: int) -> None:
        self._tab_size = max(1, min(12, int(value)))
        self._config = self._settings.save_global({"editor": {"tabSize": self._tab_size}})
        self.reload()

    @Property(int, notify=editorMetricsChanged)
    def tabSize(self) -> int:
        return self._tab_size

    @Slot(bool)
    def setAutoSaveEnabled(self, value: bool) -> None:
        self._auto_save_enabled = bool(value)
        self._config = self._settings.save_global(
            {"editor": {"autoSave": {"enabled": self._auto_save_enabled}}}
        )
        self.reload()

    @Property(bool, notify=editorMetricsChanged)
    def autoSaveEnabled(self) -> bool:
        return self._auto_save_enabled

    @Slot(int)
    def setAutoSaveDelayMs(self, value: int) -> None:
        self._auto_save_delay_ms = max(250, min(10000, int(value)))
        self._config = self._settings.save_global(
            {"editor": {"autoSave": {"delayMs": self._auto_save_delay_ms}}}
        )
        self.reload()

    @Property(int, notify=editorMetricsChanged)
    def autoSaveDelayMs(self) -> int:
        return self._auto_save_delay_ms

    @Slot(bool)
    def setTrimTrailingWhitespace(self, value: bool) -> None:
        self._trim_trailing_whitespace = bool(value)
        self._config = self._settings.save_global(
            {"editor": {"trimTrailingWhitespace": self._trim_trailing_whitespace}}
        )
        self.reload()

    @Property(bool, notify=editorMetricsChanged)
    def trimTrailingWhitespace(self) -> bool:
        return self._trim_trailing_whitespace

    @Slot(bool)
    def setInsertFinalNewline(self, value: bool) -> None:
        self._insert_final_newline = bool(value)
        self._config = self._settings.save_global(
            {"editor": {"insertFinalNewline": self._insert_final_newline}}
        )
        self.reload()

    @Property(bool, notify=editorMetricsChanged)
    def insertFinalNewline(self) -> bool:
        return self._insert_final_newline

    @Slot(str)
    def setRulersCsv(self, value: str) -> None:
        rulers: list[int] = []
        for item in str(value or "").split(","):
            item = item.strip()
            if not item:
                continue
            try:
                rulers.append(max(1, min(240, int(item))))
            except ValueError:
                continue
        self._rulers = sorted(dict.fromkeys(rulers))
        self._config = self._settings.save_global({"editor": {"rulers": self._rulers}})
        self.reload()

    @Property(str, notify=editorMetricsChanged)
    def rulersCsv(self) -> str:
        return ", ".join(str(item) for item in self._rulers)

    @Slot(int)
    def setHoverDelayMs(self, value: int) -> None:
        self._hover_delay_ms = max(100, min(3000, int(value)))
        self._config = self._settings.save_global({"editor": {"hoverDelayMs": self._hover_delay_ms}})
        self.reload()

    @Property(int, notify=editorMetricsChanged)
    def hoverDelayMs(self) -> int:
        return self._hover_delay_ms

    @Slot(bool)
    def setMinimapEnabled(self, value: bool) -> None:
        self._minimap_enabled = bool(value)
        self._config = self._settings.save_global({"editor": {"minimap": {"enabled": self._minimap_enabled}}})
        self.reload()

    @Property(bool, notify=editorMetricsChanged)
    def minimapEnabled(self) -> bool:
        return self._minimap_enabled

    @Slot(int)
    def setMinimapWidth(self, value: int) -> None:
        self._minimap_width = max(48, min(180, int(value)))
        self._config = self._settings.save_global({"editor": {"minimap": {"width": self._minimap_width}}})
        self.reload()

    @Property(int, notify=editorMetricsChanged)
    def minimapWidth(self) -> int:
        return self._minimap_width

    @Slot(bool)
    def setMinimapDiagnostics(self, value: bool) -> None:
        self._minimap_diagnostics = bool(value)
        self._config = self._settings.save_global(
            {"editor": {"minimap": {"diagnostics": self._minimap_diagnostics}}}
        )
        self.reload()

    @Property(bool, notify=editorMetricsChanged)
    def minimapDiagnostics(self) -> bool:
        return self._minimap_diagnostics

    @Slot(bool)
    def setWordWrap(self, value: bool) -> None:
        self._word_wrap = bool(value)
        self._config = self._settings.save_global({"editor": {"wordWrap": self._word_wrap}})
        self.reload()

    @Property(bool, notify=editorMetricsChanged)
    def wordWrap(self) -> bool:
        return self._word_wrap

    @Slot(bool)
    def setSuggestionsAuto(self, value: bool) -> None:
        self._suggestions_auto = bool(value)
        self._config = self._settings.save_global(
            {"editor": {"suggestions": {"auto": self._suggestions_auto}}}
        )
        self.reload()

    @Property(bool, notify=editorMetricsChanged)
    def suggestionsAuto(self) -> bool:
        return self._suggestions_auto

    @Slot(int)
    def setSuggestionsDelayMs(self, value: int) -> None:
        self._suggestions_delay_ms = max(0, min(2000, int(value)))
        self._config = self._settings.save_global(
            {"editor": {"suggestions": {"delayMs": self._suggestions_delay_ms}}}
        )
        self.reload()

    @Property(int, notify=editorMetricsChanged)
    def suggestionsDelayMs(self) -> int:
        return self._suggestions_delay_ms

    @Slot(bool)
    def setSuggestionsDetailsOnSpace(self, value: bool) -> None:
        self._suggestions_details_on_space = bool(value)
        self._config = self._settings.save_global(
            {"editor": {"suggestions": {"detailsOnSpace": self._suggestions_details_on_space}}}
        )
        self.reload()

    @Property(bool, notify=editorMetricsChanged)
    def suggestionsDetailsOnSpace(self) -> bool:
        return self._suggestions_details_on_space

    @Slot(int)
    def setDiagnosticsDelayMs(self, value: int) -> None:
        self._diagnostics_delay_ms = max(0, min(5000, int(value)))
        self._config = self._settings.save_global(
            {"editor": {"diagnostics": {"delayMs": self._diagnostics_delay_ms}}}
        )
        self.reload()

    @Property(int, notify=editorMetricsChanged)
    def diagnosticsDelayMs(self) -> int:
        return self._diagnostics_delay_ms

    @Slot(int)
    def setSymbolsDelayMs(self, value: int) -> None:
        self._symbols_delay_ms = max(100, min(5000, int(value)))
        self._config = self._settings.save_global(
            {"editor": {"symbols": {"delayMs": self._symbols_delay_ms}}}
        )
        self.reload()

    @Property(int, notify=editorMetricsChanged)
    def symbolsDelayMs(self) -> int:
        return self._symbols_delay_ms

    @Slot(bool)
    def setLspEnabled(self, value: bool) -> None:
        self._lsp_enabled = bool(value)
        self._config = self._settings.save_global(
            {"language": {"lsp": {"enabled": self._lsp_enabled}}}
        )
        self.reload()

    @Property(bool, notify=configChanged)
    def lspEnabled(self) -> bool:
        return self._lsp_enabled

    @Slot(bool)
    def setDiagnosticsOnType(self, value: bool) -> None:
        self._diagnostics_on_type = bool(value)
        self._config = self._settings.save_global(
            {"language": {"diagnosticsOnType": self._diagnostics_on_type}}
        )
        self.reload()

    @Property(bool, notify=configChanged)
    def diagnosticsOnType(self) -> bool:
        return self._diagnostics_on_type

    @Slot(str)
    def setPythonLspServersCsv(self, value: str) -> None:
        servers = [item.strip() for item in value.split(",") if item.strip()]
        self._python_lsp_servers = servers or ["ty", "ruff"]
        self._config = self._settings.save_global(
            {"language": {"lsp": {"python": {"servers": self._python_lsp_servers}}}}
        )
        self.reload()

    @Property(str, notify=configChanged)
    def pythonLspServersCsv(self) -> str:
        return ", ".join(self._python_lsp_servers)

    @Slot(str, result="QVariantList")
    def getLspProvidersForLanguage(self, language: str) -> list[str]:
        language_key = language.strip().lower() or "python"
        return list(self._lsp_providers_by_language.get(language_key, []) or [])

    @Slot(str, result=str)
    def getLspProvidersCsv(self, language: str) -> str:
        return ", ".join(self.getLspProvidersForLanguage(language))

    @Slot(str, str)
    def setLspProvidersCsv(self, language: str, value: str) -> None:
        language_key = language.strip().lower() or "python"
        providers = [item.strip() for item in value.split(",") if item.strip()]
        self._lsp_providers_by_language[language_key] = providers
        patch = {"language": {"lsp": {"providers": {language_key: providers}}}}
        if language_key == "python":
            legacy_servers = [
                provider.split(".", 1)[1] if provider.startswith("python.") else provider
                for provider in providers
            ]
            self._python_lsp_servers = legacy_servers or ["ty", "ruff"]
            patch["language"]["lsp"]["python"] = {"servers": self._python_lsp_servers}
        self._config = self._settings.save_global(patch)
        self.reload()

    @Slot(str, result="QVariantMap")
    def getLspProviderConfig(self, provider_id: str) -> dict:
        return dict(self._lsp_provider_configs.get(provider_id.strip(), {}) or {})

    @Slot(str, result=str)
    def getLspProviderConfigJson(self, provider_id: str) -> str:
        return json.dumps(self.getLspProviderConfig(provider_id), indent=2, ensure_ascii=False)

    @Slot(str, str, result=str)
    def saveLspProviderConfigJson(self, provider_id: str, content: str) -> str:
        provider_key = provider_id.strip()
        if not provider_key:
            return "Invalid LSP provider: empty provider id."
        try:
            data = json.loads(content or "{}")
            if not isinstance(data, dict):
                return "Invalid LSP provider config: root value must be a JSON object."
            self._lsp_provider_configs[provider_key] = data
            self._config = self._settings.save_global(
                {"language": {"lsp": {"providerConfigs": {provider_key: data}}}}
            )
            self.reload()
            return f"LSP provider config saved for {provider_key}."
        except Exception as exc:
            return f"Could not save LSP provider config: {exc}"

    @Property("QVariantMap", notify=configChanged)
    def lspProvidersByLanguage(self) -> dict:
        return dict(self._lsp_providers_by_language)

    @Slot("QVariantMap", result="QVariantMap")
    def previewLspProviderToolInstall(self, provider: dict) -> dict:
        provider_data = dict(provider or {})
        install_spec = dict(provider_data.get("install") or {})
        command = [str(install_spec.get("command") or ""), *[str(arg) for arg in install_spec.get("args") or []]]
        command = [item for item in command if item]
        return {
            "providerId": str(provider_data.get("id") or provider_data.get("name") or ""),
            "plugin": str(provider_data.get("plugin") or "core"),
            "description": str(install_spec.get("description") or ""),
            "command": command,
            "commandText": " ".join(command),
            "requiresApproval": bool(install_spec.get("requiresApproval", True)),
            "strategy": str(install_spec.get("strategy") or ""),
        }

    @Slot("QVariantMap", bool, result=bool)
    def installLspProviderTool(self, provider: dict, approved: bool = False) -> bool:
        provider_data = dict(provider or {})
        if not approved:
            self._notify("warning", "Install not approved", str(provider_data.get("id") or "LSP provider"))
            return False
        schedule(self._install_lsp_provider_tool(provider_data))
        return True

    async def _install_lsp_provider_tool(self, provider: dict) -> None:
        provider_id = str(provider.get("id") or provider.get("name") or "lsp-provider")
        install_spec = dict(provider.get("install") or {})
        if not install_spec:
            self._notify("warning", "No installer declared", provider_id)
            return

        command_preview = " ".join(
            [str(install_spec.get("command") or ""), *[str(arg) for arg in install_spec.get("args") or []]]
        ).strip()
        busy_key = f"settings:lsp-install:{provider_id}"
        self._busy_start(busy_key, f"Installing {provider_id}…")
        self._notify("info", "Installing LSP tool", command_preview or provider_id)
        try:
            result = await self._tool_installer.install(install_spec)
            await self._record_tool_install(provider, result)
            if result.ok:
                self._notify("success", "LSP tool installed", command_preview or result.message)
            else:
                details = result.stderr.strip() or result.stdout.strip() or result.message
                self._notify("error", "LSP tool install failed", details[:700])
        finally:
            self._busy_end(busy_key)

    async def _record_tool_install(self, provider: dict, result) -> None:
        try:
            from app.data.models import ToolInstallAudit

            await ToolInstallAudit.objects.create(
                provider_id=str(provider.get("id") or provider.get("name") or ""),
                plugin_name=str(provider.get("plugin") or ""),
                command=" ".join(result.command),
                status="success" if result.ok else "failed",
                message=result.message,
                stdout=result.stdout[-4000:] if result.stdout else "",
                stderr=result.stderr[-4000:] if result.stderr else "",
            )
            await self._refresh_tool_install_audits()
        except Exception as exc:
            print(f"[SettingsVM] Could not record tool install audit: {exc}")

    @Slot(result="QVariantList")
    def getToolInstallAudits(self) -> list[dict]:
        return list(self._tool_install_audits)

    @Property("QVariantList", notify=toolInstallAuditsChanged)
    def toolInstallAudits(self) -> list[dict]:
        return list(self._tool_install_audits)

    @Slot()
    def refreshToolInstallAudits(self) -> None:
        schedule(self._refresh_tool_install_audits())

    async def _refresh_tool_install_audits(self) -> None:
        try:
            from app.data.models import ToolInstallAudit

            rows = await ToolInstallAudit.objects.order_by("-created_at").limit(12).all()
            self._tool_install_audits = [
                {
                    "providerId": str(getattr(row, "provider_id", "") or ""),
                    "plugin": str(getattr(row, "plugin_name", "") or ""),
                    "command": str(getattr(row, "command", "") or ""),
                    "status": str(getattr(row, "status", "") or ""),
                    "message": str(getattr(row, "message", "") or ""),
                    "stdout": str(getattr(row, "stdout", "") or ""),
                    "stderr": str(getattr(row, "stderr", "") or ""),
                    "createdAt": str(getattr(row, "created_at", "") or ""),
                }
                for row in rows
            ]
            self.toolInstallAuditsChanged.emit()
        except Exception as exc:
            print(f"[SettingsVM] Could not refresh tool install audits: {exc}")

    @Slot("QVariantMap", result="QVariantMap")
    def previewSearchProviderToolInstall(self, provider: dict) -> dict:
        return self.previewLspProviderToolInstall(provider)

    @Slot("QVariantMap", bool, result=bool)
    def installSearchProviderTool(self, provider: dict, approved: bool = False) -> bool:
        provider_data = dict(provider or {})
        if not approved:
            self._notify("warning", "Install not approved", str(provider_data.get("id") or "Search provider"))
            return False
        schedule(self._install_search_provider_tool(provider_data))
        return True

    async def _install_search_provider_tool(self, provider: dict) -> None:
        provider_id = str(provider.get("id") or provider.get("name") or "search-provider")
        install_spec = dict(provider.get("install") or {})
        if not install_spec:
            self._notify("warning", "No installer declared", provider_id)
            return
        command_preview = " ".join(
            [str(install_spec.get("command") or ""), *[str(arg) for arg in install_spec.get("args") or []]]
        ).strip()
        busy_key = f"settings:search-install:{provider_id}"
        self._busy_start(busy_key, f"Installing {provider_id}…")
        self._notify("info", "Installing search tool", command_preview or provider_id)
        try:
            result = await self._tool_installer.install(install_spec)
            await self._record_tool_install(provider, result)
            if result.ok:
                self._notify("success", "Search tool installed", command_preview or result.message)
            else:
                details = result.stderr.strip() or result.stdout.strip() or result.message
                self._notify("error", "Search tool install failed", details[:700])
        finally:
            self._busy_end(busy_key)

    @Slot("QVariantMap", result="QVariantMap")
    def searchProviderPreviewStatus(self, provider: dict) -> dict:
        provider_data = dict(provider or {})
        command = str(provider_data.get("command") or "").strip()
        args = [str(arg) for arg in provider_data.get("args") or []]
        resolved = shutil.which(command) if command else ""
        return {
            "name": str(provider_data.get("id") or provider_data.get("name") or "search-provider"),
            "command": " ".join([command, *args]).strip(),
            "available": bool(resolved) or str(provider_data.get("providerType") or "").lower() == "python",
            "running": False,
            "resolvedCommand": resolved or command,
            "commandError": "" if (resolved or not command) else f"Command not found: {command}",
            "logs": [],
        }

    @Slot("QVariantMap", result="QVariantMap")
    def lspProviderPreviewStatus(self, provider: dict) -> dict:
        provider_data = dict(provider or {})
        command = [
            str(provider_data.get("command") or ""),
            *[str(arg) for arg in provider_data.get("args") or []],
        ]
        command = [item for item in command if item]
        try:
            from app.services.lsp_process import ExternalLSPProcess

            process = ExternalLSPProcess(
                str(provider_data.get("id") or provider_data.get("name") or "lsp-provider"),
                command,
                timeout=float((provider_data.get("defaults") or {}).get("timeout", 1.8) or 1.8),
            )
            return process.status()
        except Exception as exc:
            return {
                "name": str(provider_data.get("id") or provider_data.get("name") or "lsp-provider"),
                "command": " ".join(command),
                "available": False,
                "running": False,
                "resolvedCommand": "",
                "commandError": str(exc),
                "logs": [],
            }

    @Slot(bool)
    def setFormatOnSave(self, value: bool) -> None:
        self._format_on_save = bool(value)
        self._config = self._settings.save_global({
            "files": {"formatOnSave": self._format_on_save},
            "language": {"formatOnSave": self._format_on_save},
        })
        self.reload()

    @Property(bool, notify=configChanged)
    def formatOnSave(self) -> bool:
        return self._format_on_save

    @Slot(bool)
    def setFilesRestoreWorkspace(self, value: bool) -> None:
        self._files_restore_workspace = bool(value)
        self._config = self._settings.save_global(
            {"files": {"restoreWorkspace": self._files_restore_workspace}}
        )
        self.reload()

    @Property(bool, notify=configChanged)
    def filesRestoreWorkspace(self) -> bool:
        return self._files_restore_workspace

    @Slot(bool)
    def setFilesWatcherEnabled(self, value: bool) -> None:
        self._files_watcher_enabled = bool(value)
        self._config = self._settings.save_global(
            {"files": {"watcher": {"enabled": self._files_watcher_enabled}}}
        )
        self.reload()

    @Property(bool, notify=configChanged)
    def filesWatcherEnabled(self) -> bool:
        return self._files_watcher_enabled

    @Slot(bool)
    def setFilesShowHidden(self, value: bool) -> None:
        self._files_show_hidden = bool(value)
        self._config = self._settings.save_global({"files": {"showHidden": self._files_show_hidden}})
        self.reload()
        self.searchConfigChanged.emit(self.getSearchConfig())

    @Property(bool, notify=configChanged)
    def filesShowHidden(self) -> bool:
        return self._files_show_hidden

    @Slot(bool)
    def setFilesConfirmDelete(self, value: bool) -> None:
        self._files_confirm_delete = bool(value)
        self._config = self._settings.save_global(
            {"files": {"confirmDelete": self._files_confirm_delete}}
        )
        self.reload()

    @Property(bool, notify=configChanged)
    def filesConfirmDelete(self) -> bool:
        return self._files_confirm_delete

    @Slot(str)
    @Slot(str, bool)
    def setFilesExcludeCsv(self, value: str, project: bool = False) -> None:
        exclusions = []
        for item in str(value or "").replace("\n", ",").split(","):
            item = item.strip()
            if item and item not in exclusions:
                exclusions.append(item)
        self._files_exclude = exclusions
        patch = {"files": {"exclude": exclusions}}
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self.reload()
        self.searchConfigChanged.emit(self.getSearchConfig())

    @Property(str, notify=configChanged)
    def filesExcludeCsv(self) -> str:
        return ", ".join(str(item) for item in self._files_exclude)

    @Slot(result="QVariantMap")
    def getFilesConfig(self) -> dict:
        return {
            "restoreWorkspace": self._files_restore_workspace,
            "watcherEnabled": self._files_watcher_enabled,
            "showHidden": self._files_show_hidden,
            "confirmDelete": self._files_confirm_delete,
            "exclude": list(self._files_exclude),
        }

    @Slot(result="QVariantMap")
    def getDefaultFormatterByLanguage(self) -> dict:
        return dict(self._default_formatter_by_language)

    @Slot(result="QVariantMap")
    def getDefaultFormatterByExtension(self) -> dict:
        return dict(self._default_formatter_by_extension)

    @Slot(str, result=str)
    def getDefaultFormatterForLanguage(self, language: str) -> str:
        return str(self._default_formatter_by_language.get(language.strip().lower(), ""))

    @Slot(str, result=str)
    def getDefaultFormatterForExtension(self, extension: str) -> str:
        key = self._normalize_extension(extension)
        return str(self._default_formatter_by_extension.get(key, ""))

    @Slot(str, str)
    def setDefaultFormatterForLanguage(self, language: str, formatter_id: str) -> None:
        key = language.strip().lower()
        if not key:
            return
        self._default_formatter_by_language[key] = formatter_id.strip()
        self._config = self._settings.save_global({
            "files": {"defaultFormatterByLanguage": {key: formatter_id.strip()}}
        })
        self.reload()

    @Slot(str, str)
    def setDefaultFormatterForExtension(self, extension: str, formatter_id: str) -> None:
        key = self._normalize_extension(extension)
        if not key:
            return
        self._default_formatter_by_extension[key] = formatter_id.strip()
        self._config = self._settings.save_global({
            "files": {"defaultFormatterByExtension": {key: formatter_id.strip()}}
        })
        self.reload()

    @staticmethod
    def _normalize_extension(extension: str) -> str:
        value = str(extension or "").strip().lower()
        if not value:
            return ""
        return value if value.startswith(".") else f".{value}"

    # ── Search ───────────────────────────────────────────

    @Slot(result="QVariantMap")
    def getSearchConfig(self) -> dict:
        return {
            "provider": self._search_provider,
            "caseSensitive": self._search_case_sensitive,
            "regex": self._search_regex,
            "includeHidden": self._search_include_hidden or self._files_show_hidden,
            "maxResults": self._search_max_results,
            "maxFileSize": self._search_max_file_size,
            "exclude": list(self._files_exclude),
        }

    @Slot(str, bool, bool, bool, int, int, bool)
    def setSearchConfig(
        self,
        provider: str,
        case_sensitive: bool,
        regex: bool,
        include_hidden: bool,
        max_results: int,
        max_file_size: int,
        project: bool = False,
    ) -> None:
        self._search_provider = provider.strip() or "core.python"
        self._search_case_sensitive = bool(case_sensitive)
        self._search_regex = bool(regex)
        self._search_include_hidden = bool(include_hidden)
        self._search_max_results = max(10, min(10000, int(max_results)))
        self._search_max_file_size = max(1024, min(50_000_000, int(max_file_size)))
        patch = {
            "search": {
                "provider": self._search_provider,
                "caseSensitive": self._search_case_sensitive,
                "regex": self._search_regex,
                "includeHidden": self._search_include_hidden,
                "maxResults": self._search_max_results,
                "maxFileSize": self._search_max_file_size,
            }
        }
        self._config = self._settings.save_project(patch) if project else self._settings.save_global(patch)
        self.configChanged.emit(self._config)
        self.searchChanged.emit()
        self.searchConfigChanged.emit(self.getSearchConfig())

    @Property(str, notify=searchChanged)
    def searchProvider(self) -> str:
        return self._search_provider

    @Property(bool, notify=searchChanged)
    def searchCaseSensitive(self) -> bool:
        return self._search_case_sensitive

    @Property(bool, notify=searchChanged)
    def searchRegex(self) -> bool:
        return self._search_regex

    @Property(bool, notify=searchChanged)
    def searchIncludeHidden(self) -> bool:
        return self._search_include_hidden

    @Property(int, notify=searchChanged)
    def searchMaxResults(self) -> int:
        return self._search_max_results

    @Property(int, notify=searchChanged)
    def searchMaxFileSize(self) -> int:
        return self._search_max_file_size

    # ── AI ───────────────────────────────────────────────

    @Slot(bool)
    def setAiInlineSuggestions(self, value: bool) -> None:
        self._ai_inline_suggestions = bool(value)
        self._config = self._settings.save_global(
            {"ai": {"inlineSuggestions": self._ai_inline_suggestions}}
        )
        self.reload()

    @Property(bool, notify=configChanged)
    def aiInlineSuggestions(self) -> bool:
        return self._ai_inline_suggestions

    @Slot(str, str, str, float, int)
    def setAiConfig(
        self,
        provider: str,
        model: str,
        endpoint: str,
        temperature: float,
        max_tokens: int,
    ) -> None:
        self._ai_provider = provider.strip() or "ollama"
        self._ai_model = model.strip()
        self._ai_endpoint = endpoint.strip()
        self._ai_temperature = max(0.0, min(2.0, float(temperature)))
        self._ai_max_tokens = max(64, min(32000, int(max_tokens)))
        provider_config = dict(self._ai_provider_configs.get(self._ai_provider, {}) or {})
        provider_config.update({
            "model": self._ai_model,
            "endpoint": self._ai_endpoint,
            "temperature": self._ai_temperature,
            "maxTokens": self._ai_max_tokens,
        })
        self._ai_provider_configs[self._ai_provider] = provider_config
        self._config = self._settings.save_global({
            "ai": {
                "provider": self._ai_provider,
                "model": self._ai_model,
                "endpoint": self._ai_endpoint,
                "temperature": self._ai_temperature,
                "maxTokens": self._ai_max_tokens,
                "providerConfigs": {self._ai_provider: provider_config},
            }
        })
        self.reload()

    @Slot(str, result="QVariantMap")
    def getAiProviderConfig(self, provider: str) -> dict:
        provider_key = provider.strip() or self._ai_provider
        return dict(self._ai_provider_configs.get(provider_key, {}) or {})

    @Slot(str, result=str)
    def getAiProviderConfigJson(self, provider: str) -> str:
        return json.dumps(self.getAiProviderConfig(provider), indent=2, ensure_ascii=False)

    @Slot(str, str, result=str)
    def saveAiProviderConfigJson(self, provider: str, content: str) -> str:
        provider_key = provider.strip() or self._ai_provider
        try:
            data = json.loads(content or "{}")
            if not isinstance(data, dict):
                return "Invalid provider config: root value must be a JSON object."
            self._ai_provider_configs[provider_key] = data
            patch = {"ai": {"providerConfigs": {provider_key: data}}}
            if provider_key == self._ai_provider:
                patch["ai"].update({
                    "model": str(data.get("model", self._ai_model) or ""),
                    "endpoint": str(data.get("endpoint", self._ai_endpoint) or ""),
                    "temperature": float(data.get("temperature", self._ai_temperature) or 0.2),
                    "maxTokens": int(data.get("maxTokens", self._ai_max_tokens) or 1024),
                })
            self._config = self._settings.save_global(patch)
            self.reload()
            return f"AI provider config saved for {provider_key}."
        except Exception as exc:
            return f"Could not save AI provider config: {exc}"

    @Property("QVariantMap", notify=configChanged)
    def aiProviderConfigs(self) -> dict:
        return dict(self._ai_provider_configs)

    @Property(int, notify=aiModelsRevisionChanged)
    def aiModelsRevision(self) -> int:
        return self._ai_models_revision

    @Slot(str, result="QVariantList")
    def getAiRuntimeModels(self, provider: str) -> list[str]:
        provider_key = provider.strip() or self._ai_provider
        return list(self._ai_provider_models.get(provider_key, []) or [])

    @Slot(str, str, str)
    def refreshAiProviderModels(self, provider: str, endpoint: str = "", provider_type: str = "") -> None:
        provider_key = provider.strip() or self._ai_provider
        config = dict(self._ai_provider_configs.get(provider_key, {}) or {})
        resolved_endpoint = endpoint.strip() or str(config.get("endpoint") or self._ai_endpoint)
        resolved_type = provider_type.strip() or str(config.get("providerType") or provider_key)
        schedule(self._refresh_ai_provider_models(provider_key, resolved_endpoint, resolved_type, config))

    @Slot(bool)
    def setAiCache(self, value: bool) -> None:
        self._ai_cache = bool(value)
        self._config = self._settings.save_global({"ai": {"cache": self._ai_cache}})
        self.reload()

    @Slot(int)
    def setAiContextChars(self, value: int) -> None:
        self._ai_context_chars = max(1000, min(50000, int(value)))
        self._config = self._settings.save_global({"ai": {"contextChars": self._ai_context_chars}})
        self.reload()

    @Property(str, notify=configChanged)
    def aiProvider(self) -> str:
        return self._ai_provider

    @Property(str, notify=configChanged)
    def aiModel(self) -> str:
        return self._ai_model

    @Property(str, notify=configChanged)
    def aiEndpoint(self) -> str:
        return self._ai_endpoint

    @Property(float, notify=configChanged)
    def aiTemperature(self) -> float:
        return self._ai_temperature

    @Property(int, notify=configChanged)
    def aiMaxTokens(self) -> int:
        return self._ai_max_tokens

    @Property(bool, notify=configChanged)
    def aiCache(self) -> bool:
        return self._ai_cache

    @Property(int, notify=configChanged)
    def aiContextChars(self) -> int:
        return self._ai_context_chars

    async def _refresh_ai_provider_models(
        self,
        provider: str,
        endpoint: str,
        provider_type: str,
        config: dict,
    ) -> None:
        busy_key = f"settings:ai-models:{provider}"
        self._busy_start(busy_key, f"Refreshing {provider} models…")
        try:
            models = await self._fetch_ai_models(provider, endpoint, provider_type, config)
            self._ai_provider_models[provider] = models
            self._ai_models_revision += 1
            self.aiModelsRevisionChanged.emit()
            self.aiModelsChanged.emit(provider, models)
            self._notify(
                "success",
                "AI models refreshed",
                f"{len(models)} model(s) available for {provider}.",
            )
        except Exception as exc:
            self._notify("error", "AI model refresh failed", str(exc))
            self._ai_provider_models[provider] = []
            self._ai_models_revision += 1
            self.aiModelsRevisionChanged.emit()
            self.aiModelsChanged.emit(provider, [])
        finally:
            self._busy_end(busy_key)

    async def _fetch_ai_models(
        self,
        provider: str,
        endpoint: str,
        provider_type: str,
        config: dict,
    ) -> list[str]:
        import httpx

        base_url = (endpoint or "").rstrip("/")
        if not base_url:
            raise ValueError("Provider endpoint is empty.")

        headers = {}
        api_key = str(config.get("apiKey") or config.get("api_key") or "").strip()
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"

        candidates = self._model_endpoint_candidates(provider, provider_type, base_url)
        errors: list[str] = []
        async with httpx.AsyncClient(timeout=12.0, headers=headers) as client:
            for url, parser in candidates:
                try:
                    response = await client.get(url)
                    response.raise_for_status()
                    data = response.json()
                    models = parser(data)
                    if models:
                        return sorted(set(models), key=str.lower)
                    errors.append(f"{url}: no models returned")
                except Exception as exc:
                    errors.append(f"{url}: {exc}")
        raise RuntimeError("; ".join(errors[-2:]) or "No model endpoint responded.")

    @staticmethod
    def _model_endpoint_candidates(provider: str, provider_type: str, base_url: str) -> list:
        provider_key = provider.lower()
        type_key = provider_type.lower()

        def ollama_parser(data: dict) -> list[str]:
            return [
                str(item.get("name") or item.get("model") or "").strip()
                for item in data.get("models", [])
                if isinstance(item, dict)
            ]

        def openai_parser(data: dict) -> list[str]:
            return [
                str(item.get("id") or "").strip()
                for item in data.get("data", [])
                if isinstance(item, dict)
            ]

        if provider_key == "ollama" or "ollama" in type_key:
            return [(f"{base_url}/api/tags", ollama_parser), (f"{base_url}/models", openai_parser)]
        if "openai" in provider_key or "openai" in type_key:
            return [(f"{base_url}/models", openai_parser), (f"{base_url}/api/tags", ollama_parser)]
        return [(f"{base_url}/models", openai_parser), (f"{base_url}/api/tags", ollama_parser)]

    def _notify(self, level: str, title: str, message: str = "") -> None:
        if not self._notification_vm:
            return
        try:
            self._notification_vm.push(level, title, message, 4200)
        except Exception:
            pass

    def _busy_start(self, key: str, label: str) -> None:
        if not self._notification_vm:
            return
        try:
            self._notification_vm.startBusy(key, label)
        except Exception:
            pass

    def _busy_end(self, key: str) -> None:
        if not self._notification_vm:
            return
        try:
            self._notification_vm.endBusy(key)
        except Exception:
            pass

    # ── Extensions ───────────────────────────────────────

    @Slot(bool)
    def setExtensionsEnabled(self, value: bool) -> None:
        self._extensions_enabled = bool(value)
        self._config = self._settings.save_global(
            {"extensions": {"enabled": self._extensions_enabled}}
        )
        self.reload()

    @Slot(bool)
    def setExtensionsAutoActivate(self, value: bool) -> None:
        self._extensions_auto_activate = bool(value)
        self._config = self._settings.save_global(
            {"extensions": {"autoActivate": self._extensions_auto_activate}}
        )
        self.reload()

    @Slot(bool)
    def setExtensionsAllowUserPlugins(self, value: bool) -> None:
        self._extensions_allow_user_plugins = bool(value)
        self._config = self._settings.save_global(
            {"extensions": {"allowUserPlugins": self._extensions_allow_user_plugins}}
        )
        self.reload()

    @Slot(bool)
    def setExtensionsAllowNetworkInstall(self, value: bool) -> None:
        self._extensions_allow_network_install = bool(value)
        self._config = self._settings.save_global(
            {"extensions": {"allowNetworkInstall": self._extensions_allow_network_install}}
        )
        self.reload()

    @Slot(str)
    def setExtensionsMarketplaceApiUrl(self, value: str) -> None:
        self._extensions_marketplace_api_url = str(value or "").strip()
        self._config = self._settings.save_global(
            {"extensions": {"marketplace": {"apiUrl": self._extensions_marketplace_api_url}}}
        )
        self.reload()

    @Slot(str)
    def setExtensionsMarketplaceLocalSourcesJson(self, value: str) -> None:
        try:
            parsed = json.loads(value or "[]")
            if not isinstance(parsed, list):
                parsed = []
            self._extensions_marketplace_local_sources = [str(item) for item in parsed if str(item)]
        except Exception:
            self._extensions_marketplace_local_sources = []
        self._config = self._settings.save_global(
            {
                "extensions": {
                    "marketplace": {
                        "localSources": self._extensions_marketplace_local_sources
                    }
                }
            }
        )
        self.reload()

    @Property(bool, notify=configChanged)
    def extensionsEnabled(self) -> bool:
        return self._extensions_enabled

    @Property(bool, notify=configChanged)
    def extensionsAutoActivate(self) -> bool:
        return self._extensions_auto_activate

    @Property(bool, notify=configChanged)
    def extensionsAllowUserPlugins(self) -> bool:
        return self._extensions_allow_user_plugins

    @Property(bool, notify=configChanged)
    def extensionsAllowNetworkInstall(self) -> bool:
        return self._extensions_allow_network_install

    @Property(str, notify=configChanged)
    def extensionsMarketplaceApiUrl(self) -> str:
        return self._extensions_marketplace_api_url

    @Property("QVariantList", notify=configChanged)
    def extensionsMarketplaceLocalSources(self) -> list[str]:
        return list(self._extensions_marketplace_local_sources)

    @Property(str, notify=configChanged)
    def extensionsMarketplaceLocalSourcesJson(self) -> str:
        return json.dumps(self._extensions_marketplace_local_sources, indent=2)

    # ── Workbench layout ─────────────────────────────────

    @Slot(bool)
    def setActivityBarVisible(self, value: bool) -> None:
        self._activity_bar_visible = bool(value)
        self._config = self._settings.save_global(
            {"workbench": {"activityBar": {"visible": self._activity_bar_visible}}}
        )
        self.reload()

    @Property(bool, notify=workbenchChanged)
    def activityBarVisible(self) -> bool:
        return self._activity_bar_visible

    @Slot(bool)
    def setSidebarVisible(self, value: bool) -> None:
        self._sidebar_visible = bool(value)
        self._config = self._settings.save_global(
            {"workbench": {"sidebar": {"visible": self._sidebar_visible}}}
        )
        self.reload()

    @Property(bool, notify=workbenchChanged)
    def sidebarVisible(self) -> bool:
        return self._sidebar_visible

    @Slot(int)
    def setSidebarWidth(self, value: int) -> None:
        self._sidebar_width = max(180, min(520, int(value)))
        self._config = self._settings.save_global(
            {"workbench": {"sidebar": {"width": self._sidebar_width}}}
        )
        self.reload()

    @Property(int, notify=workbenchChanged)
    def sidebarWidth(self) -> int:
        return self._sidebar_width

    @Slot(bool)
    def setPanelVisible(self, value: bool) -> None:
        self._panel_visible = bool(value)
        self._config = self._settings.save_global(
            {"workbench": {"panel": {"visible": self._panel_visible}}}
        )
        self.reload()

    @Property(bool, notify=workbenchChanged)
    def panelVisible(self) -> bool:
        return self._panel_visible

    @Slot(int)
    def setPanelHeight(self, value: int) -> None:
        self._panel_height = max(120, min(500, int(value)))
        self._config = self._settings.save_global(
            {"workbench": {"panel": {"height": self._panel_height}}}
        )
        self.reload()

    @Property(int, notify=workbenchChanged)
    def panelHeight(self) -> int:
        return self._panel_height

    @Slot(bool)
    def setRightPanelVisible(self, value: bool) -> None:
        self._right_panel_visible = bool(value)
        self._config = self._settings.save_global(
            {"workbench": {"rightPanel": {"visible": self._right_panel_visible}}}
        )
        self.reload()

    @Property(bool, notify=workbenchChanged)
    def rightPanelVisible(self) -> bool:
        return self._right_panel_visible

    @Slot(int)
    def setRightPanelWidth(self, value: int) -> None:
        self._right_panel_width = max(180, min(520, int(value)))
        self._config = self._settings.save_global(
            {"workbench": {"rightPanel": {"width": self._right_panel_width}}}
        )
        self.reload()

    @Property(int, notify=workbenchChanged)
    def rightPanelWidth(self) -> int:
        return self._right_panel_width

    # ── Settings persistence ──────────────────────────────

    async def get_setting(self, key: str) -> dict | None:
        from app.data.models import UserSettings
        try:
            s = await UserSettings.objects.get(key=key)
            return s.value
        except Exception:
            return None

    async def set_setting(self, key: str, value: dict) -> None:
        from app.data.models import UserSettings
        obj, created = await UserSettings.objects.get_or_create(
            key=key, defaults={"value": value}
        )
        if not created:
            obj.value = value
            await obj.save()

    async def save_theme(self, name: str) -> None:
        await self.set_setting("theme", {"name": name})
