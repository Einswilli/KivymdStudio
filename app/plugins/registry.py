"""
Plugin registry — discovery, installation, and lifecycle management.

Directory structure per plugin:
    ~/.Ember/plugins/python/myPlugin/
        manifest.json    — PluginManifest (required)
        backend.py       — Python entry point (optional)
        frontend.qml     — QML UI component (optional)
        assets/          — Icons, resources
"""

from __future__ import annotations

import os
import glob
import shutil
import asyncio
import hashlib
import json
import tempfile
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

from app.core.settings import PATHS
from app.plugins.manifest import PluginManifest
from app.plugins.permissions import get_permission_registry


@dataclass
class PluginState:
    manifest: PluginManifest
    directory: str = ""          # Absolute path to plugin directory
    installed: bool = False
    enabled: bool = False
    loaded: bool = False
    active: bool = False
    error: str | None = None
    installed_from: str = ""
    manifest_hash: str = ""
    current_manifest_hash: str = ""
    trusted: bool = False
    modified: bool = False
    module: object | None = field(default=None, repr=False)


class PluginRegistry:
    def __init__(self):
        self._plugins: dict[str, PluginState] = {}
        self._install_dir = os.path.join(PATHS["PLUGINS"], "python")
        self._repo_plugin_dir = str(Path.cwd() / "plugins" / "python")
        self._allow_user_plugins = True

    def configure(self, *, allow_user_plugins: bool = True) -> None:
        self._allow_user_plugins = bool(allow_user_plugins)

    # ── Discovery ─────────────────────────────────────────

    async def discover(self) -> dict[str, PluginState]:
        os.makedirs(self._install_dir, exist_ok=True)
        discovered: dict[str, PluginState] = {}

        plugin_dirs = []
        roots = [self._repo_plugin_dir]
        if self._allow_user_plugins:
            roots.append(self._install_dir)
        for root in roots:
            plugin_dirs.extend(glob.glob(os.path.join(root, "*")))

        seen: set[str] = set()
        for plugin_dir in plugin_dirs:
            if not os.path.isdir(plugin_dir) or plugin_dir in seen:
                continue
            seen.add(plugin_dir)
            dir_name = os.path.basename(plugin_dir)
            try:
                manifest = PluginManifest.from_directory(plugin_dir)
                key = manifest.name
                enabled = await self._load_enabled_state(key)
                current_manifest_hash = self._manifest_hash(manifest)
                stored_manifest_hash = await self._load_manifest_hash(key)
                manifest_hash = stored_manifest_hash or current_manifest_hash
                modified = bool(stored_manifest_hash and stored_manifest_hash != current_manifest_hash)
                trusted = bool(await self._load_trusted_state(key, manifest) or manifest.proprietary)
                state = PluginState(
                    manifest=manifest,
                    directory=plugin_dir,
                    installed=True,
                    enabled=enabled,
                    installed_from=await self._load_installed_from(key) or plugin_dir,
                    manifest_hash=manifest_hash,
                    current_manifest_hash=current_manifest_hash,
                    trusted=trusted,
                    modified=modified,
                )
                discovered[key] = state
            except Exception as e:
                # Also try legacy plugins (no manifest.json, just *Plugin.py)
                discovered[dir_name] = self._discover_legacy(plugin_dir, dir_name)
                print(f"[PluginRegistry] {dir_name}: {e}")

        self._plugins = discovered
        return discovered

    async def _load_enabled_state(self, name: str) -> bool:
        try:
            from app.data.models import PluginInfo

            plugin = await PluginInfo.objects.get(name=name)
            return bool(plugin.enabled)
        except Exception:
            return True

    async def _load_installed_from(self, name: str) -> str:
        try:
            from app.data.models import PluginInfo

            plugin = await PluginInfo.objects.get(name=name)
            return str(getattr(plugin, "installed_from", "") or "")
        except Exception:
            return ""

    async def _load_manifest_hash(self, name: str) -> str:
        try:
            from app.data.models import PluginInfo

            plugin = await PluginInfo.objects.get(name=name)
            return str(getattr(plugin, "manifest_hash", "") or "")
        except Exception:
            return ""

    async def _load_trusted_state(self, name: str, manifest: PluginManifest) -> bool:
        if manifest.proprietary:
            return True
        try:
            from app.data.models import PluginInfo

            plugin = await PluginInfo.objects.get(name=name)
            return bool(getattr(plugin, "trusted", False))
        except Exception:
            return False

    async def set_enabled(self, name: str, enabled: bool) -> None:
        state = self._plugins.get(name)
        if state:
            state.enabled = bool(enabled)
        try:
            from app.data.models import PluginInfo

            try:
                plugin = await PluginInfo.objects.get(name=name)
                plugin.enabled = bool(enabled)
                await plugin.save()
            except Exception:
                if not state:
                    return
                manifest = state.manifest
                await PluginInfo.objects.create(
                    name=manifest.name,
                    version=manifest.version,
                    author=manifest.author,
                    description=manifest.description,
                    manifest=manifest.model_dump(),
                    enabled=bool(enabled),
                    installed_from=state.installed_from or state.directory,
                    manifest_hash=state.manifest_hash or self._manifest_hash(manifest),
                    trusted=bool(state.trusted or manifest.proprietary),
                )
        except Exception:
            pass

    async def trust_current_manifest(self, name: str) -> bool:
        state = self._plugins.get(name)
        if not state:
            return False
        current_hash = self._manifest_hash(state.manifest)
        state.manifest_hash = current_hash
        state.current_manifest_hash = current_hash
        state.trusted = True
        state.modified = False
        state.error = None
        try:
            from app.data.models import PluginInfo

            try:
                plugin = await PluginInfo.objects.get(name=name)
                plugin.manifest = state.manifest.model_dump()
                plugin.version = state.manifest.version
                plugin.author = state.manifest.author
                plugin.description = state.manifest.description
                plugin.manifest_hash = current_hash
                plugin.trusted = True
                plugin.installed_from = state.installed_from or state.directory
                await plugin.save()
            except Exception:
                await PluginInfo.objects.create(
                    name=state.manifest.name,
                    version=state.manifest.version,
                    author=state.manifest.author,
                    description=state.manifest.description,
                    manifest=state.manifest.model_dump(),
                    enabled=state.enabled,
                    installed_from=state.installed_from or state.directory,
                    manifest_hash=current_hash,
                    trusted=True,
                )
        except Exception as exc:
            print(f"[PluginRegistry] Could not trust manifest for {name}: {exc}")
        return True

    def _discover_legacy(self, plugin_dir: str, dir_name: str) -> PluginState:
        """Create a minimal PluginState for legacy plugins without manifest.json."""
        from app.plugins.manifest import PluginManifest, LifecycleHooks
        manifest = PluginManifest(
            name=dir_name,
            display_name=dir_name.replace("Plugin", ""),
            version="0.1.0",
            author="unknown",
            description="Legacy plugin (no manifest.json)",
            lifecycle=LifecycleHooks(),
        )
        return PluginState(
            manifest=manifest,
            directory=plugin_dir,
            installed=True,
            enabled=True,
        )

    # ── Install / Uninstall ────────────────────────────────

    async def install(self, source_path: str) -> PluginState | None:
        original_source = os.path.abspath(os.path.expanduser(source_path))
        prepared_dir, cleanup = self._prepare_install_source(original_source)
        try:
            try:
                manifest = PluginManifest.from_directory(prepared_dir)
            except Exception as e:
                raise ValueError(f"Invalid plugin: {e}") from e

            target = os.path.join(self._install_dir, manifest.name)
            if os.path.exists(target):
                shutil.rmtree(target)
            shutil.copytree(prepared_dir, target)
        finally:
            cleanup()

        perms = get_permission_registry()
        perms.register(manifest.name, manifest.permissions)
        manifest_hash = self._manifest_hash(manifest)

        state = PluginState(
            manifest=manifest,
            directory=target,
            installed=True,
            enabled=True,
            installed_from=original_source,
            manifest_hash=manifest_hash,
            current_manifest_hash=manifest_hash,
            trusted=bool(manifest.proprietary),
            modified=False,
        )
        self._plugins[manifest.name] = state

        from app.data.models import PluginInfo
        try:
            await PluginInfo.objects.update_or_create(
                name=manifest.name,
                defaults={
                    "version": manifest.version,
                    "author": manifest.author,
                    "description": manifest.description,
                    "manifest": manifest.model_dump(),
                    "enabled": True,
                    "installed_from": state.installed_from,
                    "manifest_hash": state.manifest_hash,
                    "trusted": state.trusted,
                },
            )
        except Exception as e:
            print(f"[PluginRegistry] DB error: {e}")

        return state

    async def analyze_update(self, name: str) -> dict:
        state = self._plugins.get(name)
        if not state:
            return self._update_status(name, "missing", False, "Plugin is not installed.")
        source = state.installed_from or state.directory
        if not source:
            return self._update_status(name, "source_missing", False, "No install source recorded.")
        source_path = os.path.abspath(os.path.expanduser(source))
        if not self._source_exists(source_path):
            return self._update_status(
                name,
                "source_missing",
                False,
                f"Install source is unavailable: {source_path}",
                source=source_path,
            )
        prepared_dir, cleanup = self._prepare_install_source(source_path)
        try:
            candidate = PluginManifest.from_directory(prepared_dir)
        except Exception as exc:
            return self._update_status(
                name,
                "invalid",
                False,
                f"Install source manifest is invalid: {exc}",
                source=source_path,
            )
        finally:
            cleanup()
        if candidate.name != state.manifest.name:
            return self._update_status(
                name,
                "invalid",
                False,
                f"Install source belongs to '{candidate.name}', expected '{state.manifest.name}'.",
                source=source_path,
                candidate=candidate,
            )

        candidate_hash = self._manifest_hash(candidate)
        changed = candidate_hash != state.manifest_hash
        status = "update_available" if changed else "up_to_date"
        if state.modified:
            status = "modified"
            changed = True
        return self._update_status(
            name,
            status,
            changed,
            "Update available." if changed else "Plugin is up to date.",
            source=source_path,
            candidate=candidate,
            current=state.manifest,
            stored_hash=state.manifest_hash,
            candidate_hash=candidate_hash,
        )

    async def update_from_source(self, name: str) -> PluginState | None:
        state = self._plugins.get(name)
        if not state:
            raise ValueError(f"Plugin '{name}' is not installed")
        source = state.installed_from or state.directory
        if not source:
            raise ValueError(f"Plugin '{name}' has no install source")
        source_path = os.path.abspath(os.path.expanduser(source))
        if not self._source_exists(source_path):
            raise ValueError(f"Install source is unavailable: {source_path}")
        if os.path.abspath(state.directory or "") == source_path:
            await self.trust_current_manifest(name)
            return self._plugins.get(name)
        return await self.install(source_path)

    async def uninstall(self, name: str) -> bool:
        state = self._plugins.get(name)
        plugin_dir = os.path.join(self._install_dir, name)
        if os.path.exists(plugin_dir):
            shutil.rmtree(plugin_dir)

        perms = get_permission_registry()
        perms.remove(name)
        self._plugins.pop(name, None)

        from app.data.models import PluginInfo
        try:
            plugin = await PluginInfo.objects.get(name=name)
            await plugin.delete()
        except Exception:
            pass

        return True

    # ── Queries ───────────────────────────────────────────

    def get(self, name: str) -> PluginState | None:
        return self._plugins.get(name)

    def list_all(self) -> list[PluginState]:
        return list(self._plugins.values())

    def list_enabled(self) -> list[PluginState]:
        return [s for s in self._plugins.values() if s.enabled]

    def list_active(self) -> list[PluginState]:
        return [s for s in self._plugins.values() if s.active]

    def get_legacy_configs(self) -> list[dict]:
        """Backward compat: return legacy CONFIG dicts for old QML sidebar."""
        configs = []
        for key, state in self._plugins.items():
            if not state.manifest:
                continue
            m = state.manifest
            icon = m.icon or ""
            if icon and not icon.startswith("/"):
                icon = os.path.join(state.directory, icon)
            qml = m.qml or ""
            if qml and not qml.startswith("/"):
                qml = os.path.join(state.directory, qml)
            configs.append({
                "id": m.name,
                "name": m.display_name,
                "author": m.author,
                "type": m.keywords[0] if m.keywords else "",
                "description": m.description,
                "version": m.version,
                "icon": icon,
                "template": qml,
                "backend": m.entry or "",
                "display_view": "leftbar",
                "active": state.active,
                "enabled": state.enabled,
                "proprietary": bool(m.proprietary),
                "canUninstall": not bool(m.proprietary),
                "installedFrom": state.installed_from,
                "manifestHash": state.manifest_hash,
                "currentManifestHash": state.current_manifest_hash,
                "trusted": bool(state.trusted),
                "modified": bool(state.modified),
                "error": state.error or "",
            })
        return configs

    def discover_store(self, sources: list[str]) -> list[dict]:
        candidates: dict[str, dict] = {}
        for source in sources or []:
            source_path = os.path.abspath(os.path.expanduser(str(source or "")))
            for candidate_path in self._iter_store_candidates(source_path):
                prepared_dir, cleanup = self._prepare_install_source(candidate_path)
                try:
                    manifest = PluginManifest.from_directory(prepared_dir)
                    manifest_hash = self._manifest_hash(manifest)
                    installed = self._plugins.get(manifest.name)
                    source_is_zip = zipfile.is_zipfile(candidate_path)
                    icon = manifest.icon or ""
                    if icon and not source_is_zip and not icon.startswith(("/", "file:", "qrc:", "http://", "https://")):
                        icon = os.path.join(prepared_dir, icon)
                    elif source_is_zip:
                        icon = ""
                    candidates[manifest.name] = {
                        "id": manifest.name,
                        "name": manifest.display_name,
                        "description": manifest.description,
                        "version": manifest.version,
                        "author": manifest.author,
                        "source": candidate_path,
                        "sourceKind": "zip" if source_is_zip else "directory",
                        "icon": icon,
                        "permissions": list(manifest.permissions or []),
                        "contributions": self._contribution_summary(manifest),
                        "proprietary": bool(manifest.proprietary),
                        "manifestHash": manifest_hash,
                        "installed": installed is not None,
                        "active": bool(installed.active) if installed else False,
                        "installedVersion": installed.manifest.version if installed else "",
                        "installedHash": installed.manifest_hash if installed else "",
                        "updateAvailable": bool(installed and installed.manifest_hash != manifest_hash),
                    }
                except Exception as exc:
                    print(f"[PluginRegistry] Store candidate skipped {candidate_path}: {exc}")
                finally:
                    cleanup()
        return sorted(candidates.values(), key=lambda item: item["name"].lower())

    def _iter_store_candidates(self, source_path: str) -> list[str]:
        if not source_path:
            return []
        if zipfile.is_zipfile(source_path):
            return [source_path]
        if not os.path.isdir(source_path):
            return []
        candidates = []
        if os.path.exists(os.path.join(source_path, "manifest.json")):
            candidates.append(source_path)
        for child in sorted(Path(source_path).iterdir(), key=lambda item: item.name.lower()):
            child_path = str(child)
            if child.is_dir() and os.path.exists(os.path.join(child_path, "manifest.json")):
                candidates.append(child_path)
            elif child.is_file() and child.suffix.lower() == ".zip" and zipfile.is_zipfile(child_path):
                candidates.append(child_path)
        return candidates

    def _prepare_install_source(self, source_path: str) -> tuple[str, callable]:
        if os.path.isdir(source_path):
            return source_path, lambda: None
        if not zipfile.is_zipfile(source_path):
            raise ValueError(f"Plugin source is not a directory or zip archive: {source_path}")
        temp_dir = tempfile.TemporaryDirectory(prefix="ember-plugin-")
        with zipfile.ZipFile(source_path) as archive:
            self._safe_extract(archive, temp_dir.name)
        plugin_dir = self._find_manifest_dir(temp_dir.name)
        if not plugin_dir:
            temp_dir.cleanup()
            raise ValueError("manifest.json not found in plugin archive")
        return plugin_dir, temp_dir.cleanup

    @staticmethod
    def _find_manifest_dir(root: str) -> str:
        manifest = os.path.join(root, "manifest.json")
        if os.path.exists(manifest):
            return root
        for current, dirs, files in os.walk(root):
            if "manifest.json" in files:
                return current
            if current != root:
                dirs[:] = []
        return ""

    @staticmethod
    def _source_exists(source_path: str) -> bool:
        return os.path.isdir(source_path) or (os.path.isfile(source_path) and zipfile.is_zipfile(source_path))

    @staticmethod
    def _safe_extract(archive: zipfile.ZipFile, target: str) -> None:
        target_root = os.path.abspath(target)
        for member in archive.infolist():
            member_path = os.path.abspath(os.path.join(target_root, member.filename))
            if os.path.commonpath([target_root, member_path]) != target_root:
                raise ValueError(f"Unsafe archive path: {member.filename}")
        archive.extractall(target_root)

    @staticmethod
    def _contribution_summary(manifest: PluginManifest) -> dict:
        c = manifest.contributes
        return {
            "commands": len(c.commands),
            "views": len(c.views),
            "disabledViews": len(c.disabledViews),
            "panels": len(c.panels),
            "keybindings": len(c.keybindings),
            "themes": len(c.themes),
            "icons": len(c.icons),
            "fileIcons": len(c.fileIcons),
            "fileIconOverrides": len(c.fileIconOverrides),
            "fonts": len(c.fonts),
            "editorDecorations": len(c.editorDecorations),
            "aiProviders": len(c.aiProviders),
            "lspProviders": len(c.lspProviders),
            "searchProviders": len(c.searchProviders),
            "fileFormatters": len(c.fileFormatters),
            "fileActions": len(c.fileActions),
            "fileDecorations": len(c.fileDecorations),
            "searchResultActions": len(c.searchResultActions),
        }

    @staticmethod
    def _manifest_hash(manifest: PluginManifest) -> str:
        payload = json.dumps(
            manifest.model_dump(),
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
        )
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()

    def _update_status(
        self,
        name: str,
        state: str,
        can_update: bool,
        message: str,
        *,
        source: str = "",
        candidate: PluginManifest | None = None,
        current: PluginManifest | None = None,
        stored_hash: str = "",
        candidate_hash: str = "",
    ) -> dict:
        return {
            "plugin": name,
            "state": state,
            "canUpdate": can_update,
            "message": message,
            "source": source,
            "storedHash": stored_hash,
            "candidateHash": candidate_hash,
            "candidate": candidate.model_dump() if candidate else {},
            "diff": self._manifest_diff(current, candidate) if current and candidate else {},
        }

    @staticmethod
    def _manifest_diff(current: PluginManifest, candidate: PluginManifest) -> dict:
        current_dump = current.model_dump()
        candidate_dump = candidate.model_dump()
        current_permissions = set(current.permissions or [])
        candidate_permissions = set(candidate.permissions or [])
        current_contributes = current_dump.get("contributes") or {}
        candidate_contributes = candidate_dump.get("contributes") or {}
        contribution_changes: dict[str, dict] = {}
        for key in sorted(set(current_contributes.keys()) | set(candidate_contributes.keys())):
            before = current_contributes.get(key) or []
            after = candidate_contributes.get(key) or []
            if len(before) != len(after):
                contribution_changes[key] = {"before": len(before), "after": len(after)}
        return {
            "versionChanged": current.version != candidate.version,
            "fromVersion": current.version,
            "toVersion": candidate.version,
            "authorChanged": current.author != candidate.author,
            "fromAuthor": current.author,
            "toAuthor": candidate.author,
            "permissionsAdded": sorted(candidate_permissions - current_permissions),
            "permissionsRemoved": sorted(current_permissions - candidate_permissions),
            "contributions": contribution_changes,
        }
