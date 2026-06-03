from __future__ import annotations

import asyncio
from collections.abc import Coroutine
from typing import Any


def schedule(coro: Coroutine[Any, Any, Any]) -> asyncio.Task[Any]:
    """Schedule a coroutine on the active Qt/asyncio loop.

    QML slots can be called from contexts where `asyncio.ensure_future()` tries
    to discover a loop implicitly. Keeping this path explicit avoids the
    `There is no current event loop in thread 'MainThread'` runtime failure.
    """

    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = asyncio.get_event_loop_policy().get_event_loop()
    return loop.create_task(coro)
