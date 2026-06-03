"""
Plugin System v2.0 — Full lifecycle, permissions, API, and marketplace.

Architecture:
    manifest.py    → PluginManifest (pydantic validation)
    permissions.py → PermissionRegistry (scopes, grants, checks)
    api.py         → PluginAPI (EditorAPI, FileAPI, TerminalAPI, CommandAPI, EventAPI)
    registry.py    → PluginRegistry (discovery, install, uninstall)
    manager.py     → PluginManager (lifecycle: resolve → activate → deactivate)

Quick start:
    from app.plugins import PluginManager

    pm = PluginManager()
    pm.create_api(editor_vm=..., file_vm=..., event_bus=...)
    await pm.discover_all()
    await pm.activate_all()
"""

from app.plugins.manifest import PluginManifest
from app.plugins.permissions import (
    Scope,
    PermissionGrant,
    PermissionRegistry,
    get_permission_registry,
)
from app.plugins.api import (
    PluginAPI,
    EditorAPI,
    FileAPI,
    TerminalAPI,
    CommandAPI,
    EventAPI,
)
from app.plugins.registry import PluginRegistry, PluginState
from app.plugins.manager import PluginManager

__all__ = [
    "PluginManifest",
    "Scope",
    "PermissionGrant",
    "PermissionRegistry",
    "get_permission_registry",
    "PluginAPI",
    "EditorAPI",
    "FileAPI",
    "TerminalAPI",
    "CommandAPI",
    "EventAPI",
    "PluginRegistry",
    "PluginState",
    "PluginManager",
]
