"""
Plugin manifest validation using pydantic.

Each plugin directory must contain a `manifest.json` following this schema.

Specification:
    {
        "name": "my-plugin",                    // unique id, kebab-case
        "display_name": "My Plugin",             // human-readable
        "version": "1.0.0",                      // semver
        "author": "Author Name",
        "description": "Does something cool",
        "icon": "assets/icon.png",               // relative to plugin dir
        "entry": "backend.py",                   // Python entry point
        "qml": "frontend.qml",                   // QML UI component
        "homepage": "https://...",
        "repository": "https://...",
        "license": "MIT",
        "keywords": ["python", "kivy"],
        "min_app_version": "2.0.0",

        "lifecycle": {
            "on_activate": "activate",
            "on_deactivate": "deactivate",
            "on_config_changed": "on_config_change"
        },

        "permissions": [
            "editor:read",
            "file:read",
            "terminal:exec"
        ],

        "contributes": {
            "commands": [
                {
                    "id": "myPlugin.doThing",
                    "title": "Do a Thing",
                    "keybinding": "Ctrl+Shift+D",
                    "icon": "assets/thing.png"
                }
            ],
            "menus": [
                {
                    "menu": "editor/context",
                    "command": "myPlugin.doThing",
                    "group": "navigation",
                    "when": "editorFocus"
                }
            ],
            "views": [
                {
                    "id": "myPlugin.sidebar",
                    "location": "sidebar",
                    "component": "frontend.qml",
                    "title": "My Sidebar",
                    "icon": "assets/icon.png"
                }
            ],
            "keybindings": [
                {
                    "key": "Ctrl+Shift+D",
                    "command": "myPlugin.doThing",
                    "when": "editorFocus"
                }
            ]
        },

        "dependencies": {
            "other-plugin": ">=1.0.0"
        }
    }
"""

from __future__ import annotations

import json
import os
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator


# ── Permissions ──────────────────────────────────────────────

class PluginPermission(str, Enum):
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


# ── Contributions ────────────────────────────────────────────

class CommandContribution(BaseModel):
    id: str = Field(..., min_length=1, pattern=r"^[a-zA-Z][a-zA-Z0-9._-]*$")
    title: str = Field(..., min_length=1)
    keybinding: Optional[str] = None
    icon: Optional[str] = None


class MenuContribution(BaseModel):
    menu: str = Field(..., min_length=1)
    command: str = Field(..., min_length=1)
    group: Optional[str] = None
    when: Optional[str] = None


class ViewContribution(BaseModel):
    id: str = Field(..., min_length=1)
    location: str = Field(..., min_length=1)
    component: str = Field(..., min_length=1)
    title: Optional[str] = None
    label: Optional[str] = None
    icon: Optional[str] = None
    order: int = 500
    replaces: Optional[str] = None


class PanelContribution(BaseModel):
    id: str = Field(..., min_length=1)
    location: str = Field(default="bottom")
    component: str = Field(..., min_length=1)
    title: str = Field(..., min_length=1)
    label: Optional[str] = None
    icon: Optional[str] = None
    order: int = 500
    permissions: list[str] = Field(default_factory=list)

    @field_validator("location")
    @classmethod
    def validate_location(cls, value: str) -> str:
        if value not in {"bottom", "right"}:
            raise ValueError("Panel location must be 'bottom' or 'right'")
        return value

    @field_validator("permissions")
    @classmethod
    def validate_panel_permissions(cls, value: list[str]) -> list[str]:
        valid = {p.value for p in PluginPermission}
        invalid = [item for item in value if item not in valid]
        if invalid:
            raise ValueError(f"Invalid panel permission(s): {invalid}. Valid: {sorted(valid)}")
        return value


class KeybindingContribution(BaseModel):
    key: str = Field(..., min_length=1)
    command: str = Field(..., min_length=1)
    when: Optional[str] = None


class ActionContribution(BaseModel):
    id: str = Field(..., min_length=1, pattern=r"^[a-zA-Z][a-zA-Z0-9._-]*$")
    title: str = Field(..., min_length=1)
    command: str = Field(..., min_length=1)
    category: str = Field(default="Plugin")
    description: str = Field(default="")
    icon: Optional[str] = None
    keybinding: Optional[str] = None
    requiresPayload: bool = False
    permissions: list[str] = Field(default_factory=list)

    @field_validator("permissions")
    @classmethod
    def validate_action_permissions(cls, value: list[str]) -> list[str]:
        valid = {p.value for p in PluginPermission}
        invalid = [item for item in value if item not in valid]
        if invalid:
            raise ValueError(f"Invalid action permission(s): {invalid}. Valid: {sorted(valid)}")
        return value


class ThemeContribution(BaseModel):
    id: str = Field(..., min_length=1)
    label: str = Field(..., min_length=1)
    path: str = Field(..., min_length=1)


class IconContribution(BaseModel):
    id: str = Field(..., min_length=1)
    path: str = Field(..., min_length=1)


class FileIconContribution(BaseModel):
    pattern: str = Field(..., min_length=1)
    icon: str = Field(..., min_length=1)


class FileIconOverrideContribution(BaseModel):
    id: str = Field(..., min_length=1, pattern=r"^[a-zA-Z][a-zA-Z0-9._-]*$")
    pattern: str = Field(..., min_length=1)
    icon: str = Field(..., min_length=1)
    appliesTo: list[str] = Field(default_factory=lambda: ["file", "folder"])
    priority: int = 500
    when: Optional[str] = None

    @field_validator("appliesTo")
    @classmethod
    def validate_applies_to(cls, value: list[str]) -> list[str]:
        valid = {"file", "folder", "*"}
        invalid = [item for item in value if item not in valid]
        if invalid:
            raise ValueError(f"Invalid file icon override target(s): {invalid}. Valid: {sorted(valid)}")
        return value or ["file", "folder"]


class FontContribution(BaseModel):
    id: str = Field(..., min_length=1)
    label: str = Field(..., min_length=1)
    family: str = Field(..., min_length=1)
    fallbacks: list[str] = Field(default_factory=list)
    target: str = "editor"
    path: Optional[str] = None
    downloadUrl: Optional[str] = None
    license: Optional[str] = None


class EditorDecorationContribution(BaseModel):
    id: str = Field(..., min_length=1)
    type: str = Field(..., min_length=1)
    source: str = Field(default="")
    label: str = Field(default="")


class AIProviderContribution(BaseModel):
    id: str = Field(..., min_length=1, pattern=r"^[a-zA-Z][a-zA-Z0-9._-]*$")
    label: str = Field(..., min_length=1)
    description: str = Field(default="")
    providerType: str = Field(default="openai-compatible")
    endpoint: str = Field(default="")
    defaultModel: str = Field(default="")
    models: list[str] = Field(default_factory=list)
    requiresApiKey: bool = False
    configSchema: dict = Field(default_factory=dict)
    defaults: dict = Field(default_factory=dict)


class LSPProviderContribution(BaseModel):
    id: str = Field(..., min_length=1, pattern=r"^[a-zA-Z][a-zA-Z0-9._-]*$")
    label: str = Field(..., min_length=1)
    language: str = Field(..., min_length=1)
    description: str = Field(default="")
    command: str = Field(..., min_length=1)
    args: list[str] = Field(default_factory=list)
    env: dict[str, str] = Field(default_factory=dict)
    fileExtensions: list[str] = Field(default_factory=list)
    rootPatterns: list[str] = Field(default_factory=list)
    capabilities: list[str] = Field(default_factory=list)
    configSchema: dict = Field(default_factory=dict)
    defaults: dict = Field(default_factory=dict)
    install: dict = Field(default_factory=dict)


class SearchProviderContribution(BaseModel):
    id: str = Field(..., min_length=1, pattern=r"^[a-zA-Z][a-zA-Z0-9._-]*$")
    label: str = Field(..., min_length=1)
    description: str = Field(default="")
    providerType: str = Field(default="python")
    command: Optional[str] = None
    args: list[str] = Field(default_factory=list)
    capabilities: list[str] = Field(default_factory=list)
    configSchema: dict = Field(default_factory=dict)
    defaults: dict = Field(default_factory=dict)
    install: dict = Field(default_factory=dict)


class FileFormatterContribution(BaseModel):
    id: str = Field(..., min_length=1, pattern=r"^[a-zA-Z][a-zA-Z0-9._-]*$")
    label: str = Field(..., min_length=1)
    description: str = Field(default="")
    languages: list[str] = Field(default_factory=list)
    extensions: list[str] = Field(default_factory=list)
    command: str = Field(..., min_length=1)
    args: list[str] = Field(default_factory=list)
    env: dict[str, str] = Field(default_factory=dict)
    priority: int = 500
    permissions: list[str] = Field(default_factory=list)
    configSchema: dict = Field(default_factory=dict)
    defaults: dict = Field(default_factory=dict)
    install: dict = Field(default_factory=dict)

    @field_validator("permissions")
    @classmethod
    def validate_formatter_permissions(cls, value: list[str]) -> list[str]:
        valid = {p.value for p in PluginPermission}
        invalid = [item for item in value if item not in valid]
        if invalid:
            raise ValueError(f"Invalid formatter permission(s): {invalid}. Valid: {sorted(valid)}")
        return value


class FileActionContribution(BaseModel):
    id: str = Field(..., min_length=1, pattern=r"^[a-zA-Z][a-zA-Z0-9._-]*$")
    title: str = Field(..., min_length=1)
    command: str = Field(..., min_length=1)
    icon: Optional[str] = None
    group: str = Field(default="999_plugin")
    when: Optional[str] = None
    appliesTo: list[str] = Field(default_factory=lambda: ["file", "folder"])
    permissions: list[str] = Field(default_factory=list)

    @field_validator("appliesTo")
    @classmethod
    def validate_applies_to(cls, value: list[str]) -> list[str]:
        valid = {"file", "folder", "*"}
        invalid = [item for item in value if item not in valid]
        if invalid:
            raise ValueError(f"Invalid file action target(s): {invalid}. Valid: {sorted(valid)}")
        return value or ["file", "folder"]

    @field_validator("permissions")
    @classmethod
    def validate_action_permissions(cls, value: list[str]) -> list[str]:
        valid = {p.value for p in PluginPermission}
        invalid = [item for item in value if item not in valid]
        if invalid:
            raise ValueError(f"Invalid file action permission(s): {invalid}. Valid: {sorted(valid)}")
        return value


class FileDecorationContribution(BaseModel):
    id: str = Field(..., min_length=1, pattern=r"^[a-zA-Z][a-zA-Z0-9._-]*$")
    title: str = Field(..., min_length=1)
    icon: Optional[str] = None
    badge: Optional[str] = None
    color: Optional[str] = None
    tooltip: str = Field(default="")
    group: str = Field(default="999_plugin")
    when: Optional[str] = None
    appliesTo: list[str] = Field(default_factory=lambda: ["file", "folder"])
    permissions: list[str] = Field(default_factory=list)

    @field_validator("appliesTo")
    @classmethod
    def validate_applies_to(cls, value: list[str]) -> list[str]:
        valid = {"file", "folder", "*"}
        invalid = [item for item in value if item not in valid]
        if invalid:
            raise ValueError(f"Invalid file decoration target(s): {invalid}. Valid: {sorted(valid)}")
        return value or ["file", "folder"]

    @field_validator("permissions")
    @classmethod
    def validate_decoration_permissions(cls, value: list[str]) -> list[str]:
        valid = {p.value for p in PluginPermission}
        invalid = [item for item in value if item not in valid]
        if invalid:
            raise ValueError(f"Invalid file decoration permission(s): {invalid}. Valid: {sorted(valid)}")
        return value


class SearchResultActionContribution(BaseModel):
    id: str = Field(..., min_length=1, pattern=r"^[a-zA-Z][a-zA-Z0-9._-]*$")
    title: str = Field(..., min_length=1)
    command: str = Field(..., min_length=1)
    icon: Optional[str] = None
    group: str = Field(default="999_plugin")
    when: Optional[str] = None
    providers: list[str] = Field(default_factory=lambda: ["*"])
    languages: list[str] = Field(default_factory=lambda: ["*"])
    permissions: list[str] = Field(default_factory=list)

    @field_validator("permissions")
    @classmethod
    def validate_action_permissions(cls, value: list[str]) -> list[str]:
        valid = {p.value for p in PluginPermission}
        invalid = [item for item in value if item not in valid]
        if invalid:
            raise ValueError(f"Invalid search result action permission(s): {invalid}. Valid: {sorted(valid)}")
        return value


class PluginContributes(BaseModel):
    commands: list[CommandContribution] = Field(default_factory=list)
    menus: list[MenuContribution] = Field(default_factory=list)
    views: list[ViewContribution] = Field(default_factory=list)
    disabledViews: list[str] = Field(default_factory=list)
    panels: list[PanelContribution] = Field(default_factory=list)
    keybindings: list[KeybindingContribution] = Field(default_factory=list)
    actions: list[ActionContribution] = Field(default_factory=list)
    themes: list[ThemeContribution] = Field(default_factory=list)
    icons: list[IconContribution] = Field(default_factory=list)
    fileIcons: list[FileIconContribution] = Field(default_factory=list)
    fileIconOverrides: list[FileIconOverrideContribution] = Field(default_factory=list)
    fonts: list[FontContribution] = Field(default_factory=list)
    editorDecorations: list[EditorDecorationContribution] = Field(default_factory=list)
    aiProviders: list[AIProviderContribution] = Field(default_factory=list)
    lspProviders: list[LSPProviderContribution] = Field(default_factory=list)
    searchProviders: list[SearchProviderContribution] = Field(default_factory=list)
    fileFormatters: list[FileFormatterContribution] = Field(default_factory=list)
    fileActions: list[FileActionContribution] = Field(default_factory=list)
    fileDecorations: list[FileDecorationContribution] = Field(default_factory=list)
    searchResultActions: list[SearchResultActionContribution] = Field(default_factory=list)

    @property
    def has_any(self) -> bool:
        return bool(
            self.commands
            or self.menus
            or self.views
            or self.disabledViews
            or self.panels
            or self.keybindings
            or self.actions
            or self.themes
            or self.icons
            or self.fileIcons
            or self.fileIconOverrides
            or self.fonts
            or self.editorDecorations
            or self.aiProviders
            or self.lspProviders
            or self.searchProviders
            or self.fileFormatters
            or self.fileActions
            or self.fileDecorations
            or self.searchResultActions
        )


# ── Lifecycle ────────────────────────────────────────────────

class LifecycleHooks(BaseModel):
    on_activate: str = "activate"
    on_deactivate: str = "deactivate"
    on_config_changed: Optional[str] = None


# ── Manifest ─────────────────────────────────────────────────

class PluginManifest(BaseModel):
    name: str = Field(
        ...,
        min_length=2,
        max_length=100,
        pattern=r"^[a-z0-9][a-z0-9._-]*[a-z0-9]$",
        description="Unique plugin identifier (kebab-case).",
    )
    display_name: str = Field(..., min_length=1, max_length=200)
    version: str = Field(..., pattern=r"^\d+\.\d+\.\d+$")
    author: str = Field(..., min_length=1, max_length=200)
    description: str = Field(default="", max_length=2000)
    icon: Optional[str] = None
    entry: Optional[str] = None
    qml: Optional[str] = None
    homepage: Optional[str] = None
    repository: Optional[str] = None
    license: str = Field(default="MIT")
    keywords: list[str] = Field(default_factory=list)
    min_app_version: Optional[str] = None
    proprietary: bool = False

    lifecycle: LifecycleHooks = Field(default_factory=LifecycleHooks)
    permissions: list[str] = Field(default_factory=list)
    contributes: PluginContributes = Field(default_factory=PluginContributes)
    dependencies: dict[str, str] = Field(default_factory=dict)

    @field_validator("permissions")
    @classmethod
    def validate_permissions(cls, v: list[str]) -> list[str]:
        valid = {p.value for p in PluginPermission}
        for perm in v:
            if perm not in valid:
                raise ValueError(
                    f"Unknown permission '{perm}'. "
                    f"Valid: {sorted(valid)}"
                )
        return v

    @classmethod
    def from_file(cls, path: str) -> PluginManifest:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return cls(**data)

    @classmethod
    def from_directory(cls, plugin_dir: str) -> PluginManifest:
        manifest_path = os.path.join(plugin_dir, "manifest.json")
        if not os.path.exists(manifest_path):
            raise FileNotFoundError(f"manifest.json not found in {plugin_dir}")
        return cls.from_file(manifest_path)
