from __future__ import annotations

import os

from PySide6.QtGui import QGuiApplication


def activate(api):
    def _copy(text: str, empty_message: str = "Nothing to copy") -> dict:
        clipboard = QGuiApplication.clipboard()
        if clipboard and text:
            clipboard.setText(text)
            return {"ok": True, "message": f"Copied {text}"}
        return {"ok": False, "message": empty_message}

    def _relative_path(context: dict) -> str:
        path = str(context.get("path") or "")
        workspace = str(context.get("workspace") or "")
        if path and workspace:
            try:
                return os.path.relpath(path, workspace)
            except ValueError:
                return path
        return str(context.get("relativePath") or path)

    def copy_relative_path(context: dict, action: dict | None = None) -> dict:
        return _copy(_relative_path(context), "No path to copy")

    def copy_name(context: dict, action: dict | None = None) -> dict:
        name = str(context.get("name") or os.path.basename(str(context.get("path") or "")))
        return _copy(name, "No file name to copy")

    def copy_python_import_path(context: dict, action: dict | None = None) -> dict:
        relative_path = _relative_path(context)
        if not relative_path.endswith(".py"):
            return {"ok": False, "message": "Only Python files expose import paths"}
        without_extension = relative_path[:-3]
        parts = [
            part
            for part in without_extension.replace("\\", "/").split("/")
            if part and part != "__init__"
        ]
        return _copy(".".join(parts), "No Python import path to copy")

    api.commands.register("emberWorkbench.search.copyRelativePath", copy_relative_path)
    api.commands.register("emberWorkbench.file.copyRelativePath", copy_relative_path)
    api.commands.register("emberWorkbench.file.copyName", copy_name)
    api.commands.register("emberWorkbench.file.copyPythonImportPath", copy_python_import_path)


def deactivate(api):
    api.commands.unregister("emberWorkbench.search.copyRelativePath")
    api.commands.unregister("emberWorkbench.file.copyRelativePath")
    api.commands.unregister("emberWorkbench.file.copyName")
    api.commands.unregister("emberWorkbench.file.copyPythonImportPath")
