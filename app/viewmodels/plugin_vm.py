from __future__ import annotations

import json
from PySide6.QtCore import QObject, Signal, Slot, Property
from app.core.async_tasks import schedule
from app.core.events import EventBus


class PluginViewModel(QObject):
    pluginsChanged = Signal()
    pluginActivated = Signal(str)
    pluginDeactivated = Signal(str)
    pluginInstalled = Signal(str)
    contributionsChanged = Signal()
    permissionsChanged = Signal()
    installStatusChanged = Signal("QVariantMap")
    updateStatusChanged = Signal("QVariantMap")
    storeChanged = Signal()
    fileActionCompleted = Signal("QVariantMap")
    searchResultActionCompleted = Signal("QVariantMap")

    def __init__(self, events: EventBus, parent: QObject | None = None):
        super().__init__(parent)
        self._events = events
        self._manager = None
        self._plugins_data: list[dict] = []
        self._install_status: dict = {
            "state": "idle",
            "ok": False,
            "message": "",
            "errors": [],
            "source": "",
            "manifest": {},
        }
        self._update_status: dict = {
            "plugin": "",
            "state": "idle",
            "canUpdate": False,
            "message": "",
            "source": "",
            "storedHash": "",
            "candidateHash": "",
            "candidate": {},
            "diff": {},
        }
        self._store_plugins: list[dict] = []
        self._store_sources: list[str] = []
        self._store_api_url = ""

    def set_manager(self, manager) -> None:
        self._manager = manager
        self.refresh_from_manager()

    def refresh_from_manager(self) -> None:
        if not self._manager:
            return
        self._plugins_data = self._manager.registry.get_legacy_configs()
        self._store_sources = self._manager.get_store_sources()
        self._store_api_url = self._manager.get_store_api_url()
        self.pluginsChanged.emit()
        self.contributionsChanged.emit()
        self.permissionsChanged.emit()
        self.storeChanged.emit()

    def _notifications(self):
        return getattr(self._manager, "_notification_vm", None) if self._manager else None

    def _notify(self, level: str, title: str, message: str = "") -> None:
        notifications = self._notifications()
        method = getattr(notifications, level, None) if notifications else None
        if callable(method):
            method(title, message)

    def _busy_start(self, key: str, label: str) -> None:
        notifications = self._notifications()
        if notifications:
            notifications.startBusy(f"plugin-vm:{key}", label)

    def _busy_end(self, key: str) -> None:
        notifications = self._notifications()
        if notifications:
            notifications.endBusy(f"plugin-vm:{key}")

    # ── QML Slots ────────────────────────────────────────

    @Slot(result=str)
    def loadPlugins(self) -> str:
        if not self._manager:
            return "[]"
        schedule(self._load_plugins_async())
        return json.dumps(self._plugins_data)

    @Slot(str, result="bool")
    def activatePlugin(self, name: str) -> bool:
        if not self._manager:
            return False
        schedule(self._activate_plugin_async(name))
        return True

    @Slot(str, result="bool")
    def deactivatePlugin(self, name: str) -> bool:
        if not self._manager:
            return False
        schedule(self._deactivate_plugin_async(name))
        return True

    @Slot(str, result=str)
    def installPlugin(self, source: str) -> str:
        if not self._manager:
            return json.dumps({"msg": "FAILED: No plugin manager"})
        self._set_install_status({
            "state": "installing",
            "ok": False,
            "message": "Installing plugin…",
            "errors": [],
            "source": source,
            "manifest": {},
        })
        schedule(self._install_plugin_async(source))
        return json.dumps({"msg": "QUEUED"})

    @Slot(result=str)
    def choosePluginDirectory(self) -> str:
        from PySide6.QtWidgets import QFileDialog
        import os

        path = QFileDialog.getExistingDirectory(
            None,
            "Select Ember Plugin Directory",
            os.path.expanduser("~"),
        )
        if path:
            self.validatePluginSource(path)
        return path or ""

    @Slot(str, result="QVariantMap")
    def validatePluginSource(self, source: str) -> dict:
        if not self._manager:
            result = {
                "state": "invalid",
                "ok": False,
                "message": "No plugin manager",
                "errors": ["No plugin manager"],
                "source": source,
                "manifest": {},
            }
        else:
            result = dict(self._manager.validate_source(source))
            result["state"] = "valid" if result.get("ok") else "invalid"
        self._set_install_status(result)
        return result

    @Slot(result=bool)
    def applyPluginPolicies(self) -> bool:
        if not self._manager:
            return False
        schedule(self._apply_plugin_policies_async())
        return True

    @Slot(str, result="bool")
    def uninstallPlugin(self, name: str) -> bool:
        if not self._manager:
            return False
        state = self._manager.registry.get(name)
        if state and state.manifest.proprietary:
            return False
        schedule(self._uninstall_plugin_async(name))
        return True

    @Slot(str, result="bool")
    def trustPluginCurrentManifest(self, name: str) -> bool:
        if not self._manager:
            return False
        schedule(self._trust_plugin_manifest_async(name))
        return True

    @Slot(str, result="bool")
    def checkPluginUpdate(self, name: str) -> bool:
        if not self._manager:
            return False
        schedule(self._check_plugin_update_async(name))
        return True

    @Slot(str, result="bool")
    def updatePluginFromSource(self, name: str) -> bool:
        if not self._manager:
            return False
        schedule(self._update_plugin_from_source_async(name))
        return True

    @Slot(result="QVariantList")
    def loadPluginStore(self) -> list[dict]:
        if not self._manager:
            return []
        schedule(self._load_plugin_store_async())
        return self._store_plugins

    @Slot(str, result=bool)
    def setPluginStoreApiUrl(self, api_url: str) -> bool:
        if not self._manager:
            return False
        try:
            self._store_api_url = self._manager.set_store_api_url(api_url)
            schedule(self._load_plugin_store_async())
            self.storeChanged.emit()
            return True
        except Exception as exc:
            print(f"[PluginVM] set store api url error: {exc}")
            return False

    @Slot(result=str)
    def choosePluginStoreDirectory(self) -> str:
        from PySide6.QtWidgets import QFileDialog
        import os

        path = QFileDialog.getExistingDirectory(
            None,
            "Select Ember Plugin Store Directory",
            os.path.expanduser("~"),
        )
        if path:
            self.addPluginStoreSource(path)
        return path or ""

    @Slot(str, result=bool)
    def addPluginStoreSource(self, source: str) -> bool:
        if not self._manager:
            return False
        try:
            self._store_sources = self._manager.add_store_source(source)
            schedule(self._load_plugin_store_async())
            self.storeChanged.emit()
            return True
        except Exception as exc:
            print(f"[PluginVM] add store source error: {exc}")
            return False

    @Slot(str, result=bool)
    def removePluginStoreSource(self, source: str) -> bool:
        if not self._manager:
            return False
        try:
            self._store_sources = self._manager.remove_store_source(source)
            schedule(self._load_plugin_store_async())
            self.storeChanged.emit()
            return True
        except Exception as exc:
            print(f"[PluginVM] remove store source error: {exc}")
            return False

    @Slot(str, result=bool)
    @Slot(str, str, result=bool)
    def installStorePlugin(self, source: str, archive_hash: str = "") -> bool:
        if not source:
            return False
        self._set_install_status({
            "state": "installing",
            "ok": False,
            "message": "Installing plugin from marketplace…",
            "errors": [],
            "source": source,
            "manifest": {},
        })
        schedule(self._install_store_plugin_async(source, archive_hash))
        return True

    @Slot(str, result=bool)
    def approvePluginPermissions(self, name: str) -> bool:
        if not self._manager:
            return False
        schedule(self._approve_permissions_async(name))
        return True

    @Slot(str, result=bool)
    def revokePluginPermissions(self, name: str) -> bool:
        if not self._manager:
            return False
        schedule(self._revoke_permissions_async(name))
        return True

    @Slot(result="QVariantList")
    def getActivePlugins(self) -> list[str]:
        if self._manager:
            return self._manager.get_active_names()
        return []

    @Slot(result="QVariantList")
    def getPluginCommands(self) -> list[dict]:
        if self._manager:
            return self._manager.get_commands()
        return []

    @Slot(str, result="QVariantList")
    def getPluginMenus(self, menu_id: str = "editor/context") -> list[dict]:
        if self._manager:
            return self._manager.get_menus(menu_id)
        return []

    @Slot(str, result="QVariantList")
    def getPluginViews(self, location: str = "sidebar") -> list[dict]:
        if self._manager:
            return self._manager.get_views(location)
        return []

    @Slot(str, result="QVariantList")
    def getPluginPanels(self, location: str = "bottom") -> list[dict]:
        if self._manager:
            return self._manager.get_panels(location)
        return []

    @Slot(result="QVariantList")
    def getSearchProviders(self) -> list[dict]:
        if self._manager:
            return self._manager.get_search_provider_options()
        return []

    @Slot("QVariantMap", result="QVariantList")
    def getFileBrowserActions(self, context: dict) -> list[dict]:
        if self._manager:
            return self._manager.get_file_actions(context)
        return []

    @Slot("QVariantMap", result="QVariantList")
    def getFileBrowserDecorations(self, context: dict) -> list[dict]:
        if self._manager:
            return self._manager.get_file_decorations(context)
        return []

    @Slot("QVariantMap", result=str)
    def getFileBrowserIconOverride(self, context: dict) -> str:
        if self._manager:
            return self._manager.get_file_icon_override(context)
        return ""

    @Slot(str, "QVariantMap", result="QVariantMap")
    def executeFileBrowserAction(self, action_id: str, context: dict) -> dict:
        if not self._manager:
            return {"ok": False, "message": "Plugin manager unavailable"}
        schedule(self._execute_file_browser_action_async(action_id, context))
        return {"ok": True, "message": "Action scheduled"}

    @Slot("QVariantMap", result="QVariantList")
    def getSearchResultActions(self, context: dict) -> list[dict]:
        if self._manager:
            return self._manager.get_search_result_actions(context)
        return []

    @Slot(str, "QVariantMap", result="QVariantMap")
    def executeSearchResultAction(self, action_id: str, context: dict) -> dict:
        if not self._manager:
            return {"ok": False, "message": "Plugin manager unavailable"}
        schedule(self._execute_search_result_action_async(action_id, context))
        return {"ok": True, "message": "Action scheduled"}

    @Slot(result="QVariantList")
    def getPluginKeybindings(self) -> list[dict]:
        if self._manager:
            return self._manager.get_keybindings()
        return []

    @Slot(result="QVariantList")
    def getResolvedKeybindings(self) -> list[dict]:
        if self._manager:
            return self._manager.get_resolved_keybindings()
        return []

    @Slot(str, str, result=str)
    def resolveKeybinding(self, sequence: str, fallback_command: str = "") -> str:
        if self._manager:
            return self._manager.resolve_keybinding(sequence, fallback_command)
        return fallback_command

    @Slot(result="QVariantList")
    def getEditorDecorations(self) -> list[dict]:
        if self._manager:
            return self._manager.get_editor_decorations()
        return []

    @Slot(str, result=bool)
    def hasEditorDecoration(self, decoration_id: str) -> bool:
        if self._manager:
            return self._manager.has_editor_decoration(decoration_id)
        return False

    @Slot(result="QVariantMap")
    def getPluginIcons(self) -> dict:
        if self._manager:
            return self._manager.get_icons()
        return {}

    @Slot(result="QVariantMap")
    def getFileIconAssociations(self) -> dict:
        if self._manager:
            return self._manager.get_file_icons()
        return {}

    @Slot(str, result="QVariantMap")
    def getPluginIconsFor(self, plugin_name: str) -> dict:
        if self._manager:
            return self._manager.get_icons_for(plugin_name)
        return {}

    @Slot(str, result="QVariantMap")
    def getFileIconAssociationsFor(self, plugin_name: str) -> dict:
        if self._manager:
            return self._manager.get_file_icons_for(plugin_name)
        return {}

    @Slot(str, result="QVariantList")
    def getAppearanceProviderOptions(self, aspect: str) -> list[dict]:
        if self._manager:
            return self._manager.get_appearance_provider_options(aspect)
        return [{"name": "core", "displayName": "Core", "active": True, "capabilities": ["fonts"]}]

    @Slot(result="QVariantList")
    def getAiProviderOptions(self) -> list[dict]:
        if self._manager:
            return self._manager.get_ai_provider_options()
        return [
            {
                "id": "ollama",
                "name": "ollama",
                "label": "Ollama",
                "displayName": "Ollama",
                "description": "Local OpenAI-compatible provider.",
                "plugin": "core",
                "providerType": "openai-compatible",
                "endpoint": "http://localhost:11434",
                "defaultModel": "codellama:7b",
                "models": ["codellama:7b"],
                "requiresApiKey": False,
                "configSchema": {},
                "defaults": {},
            }
        ]

    @Slot(result="QVariantList")
    @Slot(str, result="QVariantList")
    def getLspProviderOptions(self, language: str = "") -> list[dict]:
        if self._manager:
            return self._manager.get_lsp_provider_options(language)
        return [
            {
                "id": "python.ty",
                "name": "python.ty",
                "label": "ty",
                "displayName": "ty",
                "language": "python",
                "description": "Fast Python type checker and language server.",
                "plugin": "core",
                "command": "ty",
                "args": ["server"],
                "env": {},
                "fileExtensions": [".py", ".pyi"],
                "rootPatterns": ["pyproject.toml", ".git"],
                "capabilities": ["hover", "completion", "diagnostics", "symbols"],
                "configSchema": {},
                "defaults": {},
                "install": {},
                "active": True,
            }
        ]

    @Slot(result="QVariantList")
    @Slot(str, result="QVariantList")
    @Slot(str, str, result="QVariantList")
    def getFileFormatterOptions(self, language: str = "", extension: str = "") -> list[dict]:
        if self._manager:
            return self._manager.get_file_formatter_options(language, extension)
        return [
            {
                "id": "core.ruff-format",
                "name": "core.ruff-format",
                "label": "ruff format",
                "displayName": "ruff format",
                "language": "python",
                "languages": ["python"],
                "extensions": [".py", ".pyi"],
                "command": "ruff",
                "args": ["format", "{file}"],
                "priority": 100,
                "active": True,
            }
        ]

    @Slot(str, result="QVariantList")
    def getFontsFor(self, plugin_name: str) -> list[dict]:
        if self._manager:
            return self._manager.get_fonts_for(plugin_name)
        return [{"id": "menlo", "label": "Menlo", "family": "Menlo", "fallbacks": ["Monaco", "Courier New"]}]

    @Slot(str, result="QVariantList")
    def loadFontsFor(self, plugin_name: str) -> list[str]:
        if self._manager:
            return self._manager.load_fonts_for(plugin_name)
        return []

    @Slot(result="QVariantList")
    def getPermissionRequests(self) -> list[dict]:
        if self._manager:
            return self._manager.get_permission_requests()
        return []

    @Slot(result="QVariantMap")
    def getPluginStats(self) -> dict:
        plugins = self._plugins_data or []
        active = [p for p in plugins if p.get("active")]
        enabled = [p for p in plugins if p.get("enabled")]
        proprietary = [p for p in plugins if p.get("proprietary")]
        return {
            "installed": len(plugins),
            "enabled": len(enabled),
            "active": len(active),
            "proprietary": len(proprietary),
            "commands": len(self.getPluginCommands()),
            "views": len(self.getPluginViews("sidebar")),
            "panels": len(self.getPluginPanels("bottom")) + len(self.getPluginPanels("right")),
            "searchProviders": len(self.getSearchProviders()),
            "permissions": len(self.getPermissionRequests()),
        }

    # ── Properties ───────────────────────────────────────

    @Property("QVariantList", notify=pluginsChanged)
    def plugins(self) -> list[dict]:
        return self._plugins_data

    @Property("QVariantMap", notify=installStatusChanged)
    def installStatus(self) -> dict:
        return dict(self._install_status)

    @Property("QVariantMap", notify=updateStatusChanged)
    def updateStatus(self) -> dict:
        return dict(self._update_status)

    @Property("QVariantList", notify=storeChanged)
    def pluginStore(self) -> list[dict]:
        return list(self._store_plugins)

    @Property("QVariantList", notify=storeChanged)
    def pluginStoreSources(self) -> list[str]:
        return list(self._store_sources)

    @Property(str, notify=storeChanged)
    def pluginStoreApiUrl(self) -> str:
        return self._store_api_url

    def _set_install_status(self, payload: dict) -> None:
        self._install_status = {
            "state": payload.get("state", "idle"),
            "ok": bool(payload.get("ok", False)),
            "message": str(payload.get("message", "")),
            "errors": list(payload.get("errors", []) or []),
            "source": str(payload.get("source", "")),
            "manifest": dict(payload.get("manifest", {}) or {}),
        }
        self.installStatusChanged.emit(self._install_status)

    def _set_update_status(self, payload: dict) -> None:
        self._update_status = {
            "plugin": str(payload.get("plugin", "")),
            "state": str(payload.get("state", "idle")),
            "canUpdate": bool(payload.get("canUpdate", False)),
            "message": str(payload.get("message", "")),
            "source": str(payload.get("source", "")),
            "storedHash": str(payload.get("storedHash", "")),
            "candidateHash": str(payload.get("candidateHash", "")),
            "candidate": dict(payload.get("candidate", {}) or {}),
            "diff": dict(payload.get("diff", {}) or {}),
        }
        self.updateStatusChanged.emit(self._update_status)

    async def _load_plugins_async(self) -> None:
        try:
            await self._manager.discover_all()
            await self._manager.apply_policies()
            self._plugins_data = self._manager.registry.get_legacy_configs()
            self.pluginsChanged.emit()
            self.contributionsChanged.emit()
            self.permissionsChanged.emit()
        except Exception as exc:
            print(f"[PluginVM] load error: {exc}")

    async def _activate_plugin_async(self, name: str) -> None:
        try:
            result = await self._manager.activate(name)
            if result:
                self._plugins_data = self._manager.registry.get_legacy_configs()
                self.pluginsChanged.emit()
                self.contributionsChanged.emit()
                self.permissionsChanged.emit()
                self.pluginActivated.emit(name)
        except Exception as exc:
            print(f"[PluginVM] activate error for {name}: {exc}")

    async def _deactivate_plugin_async(self, name: str) -> None:
        try:
            result = await self._manager.deactivate(name)
            if result:
                self._plugins_data = self._manager.registry.get_legacy_configs()
                self.pluginsChanged.emit()
                self.contributionsChanged.emit()
                self.permissionsChanged.emit()
                self.pluginDeactivated.emit(name)
        except Exception as exc:
            print(f"[PluginVM] deactivate error for {name}: {exc}")

    async def _install_plugin_async(self, source: str) -> None:
        self._busy_start("install", "Installing plugin…")
        try:
            state = await self._manager.install(source)
            if not state:
                return
            await self._manager.activate(state.manifest.name)
            self._plugins_data = self._manager.registry.get_legacy_configs()
            self.pluginsChanged.emit()
            self.contributionsChanged.emit()
            self.permissionsChanged.emit()
            self.pluginInstalled.emit(state.manifest.name)
            self._set_install_status({
                "state": "installed",
                "ok": True,
                "message": f"Installed {state.manifest.display_name}.",
                "errors": [],
                "source": source,
                "manifest": state.manifest.model_dump(),
            })
            self._notify("success", "Plugin installed", state.manifest.display_name)
        except Exception as exc:
            self._set_install_status({
                "state": "failed",
                "ok": False,
                "message": str(exc),
                "errors": [str(exc)],
                "source": source,
                "manifest": {},
            })
            self._notify("error", "Plugin install failed", str(exc))
            print(f"[PluginVM] install error: {exc}")
        finally:
            self._busy_end("install")

    async def _apply_plugin_policies_async(self) -> None:
        try:
            await self._manager.apply_policies()
            self.refresh_from_manager()
        except Exception as exc:
            print(f"[PluginVM] apply policies error: {exc}")

    async def _uninstall_plugin_async(self, name: str) -> None:
        self._busy_start(f"uninstall:{name}", "Removing plugin…")
        try:
            if self._manager.is_active(name):
                await self._manager.deactivate(name)
            await self._manager.registry.uninstall(name)
            self._plugins_data = self._manager.registry.get_legacy_configs()
            self.pluginsChanged.emit()
            self.contributionsChanged.emit()
            self.permissionsChanged.emit()
            self._notify("info", "Plugin removed", name)
        except Exception as exc:
            self._notify("error", "Plugin removal failed", str(exc))
            print(f"[PluginVM] uninstall error for {name}: {exc}")
        finally:
            self._busy_end(f"uninstall:{name}")

    async def _execute_file_browser_action_async(self, action_id: str, context: dict) -> None:
        self._busy_start(f"file-action:{action_id}", "Running file action…")
        try:
            result = await self._manager.execute_file_action(action_id, context or {})
            self.fileActionCompleted.emit(result)
            if result.get("ok"):
                self._notify("success", "File action completed", result.get("message", ""))
            else:
                self._notify("error", "File action failed", result.get("message", ""))
        except Exception as exc:
            self._notify("error", "File action failed", str(exc))
            print(f"[PluginVM] file action error for {action_id}: {exc}")
        finally:
            self._busy_end(f"file-action:{action_id}")

    async def _execute_search_result_action_async(self, action_id: str, context: dict) -> None:
        self._busy_start(f"search-result-action:{action_id}", "Running search action…")
        try:
            result = await self._manager.execute_search_result_action(action_id, context or {})
            self.searchResultActionCompleted.emit(result)
            if result.get("ok"):
                self._notify("success", "Search action completed", result.get("message", ""))
            else:
                self._notify("error", "Search action failed", result.get("message", ""))
        except Exception as exc:
            self._notify("error", "Search action failed", str(exc))
            print(f"[PluginVM] search result action error for {action_id}: {exc}")
        finally:
            self._busy_end(f"search-result-action:{action_id}")

    async def _trust_plugin_manifest_async(self, name: str) -> None:
        try:
            if await self._manager.trust_current_manifest(name):
                self.refresh_from_manager()
        except Exception as exc:
            print(f"[PluginVM] trust manifest error for {name}: {exc}")

    async def _check_plugin_update_async(self, name: str) -> None:
        try:
            self._set_update_status(await self._manager.check_update(name))
        except Exception as exc:
            self._set_update_status({
                "plugin": name,
                "state": "failed",
                "canUpdate": False,
                "message": str(exc),
            })
            print(f"[PluginVM] check update error for {name}: {exc}")

    async def _update_plugin_from_source_async(self, name: str) -> None:
        self._busy_start(f"update:{name}", "Updating plugin…")
        try:
            self._set_update_status({
                "plugin": name,
                "state": "updating",
                "canUpdate": False,
                "message": "Updating plugin…",
            })
            state = await self._manager.update_from_source(name)
            self.refresh_from_manager()
            if state:
                self._set_update_status(await self._manager.check_update(state.manifest.name))
                self._notify("success", "Plugin updated", state.manifest.display_name)
        except Exception as exc:
            self._set_update_status({
                "plugin": name,
                "state": "failed",
                "canUpdate": False,
                "message": str(exc),
            })
            self._notify("error", "Plugin update failed", str(exc))
            print(f"[PluginVM] update plugin error for {name}: {exc}")
        finally:
            self._busy_end(f"update:{name}")

    async def _load_plugin_store_async(self) -> None:
        self._busy_start("store", "Refreshing plugin marketplace…")
        try:
            await self._manager.discover_all()
            self._store_sources = self._manager.get_store_sources()
            self._store_api_url = self._manager.get_store_api_url()
            self._store_plugins = await self._manager.scan_store_async()
            self._plugins_data = self._manager.registry.get_legacy_configs()
            self.pluginsChanged.emit()
            self.storeChanged.emit()
        except Exception as exc:
            self._notify("error", "Plugin store scan failed", str(exc))
            print(f"[PluginVM] load store error: {exc}")
        finally:
            self._busy_end("store")

    async def _install_store_plugin_async(self, source: str, archive_hash: str = "") -> None:
        self._busy_start("store-install", "Downloading plugin…")
        try:
            state = await self._manager.install_store_plugin(source, archive_hash)
            if not state:
                return
            await self._manager.activate(state.manifest.name)
            self.refresh_from_manager()
            self.pluginInstalled.emit(state.manifest.name)
            self._set_install_status({
                "state": "installed",
                "ok": True,
                "message": f"Installed {state.manifest.display_name}.",
                "errors": [],
                "source": source,
                "manifest": state.manifest.model_dump(),
            })
            self._notify("success", "Plugin installed", state.manifest.display_name)
            schedule(self._load_plugin_store_async())
        except Exception as exc:
            self._set_install_status({
                "state": "failed",
                "ok": False,
                "message": str(exc),
                "errors": [str(exc)],
                "source": source,
                "manifest": {},
            })
            self._notify("error", "Marketplace install failed", str(exc))
            print(f"[PluginVM] store install error: {exc}")
        finally:
            self._busy_end("store-install")

    async def _approve_permissions_async(self, name: str) -> None:
        try:
            if await self._manager.approve_permissions(name):
                await self._manager.activate(name)
                self.refresh_from_manager()
                self.pluginActivated.emit(name)
        except Exception as exc:
            print(f"[PluginVM] approve permissions error for {name}: {exc}")

    async def _revoke_permissions_async(self, name: str) -> None:
        try:
            if await self._manager.revoke_permissions(name):
                self.refresh_from_manager()
                self.pluginDeactivated.emit(name)
        except Exception as exc:
            print(f"[PluginVM] revoke permissions error for {name}: {exc}")

    @Property("QVariantList", notify=contributionsChanged)
    def pluginCommands(self) -> list[dict]:
        return self.getPluginCommands()

    @Property("QVariantList", notify=contributionsChanged)
    def pluginKeybindings(self) -> list[dict]:
        return self.getPluginKeybindings()

    @Property("QVariantList", notify=contributionsChanged)
    def editorDecorations(self) -> list[dict]:
        return self.getEditorDecorations()

    @Property("QVariantMap", notify=contributionsChanged)
    def pluginIcons(self) -> dict:
        return self.getPluginIcons()

    @Property("QVariantMap", notify=contributionsChanged)
    def fileIconAssociations(self) -> dict:
        return self.getFileIconAssociations()

    @Property("QVariantList", notify=contributionsChanged)
    def sidebarViews(self) -> list[dict]:
        return self.getPluginViews("sidebar")

    @Property("QVariantList", notify=permissionsChanged)
    def permissionRequests(self) -> list[dict]:
        return self.getPermissionRequests()
