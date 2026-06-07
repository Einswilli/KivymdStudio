from __future__ import annotations

import inspect
from dataclasses import dataclass, field
from time import time
from typing import Any, Callable

from app.core.events import EventBus


ActionHandler = Callable[[dict[str, Any]], Any]


@dataclass(slots=True)
class ActionDefinition:
    id: str
    title: str
    category: str = "General"
    description: str = ""
    source: str = "core"
    busy_label: str = "Working…"
    notify: bool = True
    requires_payload: bool = False
    handler: ActionHandler | None = field(default=None, repr=False)


class ActionService:
    """Central action registry and execution pipeline.

    This service is intentionally UI-agnostic. ViewModels can observe it through
    callbacks while plugins/core register actions through one stable contract.
    """

    def __init__(self, events: EventBus):
        self._events = events
        self._actions: dict[str, ActionDefinition] = {}
        self._running: dict[str, dict[str, Any]] = {}
        self._history: list[dict[str, Any]] = []
        self._listeners: list[Callable[[], None]] = []

    def on_changed(self, listener: Callable[[], None]) -> None:
        self._listeners.append(listener)

    def register(self, definition: ActionDefinition) -> None:
        if not definition.id:
            raise ValueError("Action id is required")
        self._actions[definition.id] = definition
        self._notify_changed()

    def unregister(self, action_id: str) -> None:
        self._actions.pop(action_id, None)
        self._notify_changed()

    def list_actions(self) -> list[dict[str, Any]]:
        return [
            {
                "id": action.id,
                "title": action.title,
                "category": action.category,
                "description": action.description,
                "source": action.source,
                "busyLabel": action.busy_label,
                "notify": action.notify,
                "requiresPayload": action.requires_payload,
            }
            for action in sorted(self._actions.values(), key=lambda item: (item.category, item.title))
        ]

    def running_actions(self) -> list[dict[str, Any]]:
        return list(self._running.values())

    def history(self) -> list[dict[str, Any]]:
        return list(self._history)

    def clear_history(self) -> None:
        self._history = []
        self._notify_changed()

    def is_running(self, action_id: str) -> bool:
        return action_id in self._running

    async def execute(self, action_id: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        payload = dict(payload or {})
        action = self._actions.get(action_id)
        if not action:
            result = self._result(action_id, payload, "error", f"Unknown action: {action_id}")
            self._append_history(result)
            await self._emit("action:error", result=result)
            return result

        started_at = time()
        self._running[action_id] = {
            "id": action.id,
            "title": action.title,
            "label": action.busy_label or action.title,
            "category": action.category,
            "source": action.source,
            "startedAt": started_at,
        }
        self._notify_changed()
        await self._emit("action:before", action=action.id, payload=payload)

        try:
            value = action.handler(payload) if action.handler else None
            if inspect.isawaitable(value):
                value = await value
            result = self._result(
                action.id,
                payload,
                "success",
                self._message_from_value(value) or f"{action.title} completed.",
                value,
                started_at,
            )
            self._append_history(result)
            await self._emit("action:after", action=action.id, payload=payload, result=result)
            return result
        except Exception as exc:
            result = self._result(action.id, payload, "error", str(exc), None, started_at)
            self._append_history(result)
            await self._emit("action:error", action=action.id, payload=payload, result=result)
            return result
        finally:
            self._running.pop(action_id, None)
            self._notify_changed()

    async def _emit(self, event: str, **payload: Any) -> None:
        try:
            await self._events.emit(event, **payload)
        except Exception:
            pass

    def _append_history(self, result: dict[str, Any]) -> None:
        self._history.append(result)
        self._history = self._history[-200:]
        self._notify_changed()

    def _notify_changed(self) -> None:
        for listener in list(self._listeners):
            listener()

    @staticmethod
    def _message_from_value(value: Any) -> str:
        if isinstance(value, dict):
            return str(value.get("message") or "")
        if isinstance(value, str):
            return value
        return ""

    @staticmethod
    def _result(
        action_id: str,
        payload: dict[str, Any],
        state: str,
        message: str,
        value: Any = None,
        started_at: float | None = None,
    ) -> dict[str, Any]:
        now = time()
        return {
            "id": action_id,
            "state": state,
            "ok": state == "success",
            "message": message,
            "payload": payload,
            "value": value,
            "startedAt": started_at or now,
            "finishedAt": now,
            "durationMs": int((now - (started_at or now)) * 1000),
        }
