from __future__ import annotations

from typing import Any

from PySide6.QtCore import QObject, Property, Signal, Slot

from app.core.async_tasks import schedule
from app.services.action_service import ActionDefinition, ActionService


class ActionViewModel(QObject):
    actionsChanged = Signal()
    runningChanged = Signal()
    historyChanged = Signal()
    actionCompleted = Signal("QVariantMap")
    actionFailed = Signal("QVariantMap")

    def __init__(self, service: ActionService, parent: QObject | None = None):
        super().__init__(parent)
        self._service = service
        self._command_vm = None
        self._plugin_vm = None
        self._editor_vm = None
        self._file_vm = None
        self._search_vm = None
        self._settings_vm = None
        self._notification_vm = None
        self._status_vm = None
        self._service.on_changed(self._emit_state_changed)

    def set_command_vm(self, command_vm) -> None:
        self._command_vm = command_vm
        self._register_core_actions()

    def set_plugin_vm(self, plugin_vm) -> None:
        self._plugin_vm = plugin_vm
        self._register_core_actions()

    def set_editor_vm(self, editor_vm) -> None:
        self._editor_vm = editor_vm
        self._register_core_actions()

    def set_file_vm(self, file_vm) -> None:
        self._file_vm = file_vm
        self._register_core_actions()

    def set_search_vm(self, search_vm) -> None:
        self._search_vm = search_vm
        self._register_core_actions()

    def set_settings_vm(self, settings_vm) -> None:
        self._settings_vm = settings_vm
        self._register_core_actions()

    def set_notification_vm(self, notification_vm) -> None:
        self._notification_vm = notification_vm

    def set_status_vm(self, status_vm) -> None:
        self._status_vm = status_vm
        self._register_core_actions()

    def register_action(
        self,
        action_id: str,
        title: str,
        category: str = "General",
        description: str = "",
        source: str = "core",
        busy_label: str = "Working…",
        handler=None,
        notify: bool = True,
        requires_payload: bool = False,
    ) -> None:
        self._service.register(ActionDefinition(
            id=action_id,
            title=title,
            category=category,
            description=description,
            source=source,
            busy_label=busy_label,
            notify=notify,
            requires_payload=requires_payload,
            handler=handler,
        ))

    @Slot(str, result=bool)
    @Slot(str, "QVariantMap", result=bool)
    def runAction(self, action_id: str, payload: dict | None = None) -> bool:
        if not action_id:
            return False
        schedule(self._run_action_async(action_id, dict(payload or {})))
        return True

    @Slot(str, result=bool)
    def isRunning(self, action_id: str) -> bool:
        return self._service.is_running(action_id)

    @Slot()
    def clearHistory(self) -> None:
        self._service.clear_history()

    @Property("QVariantList", notify=actionsChanged)
    def actions(self) -> list[dict[str, Any]]:
        return self._service.list_actions()

    @Property("QVariantList", notify=runningChanged)
    def runningActions(self) -> list[dict[str, Any]]:
        return self._service.running_actions()

    @Property("QVariantList", notify=historyChanged)
    def history(self) -> list[dict[str, Any]]:
        return self._service.history()

    @Property(bool, notify=runningChanged)
    def busy(self) -> bool:
        return bool(self._service.running_actions())

    async def _run_action_async(self, action_id: str, payload: dict) -> None:
        action = next((item for item in self._service.list_actions() if item["id"] == action_id), None)
        busy_key = f"action:{action_id}"
        should_notify = bool(action.get("notify", True)) if action else True
        if self._notification_vm and action:
            self._notification_vm.startBusy(busy_key, action.get("busyLabel") or action.get("title") or "Working…")
        result = await self._service.execute(action_id, payload)
        if self._notification_vm:
            self._notification_vm.endBusy(busy_key)
            message = result.get("message", "")
            if result.get("ok") and should_notify:
                self._notification_vm.success("Action completed", message, 2600)
            elif not result.get("ok"):
                self._notification_vm.error("Action failed", message, 5600)
        if self._status_vm:
            level = "success" if result.get("ok") else "error"
            self._status_vm.append_console(level, f"{action_id}: {result.get('message', '')}")
        if result.get("ok"):
            self.actionCompleted.emit(result)
        else:
            self.actionFailed.emit(result)

    def _register_core_actions(self) -> None:
        if self._command_vm:
            self.register_action(
                "command.execute",
                "Execute Command",
                "Command",
                "Runs a registered editor command.",
                "core",
                "Executing command…",
                self._execute_command,
                requires_payload=True,
            )
        if self._status_vm:
            self.register_action(
                "clipboard.copy_text",
                "Copy Text",
                "Workbench",
                "Copies text to the system clipboard.",
                "core",
                "Copying…",
                self._copy_text,
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "output.clear",
                "Clear Output",
                "Workbench",
                "Clears the output panel.",
                "core",
                "Clearing output…",
                lambda _payload: self._status_vm.clear_output(),
            )
            self.register_action(
                "console.clear",
                "Clear Console",
                "Workbench",
                "Clears the console panel.",
                "core",
                "Clearing console…",
                lambda _payload: self._status_vm.clear_console(),
            )
            self.register_action(
                "problems.clear",
                "Clear Problems",
                "Workbench",
                "Clears current diagnostics.",
                "core",
                "Clearing problems…",
                lambda _payload: self._status_vm.clear_diagnostics(),
            )
        if self._search_vm:
            self.register_action(
                "search.run",
                "Run Search",
                "Search",
                "Runs a workspace search.",
                "core",
                "Searching…",
                self._run_search,
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "search.clear",
                "Clear Search",
                "Search",
                "Clears search results.",
                "core",
                "Clearing search…",
                lambda _payload: self._search_vm.clear(),
                notify=False,
            )
            self.register_action(
                "search.copy_path",
                "Copy Search Result Path",
                "Search",
                "Copies a search result path.",
                "core",
                "Copying path…",
                lambda payload: self._search_vm.copyPath(str(payload.get("path") or "")),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "search.result_action",
                "Emit Search Result Action",
                "Search",
                "Emits the search result action event for plugins.",
                "core",
                "Running search result action…",
                lambda payload: self._search_vm.emitResultAction(dict(payload.get("result") or {})),
                notify=False,
                requires_payload=True,
            )
        if self._notification_vm:
            self.register_action(
                "notifications.clear",
                "Clear Notifications",
                "Workbench",
                "Dismisses all visible notifications.",
                "core",
                "Clearing notifications…",
                lambda _payload: self._notification_vm.clear(),
            )
        if self._plugin_vm:
            self.register_action(
                "plugins.refresh_store",
                "Refresh Plugin Store",
                "Plugins",
                "Refreshes the configured plugin marketplace.",
                "core",
                "Refreshing plugin marketplace…",
                lambda _payload: self._plugin_vm.loadPluginStore(),
                notify=False,
            )
            self.register_action(
                "plugins.activate",
                "Activate Plugin",
                "Plugins",
                "Activates an installed plugin.",
                "core",
                "Activating plugin…",
                lambda payload: self._require_plugin_call("activatePlugin", payload),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "plugins.deactivate",
                "Deactivate Plugin",
                "Plugins",
                "Deactivates an installed plugin.",
                "core",
                "Deactivating plugin…",
                lambda payload: self._require_plugin_call("deactivatePlugin", payload),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "plugins.uninstall",
                "Uninstall Plugin",
                "Plugins",
                "Uninstalls a removable plugin.",
                "core",
                "Uninstalling plugin…",
                lambda payload: self._require_plugin_call("uninstallPlugin", payload),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "plugins.check_update",
                "Check Plugin Update",
                "Plugins",
                "Checks whether a plugin source has changed.",
                "core",
                "Checking plugin update…",
                lambda payload: self._require_plugin_call("checkPluginUpdate", payload),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "plugins.update",
                "Update Plugin",
                "Plugins",
                "Updates a plugin from its trusted source.",
                "core",
                "Updating plugin…",
                lambda payload: self._require_plugin_call("updatePluginFromSource", payload),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "plugins.install_store",
                "Install Store Plugin",
                "Plugins",
                "Installs a plugin from the configured marketplace.",
                "core",
                "Installing plugin…",
                self._install_store_plugin,
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "plugins.install_local",
                "Install Local Plugin",
                "Plugins",
                "Installs a plugin from a local source.",
                "core",
                "Installing plugin…",
                self._install_local_plugin,
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "file_browser.plugin_action",
                "Run File Plugin Action",
                "Files",
                "Runs a contributed plugin action for a file browser item.",
                "core",
                "Running file action…",
                self._run_file_plugin_action,
                notify=False,
                requires_payload=True,
            )
        if self._editor_vm:
            self.register_action(
                "lsp.start",
                "Start LSP",
                "LSP",
                "Starts language servers for the current editor context.",
                "core",
                "Starting LSP…",
                lambda _payload: self._editor_vm.startLsp(),
                notify=False,
            )
            self.register_action(
                "lsp.stop",
                "Stop LSP",
                "LSP",
                "Stops active language servers.",
                "core",
                "Stopping LSP…",
                lambda _payload: self._editor_vm.stopLsp(),
                notify=False,
            )
            self.register_action(
                "lsp.restart",
                "Restart LSP",
                "LSP",
                "Restarts active language servers.",
                "core",
                "Restarting LSP…",
                lambda _payload: self._editor_vm.restartLsp(),
                notify=False,
            )
            self.register_action(
                "lsp.refresh_status",
                "Refresh LSP Status",
                "LSP",
                "Refreshes language server status.",
                "core",
                "Refreshing LSP status…",
                lambda _payload: self._editor_vm.refreshLspStatus(),
                notify=False,
            )
        if self._settings_vm:
            self.register_action(
                "ai.refresh_models",
                "Refresh AI Models",
                "AI",
                "Refreshes available models for a configured AI provider.",
                "core",
                "Refreshing AI models…",
                self._refresh_ai_models,
                notify=False,
                requires_payload=True,
            )
        if self._file_vm:
            self.register_action(
                "file_browser.create_file",
                "Create File",
                "Files",
                "Creates a file in the file browser.",
                "core",
                "Creating file…",
                lambda payload: self._file_operation("createFileAt", payload, "parent", "name"),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "file_browser.create_folder",
                "Create Folder",
                "Files",
                "Creates a folder in the file browser.",
                "core",
                "Creating folder…",
                lambda payload: self._file_operation("createFolderAt", payload, "parent", "name"),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "file_browser.rename",
                "Rename Path",
                "Files",
                "Renames a file or folder.",
                "core",
                "Renaming…",
                lambda payload: self._file_operation("renamePath", payload, "path", "name"),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "file_browser.delete",
                "Delete Path",
                "Files",
                "Deletes a file or folder.",
                "core",
                "Deleting…",
                lambda payload: self._file_operation("deletePath", payload, "path"),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "file_browser.copy",
                "Copy Path",
                "Files",
                "Copies a file or folder into the file clipboard.",
                "core",
                "Copying…",
                lambda payload: self._file_operation("copyPath", payload, "path"),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "file_browser.cut",
                "Cut Path",
                "Files",
                "Prepares a file or folder for move.",
                "core",
                "Preparing move…",
                lambda payload: self._file_operation("cutPath", payload, "path"),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "file_browser.paste",
                "Paste Into Folder",
                "Files",
                "Pastes the current file clipboard into a folder.",
                "core",
                "Pasting…",
                lambda payload: self._file_operation("pasteInto", payload, "folder"),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "file_browser.move",
                "Move Path",
                "Files",
                "Moves a file or folder into another folder.",
                "core",
                "Moving…",
                lambda payload: self._file_operation("movePath", payload, "path", "folder"),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "file_browser.copy_link",
                "Copy Path Link",
                "Files",
                "Copies a path link to the clipboard.",
                "core",
                "Copying path…",
                lambda payload: self._file_operation("copyLink", payload, "path"),
                notify=False,
                requires_payload=True,
            )
            self.register_action(
                "file_browser.format",
                "Format Path",
                "Files",
                "Formats a file through the configured formatter.",
                "core",
                "Formatting…",
                lambda payload: self._file_operation("formatPath", payload, "path"),
                notify=False,
                requires_payload=True,
            )
        self.register_action(
            "actions.clear_history",
            "Clear Action History",
            "Workbench",
            "Clears the action execution history.",
            "core",
            "Clearing action history…",
            lambda _payload: self._service.clear_history(),
        )

    def _execute_command(self, payload: dict) -> dict:
        command_id = str(payload.get("command") or payload.get("id") or "")
        if not command_id:
            raise ValueError("Missing command id")
        if not self._command_vm or not self._command_vm.executeCommand(command_id):
            raise ValueError(f"Command is not executable: {command_id}")
        return {"message": f"Executed {command_id}"}

    def _copy_text(self, payload: dict) -> dict:
        text = str(payload.get("text") or "")
        if not self._status_vm:
            raise ValueError("Clipboard service unavailable")
        self._status_vm.copy_text(text)
        return {"message": "Copied to clipboard"}

    def _run_search(self, payload: dict) -> dict:
        query = str(payload.get("query") or "").strip()
        if not query:
            raise ValueError("Missing search query")
        self._search_vm.search(query)
        return {"message": f"Search queued: {query}"}

    def _require_plugin_call(self, method_name: str, payload: dict) -> dict:
        plugin_id = str(payload.get("plugin") or payload.get("id") or "").strip()
        if not plugin_id:
            raise ValueError("Missing plugin id")
        method = getattr(self._plugin_vm, method_name, None)
        if not callable(method) or not method(plugin_id):
            raise ValueError(f"Plugin action failed: {method_name}({plugin_id})")
        return {"message": f"{method_name} queued for {plugin_id}"}

    def _install_store_plugin(self, payload: dict) -> dict:
        source = str(payload.get("source") or "").strip()
        archive_hash = str(payload.get("archiveHash") or payload.get("archive_hash") or "")
        if not source:
            raise ValueError("Missing plugin source")
        if not self._plugin_vm.installStorePlugin(source, archive_hash):
            raise ValueError(f"Plugin install failed: {source}")
        return {"message": f"Install queued: {source}"}

    def _install_local_plugin(self, payload: dict) -> dict:
        source = str(payload.get("source") or "").strip()
        if not source:
            raise ValueError("Missing plugin source")
        if not self._plugin_vm.installPlugin(source):
            raise ValueError(f"Plugin install failed: {source}")
        return {"message": f"Install queued: {source}"}

    def _refresh_ai_models(self, payload: dict) -> dict:
        provider_id = str(payload.get("providerId") or payload.get("provider") or "").strip()
        endpoint = str(payload.get("endpoint") or "")
        provider_type = str(payload.get("providerType") or "")
        if not provider_id:
            raise ValueError("Missing provider id")
        self._settings_vm.refreshAiProviderModels(provider_id, endpoint, provider_type)
        return {"message": f"AI model refresh queued for {provider_id}"}

    def _file_operation(self, method_name: str, payload: dict, *keys: str) -> dict:
        if not self._file_vm:
            raise ValueError("File service unavailable")
        values = [str(payload.get(key) or "").strip() for key in keys]
        missing = [key for key, value in zip(keys, values) if not value]
        if missing:
            raise ValueError(f"Missing file action field: {', '.join(missing)}")
        method = getattr(self._file_vm, method_name, None)
        if not callable(method):
            raise ValueError(f"Unknown file operation: {method_name}")
        result = method(*values)
        if not isinstance(result, dict) or not result.get("ok"):
            message = result.get("message", "File operation failed") if isinstance(result, dict) else "File operation failed"
            raise ValueError(message)
        return {"message": result.get("message", "Done"), "result": result}

    def _run_file_plugin_action(self, payload: dict) -> dict:
        if not self._plugin_vm:
            raise ValueError("Plugin service unavailable")
        action_id = str(payload.get("actionId") or payload.get("id") or "").strip()
        context = payload.get("context") or {}
        if not action_id:
            raise ValueError("Missing file plugin action id")
        if not self._plugin_vm.executeFileBrowserAction(action_id, context):
            raise ValueError(f"File plugin action failed: {action_id}")
        return {"message": f"File plugin action queued: {action_id}"}

    def _emit_state_changed(self) -> None:
        self.actionsChanged.emit()
        self.runningChanged.emit()
        self.historyChanged.emit()
