"""
PluginAPI — The interface exposed to plugins.

Every activated plugin receives an instance of PluginAPI
which provides access to editor, files, terminal, commands, and events.
All access is gated by the permission system.
"""

from __future__ import annotations

import os
import asyncio
from typing import Any, Callable, Coroutine

from app.core.async_tasks import schedule
from app.services.action_service import ActionDefinition
from app.plugins.permissions import Scope, get_permission_registry


class _GuardedAccess:
    """Base class that checks permissions before delegating."""

    def __init__(self, plugin_name: str):
        self._plugin = plugin_name
        self._registry = get_permission_registry()

    def _check(self, scope: Scope) -> None:
        if not self._registry.check(self._plugin, scope):
            raise PermissionError(
                f"Plugin '{self._plugin}' does not have permission '{scope.value}'"
            )


class EditorAPI(_GuardedAccess):
    """Access to the active editor."""

    def __init__(self, plugin_name: str, editor_vm=None):
        super().__init__(plugin_name)
        self._vm = editor_vm

    def _set_vm(self, vm):
        self._vm = vm

    def get_text(self) -> str:
        self._check(Scope.EDITOR_READ)
        return self._vm._current_text if self._vm else ""

    def set_text(self, text: str) -> None:
        self._check(Scope.EDITOR_WRITE)
        if self._vm:
            self._vm.set_text(text)

    def insert(self, position: int, text: str) -> None:
        self._check(Scope.EDITOR_WRITE)
        # Handled via QML signal bridge

    def get_cursor_position(self) -> tuple[int, int]:
        self._check(Scope.EDITOR_READ)
        if self._vm:
            return (self._vm._cursor_line, self._vm._cursor_col)
        return (0, 0)

    def get_file_path(self) -> str:
        self._check(Scope.EDITOR_READ)
        return self._vm._current_path if self._vm else ""

    def get_language(self) -> str:
        self._check(Scope.EDITOR_READ)
        return self._vm._language if self._vm else "text"


class FileAPI(_GuardedAccess):
    """File system operations."""

    async def read(self, path: str) -> str:
        self._check(Scope.FILE_READ)
        import aiofiles
        async with aiofiles.open(path, "r", encoding="utf-8") as f:
            return await f.read()

    async def write(self, path: str, content: str) -> None:
        self._check(Scope.FILE_WRITE)
        import aiofiles
        os.makedirs(os.path.dirname(path), exist_ok=True)
        async with aiofiles.open(path, "w", encoding="utf-8") as f:
            await f.write(content)

    async def list_dir(self, path: str) -> list[dict]:
        self._check(Scope.FILE_READ)
        items = []
        for entry in sorted(os.listdir(path)):
            full = os.path.join(path, entry)
            items.append({
                "name": entry, "path": full,
                "isDir": os.path.isdir(full),
            })
        return items

    async def delete(self, path: str) -> None:
        self._check(Scope.FILE_WRITE)
        if os.path.isfile(path):
            os.remove(path)


class ProjectAPI(_GuardedAccess):
    """Project/workspace operations."""

    def __init__(self, plugin_name: str, project_vm=None):
        super().__init__(plugin_name)
        self._vm = project_vm

    def _set_vm(self, vm):
        self._vm = vm

    def current(self) -> dict:
        self._check(Scope.PROJECT_READ)
        return dict(self._vm.currentProject) if self._vm else {}

    def recent(self) -> list[dict]:
        self._check(Scope.PROJECT_READ)
        return list(self._vm.recentProjects) if self._vm else []

    def open(self, path: str) -> bool:
        self._check(Scope.PROJECT_WRITE)
        return bool(self._vm.openProject(path)) if self._vm else False

    def close(self) -> None:
        self._check(Scope.PROJECT_WRITE)
        if self._vm:
            self._vm.closeProject()


class TerminalAPI(_GuardedAccess):
    """Terminal / subprocess execution."""

    async def exec(self, command: str, cwd: str | None = None) -> dict:
        self._check(Scope.TERMINAL_EXEC)
        proc = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=cwd or os.getcwd(),
        )
        stdout, stderr = await proc.communicate()
        return {
            "stdout": stdout.decode("utf-8", errors="replace"),
            "stderr": stderr.decode("utf-8", errors="replace"),
            "returncode": proc.returncode or 0,
        }


class CommandAPI(_GuardedAccess):
    """Command palette registration."""

    def __init__(self, plugin_name: str):
        super().__init__(plugin_name)
        self._commands: dict[str, Callable] = {}

    def register(self, command_id: str, handler: Callable[..., Any]) -> None:
        self._commands[command_id] = handler

    def unregister(self, command_id: str) -> None:
        self._commands.pop(command_id, None)

    def list_commands(self) -> list[str]:
        return list(self._commands.keys())

    async def execute(self, command_id: str, *args: Any) -> Any:
        if command_id not in self._commands:
            raise KeyError(f"Command '{command_id}' not found")
        result = self._commands[command_id](*args)
        if asyncio.iscoroutine(result):
            return await result
        return result


class EventAPI(_GuardedAccess):
    """Event bus access for plugins."""

    def __init__(self, plugin_name: str, event_bus=None):
        super().__init__(plugin_name)
        self._bus = event_bus
        self._handlers: list[tuple[str, Callable]] = []

    def _set_bus(self, bus):
        self._bus = bus

    def on(self, event: str, handler: Callable[..., Coroutine]) -> None:
        if self._bus:
            self._bus.on(event, handler)
            self._handlers.append((event, handler))

    async def emit(self, event: str, **kwargs) -> None:
        if self._bus:
            await self._bus.emit(event, **kwargs)

    def cleanup(self) -> None:
        if self._bus:
            for event, handler in self._handlers:
                self._bus.off(event, handler)
        self._handlers.clear()


class NotificationAPI:
    """Non-privileged user feedback channel exposed to plugins."""

    def __init__(self, plugin_name: str, notification_vm=None):
        self._plugin = plugin_name
        self._vm = notification_vm

    def _set_vm(self, vm):
        self._vm = vm

    def info(self, title: str, message: str = "", timeout: int = 4200) -> int:
        return self._push("info", title, message, timeout)

    def success(self, title: str, message: str = "", timeout: int = 3600) -> int:
        return self._push("success", title, message, timeout)

    def warning(self, title: str, message: str = "", timeout: int = 5200) -> int:
        return self._push("warning", title, message, timeout)

    def error(self, title: str, message: str = "", timeout: int = 6500) -> int:
        return self._push("error", title, message, timeout)

    def start(self, key: str, label: str = "Working…") -> None:
        if self._vm:
            self._vm.startBusy(self._scoped_key(key), label)

    def progress(self, key: str, label: str) -> None:
        if self._vm:
            self._vm.setOperation(self._scoped_key(key), label)

    def end(self, key: str) -> None:
        if self._vm:
            self._vm.endBusy(self._scoped_key(key))

    def _push(self, level: str, title: str, message: str, timeout: int) -> int:
        if not self._vm:
            return 0
        return int(self._vm.push(level, title, message, timeout))

    def _scoped_key(self, key: str) -> str:
        clean = str(key or "operation").strip() or "operation"
        return f"plugin:{self._plugin}:{clean}"


class WorkbenchAPI:
    """Workbench panels exposed to plugins."""

    def __init__(self, plugin_name: str, event_bus=None):
        self._plugin = plugin_name
        self._bus = event_bus

    def _set_bus(self, bus):
        self._bus = bus

    def append_output(self, message: str, source: str | None = None, level: str = "info") -> None:
        if self._bus:
            schedule(self._bus.emit(
                "workbench:output:append",
                source=source or self._plugin,
                level=level,
                message=message,
            ))

    def append_console(self, message: str, level: str = "info", source: str | None = None) -> None:
        if self._bus:
            schedule(self._bus.emit(
                "workbench:console:append",
                source=source or self._plugin,
                level=level,
                message=message,
            ))


class ActionAPI:
    """Action registry exposed to plugins.

    Plugins can register action handlers that are executable from QML,
    notifications, command palette bridges, or other plugins.
    """

    def __init__(self, plugin_name: str, action_service=None):
        self._plugin = plugin_name
        self._service = action_service
        self._registered: set[str] = set()

    def _set_service(self, service):
        self._service = service

    def register(
        self,
        action_id: str,
        title: str,
        handler: Callable[[dict], Any],
        category: str = "Plugin",
        description: str = "",
        busy_label: str = "Running plugin action…",
    ) -> None:
        if not self._service:
            return
        scoped_id = self._scoped_id(action_id)
        self._service.register(ActionDefinition(
            id=scoped_id,
            title=title,
            category=category,
            description=description,
            source=self._plugin,
            busy_label=busy_label,
            handler=handler,
        ))
        self._registered.add(scoped_id)

    def unregister(self, action_id: str) -> None:
        if not self._service:
            return
        scoped_id = self._scoped_id(action_id)
        self._service.unregister(scoped_id)
        self._registered.discard(scoped_id)

    async def run(self, action_id: str, payload: dict | None = None) -> dict:
        if not self._service:
            return {"ok": False, "message": "Action service unavailable"}
        return await self._service.execute(self._scoped_id(action_id), payload or {})

    def list(self) -> list[dict]:
        return self._service.list_actions() if self._service else []

    def cleanup(self) -> None:
        if not self._service:
            return
        for action_id in list(self._registered):
            self._service.unregister(action_id)
        self._registered.clear()

    def _scoped_id(self, action_id: str) -> str:
        clean = str(action_id or "").strip()
        if clean.startswith(f"{self._plugin}."):
            return clean
        return f"{self._plugin}.{clean}"


class PluginAPI:
    """
    The complete API surface exposed to an activated plugin.

    Usage in plugin backend.py:
        def activate(api: PluginAPI):
            api.commands.register("myPlugin.hello", say_hello)
            api.events.on("editor:save", on_save)
    """

    def __init__(
        self,
        plugin_name: str,
        editor_vm=None,
        file_vm=None,
        project_vm=None,
        terminal_vm=None,
        event_bus=None,
        notification_vm=None,
        action_service=None,
    ):
        self.editor = EditorAPI(plugin_name, editor_vm)
        self.files = FileAPI(plugin_name)
        self.projects = ProjectAPI(plugin_name, project_vm)
        self.terminal = TerminalAPI(plugin_name)
        self.commands = CommandAPI(plugin_name)
        self.events = EventAPI(plugin_name, event_bus)
        self.notifications = NotificationAPI(plugin_name, notification_vm)
        self.workbench = WorkbenchAPI(plugin_name, event_bus)
        self.actions = ActionAPI(plugin_name, action_service)
        self._plugin_name = plugin_name

    def update_vms(
        self,
        editor_vm=None,
        file_vm=None,
        project_vm=None,
        terminal_vm=None,
        event_bus=None,
        notification_vm=None,
        action_service=None,
    ):
        if editor_vm:
            self.editor._set_vm(editor_vm)
        if project_vm:
            self.projects._set_vm(project_vm)
        if event_bus:
            self.events._set_bus(event_bus)
            self.workbench._set_bus(event_bus)
        if notification_vm:
            self.notifications._set_vm(notification_vm)
        if action_service:
            self.actions._set_service(action_service)

    def cleanup(self):
        self.events.cleanup()
        self.actions.cleanup()
