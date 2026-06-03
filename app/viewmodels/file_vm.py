from __future__ import annotations

import os
import asyncio
import aiofiles
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from app.core.async_tasks import schedule
from app.core.events import EventBus
from app.services.file_operations_service import FileOperationsService
from app.services.file_watcher import FileWatcherService
from app.services.workspace_service import WorkspaceService, project_avatar, project_color


class FileViewModel(QObject):
    folderChanged = Signal(str)
    workspaceRestored = Signal(str)
    projectChanged = Signal("QVariantMap")
    historyChanged = Signal()
    recentProjectsChanged = Signal()
    fileListChanged = Signal()

    def __init__(
        self,
        events: EventBus,
        workspace_service: WorkspaceService | None = None,
        parent: QObject | None = None,
    ):
        super().__init__(parent)
        self._events = events
        self._workspace_service = workspace_service or WorkspaceService()
        self._current_folder = ""
        self._current_project: dict = {}
        self._recent_files: list[dict] = []
        self._recent_projects: list[dict] = []
        self._file_list: list[dict] = []
        self._operations = FileOperationsService(events)
        self._watcher = FileWatcherService(events)
        self._notification_vm = None
        self._plugin_vm = None
        self._settings_vm = None
        self._restore_workspace = True
        self._watcher_enabled = True
        self._pending_external_paths: set[str] = set()
        self._external_refresh_timer = QTimer(self)
        self._external_refresh_timer.setSingleShot(True)
        self._external_refresh_timer.setInterval(250)
        self._external_refresh_timer.timeout.connect(self._flush_external_file_changes)
        self._events.on("file:external_change", self._on_external_file_change)

    def set_notification_vm(self, notification_vm) -> None:
        self._notification_vm = notification_vm

    def set_plugin_vm(self, plugin_vm) -> None:
        self._plugin_vm = plugin_vm
        if plugin_vm:
            plugin_vm.contributionsChanged.connect(self.refresh_formatters)
        self.refresh_formatters()

    def set_settings_vm(self, settings_vm) -> None:
        self._settings_vm = settings_vm
        if settings_vm:
            settings_vm.configChanged.connect(lambda *_: self.refresh_formatters())
            settings_vm.configChanged.connect(lambda *_: self.refresh_file_settings())
        self.refresh_formatters()
        self.refresh_file_settings()

    @Slot()
    @Slot("QVariantMap")
    def refresh_file_settings(self, *_args) -> None:
        config = {}
        if self._settings_vm:
            try:
                config = self._settings_vm.getFilesConfig()
            except Exception:
                config = {}
        self._restore_workspace = bool(config.get("restoreWorkspace", True))
        self._watcher_enabled = bool(config.get("watcherEnabled", True))
        self._operations.configure_listing(
            list(config.get("exclude", []) or []),
            bool(config.get("showHidden", False)),
        )
        self._sync_watcher()
        if self._current_folder:
            self._file_list = self.list_folder(self._current_folder)
            self.fileListChanged.emit()

    def refresh_formatters(self) -> None:
        formatters = []
        if self._plugin_vm:
            try:
                formatters = self._plugin_vm.getFileFormatterOptions()
            except Exception:
                formatters = []
        default_by_language = {}
        default_by_extension = {}
        if self._settings_vm:
            try:
                default_by_language = self._settings_vm.getDefaultFormatterByLanguage()
                default_by_extension = self._settings_vm.getDefaultFormatterByExtension()
            except Exception:
                pass
        self._operations.configure_formatters(formatters, default_by_language, default_by_extension)

    @Slot(str, result="QVariantList")
    def list_folder(self, path: str) -> list[dict]:
        return self._operations.list_folder(path)

    @Slot(str, result=bool)
    def openFolder(self, path: str) -> bool:
        if not os.path.isdir(path):
            return False
        next_folder = os.path.abspath(os.path.expanduser(path))
        if self._current_folder and next_folder != self._current_folder:
            self._watcher.stop()
        self._current_folder = next_folder
        project_name = os.path.basename(self._current_folder) or self._current_folder
        self._current_project = {
            "name": project_name,
            "path": self._current_folder,
            "template": "Existing",
            "isActive": True,
            "color": project_color(self._current_folder),
            "avatar": project_avatar(project_name),
        }
        self._file_list = self.list_folder(self._current_folder)
        self.fileListChanged.emit()
        self.folderChanged.emit(self._current_folder)
        self.projectChanged.emit(self._current_project)
        self._emit_file_event("folder:opened", path=self._current_folder, project=self._current_project)
        self._sync_watcher()
        schedule(self._persist_workspace(self._current_folder))
        return True

    @Slot()
    def loadWorkspace(self) -> None:
        if not self._restore_workspace:
            return
        schedule(self._load_workspace())

    @Slot()
    def closeWorkspace(self) -> None:
        self._watcher.stop()
        self._current_folder = ""
        self._current_project = {}
        self._file_list = []
        self.fileListChanged.emit()
        self.folderChanged.emit("")
        self.projectChanged.emit({})
        schedule(self._workspace_service.close_workspace())

    @Slot(str, result=bool)
    def is_dir(self, path: str) -> bool:
        return self._operations.is_dir(path)

    @Slot(str, result=str)
    def read_file(self, path: str) -> str:
        return self._operations.read_file(path)

    def _result(self, ok: bool, message: str = "", path: str = "") -> dict:
        if ok:
            self.fileListChanged.emit()
        return {"ok": ok, "message": message, "path": path}

    def _emit_file_event(self, event: str, **payload) -> None:
        schedule(self._events.emit(event, **payload))

    def _apply_operation_result(self, result: dict, action: str = "File operation") -> dict:
        if result.get("ok"):
            self.fileListChanged.emit()
            self._notify("success", action, result.get("message", "Done"))
        else:
            self._notify("error", f"{action} failed", result.get("message", "Operation failed"))
        return result

    def _notify(self, level: str, title: str, message: str = "") -> None:
        if not self._notification_vm:
            return
        method = getattr(self._notification_vm, level, None)
        if method:
            method(title, message, 3600 if level == "success" else 6500)

    @Slot(str)
    def notifyFileOpened(self, path: str) -> None:
        self._operations.notify_file_opened(path)

    @Slot(str, str, result="QVariantMap")
    def createFileAt(self, parent: str, name: str) -> dict:
        return self._apply_operation_result(self._operations.create_file(parent, name), "File created")

    @Slot(str, str, result="QVariantMap")
    def createFolderAt(self, parent: str, name: str) -> dict:
        return self._apply_operation_result(self._operations.create_folder(parent, name), "Folder created")

    @Slot(str, str, result="QVariantMap")
    def renamePath(self, path: str, new_name: str) -> dict:
        return self._apply_operation_result(self._operations.rename_path(path, new_name), "Rename")

    @Slot(str, result="QVariantMap")
    def deletePath(self, path: str) -> dict:
        return self._apply_operation_result(self._operations.delete_path(path), "Delete")

    @Slot(str, result="QVariantMap")
    def copyPath(self, path: str) -> dict:
        return self._apply_operation_result(self._operations.copy_path(path), "Copy")

    @Slot(str, result="QVariantMap")
    def cutPath(self, path: str) -> dict:
        return self._apply_operation_result(self._operations.cut_path(path), "Cut")

    @Slot(str, result="QVariantMap")
    def pasteInto(self, folder: str) -> dict:
        return self._apply_operation_result(self._operations.paste_into(folder), "Paste")

    @Slot(str, str, result="QVariantMap")
    def movePath(self, path: str, folder: str) -> dict:
        return self._apply_operation_result(self._operations.move_path(path, folder), "Move")

    @Slot(str, result="QVariantMap")
    def copyLink(self, path: str) -> dict:
        return self._apply_operation_result(self._operations.copy_link(path), "Path copied")

    @Slot(str, result="QVariantMap")
    def formatPath(self, path: str) -> dict:
        return self._apply_operation_result(self._operations.format_path(path, self._current_folder), "Format")

    async def read_file_async(self, path: str) -> str:
        try:
            async with aiofiles.open(path, "r", encoding="utf-8") as f:
                return await f.read()
        except Exception:
            return ""

    async def write_file_async(self, path: str, content: str) -> None:
        async with aiofiles.open(path, "w", encoding="utf-8") as f:
            await f.write(content)

    async def create_file(self, name: str, folder: str) -> dict:
        return self._operations.create_file(folder, name)

    async def create_folder(self, name: str, parent: str) -> dict:
        return self._operations.create_folder(parent, name)

    async def delete_file(self, path: str) -> None:
        self._operations.delete_path(path)

    async def load_history(self) -> list[dict]:
        from app.data.models import FileHistory

        history = await FileHistory.objects.order_by("-opened_at").limit(30).all()
        self._recent_files = [
            {"name": f.display_name, "path": f.path, "language": f.language}
            for f in history
        ]
        self._recent_projects = [
            workspace.to_dict()
            for workspace in await self._workspace_service.recent_workspaces(24)
        ]
        self.historyChanged.emit()
        self.recentProjectsChanged.emit()
        return self._recent_files

    @Slot()
    def loadHistory(self):
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(self.load_history())
        except RuntimeError:
            pass

    @Property(str, notify=folderChanged)
    def currentFolder(self) -> str:
        return self._current_folder

    @Property("QVariantMap", notify=projectChanged)
    def currentProject(self) -> dict:
        return self._current_project

    @Property("QVariantList", notify=historyChanged)
    def recentFiles(self) -> list[dict]:
        return self._recent_files

    @Property("QVariantList", notify=recentProjectsChanged)
    def recentProjects(self) -> list[dict]:
        return self._recent_projects

    async def _persist_workspace(self, path: str) -> None:
        try:
            state = await self._workspace_service.open_workspace(path)
            self._current_project = state.to_dict()
            self.projectChanged.emit(self._current_project)
            self._recent_projects = [
                workspace.to_dict()
                for workspace in await self._workspace_service.recent_workspaces(24)
            ]
            self.recentProjectsChanged.emit()
            await self._events.emit("workspace:open", **self._current_project)
        except Exception as exc:
            print(f"[FileVM] open workspace error: {exc}")

    async def _load_workspace(self) -> None:
        try:
            state = await self._workspace_service.get_active_workspace()
        except Exception as exc:
            print(f"[FileVM] restore workspace error: {exc}")
            return
        if not state:
            return
        self._current_folder = state.path
        self._current_project = state.to_dict()
        self._file_list = self.list_folder(state.path)
        self.fileListChanged.emit()
        self.folderChanged.emit(state.path)
        self.projectChanged.emit(self._current_project)
        self._sync_watcher()
        self._recent_projects = [
            workspace.to_dict()
            for workspace in await self._workspace_service.recent_workspaces(24)
        ]
        self.recentProjectsChanged.emit()
        self.workspaceRestored.emit(state.path)

    def _sync_watcher(self) -> None:
        if not self._watcher_enabled or not self._current_folder:
            self._watcher.stop()
            return
        self._watcher.watch(self._current_folder)

    def _on_external_file_change(self, path: str = "") -> None:
        if not self._watcher_enabled or not self._current_folder or not path:
            return
        try:
            current = os.path.abspath(self._current_folder)
            changed = os.path.abspath(path)
            if os.path.commonpath([current, changed]) != current:
                return
        except ValueError:
            return
        self._pending_external_paths.add(path)
        self._external_refresh_timer.start()

    def _flush_external_file_changes(self) -> None:
        if not self._current_folder or not self._pending_external_paths:
            return
        changed_count = len(self._pending_external_paths)
        self._pending_external_paths.clear()
        self._file_list = self.list_folder(self._current_folder)
        self.fileListChanged.emit()
        self._emit_file_event("folder:refreshed", path=self._current_folder, reason="external_change")
        if self._notification_vm and changed_count > 0:
            self._notification_vm.info(
                "File explorer refreshed",
                f"{changed_count} external change(s)",
                1800,
            )

    # ── File Dialogs (Qt6 compat) ────────────────────────

    @Slot(result=str)
    def openFileDialog(self) -> str:
        from PySide6.QtWidgets import QFileDialog
        path, _ = QFileDialog.getOpenFileName(
            None, "Open File", self._current_folder or os.path.expanduser("~"),
            "All Files (*);;Python (*.py);;Kivy (*.kv);;Text (*.txt *.md)",
        )
        return path or ""

    @Slot(result=str)
    def openFolderDialog(self) -> str:
        from PySide6.QtWidgets import QFileDialog
        path = QFileDialog.getExistingDirectory(
            None, "Open Folder", self._current_folder or os.path.expanduser("~"),
        )
        return path or ""

    @Slot(result=str)
    def saveFileDialog(self) -> str:
        from PySide6.QtWidgets import QFileDialog
        path, _ = QFileDialog.getSaveFileName(
            None, "Save File", self._current_folder or os.path.expanduser("~"),
            "All Files (*)",
        )
        return path or ""
