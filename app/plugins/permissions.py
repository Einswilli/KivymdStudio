"""
Plugin permission system.

Each plugin declares required permissions in its manifest.json.
The user must approve permissions before the plugin can be activated.
"""

from __future__ import annotations

from enum import Enum
from dataclasses import dataclass, field


class Scope(str, Enum):
    EDITOR_READ = "editor:read"
    EDITOR_WRITE = "editor:write"
    DIAGNOSTICS_READ = "diagnostics:read"
    FILE_READ = "file:read"
    FILE_WRITE = "file:write"
    FILE_DELETE = "file:delete"
    FILE_ACTIONS = "file:actions"
    PROJECT_READ = "project:read"
    PROJECT_WRITE = "project:write"
    TERMINAL_EXEC = "terminal:exec"
    NETWORK = "network"
    SETTINGS_READ = "settings:read"
    SETTINGS_WRITE = "settings:write"


SCOPE_DESCRIPTIONS: dict[Scope, str] = {
    Scope.EDITOR_READ: "Read the content of open files",
    Scope.EDITOR_WRITE: "Modify editor content, insert text, change cursor",
    Scope.DIAGNOSTICS_READ: "Read diagnostics produced by language services",
    Scope.FILE_READ: "Read files from disk",
    Scope.FILE_WRITE: "Write files on disk",
    Scope.FILE_DELETE: "Delete files or folders from disk",
    Scope.FILE_ACTIONS: "Register and execute file browser actions",
    Scope.PROJECT_READ: "Read workspace and project metadata",
    Scope.PROJECT_WRITE: "Open, close, or create projects",
    Scope.TERMINAL_EXEC: "Execute shell commands",
    Scope.NETWORK: "Make network requests",
    Scope.SETTINGS_READ: "Read editor settings",
    Scope.SETTINGS_WRITE: "Modify editor settings",
}


@dataclass
class PermissionGrant:
    plugin_name: str
    scopes: list[Scope]
    approved: bool = False

    def has(self, scope: Scope) -> bool:
        return self.approved and scope in self.scopes

    def has_any(self, *scopes: Scope) -> bool:
        return self.approved and any(s in self.scopes for s in scopes)

    def to_dict(self) -> dict:
        return {
            "plugin": self.plugin_name,
            "scopes": [scope.value for scope in self.scopes],
            "approved": self.approved,
            "descriptions": [
                {"scope": scope.value, "description": SCOPE_DESCRIPTIONS.get(scope, scope.value)}
                for scope in self.scopes
            ],
        }


class PermissionRegistry:
    def __init__(self):
        self._grants: dict[str, PermissionGrant] = {}

    def register(self, plugin_name: str, scopes: list[str]) -> PermissionGrant:
        parsed = [Scope(s) for s in scopes]
        existing = self._grants.get(plugin_name)
        approved = bool(existing and existing.approved and existing.scopes == parsed)
        grant = PermissionGrant(plugin_name=plugin_name, scopes=parsed, approved=approved)
        self._grants[plugin_name] = grant
        return grant

    def approve(self, plugin_name: str, scopes: list[str] | None = None) -> None:
        if scopes is not None and plugin_name not in self._grants:
            self.register(plugin_name, scopes)
        if plugin_name in self._grants:
            self._grants[plugin_name].approved = True

    def revoke(self, plugin_name: str) -> None:
        if plugin_name in self._grants:
            self._grants[plugin_name].approved = False

    def check(self, plugin_name: str, scope: Scope) -> bool:
        grant = self._grants.get(plugin_name)
        return grant is not None and grant.has(scope)

    def remove(self, plugin_name: str) -> None:
        self._grants.pop(plugin_name, None)

    def get_pending_approvals(self) -> list[PermissionGrant]:
        return [g for g in self._grants.values() if not g.approved]

    def get_scopes_for(self, plugin_name: str) -> list[Scope]:
        grant = self._grants.get(plugin_name)
        return grant.scopes if grant else []

    def get(self, plugin_name: str) -> PermissionGrant | None:
        return self._grants.get(plugin_name)

    def list_all(self) -> list[PermissionGrant]:
        return list(self._grants.values())


_registry = PermissionRegistry()


def get_permission_registry() -> PermissionRegistry:
    return _registry
