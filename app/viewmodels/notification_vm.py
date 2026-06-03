from __future__ import annotations

import itertools
from time import time

from PySide6.QtCore import QObject, Property, Signal, Slot


class NotificationViewModel(QObject):
    notificationsChanged = Signal()
    busyChanged = Signal()

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)
        self._ids = itertools.count(1)
        self._notifications: list[dict] = []
        self._busy_count = 0
        self._operations: dict[str, dict] = {}

    @Property("QVariantList", notify=notificationsChanged)
    def notifications(self) -> list[dict]:
        return list(self._notifications)

    @Property(bool, notify=busyChanged)
    def busy(self) -> bool:
        return self._busy_count > 0 or bool(self._operations)

    @Property(int, notify=busyChanged)
    def busyCount(self) -> int:
        return self._busy_count + len(self._operations)

    @Property("QVariantList", notify=busyChanged)
    def operations(self) -> list[dict]:
        return list(self._operations.values())

    @Slot(str, str, str, int, result=int)
    @Slot(str, str, str, int, "QVariantMap", result=int)
    def push(
        self,
        level: str,
        title: str,
        message: str = "",
        timeout: int = 4200,
        actions: dict | None = None,
    ) -> int:
        notification_id = next(self._ids)
        self._notifications.insert(0, {
            "id": notification_id,
            "level": level or "info",
            "title": title or "Notification",
            "message": message or "",
            "timeout": max(1200, int(timeout or 4200)),
            "createdAt": time(),
            "actions": self._normalize_actions(actions),
        })
        self._notifications = self._notifications[:6]
        self.notificationsChanged.emit()
        return notification_id

    @Slot(str, str, int, result=int)
    def info(self, title: str, message: str = "", timeout: int = 4200) -> int:
        return self.push("info", title, message, timeout)

    @Slot(str, str, int, result=int)
    def success(self, title: str, message: str = "", timeout: int = 3600) -> int:
        return self.push("success", title, message, timeout)

    @Slot(str, str, int, result=int)
    def warning(self, title: str, message: str = "", timeout: int = 5200) -> int:
        return self.push("warning", title, message, timeout)

    @Slot(str, str, int, result=int)
    def error(self, title: str, message: str = "", timeout: int = 6500) -> int:
        return self.push("error", title, message, timeout)

    @Slot(int)
    def dismiss(self, notification_id: int) -> None:
        original_len = len(self._notifications)
        self._notifications = [
            item for item in self._notifications if int(item.get("id", 0)) != notification_id
        ]
        if len(self._notifications) != original_len:
            self.notificationsChanged.emit()

    @Slot()
    def clear(self) -> None:
        if self._notifications:
            self._notifications = []
            self.notificationsChanged.emit()

    @Slot()
    @Slot(str, str)
    def startBusy(self, key: str = "", label: str = "Working…") -> None:
        if key:
            self._operations[key] = {
                "key": key,
                "label": label or key,
                "startedAt": time(),
            }
            self.busyChanged.emit()
            return
        self._busy_count += 1
        self.busyChanged.emit()

    @Slot()
    @Slot(str)
    def endBusy(self, key: str = "") -> None:
        if key:
            if key in self._operations:
                self._operations.pop(key, None)
                self.busyChanged.emit()
            return
        self._busy_count = max(0, self._busy_count - 1)
        self.busyChanged.emit()

    @Slot(str, str)
    def setOperation(self, key: str, label: str) -> None:
        if not key:
            return
        self._operations[key] = {
            "key": key,
            "label": label or key,
            "startedAt": self._operations.get(key, {}).get("startedAt", time()),
        }
        self.busyChanged.emit()

    @staticmethod
    def _normalize_actions(actions: dict | None) -> list[dict]:
        if not actions:
            return []
        if isinstance(actions, list):
            raw = actions
        else:
            raw = actions.get("items", []) if isinstance(actions, dict) else []
        normalized = []
        for item in raw:
            if not isinstance(item, dict):
                continue
            action_id = str(item.get("id", "")).strip()
            label = str(item.get("label", "")).strip()
            if action_id and label:
                payload = item.get("payload", {})
                normalized.append({
                    "id": action_id,
                    "label": label,
                    "payload": payload if isinstance(payload, dict) else {},
                })
        return normalized[:3]
