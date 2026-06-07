"""
File watcher service — detects external file changes using watchdog.
Emits events through the EventBus for the UI to react.
"""

from __future__ import annotations

import os
import asyncio
from watchdog.observers.polling import PollingObserver as Observer
from watchdog.events import FileSystemEventHandler


class FileChangeHandler(FileSystemEventHandler):
    def __init__(self, callback):
        self._callback = callback

    def on_modified(self, event):
        self._callback(event.src_path)

    def on_created(self, event):
        self._callback(event.src_path)

    def on_deleted(self, event):
        self._callback(event.src_path)

    def on_moved(self, event):
        self._callback(event.dest_path)


class FileWatcherService:
    def __init__(self, event_bus):
        self._event_bus = event_bus
        self._observer: Observer | None = None
        self._watched: set[str] = set()
        self._loop: asyncio.AbstractEventLoop | None = None

    def watch(self, path: str) -> None:
        if not os.path.isdir(path):
            return
        self._capture_loop()
        if path in self._watched:
            return
        self._watched.add(path)

        if self._observer is None:
            self._observer = Observer()

        handler = FileChangeHandler(self._on_change)
        self._observer.schedule(handler, path, recursive=True)

        if not self._observer.is_alive():
            self._observer.start()

    def unwatch(self, path: str) -> None:
        self._watched.discard(path)
        if self._observer:
            for watch in list(self._observer._watches or []):
                if hasattr(watch, 'path') and watch.path.startswith(path):
                    self._observer.unschedule(watch)

    def stop(self) -> None:
        if self._observer and self._observer.is_alive():
            self._observer.stop()
            self._observer.join()
            self._observer = None
        self._watched.clear()

    def _on_change(self, path: str) -> None:
        if not self._loop or self._loop.is_closed():
            return
        self._loop.call_soon_threadsafe(
            lambda: asyncio.create_task(self._event_bus.emit("file:external_change", path=path))
        )

    def _capture_loop(self) -> None:
        if self._loop and not self._loop.is_closed():
            return
        try:
            self._loop = asyncio.get_running_loop()
        except RuntimeError:
            try:
                self._loop = asyncio.get_event_loop_policy().get_event_loop()
            except RuntimeError:
                self._loop = None
