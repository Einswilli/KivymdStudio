from __future__ import annotations

from datetime import datetime

from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtGui import QGuiApplication
from app.core.events import EventBus


class StatusViewModel(QObject):
    messageChanged = Signal(str)
    languageChanged = Signal(str)
    encodingChanged = Signal(str)
    errorCountChanged = Signal(int)
    warningCountChanged = Signal(int)
    diagnosticsChanged = Signal()
    lspStatusChanged = Signal()
    outputChanged = Signal()
    consoleChanged = Signal()

    def __init__(self, events: EventBus, parent: QObject | None = None):
        super().__init__(parent)
        self._events = events
        self._message = "Ready"
        self._language = "Python"
        self._encoding = "UTF-8"
        self._error_count = 0
        self._warning_count = 0
        self._lsp_status = "LSP idle"
        self._lsp_details = ""
        self._lsp_healthy = True
        self._lsp_servers: list[dict] = []
        self._diagnostics: list[dict] = []
        self._output: list[dict] = []
        self._console: list[dict] = []
        self._events.on("workbench:output:append", self._append_output_event)
        self._events.on("workbench:console:append", self._append_console_event)
        self._events.on("workbench:problems:clear", lambda **_: self.clear_diagnostics())

    @Slot(str)
    def set_message(self, msg: str) -> None:
        self._message = msg
        self.messageChanged.emit(msg)

    @Slot(str)
    def set_language(self, lang: str) -> None:
        self._language = lang
        self.languageChanged.emit(lang)

    @Slot(int, int)
    def set_diagnostics(self, errors: int, warnings: int) -> None:
        self._error_count = errors
        self._warning_count = warnings
        self.errorCountChanged.emit(errors)
        self.warningCountChanged.emit(warnings)
        self.diagnosticsChanged.emit()

    @Slot("QVariantList")
    def set_diagnostics_from_list(self, diagnostics: list[dict]) -> None:
        self._diagnostics = list(diagnostics or [])
        errors = 0
        warnings = 0
        for item in diagnostics or []:
            severity = str(item.get("severity") or "").lower()
            if severity == "error":
                errors += 1
            elif severity == "warning":
                warnings += 1
        self.set_diagnostics(errors, warnings)

    @Slot("QVariantMap")
    def set_lsp_status(self, status: dict) -> None:
        language = str(status.get("language") or "").strip()
        if language:
            self.set_language(language)
        self._lsp_status = str(status.get("label") or "LSP idle")
        self._lsp_healthy = bool(status.get("healthy", True))
        servers = status.get("servers") or []
        self._lsp_servers = list(servers)
        details = []
        for server in servers:
            name = server.get("name", "server")
            state = "running" if server.get("running") else ("available" if server.get("available") else "missing")
            command_error = str(server.get("commandError") or "").strip()
            details.append(f"{name}: {state}" + (f" · {command_error}" if command_error else ""))
            for log in server.get("logs") or []:
                self.append_output(str(name), str(log))
        self._lsp_details = " · ".join(details)
        self.lspStatusChanged.emit()

    @Slot(str, str)
    def append_output(self, source: str, message: str) -> None:
        if not message:
            return
        self._output.append({
            "source": source or "system",
            "level": "info",
            "message": message,
            "time": self._timestamp(),
        })
        self._output = self._output[-300:]
        self.outputChanged.emit()

    @Slot(str, str)
    def append_console(self, level: str, message: str) -> None:
        if not message:
            return
        self._console.append({
            "level": level or "info",
            "source": "system",
            "message": message,
            "time": self._timestamp(),
        })
        self._console = self._console[-300:]
        self.consoleChanged.emit()

    def _append_output_event(self, **payload) -> None:
        source = str(payload.get("source") or "plugin")
        message = str(payload.get("message") or "")
        level = str(payload.get("level") or "info")
        if not message:
            return
        self._output.append({
            "source": source,
            "level": level,
            "message": message,
            "time": self._timestamp(),
        })
        self._output = self._output[-300:]
        self.outputChanged.emit()

    def _append_console_event(self, **payload) -> None:
        source = str(payload.get("source") or "plugin")
        level = str(payload.get("level") or "info")
        message = str(payload.get("message") or "")
        if not message:
            return
        self._console.append({
            "level": level,
            "source": source,
            "message": message,
            "time": self._timestamp(),
        })
        self._console = self._console[-300:]
        self.consoleChanged.emit()

    @staticmethod
    def _timestamp() -> str:
        return datetime.now().strftime("%H:%M:%S")

    @Slot()
    def clear_output(self) -> None:
        self._output = []
        self.outputChanged.emit()

    @Slot()
    def clear_console(self) -> None:
        self._console = []
        self.consoleChanged.emit()

    @Slot()
    def clear_diagnostics(self) -> None:
        self._diagnostics = []
        self.set_diagnostics(0, 0)

    @Slot(str)
    def copy_text(self, text: str) -> None:
        clipboard = QGuiApplication.clipboard()
        if clipboard:
            clipboard.setText(text or "")

    @Property(str, notify=messageChanged)
    def message(self) -> str:
        return self._message

    @Property(str, notify=languageChanged)
    def language(self) -> str:
        return self._language

    @Property(str, notify=encodingChanged)
    def encoding(self) -> str:
        return self._encoding

    @Property(int, notify=diagnosticsChanged)
    def errorCount(self) -> int:
        return self._error_count

    @Property(int, notify=diagnosticsChanged)
    def warningCount(self) -> int:
        return self._warning_count

    @Property("QVariantList", notify=diagnosticsChanged)
    def problems(self) -> list[dict]:
        return list(self._diagnostics)

    @Property(str, notify=lspStatusChanged)
    def lspStatus(self) -> str:
        return self._lsp_status

    @Property(str, notify=lspStatusChanged)
    def lspDetails(self) -> str:
        return self._lsp_details

    @Property(bool, notify=lspStatusChanged)
    def lspHealthy(self) -> bool:
        return self._lsp_healthy

    @Property("QVariantList", notify=lspStatusChanged)
    def lspServers(self) -> list[dict]:
        return list(self._lsp_servers)

    @Property("QVariantList", notify=outputChanged)
    def output(self) -> list[dict]:
        return list(self._output)

    @Property("QVariantList", notify=consoleChanged)
    def console(self) -> list[dict]:
        return list(self._console)
