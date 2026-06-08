from __future__ import annotations

import os
import json
import asyncio
import time
from PySide6.QtCore import QObject, Signal, Slot, Property
from app.core.async_tasks import schedule
from app.core.events import EventBus
from app.services.editor_session_service import EditorSessionService
from app.services.file_operations_service import FileOperationsService
from app.services.language_detection import detect_language
from app.services.lsp_service import LSPClient
from app.services.lsp_process import uri_to_path


class EditorViewModel(QObject):
    textChanged = Signal(str)
    cursorChanged = Signal(int, int)
    fileOpened = Signal(str)
    fileContentReady = Signal(str, str)
    fileOpenFailed = Signal(str, str)
    fileSaved = Signal(str)
    fileFormatted = Signal(str, str)
    externalFileChanged = Signal("QVariantMap")
    suggestionReady = Signal(str)
    diagnosticsReady = Signal("QVariantList")
    completerReady = Signal(str)
    hoverReady = Signal("QVariantMap")
    symbolsReady = Signal("QVariantList")
    definitionReady = Signal("QVariantList")
    referencesReady = Signal("QVariantList")
    navigationReady = Signal("QVariantMap")
    codeActionsReady = Signal("QVariantList")
    codeActionPreviewReady = Signal("QVariantMap")
    codeActionApplied = Signal(str, str)
    lspStatusReady = Signal("QVariantMap")
    tabsChanged = Signal()
    dirtyTabsChanged = Signal()
    currentTabChanged = Signal(int)
    sessionRestored = Signal()

    def __init__(self, events: EventBus, parent: QObject | None = None):
        super().__init__(parent)
        self._events = events
        self._active_doc = None
        self._current_path = ""
        self._is_dirty = False
        self._language = "python"
        self._completion_generation = 0
        self._hover_generation = 0
        self._symbols_generation = 0
        self._definition_generation = 0
        self._references_generation = 0
        self._diagnostics_generation = 0
        self._code_actions_generation = 0
        self._document_generation = 0
        self._lsp = LSPClient()
        self._notification_vm = None
        self._session_service = EditorSessionService()
        self._open_generation = 0
        self._tabs: list[dict[str, str]] = []
        self._tab_content: dict[str, str] = {}
        self._dirty_tabs: dict[str, bool] = {}
        self._cursor_positions: dict[str, dict[str, int]] = {}
        self._current_tab_index = -1
        self._workspace_path = ""
        self._settings_vm = None
        self._plugin_vm = None
        self._operations = FileOperationsService(events)
        self._recent_internal_writes: dict[str, float] = {}
        self._external_change_pending: dict[str, dict] = {}
        self._symbols: list[dict] = []
        self._references: list[dict] = []
        self._navigation_back: list[dict] = []
        self._navigation_forward: list[dict] = []
        self._events.on("file:external_change", self._handle_external_file_change)

    # ── Active document management ───────────────────────

    @Slot("QVariant")
    def setActiveDocument(self, doc) -> None:
        self._active_doc = doc

    def set_notification_vm(self, notification_vm) -> None:
        self._notification_vm = notification_vm

    def set_settings_vm(self, settings_vm) -> None:
        self._settings_vm = settings_vm
        if settings_vm:
            settings_vm.configChanged.connect(self._apply_lsp_settings)
            settings_vm.configChanged.connect(lambda *_: self.refresh_formatters())
        self._apply_lsp_settings()
        self.refresh_formatters()

    def set_plugin_vm(self, plugin_vm) -> None:
        self._plugin_vm = plugin_vm
        if plugin_vm:
            plugin_vm.contributionsChanged.connect(self._apply_lsp_settings)
            plugin_vm.pluginsChanged.connect(self._apply_lsp_settings)
            plugin_vm.contributionsChanged.connect(self.refresh_formatters)
        self._apply_lsp_settings()
        self.refresh_formatters()

    @Slot()
    @Slot("QVariantMap")
    def refresh_formatters(self, *_args) -> None:
        formatters = []
        default_by_language = {}
        default_by_extension = {}
        if self._plugin_vm:
            try:
                formatters = self._plugin_vm.getFileFormatterOptions()
            except Exception:
                formatters = []
        if self._settings_vm:
            try:
                default_by_language = self._settings_vm.getDefaultFormatterByLanguage()
                default_by_extension = self._settings_vm.getDefaultFormatterByExtension()
            except Exception:
                default_by_language = {}
                default_by_extension = {}
        self._operations.configure_formatters(formatters, default_by_language, default_by_extension)

    @Slot()
    @Slot("QVariantMap")
    def _apply_lsp_settings(self, *_args) -> None:
        if not self._settings_vm:
            return
        try:
            languages = ["python", "rust", "javascript", "typescript", "json", "toml"]
            for language in languages:
                providers = self._settings_vm.getLspProvidersForLanguage(language)
                provider_options = (
                    self._plugin_vm.getLspProviderOptions(language)
                    if self._plugin_vm
                    else []
                )
                self._lsp.configure_lsp_providers(language, providers, provider_options)
            self._emit_lsp_status()
        except Exception as exc:
            print(f"[EditorVM] Could not apply LSP settings: {exc}")

    # ── QML Slots ────────────────────────────────────────

    @Slot(str, result="QString")
    def get_filename(self, path: str) -> str:
        return os.path.basename(path)

    @Slot(str, str, result=int)
    def addTab(self, title: str, content: str) -> int:
        tab_id = self._tab_id(title, content)
        for index, tab in enumerate(self._tabs):
            if tab.get("id") == tab_id:
                self._current_tab_index = index
                self.currentTabChanged.emit(index)
                return index
        self._tabs.append({"id": tab_id, "title": title, "content": content})
        self._tab_content[tab_id] = content
        self._current_tab_index = len(self._tabs) - 1
        self.tabsChanged.emit()
        self.currentTabChanged.emit(self._current_tab_index)
        self._schedule_session_save()
        return self._current_tab_index

    @Slot(int)
    def closeTab(self, index: int) -> None:
        if index < 0 or index >= len(self._tabs):
            return
        tab_id = self._tabs[index].get("id", "")
        content = self._tabs[index].get("content", "")
        if content and content not in {"welcome", "settings"}:
            schedule(self._close_document_async(content))
        self._tab_content.pop(tab_id, None)
        self._dirty_tabs.pop(tab_id, None)
        self._tabs.pop(index)
        if not self._tabs:
            self.tabsChanged.emit()
            self.dirtyTabsChanged.emit()
            self.addTab("Welcome", "welcome")
            return
        if index >= len(self._tabs):
            self._current_tab_index = len(self._tabs) - 1
        else:
            self._current_tab_index = index
        self.tabsChanged.emit()
        self.dirtyTabsChanged.emit()
        self.currentTabChanged.emit(self._current_tab_index)
        self._schedule_session_save()

    @Slot(int)
    def setCurrentTab(self, index: int) -> None:
        if index < 0 or index >= len(self._tabs):
            return
        if self._current_tab_index == index:
            return
        self._current_tab_index = index
        self.currentTabChanged.emit(index)
        self._schedule_session_save()

    @Slot()
    def closeAllTabs(self) -> None:
        self._set_welcome_tabs()
        self._schedule_session_save()

    @Slot(str)
    def switchWorkspaceSession(self, path: str) -> None:
        schedule(self._switch_workspace_session(path))

    def _set_welcome_tabs(self) -> None:
        self._tabs = []
        self._tab_content = {}
        self._dirty_tabs = {}
        self._current_tab_index = -1
        self.tabsChanged.emit()
        self.dirtyTabsChanged.emit()
        self.addTab("Welcome", "welcome")

    @Slot(int, int)
    def moveTab(self, from_index: int, to_index: int) -> None:
        if from_index == to_index:
            return
        if from_index < 0 or to_index < 0:
            return
        if from_index >= len(self._tabs) or to_index >= len(self._tabs):
            return
        active_title = self.currentTabTitle()
        active_id = self.currentTabId()
        tab = self._tabs.pop(from_index)
        self._tabs.insert(to_index, tab)
        self._current_tab_index = self._index_for_id(active_id) if active_id else self._index_for_title(active_title)
        self.tabsChanged.emit()
        self.currentTabChanged.emit(self._current_tab_index)
        self._schedule_session_save()

    @Slot(int, bool)
    def setTabDirty(self, index: int, dirty: bool) -> None:
        if index < 0 or index >= len(self._tabs):
            return
        tab_id = self._tabs[index].get("id", "")
        if dirty:
            self._dirty_tabs[tab_id] = True
        else:
            self._dirty_tabs.pop(tab_id, None)
        self.dirtyTabsChanged.emit()

    @Slot(int, result="QString")
    def tabTitle(self, index: int) -> str:
        if 0 <= index < len(self._tabs):
            return self._tabs[index].get("title", "")
        return ""

    @Slot(int, result="QString")
    def tabContent(self, index: int) -> str:
        tab_id = self.tabId(index)
        return self._tab_content.get(tab_id, "")

    @Slot(int, result="QString")
    def tabId(self, index: int) -> str:
        if 0 <= index < len(self._tabs):
            return self._tabs[index].get("id", "")
        return ""

    @Slot(result="QString")
    def currentTabTitle(self) -> str:
        return self.tabTitle(self._current_tab_index)

    @Slot(result="QString")
    def currentTabId(self) -> str:
        return self.tabId(self._current_tab_index)

    @Slot(result="QString")
    def currentTabContent(self) -> str:
        return self.tabContent(self._current_tab_index)

    @Slot(result=int)
    def tabCount(self) -> int:
        return len(self._tabs)

    @Slot()
    def loadEditorSession(self) -> None:
        schedule(self._load_editor_session())

    @Slot(str, int, int)
    def saveEditorSession(self, active_file: str = "", cursor_line: int = 1, cursor_col: int = 1) -> None:
        if active_file:
            self._cursor_positions[active_file] = {
                "line": max(1, int(cursor_line)),
                "col": max(1, int(cursor_col)),
            }
        self._schedule_session_save(active_file)

    @Slot(str, result="QString")
    def openfile(self, path: str) -> str | None:
        try:
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            self._current_path = path
            self._language = self._detect_language(path)
            self._completion_generation += 1
            self.completerReady.emit("[]")
            schedule(self._record_open(path, content))
            return content
        except Exception as e:
            print(f"[EditorVM] openfile error: {e}")
            return ""

    @Slot(str)
    def openFileAsync(self, path: str) -> None:
        self._open_generation += 1
        generation = self._open_generation
        self._current_path = path
        self._language = self._detect_language(path)
        self._completion_generation += 1
        self._hover_generation += 1
        self._symbols_generation += 1
        self._definition_generation += 1
        self._references_generation += 1
        self._diagnostics_generation += 1
        self._code_actions_generation += 1
        self.completerReady.emit("[]")
        self._symbols = []
        self._references = []
        self.symbolsReady.emit([])
        self.referencesReady.emit([])
        self._emit_lsp_status()
        schedule(self._open_async(path, generation))

    @Slot(str, str, str)
    def savefile(self, path: str, filename: str, content: str) -> None:
        schedule(self._save(path, content))

    @Slot(str, str)
    def formatDocument(self, path: str, content: str) -> None:
        schedule(self._format_document(path, content))

    @Slot(str)
    def reloadFileFromDisk(self, path: str) -> None:
        schedule(self._reload_from_disk(path))

    @Slot(str)
    def keepLocalFile(self, path: str) -> None:
        target = self._normalize_path(path)
        self._external_change_pending.pop(target, None)
        if self._notification_vm:
            self._notification_vm.info("Keeping local changes", os.path.basename(target), 2400)

    @Slot(str, int)
    def requestCompletions(self, code: str, cursor_pos: int) -> None:
        self._completion_generation += 1
        generation = self._completion_generation
        schedule(self._complete_async(code, cursor_pos, generation, False))

    @Slot(str, int)
    def requestCompletionsForced(self, code: str, cursor_pos: int) -> None:
        self._completion_generation += 1
        generation = self._completion_generation
        schedule(self._complete_async(code, cursor_pos, generation, True))

    @Slot(str, int)
    def requestHover(self, code: str, cursor_pos: int) -> None:
        self._hover_generation += 1
        generation = self._hover_generation
        schedule(self._hover_async(code, cursor_pos, generation))

    @Slot(str)
    def requestDocumentSymbols(self, code: str) -> None:
        self._symbols_generation += 1
        generation = self._symbols_generation
        schedule(self._symbols_async(code, generation))

    @Slot(str, int)
    def requestDefinition(self, code: str, cursor_pos: int) -> None:
        self._definition_generation += 1
        generation = self._definition_generation
        schedule(self._definition_async(code, cursor_pos, generation))

    @Slot(str, int)
    def requestReferences(self, code: str, cursor_pos: int) -> None:
        self._references_generation += 1
        generation = self._references_generation
        schedule(self._references_async(code, cursor_pos, generation))

    @Slot(str, int, int)
    def pushNavigationLocation(self, path: str, line: int, col: int) -> None:
        location = {
            "path": path or self._current_path,
            "line": max(1, int(line or 1)),
            "col": max(0, int(col or 0)),
        }
        if not location["path"]:
            return
        if self._navigation_back and self._navigation_back[-1] == location:
            return
        self._navigation_back.append(location)
        self._navigation_back = self._navigation_back[-100:]
        self._navigation_forward = []

    @Slot()
    def jumpBack(self) -> None:
        if not self._navigation_back:
            return
        current = {"path": self._current_path, "line": 1, "col": 0}
        self._navigation_forward.append(current)
        self.navigationReady.emit(self._navigation_back.pop())

    @Slot()
    def jumpForward(self) -> None:
        if not self._navigation_forward:
            return
        if self._current_path:
            self._navigation_back.append({"path": self._current_path, "line": 1, "col": 0})
        self.navigationReady.emit(self._navigation_forward.pop())

    @Slot(str)
    def requestDiagnostics(self, path: str) -> None:
        if path:
            self._diagnostics_generation += 1
            schedule(self._run_diagnostics(path, "", self._diagnostics_generation))

    @Slot(str, str)
    def requestDiagnosticsForCode(self, path: str, code: str) -> None:
        if path:
            self._diagnostics_generation += 1
            schedule(self._run_diagnostics(path, code, self._diagnostics_generation))

    @Slot(str, str)
    def syncDocument(self, path: str, code: str) -> None:
        if not path:
            return
        self._document_generation += 1
        generation = self._document_generation
        schedule(self._sync_document_async(path, code, generation))

    @Slot(str, int)
    def requestCodeActions(self, code: str, cursor_pos: int) -> None:
        self._code_actions_generation += 1
        generation = self._code_actions_generation
        schedule(self._code_actions_async(code, cursor_pos, generation))

    @Slot("QVariantMap", str)
    def applyCodeAction(self, action: dict, code: str) -> None:
        if action:
            schedule(self._apply_code_action_async(action, code))

    @Slot("QVariantMap", str)
    def previewCodeAction(self, action: dict, code: str) -> None:
        if action:
            schedule(self._preview_code_action_async(action, code))

    @Slot()
    def refreshLspStatus(self) -> None:
        self._emit_lsp_status()

    @Slot()
    def startLsp(self) -> None:
        schedule(self._control_lsp("start"))

    @Slot()
    def stopLsp(self) -> None:
        schedule(self._control_lsp("stop"))

    @Slot()
    def restartLsp(self) -> None:
        schedule(self._control_lsp("restart"))

    @Slot(str, int)
    def requestAiSuggestion(self, code: str, cursor_pos: int) -> None:
        schedule(self._ai_suggest(code, cursor_pos))

    @Slot(str, result="QString")
    def get_prev_indent(self, text: str) -> str:
        lines = text.split("\n")
        if len(lines) < 2:
            return ""
        prev = lines[-2]
        stripped = prev.lstrip(" \t")
        indent = len(prev) - len(stripped)
        if stripped.rstrip().endswith(":"):
            indent += 4
        return " " * indent

    @Slot(str, result="QString")
    def getLanguage(self, path: str) -> str:
        return self._detect_language(path)

    @Slot(result="QVariantList")
    def getDiagnostics(self) -> list:
        return []

    # ── Properties ───────────────────────────────────────

    @Property(bool, notify=textChanged)
    def isDirty(self) -> bool:
        return self._is_dirty

    @Property(str, notify=fileOpened)
    def currentPath(self) -> str:
        return self._current_path

    @Property(str, notify=suggestionReady)
    def currentSuggestion(self) -> str:
        return ""

    @Property("QVariantList", notify=tabsChanged)
    def tabs(self) -> list[dict[str, str]]:
        return list(self._tabs)

    @Property("QVariantList", notify=symbolsReady)
    def symbols(self) -> list[dict]:
        return list(self._symbols)

    @Property("QVariantList", notify=referencesReady)
    def references(self) -> list[dict]:
        return list(self._references)

    @Property("QVariantMap", notify=dirtyTabsChanged)
    def dirtyTabs(self) -> dict[str, bool]:
        return dict(self._dirty_tabs)

    @Property(int, notify=currentTabChanged)
    def currentTabIndex(self) -> int:
        return self._current_tab_index

    @Property("QVariantMap", notify=sessionRestored)
    def cursorPositions(self) -> dict[str, dict[str, int]]:
        return dict(self._cursor_positions)

    # ── Private async ────────────────────────────────────

    async def _read_async(self, path: str) -> str | None:
        import aiofiles
        try:
            async with aiofiles.open(path, "r", encoding="utf-8") as f:
                return await f.read()
        except Exception as e:
            print(f"[EditorVM] Read error: {e}")
            return None

    async def _open_async(self, path: str, generation: int) -> None:
        content = await self._read_async(path)
        if generation != self._open_generation:
            return
        if content is None:
            self.fileOpenFailed.emit(path, "Unable to read file")
            return
        self.fileContentReady.emit(path, content)
        schedule(self._record_open(path, content))

    async def _save(self, path: str, content: str) -> None:
        import aiofiles
        try:
            content = self._prepare_content_for_save(content)
            async with aiofiles.open(path, "w", encoding="utf-8") as f:
                await f.write(content)
            self._mark_internal_write(path)
            final_content = content
            if self._format_on_save_enabled(path):
                formatted = await asyncio.to_thread(
                    self._operations.format_path,
                    path,
                    os.path.dirname(path),
                    False,
                )
                if formatted.get("ok"):
                    reloaded = await self._read_async(path)
                    if reloaded is not None:
                        final_content = reloaded
                        self.fileFormatted.emit(path, final_content)
                elif self._notification_vm:
                    self._notification_vm.warning(formatted.get("message", "Format on save failed"))
            self._is_dirty = False
            self._current_path = path
            self._language = self._detect_language(path)
            await self._lsp.sync_document(path, final_content, self._language)
            await self._lsp.save_document(path, final_content, self._language)
            self.fileSaved.emit(path)
            await self._events.emit("editor:save", path=path, content=final_content)
            self.textChanged.emit(final_content)
            self._diagnostics_generation += 1
            schedule(self._run_diagnostics(path, final_content, self._diagnostics_generation))
        except Exception as e:
            print(f"[EditorVM] Save error: {e}")

    async def _format_document(self, path: str, content: str) -> None:
        import aiofiles
        if not path:
            return
        try:
            content = self._prepare_content_for_save(content)
            async with aiofiles.open(path, "w", encoding="utf-8") as f:
                await f.write(content)
            self._mark_internal_write(path)
            result = await asyncio.to_thread(
                self._operations.format_path,
                path,
                os.path.dirname(path),
                False,
            )
            if not result.get("ok"):
                if self._notification_vm:
                    self._notification_vm.warning(result.get("message", "Format failed"))
                return
            formatted = await self._read_async(path)
            if formatted is None:
                return
            self._current_path = path
            self._language = self._detect_language(path)
            await self._lsp.sync_document(path, formatted, self._language)
            self.fileFormatted.emit(path, formatted)
            self.textChanged.emit(formatted)
            self._diagnostics_generation += 1
            schedule(self._run_diagnostics(path, formatted, self._diagnostics_generation))
            if self._notification_vm:
                self._notification_vm.success("Document formatted")
        except Exception as exc:
            if self._notification_vm:
                self._notification_vm.error(f"Format failed: {exc}")

    async def _reload_from_disk(self, path: str) -> None:
        target = self._normalize_path(path)
        if not target or not os.path.isfile(target):
            return
        content = await self._read_async(target)
        if content is None:
            if self._notification_vm:
                self._notification_vm.error("Reload failed", os.path.basename(target), 4200)
            return
        self._external_change_pending.pop(target, None)
        self._current_path = target
        self._language = self._detect_language(target)
        await self._lsp.sync_document(target, content, self._language)
        self.fileContentReady.emit(target, content)
        self.fileSaved.emit(target)
        self.textChanged.emit(content)
        self._set_tab_dirty_by_path(target, False)
        self._diagnostics_generation += 1
        schedule(self._run_diagnostics(target, content, self._diagnostics_generation))
        if self._notification_vm:
            self._notification_vm.success("Reloaded from disk", os.path.basename(target), 2600)

    def _format_on_save_enabled(self, path: str) -> bool:
        if not path or not self._settings_vm:
            return False
        try:
            return bool(self._settings_vm.formatOnSave)
        except Exception:
            return False

    def _prepare_content_for_save(self, content: str) -> str:
        if not self._settings_vm:
            return content
        result = content
        try:
            if bool(self._settings_vm.trimTrailingWhitespace):
                lines = result.splitlines(True)
                result = "".join(line.rstrip(" \t\r\n") + ("\n" if line.endswith(("\n", "\r")) else "") for line in lines)
            if bool(self._settings_vm.insertFinalNewline) and result and not result.endswith("\n"):
                result += "\n"
        except Exception:
            return content
        return result

    def _handle_external_file_change(self, path: str = "") -> None:
        target = self._normalize_path(path)
        if not target or not os.path.isfile(target):
            return
        if not self._is_open_file(target):
            return
        if time.monotonic() - self._recent_internal_writes.get(target, 0) < 1.25:
            return
        tab_id = self._tab_id(os.path.basename(target), target)
        payload = {
            "path": target,
            "name": os.path.basename(target),
            "dirty": bool(self._dirty_tabs.get(tab_id, False)),
            "current": target == self._normalize_path(self._current_path),
        }
        self._external_change_pending[target] = payload
        self.externalFileChanged.emit(payload)
        if self._notification_vm:
            self._notification_vm.warning(
                "File changed on disk",
                f"{payload['name']} has external changes.",
                5200,
            )

    def _mark_internal_write(self, path: str) -> None:
        self._recent_internal_writes[self._normalize_path(path)] = time.monotonic()

    def _is_open_file(self, path: str) -> bool:
        target = self._normalize_path(path)
        return any(
            self._normalize_path(tab.get("content", "")) == target
            for tab in self._tabs
            if tab.get("content") not in {"welcome", "settings"}
        )

    def _set_tab_dirty_by_path(self, path: str, dirty: bool) -> None:
        tab_id = self._tab_id(os.path.basename(path), path)
        if dirty:
            self._dirty_tabs[tab_id] = True
        else:
            self._dirty_tabs.pop(tab_id, None)
        self.dirtyTabsChanged.emit()

    @staticmethod
    def _normalize_path(path: str) -> str:
        return os.path.abspath(os.path.expanduser(path or "")) if path else ""

    @Slot(str)
    def runDiagnostics(self, path: str) -> None:
        self._diagnostics_generation += 1
        schedule(self._run_diagnostics(path, "", self._diagnostics_generation))

    async def _run_diagnostics(self, path: str, code: str = "", generation: int = 0) -> None:
        try:
            diags = await self._lsp.get_diagnostics(path, code)
            if not generation or generation == self._diagnostics_generation:
                self.diagnosticsReady.emit(self._normalize_diagnostics(diags, path))
                self._emit_lsp_status()
        except Exception as e:
            print(f"[EditorVM] Diagnostics error: {e}")
            if not generation or generation == self._diagnostics_generation:
                self.diagnosticsReady.emit([])
                self._emit_lsp_status()

    async def _sync_document_async(self, path: str, code: str, generation: int) -> None:
        language = self._detect_language(path)
        try:
            await self._lsp.sync_document(path, code, language)
        except Exception as exc:
            print(f"[EditorVM] LSP sync error: {exc}")
            return
        if generation == self._document_generation:
            self._emit_lsp_status()

    async def _close_document_async(self, path: str) -> None:
        try:
            await self._lsp.close_document(path, self._detect_language(path))
        except Exception as exc:
            print(f"[EditorVM] LSP close error: {exc}")

    async def _record_open(self, path: str, content: str) -> None:
        from app.data.models import FileHistory

        self._current_path = path
        self._current_text = content
        self._is_dirty = False
        self._language = self._detect_language(path)
        self._completion_generation += 1
        self._hover_generation += 1
        self._symbols_generation += 1
        self._definition_generation += 1
        self._references_generation += 1
        self._diagnostics_generation += 1
        self._code_actions_generation += 1
        self.completerReady.emit("[]")
        self._emit_lsp_status()
        self.fileOpened.emit(path)
        self.textChanged.emit(content)
        # Update AI chat context
        await self._events.emit("editor:file_opened", path=path, content=content, language=self._language)
        schedule(self._run_diagnostics(path, content, self._diagnostics_generation))
        try:
            await FileHistory.objects.create(
                path=path, display_name=os.path.basename(path),
                language=self._language,
            )
        except Exception as e:
            print(f"[EditorVM] History error: {e}")

    async def _complete_async(
        self,
        code: str,
        cursor_pos: int,
        generation: int,
        force: bool = False,
    ) -> None:
        try:
            results = await self._lsp.get_completions(
                code,
                cursor_pos,
                self._current_path or "",
                self._language,
                force,
            )
        except Exception as e:
            print(f"[EditorVM] Completion error: {e}")
            return []
        if generation == self._completion_generation:
            results = self._rank_completions(code, cursor_pos, results, force)
            self.completerReady.emit(json.dumps(results))

    @classmethod
    def _completion_prefix(cls, code: str, cursor_pos: int) -> str:
        cursor_pos = max(0, min(int(cursor_pos or 0), len(code or "")))
        start = cursor_pos
        while start > 0 and (code[start - 1].isalnum() or code[start - 1] in {"_", "$"}):
            start -= 1
        return code[start:cursor_pos]

    @classmethod
    def _rank_completions(
        cls,
        code: str,
        cursor_pos: int,
        results: list[dict],
        force: bool = False,
    ) -> list[dict]:
        prefix = cls._completion_prefix(code, cursor_pos).lower()
        unique: dict[str, dict] = {}
        for item in results or []:
            label = str(item.get("name") or item.get("label") or item.get("text") or "")
            insert_text = str(item.get("insertText") or item.get("text") or label)
            if not label and not insert_text:
                continue
            candidate = (label or insert_text).lower()
            if prefix and not force and not candidate.startswith(prefix):
                continue
            key = label or insert_text
            unique.setdefault(key, item)

        def score(item: dict) -> tuple[int, int, str]:
            label = str(item.get("name") or item.get("label") or item.get("text") or "")
            lowered = label.lower()
            if prefix and lowered == prefix:
                rank = 0
            elif prefix and lowered.startswith(prefix):
                rank = 1
            elif prefix and prefix in lowered:
                rank = 2
            else:
                rank = 3
            return (rank, len(label), lowered)

        return sorted(unique.values(), key=score)[:80]

    async def _hover_async(self, code: str, cursor_pos: int, generation: int) -> None:
        try:
            result = await self._lsp.get_hover(
                code,
                cursor_pos,
                self._current_path or "",
                self._language,
            )
        except Exception as e:
            print(f"[EditorVM] Hover error: {e}")
            result = None
        if generation == self._hover_generation:
            self.hoverReady.emit(result or {})

    async def _symbols_async(self, code: str, generation: int) -> None:
        try:
            symbols = await self._lsp.get_document_symbols(
                code,
                self._current_path or "",
                self._language,
            )
        except Exception as e:
            print(f"[EditorVM] Symbols error: {e}")
            symbols = []
        if generation == self._symbols_generation:
            self._symbols = list(symbols or [])
            self.symbolsReady.emit(symbols)

    async def _definition_async(self, code: str, cursor_pos: int, generation: int) -> None:
        try:
            locations = await self._lsp.get_definition(
                code,
                cursor_pos,
                self._current_path or "",
                self._language,
            )
        except Exception as e:
            print(f"[EditorVM] Definition error: {e}")
            locations = []
        if generation == self._definition_generation:
            self.definitionReady.emit(self._normalize_locations(locations))

    async def _references_async(self, code: str, cursor_pos: int, generation: int) -> None:
        try:
            locations = await self._lsp.get_references(
                code,
                cursor_pos,
                self._current_path or "",
                self._language,
            )
        except Exception as e:
            print(f"[EditorVM] References error: {e}")
            locations = []
        if generation == self._references_generation:
            self._references = self._normalize_locations(locations)
            self.referencesReady.emit(self._references)

    def _normalize_locations(self, locations: list[dict]) -> list[dict]:
        output = []
        for item in locations or []:
            path = str(item.get("path") or item.get("uri") or self._current_path or "")
            if path.startswith("file://"):
                path = uri_to_path(path)
            output.append({
                **item,
                "path": path,
                "line": max(1, int(item.get("line") or 1)),
                "col": max(0, int(item.get("col") or 0)),
                "endLine": max(1, int(item.get("endLine") or item.get("line") or 1)),
                "endCol": max(0, int(item.get("endCol") or item.get("col") or 0)),
            })
        return output

    async def _code_actions_async(self, code: str, cursor_pos: int, generation: int) -> None:
        try:
            actions = await self._lsp.get_code_actions(
                code,
                cursor_pos,
                self._current_path or "",
                self._language,
            )
        except Exception as e:
            print(f"[EditorVM] Code actions error: {e}")
            actions = []
        if generation == self._code_actions_generation:
            self.codeActionsReady.emit(actions)

    async def _apply_code_action_async(self, action: dict, code: str) -> None:
        raw = action.get("raw") if isinstance(action.get("raw"), dict) else action
        edit = raw.get("edit") if isinstance(raw, dict) else {}
        if not isinstance(edit, dict):
            return
        updated = self._apply_workspace_edit(code, edit, self._current_path)
        if updated is None:
            return
        self._document_generation += 1
        await self._sync_document_async(self._current_path, updated, self._document_generation)
        self.codeActionApplied.emit(self._current_path, updated)

    async def _preview_code_action_async(self, action: dict, code: str) -> None:
        raw = action.get("raw") if isinstance(action.get("raw"), dict) else action
        edit = raw.get("edit") if isinstance(raw, dict) else {}
        title = str(action.get("title") or raw.get("title") or "Quick Fix")
        if not isinstance(edit, dict):
            self.codeActionPreviewReady.emit({
                "ok": False,
                "title": title,
                "message": "This code action has no previewable edit.",
                "action": action,
                "preview": "",
            })
            return
        updated = self._apply_workspace_edit(code, edit, self._current_path)
        if updated is None:
            self.codeActionPreviewReady.emit({
                "ok": False,
                "title": title,
                "message": "No changes affect the current file.",
                "action": action,
                "preview": "",
            })
            return
        self.codeActionPreviewReady.emit({
            "ok": True,
            "title": title,
            "message": "Review changes before applying.",
            "action": action,
            "preview": self._diff_preview(code, updated),
        })

    @staticmethod
    def _diff_preview(before: str, after: str, max_lines: int = 160) -> str:
        import difflib

        lines = list(difflib.unified_diff(
            before.splitlines(),
            after.splitlines(),
            fromfile="current",
            tofile="after",
            lineterm="",
        ))
        if len(lines) > max_lines:
            lines = lines[:max_lines] + ["… diff truncated …"]
        return "\n".join(lines)

    @classmethod
    def _apply_workspace_edit(cls, code: str, edit: dict, current_path: str) -> str | None:
        current_path = os.path.abspath(os.path.expanduser(current_path or ""))
        edits: list[dict] = []
        changes = edit.get("changes")
        if isinstance(changes, dict):
            for uri, uri_edits in changes.items():
                if uri and os.path.abspath(uri_to_path(uri)) == current_path and isinstance(uri_edits, list):
                    edits.extend(uri_edits)
        document_changes = edit.get("documentChanges")
        if isinstance(document_changes, list):
            for change in document_changes:
                if not isinstance(change, dict):
                    continue
                text_document = change.get("textDocument") or {}
                uri = text_document.get("uri", "")
                if uri and os.path.abspath(uri_to_path(uri)) == current_path and isinstance(change.get("edits"), list):
                    edits.extend(change["edits"])
        if not edits:
            return None
        output = code
        for item in sorted(edits, key=lambda e: cls._edit_start_offset(code, e), reverse=True):
            range_info = item.get("range") or {}
            start = cls._position_to_offset(output, range_info.get("start") or {})
            end = cls._position_to_offset(output, range_info.get("end") or {})
            output = output[:start] + str(item.get("newText") or "") + output[end:]
        return output

    @staticmethod
    def _position_to_offset(code: str, position: dict) -> int:
        line = max(0, int(position.get("line") or 0))
        character = max(0, int(position.get("character") or 0))
        offset = 0
        lines = code.splitlines(True)
        for index in range(min(line, len(lines))):
            offset += len(lines[index])
        if line < len(lines):
            offset += min(character, len(lines[line].rstrip("\n\r")))
        return min(offset, len(code))

    @classmethod
    def _edit_start_offset(cls, code: str, edit: dict) -> int:
        return cls._position_to_offset(code, (edit.get("range") or {}).get("start") or {})

    async def _ai_suggest(self, code: str, cursor_pos: int) -> None:
        try:
            from app.services.ai_service import AIService
            ai = AIService()
            await ai.load_config()
            suggestion = await ai.get_inline_suggestion(code, cursor_pos)
            if suggestion:
                self.suggestionReady.emit(suggestion)
        except Exception as e:
            print(f"[EditorVM] AI error: {e}")

    def _index_for_title(self, title: str) -> int:
        for index, tab in enumerate(self._tabs):
            if tab.get("title") == title:
                return index
        return -1

    @staticmethod
    def _tab_id(title: str, content: str) -> str:
        if content in {"welcome", "settings"}:
            return content
        if content:
            return os.path.abspath(os.path.expanduser(content))
        return title

    def _index_for_id(self, tab_id: str) -> int:
        for index, tab in enumerate(self._tabs):
            if tab.get("id") == tab_id:
                return index
        return -1

    async def _load_editor_session(self) -> None:
        if not self._workspace_path:
            if not self._tabs:
                self.addTab("Welcome", "welcome")
            return
        restored = await self._session_service.load_last_session(self._workspace_path)
        if not restored:
            self._set_welcome_tabs()
            return
        self._tabs = []
        self._tab_content = {}
        self._dirty_tabs = {}
        for path in restored.open_files:
            title = os.path.basename(path)
            tab_id = self._tab_id(title, path)
            self._tabs.append({"id": tab_id, "title": title, "content": path})
            self._tab_content[tab_id] = path
        self._cursor_positions = restored.cursor_positions
        self._current_tab_index = 0
        for index, tab in enumerate(self._tabs):
            if tab.get("content") == restored.active_file:
                self._current_tab_index = index
                break
        self.tabsChanged.emit()
        self.dirtyTabsChanged.emit()
        self.sessionRestored.emit()
        self.currentTabChanged.emit(self._current_tab_index)

    def _schedule_session_save(self, active_file: str = "") -> None:
        schedule(self._save_editor_session(active_file))

    async def _save_editor_session(self, active_file: str = "") -> None:
        open_files = [
            tab.get("content", "")
            for tab in self._tabs
            if tab.get("id") not in {"welcome", "settings"}
        ]
        active = active_file or self.currentTabContent()
        if active in {"welcome", "settings"}:
            active = ""
        await self._session_service.save_session(
            open_files,
            active,
            self._cursor_positions,
            self._workspace_path,
        )

    async def _switch_workspace_session(self, path: str) -> None:
        if self._workspace_path:
            await self._save_editor_session()
            for tab in self._tabs:
                content = tab.get("content", "")
                if content and content not in {"welcome", "settings"}:
                    await self._close_document_async(content)
        self._workspace_path = os.path.abspath(os.path.expanduser(path)) if path else ""
        if self._workspace_path:
            try:
                await self._lsp.set_workspace(self._workspace_path)
            except Exception as exc:
                print(f"[EditorVM] LSP workspace switch error: {exc}")
        self._tabs = []
        self._tab_content = {}
        self._dirty_tabs = {}
        self._cursor_positions = {}
        self._current_tab_index = -1
        await self._load_editor_session()

    @staticmethod
    def _detect_language(path: str) -> str:
        return detect_language(path)

    def _emit_lsp_status(self) -> None:
        try:
            self.lspStatusReady.emit(self._lsp.get_status(self._language))
        except Exception as exc:
            self.lspStatusReady.emit({
                "language": self._language,
                "label": f"LSP error: {exc}",
                "healthy": False,
                "servers": [],
            })

    async def _control_lsp(self, action: str) -> None:
        try:
            self._notify_busy(True)
            self._notify_info(f"LSP {action}", "Request sent to language backend.")
            if action == "start":
                status = await self._lsp.start_lsp(self._language)
            elif action == "stop":
                status = await self._lsp.stop_lsp(self._language)
            elif action == "restart":
                status = await self._lsp.restart_lsp(self._language)
            else:
                status = self._lsp.get_status(self._language)
            self.lspStatusReady.emit(status)
            self._notify_success("LSP updated", status.get("label", "Language backend updated."))
        except Exception as exc:
            self._notify_error("LSP action failed", str(exc))
            self.lspStatusReady.emit({
                "language": self._language,
                "label": f"LSP {action} failed",
                "healthy": False,
                "servers": [{"name": "lsp", "running": False, "available": False, "logs": [str(exc)]}],
            })
        finally:
            self._notify_busy(False)

    def _notify_busy(self, busy: bool) -> None:
        if not self._notification_vm:
            return
        if busy:
            self._notification_vm.startBusy()
        else:
            self._notification_vm.endBusy()

    def _notify_info(self, title: str, message: str = "") -> None:
        if self._notification_vm:
            self._notification_vm.info(title, message)

    def _notify_success(self, title: str, message: str = "") -> None:
        if self._notification_vm:
            self._notification_vm.success(title, message)

    def _notify_error(self, title: str, message: str = "") -> None:
        if self._notification_vm:
            self._notification_vm.error(title, message)

    @staticmethod
    def _normalize_diagnostics(diagnostics: list[dict], fallback_path: str = "") -> list[dict]:
        normalized = []
        fallback_path = os.path.abspath(os.path.expanduser(fallback_path or ""))
        for item in diagnostics:
            location = item.get("location") or {}
            end_location = item.get("end_location") or {}
            range_info = item.get("range") or {}
            range_start = range_info.get("start") or {}
            range_end = range_info.get("end") or {}
            row = int(
                location.get("row")
                or item.get("line")
                or item.get("row")
                or (range_start.get("line") + 1 if "line" in range_start else 1)
            )
            column = int(
                location.get("column")
                or item.get("column")
                or item.get("col")
                or (range_start.get("character") + 1 if "character" in range_start else 1)
            )
            end_row = int(
                end_location.get("row")
                or item.get("end_line")
                or (range_end.get("line") + 1 if "line" in range_end else row)
            )
            end_column = int(
                end_location.get("column")
                or item.get("end_column")
                or (range_end.get("character") + 1 if "character" in range_end else column + 1)
            )
            code = str(item.get("code") or item.get("source") or "")
            severity = EditorViewModel._diagnostic_severity(item.get("severity"), code)
            if severity == "unknown":
                severity = "warning" if code.startswith(("W", "I")) else "error"
            normalized.append({
                "path": item.get("path") or item.get("file") or fallback_path,
                "line": max(1, row),
                "col": max(0, column - 1),
                "endLine": max(1, end_row),
                "endCol": max(0, end_column - 1),
                "severity": severity,
                "code": code,
                "source": item.get("source") or item.get("provider") or code.split(":", 1)[0],
                "message": item.get("message") or item.get("msg") or "",
                "raw": item,
            })
        return normalized

    @staticmethod
    def _diagnostic_severity(value, code: str = "") -> str:
        if isinstance(value, int):
            return {1: "error", 2: "warning", 3: "info", 4: "hint"}.get(value, "unknown")
        severity = str(value or "").lower()
        return severity or "unknown"

    @staticmethod
    def _completion_color(type_: str) -> str:
        return {
            "class": "#E5C07B", "function": "#61AFEF",
            "keyword": "#C678DD", "module": "#56B6C2",
            "instance": "#E5C07B", "statement": "#C678DD",
            "param": "#E06C75", "path": "#56B6C2",
            "property": "#ABB2BF",
            "word": "#ABB2BF",
        }.get(type_, "#ABB2BF")
