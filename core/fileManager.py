from __future__ import annotations

import os
import glob
from PySide6.QtCore import QObject, Slot, QRunnable

from app.data.models import FileHistory


class Worker(QRunnable):
    def __init__(self, fn, *args, **kwargs):
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs

    @Slot()
    def run(self):
        self.fn(*self.args, **self.kwargs)


class FileManager(QObject):
    @Slot(str, result="QVariant")
    def search(self, text):
        pass

    @Slot(str)
    def save_to_history(self, path):
        import asyncio

        async def _save():
            try:
                await FileHistory.objects.get_or_create(
                    path=path,
                    defaults={"display_name": os.path.basename(path)},
                )
            except Exception as e:
                print(f"[FileManager] save_to_history error: {e}")

        try:
            loop = asyncio.get_event_loop()
            loop.run_until_complete(_save())
        except RuntimeError:
            pass

    def set_current_project_dir(self, url):
        pass

    def get_current_project_dir(self):
        return {"name": "", "fname": ""}

    def process_search(self, pattern):
        files = glob.glob(pattern, recursive=True)
        for file in files:
            print(file)
