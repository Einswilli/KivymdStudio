from __future__ import annotations

import os
import aiofiles
from typing import AsyncIterator, Callable
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler


class FileWatcher:
    def __init__(self):
        self._observer: Observer | None = None
        self._callbacks: dict[str, list[Callable]] = {}

    def watch(self, path: str, on_changed: Callable) -> None:
        class Handler(FileSystemEventHandler):
            def on_modified(self, event):
                if not event.is_directory:
                    on_changed(event.src_path)

        if self._observer is None:
            self._observer = Observer()
        self._observer.schedule(Handler(), path, recursive=True)
        if self._observer.is_alive():
            return
        self._observer.start()

    def unwatch(self, path: str) -> None:
        if self._observer:
            for watch in self._observer._watches:
                if watch.path == path:
                    self._observer.unschedule(watch)
                    break

    def stop(self) -> None:
        if self._observer:
            self._observer.stop()
            self._observer.join()


async def read_text(path: str) -> str:
    async with aiofiles.open(path, "r", encoding="utf-8") as f:
        return await f.read()


async def read_bytes(path: str) -> bytes:
    async with aiofiles.open(path, "rb") as f:
        return await f.read()


async def write_text(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    async with aiofiles.open(path, "w", encoding="utf-8") as f:
        await f.write(content)


async def write_bytes(path: str, content: bytes) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    async with aiofiles.open(path, "wb") as f:
        await f.write(content)


async def list_directory(path: str) -> list[dict]:
    if not os.path.isdir(path):
        return []
    items = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        items.append({
            "name": entry,
            "path": full,
            "isDir": os.path.isdir(full),
            "extension": entry.rsplit(".", 1)[-1].lower()
                        if not os.path.isdir(full) and "." in entry else "",
        })
    return items


async def tree_directory(path: str, depth: int = 2) -> list[dict]:
    if depth <= 0:
        return []
    if not os.path.isdir(path):
        return []
    items = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        is_dir = os.path.isdir(full)
        node = {
            "name": entry, "path": full, "isDir": is_dir,
            "extension": "" if is_dir else entry.rsplit(".", 1)[-1].lower(),
        }
        if is_dir and depth > 1:
            node["children"] = await tree_directory(full, depth - 1)
        items.append(node)
    return items
