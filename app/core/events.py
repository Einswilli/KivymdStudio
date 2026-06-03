from __future__ import annotations

import asyncio
import inspect
from collections import defaultdict
from typing import Any, Callable

Callback = Callable[..., Any]


class EventBus:
    """
    Central async event bus for cross-component communication.

    Usage:
        events = EventBus()
        events.on("editor:save", on_save)
        await events.emit("editor:save", path="/foo.py")
    """

    def __init__(self):
        self._subscribers: dict[str, list[Callback]] = defaultdict(list)

    def on(self, event: str, handler: Callback) -> None:
        self._subscribers[event].append(handler)

    def off(self, event: str, handler: Callback) -> None:
        subs = self._subscribers.get(event, [])
        if handler in subs:
            subs.remove(handler)

    async def emit(self, event: str, *args: Any, **kwargs: Any) -> None:
        await self.emit_collect(event, *args, **kwargs)

    async def emit_collect(self, event: str, *args: Any, **kwargs: Any) -> list[Any]:
        tasks = []
        results = []
        for handler in list(self._subscribers.get(event, [])):
            result = handler(*args, **kwargs)
            if inspect.isawaitable(result):
                tasks.append(result)
            else:
                results.append(result)
        if tasks:
            results.extend(await asyncio.gather(*tasks))
        return results

    def emit_collect_now(self, event: str, *args: Any, **kwargs: Any) -> list[Any]:
        results = []
        for handler in list(self._subscribers.get(event, [])):
            result = handler(*args, **kwargs)
            if inspect.isawaitable(result):
                asyncio.create_task(result)
            else:
                results.append(result)
        return results

    def clear(self, event: str | None = None) -> None:
        if event:
            self._subscribers.pop(event, None)
        else:
            self._subscribers.clear()
