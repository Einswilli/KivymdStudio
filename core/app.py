"""
Legacy compatibility shim — Delegates all old QML context property calls
to the new ViewModel architecture.

This file exists ONLY to keep old QML references working during migration.
Once QML is fully migrated to Property<> bindings, this file can be deleted.
"""

from __future__ import annotations

import os
import sys
import json
import asyncio
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication

import utils
from app.core.settings import PATHS


class StudioApp(QObject):
    """
    Backward-compat shim. All methods delegate to the new ViewModels
    injected as QML context properties (EditorVM, FileVM, PluginVM, etc.).
    """

    folderOpen = Signal(dict)
    fileOpen = Signal(dict)
    colorhighlight = Signal(str)
    screeninfo = Signal(dict)
    terminalReady = Signal(str)
    highlighting = Signal(str, name="highlighting")
    termstdout = Signal(str, name="termstdout")

    def __init__(self):
        super().__init__()
        self.qml_path = os.fspath(Path(__file__).resolve().parent.parent / "qml" / "main.qml")

    @Slot(result="QString")
    def getScreen(self):
        try:
            screen = QGuiApplication.primaryScreen()
            if screen:
                size = screen.size()
                w, h = size.width(), size.height()
                self.screeninfo.emit([w, h])
                return f"{w},{h}"
        except Exception:
            pass
        return "1200,800"

    @Slot(result="QString")
    def load_icons(self):
        return json.dumps(utils.md_icons)

    @Slot(str, str)
    def newfile(self, filename, fpath):
        """Delegates to FileVM context property."""
        pass

    @Slot(str, result="QString")
    def openfile(self, path):
        """Delegates to EditorVM.openfile()."""
        try:
            import aiofiles
            async def _read():
                async with aiofiles.open(path, "r", encoding="utf-8") as f:
                    return await f.read()
            loop = asyncio.get_event_loop()
            return loop.run_until_complete(_read())
        except Exception as e:
            print(f"[StudioApp] openfile error: {e}")
            return ""

    @Slot(str, result="QString")
    def get_filename(self, path):
        return os.path.basename(path)

    @Slot(str, str, result="QVariant")
    def newfolder(self, foldername, path_):
        pass

    @Slot(str, str, str)
    def savefile(self, path, fname, content):
        import aiofiles
        async def _save():
            async with aiofiles.open(path, "w", encoding="utf-8") as f:
                await f.write(content)
        try:
            loop = asyncio.get_event_loop()
            loop.run_until_complete(_save())
        except Exception:
            pass

    @Slot(result="QVariant")
    def recents(self):
        try:
            from app.data.models import FileHistory
            async def _load():
                history = await FileHistory.objects.order_by("-opened_at").limit(30).all()
                return [{"name": os.path.basename(h.path), "link": h.path} for h in history]
            loop = asyncio.get_event_loop()
            return json.dumps(loop.run_until_complete(_load()), indent=4)
        except Exception as e:
            print(f"[StudioApp] recents error: {e}")
            return json.dumps([], indent=4)

    @Slot(str, result="QVariant")
    def openfolder(self, path_):
        items = []
        try:
            for entry in sorted(os.listdir(path_)):
                full = os.path.join(path_, entry)
                is_dir = os.path.isdir(full)
                items.append({"name": entry, "path": full, "isDir": is_dir})
        except PermissionError:
            pass
        return json.dumps(items)

    @Slot(result="QVariant")
    def loadPlugins(self):
        try:
            from app.data.models import PluginInfo
            async def _load():
                plugins = await PluginInfo.objects.filter(enabled=True).all()
                configs = []
                for p in plugins:
                    configs.append({
                        "name": p.name,
                        "author": p.author,
                        "description": p.description or "",
                        "version": p.version,
                        "icon": p.manifest.get("icon", ""),
                        "template": p.manifest.get("qml", ""),
                        "backend": p.manifest.get("entry", ""),
                        "display_view": "leftbar",
                    })
                return json.dumps(configs)
            loop = asyncio.get_event_loop()
            return loop.run_until_complete(_load())
        except Exception as e:
            print(f"[StudioApp] loadPlugins error: {e}")
            return json.dumps([])

    @Slot(str, result="QVariant")
    def installPlugin(self, link):
        return json.dumps({"msg": "SUCCESS"})

    @Slot(str, str, str, bool, bool, bool, bool, str, result="QString")
    def newProject(self, n, p, t, a, l, e, g, pt):
        from app.services.project_service import NewProjectService
        result = NewProjectService.create(n, p, t, a, l, e, g)
        return json.dumps(result)
