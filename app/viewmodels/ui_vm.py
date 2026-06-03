from __future__ import annotations

from PySide6.QtCore import QObject, Property, Signal, Slot
from PySide6.QtGui import QFont
from PySide6.QtWidgets import QApplication

from app.core.async_tasks import schedule
from app.core.events import EventBus


class UiViewModel(QObject):
    fontChanged = Signal(str, int)
    shortcutDispatched = Signal(str)

    def __init__(self, events: EventBus, settings_vm=None, parent: QObject | None = None):
        super().__init__(parent)
        self._events = events
        self._settings_vm = settings_vm
        self._font_family = self._clean_font_family(settings_vm.uiFontFamily if settings_vm else "Arial", "Arial")
        self._font_size = max(10, int(settings_vm.uiFontSize) if settings_vm else 12)
        if settings_vm:
            settings_vm.fontChanged.connect(self._sync_font)
        self._apply_application_font()

    @Property(str, notify=fontChanged)
    def fontFamily(self) -> str:
        return self._font_family

    @Property(int, notify=fontChanged)
    def fontSize(self) -> int:
        return self._font_size

    @Slot(str, int)
    def _sync_font(self, family: str, size: int) -> None:
        if self._settings_vm:
            self._font_family = self._clean_font_family(self._settings_vm.uiFontFamily or self._font_family, "Arial")
            self._font_size = max(10, int(self._settings_vm.uiFontSize))
        else:
            self._font_family = self._clean_font_family(family or self._font_family, "Arial")
            self._font_size = max(10, int(size))
        self._apply_application_font()
        self.fontChanged.emit(self._font_family, self._font_size)

    def _apply_application_font(self) -> None:
        app = QApplication.instance()
        if not app:
            return
        app.setFont(QFont(self._font_family, self._font_size))

    @staticmethod
    def _clean_font_family(value: str, fallback: str) -> str:
        family = str(value or "").split(",")[0].strip().strip("\"'")
        if family.lower() in {"monospace", "serif", "sans", "sans-serif"}:
            return fallback
        return family or fallback

    @Slot(str, str)
    def dispatchShortcut(self, command_id: str, sequence: str = "") -> None:
        schedule(self._emit_shortcut(command_id, sequence))

    async def _emit_shortcut(self, command_id: str, sequence: str) -> None:
        await self._events.emit(
            "shortcut:activated",
            command=command_id,
            sequence=sequence,
        )
        await self._events.emit(
            f"shortcut:{command_id}",
            command=command_id,
            sequence=sequence,
        )
        self.shortcutDispatched.emit(command_id)
