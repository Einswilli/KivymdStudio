"""
CommandViewModel — Manages the command palette and keyboard shortcuts.

Every action in the editor is a command with an ID, title, and optional keybinding.
Plugins can register commands via the extension API.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from typing import Callable, Any
from PySide6.QtCore import QObject, Signal, Slot, Property
from app.core.async_tasks import schedule


@dataclass
class Command:
    id: str
    title: str
    category: str = "General"
    keybinding: str | None = None
    action: Callable[..., Any] | None = field(default=None, repr=False)


class CommandViewModel(QObject):
    commandsChanged = Signal()
    commandExecuted = Signal(str)
    commandFailed = Signal(str, str)

    def __init__(self, events=None, parent: QObject | None = None):
        super().__init__(parent)
        self._events = events
        self._commands: dict[str, Command] = {}
        self._register_builtins()

    def _register_builtins(self) -> None:
        builtins = [
            Command("file.new", "New File", "File", "Ctrl+N"),
            Command("file.open", "Open File...", "File", "Ctrl+O"),
            Command("file.open_folder", "Open Folder...", "File", "Ctrl+K"),
            Command("file.save", "Save", "File", "Ctrl+S"),
            Command("file.save_as", "Save As...", "File", "Ctrl+Shift+S"),
            Command("file.close", "Close Tab", "File", "Ctrl+W"),
            Command("project.new", "New Project...", "Project", None),
            Command("project.open", "Open Project...", "Project", None),
            Command("project.close", "Close Project", "Project", None),
            Command("project.recent", "Recent Projects", "Project", None),
            Command("edit.undo", "Undo", "Edit", "Ctrl+Z"),
            Command("edit.redo", "Redo", "Edit", "Ctrl+Y"),
            Command("edit.cut", "Cut", "Edit", "Ctrl+X"),
            Command("edit.copy", "Copy", "Edit", "Ctrl+C"),
            Command("edit.paste", "Paste", "Edit", "Ctrl+V"),
            Command("edit.find", "Find", "Edit", "Ctrl+F"),
            Command("edit.replace", "Find & Replace", "Edit", "Ctrl+H"),
            Command("view.command_palette", "Command Palette...", "View", "Ctrl+Shift+P"),
            Command("view.terminal", "Toggle Terminal", "View", "Ctrl+`"),
            Command("view.sidebar", "Toggle Sidebar", "View", "Ctrl+B"),
            Command("view.explorer", "Focus Explorer", "View", "Ctrl+Shift+E"),
            Command("view.search", "Focus Search", "View", "Ctrl+Shift+F"),
            Command("view.scm", "Focus Source Control", "View", "Ctrl+Shift+G"),
            Command("view.zoom_in", "Zoom In", "View", "Ctrl+="),
            Command("view.zoom_out", "Zoom Out", "View", "Ctrl+-"),
            Command("editor.format", "Format Document", "Editor", "Shift+Alt+F"),
            Command("editor.toggle_comment", "Toggle Comment", "Editor", "Ctrl+/"),
            Command("editor.go_to_line", "Go to Line...", "Editor", "Ctrl+G"),
            Command("ai.explain", "AI: Explain Code", "AI", None),
            Command("ai.refactor", "AI: Refactor Code", "AI", None),
            Command("ai.generate_tests", "AI: Generate Tests", "AI", None),
            Command("settings.open", "Open Settings", "Preferences", "Ctrl+,"),
            Command("help.about", "About Ember", "Help", None),
        ]
        for cmd in builtins:
            self._commands[cmd.id] = cmd

    def register(self, command: Command) -> None:
        self._commands[command.id] = command
        self.commandsChanged.emit()

    def unregister(self, command_id: str) -> None:
        self._commands.pop(command_id, None)
        self.commandsChanged.emit()

    def execute(self, command_id: str, *args: Any) -> Any:
        cmd = self._commands.get(command_id)
        if cmd and cmd.action:
            return cmd.action(*args)
        return None

    @Slot(str, result=bool)
    def canExecuteCommand(self, command_id: str) -> bool:
        cmd = self._commands.get(command_id)
        return bool(cmd and cmd.action)

    @Slot(str, result=bool)
    def executeCommand(self, command_id: str) -> bool:
        cmd = self._commands.get(command_id)
        if not cmd or not cmd.action:
            return False
        try:
            if self._events:
                schedule(self._events.emit("command:before", command=command_id))
            result = cmd.action()
            if asyncio.iscoroutine(result):
                schedule(self._finish_async_command(command_id, result))
            else:
                self.commandExecuted.emit(command_id)
                if self._events:
                    schedule(self._events.emit("command:after", command=command_id))
            return True
        except Exception as exc:
            self.commandFailed.emit(command_id, str(exc))
            print(f"[CommandVM] command failed: {command_id}: {exc}")
            return True

    async def _finish_async_command(self, command_id: str, coroutine) -> None:
        try:
            await coroutine
            self.commandExecuted.emit(command_id)
            if self._events:
                await self._events.emit("command:after", command=command_id)
        except Exception as exc:
            self.commandFailed.emit(command_id, str(exc))
            print(f"[CommandVM] async command failed: {command_id}: {exc}")

    @Slot(str, result="QVariantList")
    def search(self, query: str) -> list[dict]:
        q = query.lower()
        results = []
        for cmd in self._commands.values():
            if q in cmd.title.lower() or q in cmd.id.lower() or q in cmd.category.lower():
                results.append({
                    "id": cmd.id,
                    "title": cmd.title,
                    "category": cmd.category,
                    "keybinding": cmd.keybinding or "",
                })
        results.sort(key=lambda c: (c["category"], c["title"]))
        return results[:20]

    @Slot(result="QVariantList")
    def allCommands(self) -> list[dict]:
        results = [
            {"id": c.id, "title": c.title, "category": c.category,
             "keybinding": c.keybinding or ""}
            for c in self._commands.values()
        ]
        results.sort(key=lambda c: (c["category"], c["title"]))
        return results

    def get_keybinding_map(self) -> dict[str, str]:
        return {c.keybinding: c.id for c in self._commands.values() if c.keybinding}

    @Property("QVariantList", notify=commandsChanged)
    def commands(self) -> list[dict]:
        return self.allCommands()
