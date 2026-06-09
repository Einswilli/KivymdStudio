"""
PluginManager — Lifecycle management for plugins.

Lifecycle states:
    DISABLED → resolve() → RESOLVED → activate() → ACTIVE
    ACTIVE   → deactivate() → DISABLED

When a plugin is activated, its manifest.contributions are registered:
    - commands    → added to the command palette
    - menus       → injected into editor context menus
    - views       → mounted in the sidebar/panel/statusbar
    - keybindings → registered as global shortcuts
"""

from __future__ import annotations

import os
import importlib
import importlib.util
import inspect
import tempfile
import hashlib
from typing import Any
from urllib.parse import urljoin

from app.plugins.registry import PluginRegistry, PluginState
from app.plugins.manifest import PluginManifest
from app.plugins.store_contract import PluginStoreItem
from app.plugins.api import PluginAPI
from app.plugins.permissions import get_permission_registry
from app.services.action_service import ActionDefinition
from app.viewmodels.command_vm import Command
from app.services.keybinding_service import KeybindingService

PERMISSION_SETTING_PREFIX = "plugin.permissions."


class PluginManager:
    def __init__(self, command_vm=None):
        self.registry = PluginRegistry()
        self._api: PluginAPI | None = None
        self._command_vm = command_vm
        self._settings_service = None
        self._notification_vm = None
        self._action_service = None
        self._active_modules: dict[str, Any] = {}
        self._plugin_apis: dict[str, PluginAPI] = {}
        self._contributed_commands: dict[str, dict] = {}
        self._contributed_actions: dict[str, dict] = {}
        self._contributed_menus: dict[str, list[dict]] = {}
        self._contributed_views: dict[str, list[dict]] = {}
        self._disabled_views: dict[str, set[str]] = {}
        self._contributed_panels: dict[str, list[dict]] = {}
        self._contributed_keybindings: dict[str, list[dict]] = {}
        self._contributed_icons: dict[str, str] = {}
        self._contributed_file_icons: dict[str, str] = {}
        self._contributed_file_icon_overrides: dict[str, dict] = {}
        self._contributed_editor_decorations: dict[str, dict] = {}
        self._contributed_file_actions: dict[str, dict] = {}
        self._contributed_file_decorations: dict[str, dict] = {}
        self._contributed_file_formatters: dict[str, dict] = {}
        self._contributed_search_result_actions: dict[str, dict] = {}
        self._keybindings = KeybindingService()

    def set_command_vm(self, command_vm) -> None:
        self._command_vm = command_vm

    def set_settings_service(self, settings_service) -> None:
        self._settings_service = settings_service
        self._keybindings.set_settings(settings_service)
        self.registry.configure(
            allow_user_plugins=self._policy_bool("extensions.allowUserPlugins", True)
        )

    def set_notification_vm(self, notification_vm) -> None:
        self._notification_vm = notification_vm
        if self._api:
            self._api.update_vms(notification_vm=notification_vm)

    def set_action_service(self, action_service) -> None:
        self._action_service = action_service
        if self._api:
            self._api.update_vms(action_service=action_service)

    def create_api(
        self,
        editor_vm=None,
        file_vm=None,
        project_vm=None,
        terminal_vm=None,
        event_bus=None,
        notification_vm=None,
        action_service=None,
    ) -> PluginAPI:
        self._notification_vm = notification_vm or self._notification_vm
        self._action_service = action_service or self._action_service
        self._api = PluginAPI(
            plugin_name="_manager",
            editor_vm=editor_vm,
            file_vm=file_vm,
            project_vm=project_vm,
            terminal_vm=terminal_vm,
            event_bus=event_bus,
            notification_vm=self._notification_vm,
            action_service=self._action_service,
        )
        return self._api

    # ── Discovery ─────────────────────────────────────────

    async def discover_all(self) -> dict[str, PluginState]:
        await self._deactivate_policy_blocked_plugins()
        self.registry.configure(
            allow_user_plugins=self._policy_bool("extensions.allowUserPlugins", True)
        )
        return await self.registry.discover()

    # ── Resolve (load code) ────────────────────────────────

    async def resolve(self, name: str) -> bool:
        state = self.registry.get(name)
        if not state or not state.installed:
            return False
        if state.loaded:
            return True

        manifest = state.manifest
        if not manifest.entry:
            state.loaded = True
            return True

        plugin_dir = state.directory or os.path.join(self.registry._install_dir, name)
        entry_path = os.path.join(plugin_dir, manifest.entry)

        if not os.path.exists(entry_path):
            state.error = f"Entry file not found: {manifest.entry}"
            return False

        try:
            spec = importlib.util.spec_from_file_location(
                f"plugin_{name}", entry_path
            )
            if not spec or not spec.loader:
                state.error = "Failed to create module spec"
                return False

            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            state.module = module
            state.loaded = True
            state.error = None
            return True
        except Exception as e:
            state.error = str(e)
            return False

    # ── Activate ───────────────────────────────────────────

    async def activate(self, name: str, persist: bool = True, notify: bool = True) -> bool:
        state = self.registry.get(name)
        if not state:
            return False

        if not self._can_activate(state):
            return False
        if state.modified and not state.manifest.proprietary:
            state.error = "Manifest changed since installation. Review and trust the plugin before activation."
            return False

        if not state.loaded:
            resolved = await self.resolve(name)
            if not resolved:
                return False

        if state.active:
            return True  # Already active

        perms = get_permission_registry()
        grant = perms.register(name, state.manifest.permissions)

        if state.manifest.permissions:
            approved = bool(grant.approved) or await self._load_permission_approval(
                name,
                state.manifest.permissions,
            )
            if approved:
                perms.approve(name)
            else:
                state.error = "Permissions pending approval"
                return False
        else:
            perms.approve(name)

        activate_hook = state.manifest.lifecycle.on_activate
        if state.module and hasattr(state.module, activate_hook):
            hook = getattr(state.module, activate_hook)
            try:
                api = PluginAPI(
                    plugin_name=name,
                    editor_vm=self._api.editor._vm if self._api else None,
                    file_vm=None,
                    project_vm=self._api.projects._vm if self._api else None,
                    terminal_vm=None,
                    event_bus=self._api.events._bus if self._api else None,
                    notification_vm=self._notification_vm,
                    action_service=self._action_service,
                )
                self._plugin_apis[name] = api
                result = self._call_lifecycle_hook(hook, api)
                if result is not None and hasattr(result, "__await__"):
                    await result
            except Exception as e:
                self._plugin_apis.pop(name, None)
                state.error = f"Activation failed: {e}"
                return False
        else:
            self._plugin_apis[name] = PluginAPI(
                plugin_name=name,
                editor_vm=self._api.editor._vm if self._api else None,
                file_vm=None,
                project_vm=self._api.projects._vm if self._api else None,
                terminal_vm=None,
                event_bus=self._api.events._bus if self._api else None,
                notification_vm=self._notification_vm,
                action_service=self._action_service,
            )

        self._active_modules[name] = state.module
        state.active = True
        if persist:
            await self.registry.set_enabled(name, True)
        state.error = None

        self._register_contributions(name, state.manifest)
        if notify:
            self._notify("success", "Plugin activated", state.manifest.display_name)
        return True

    # ── Deactivate ─────────────────────────────────────────

    async def deactivate(self, name: str, persist: bool = True, notify: bool = True) -> bool:
        state = self.registry.get(name)
        if not state or not state.active:
            return False

        self._unregister_contributions(name)

        deactivate_hook = state.manifest.lifecycle.on_deactivate
        if state.module and hasattr(state.module, deactivate_hook):
            hook = getattr(state.module, deactivate_hook)
            try:
                result = self._call_lifecycle_hook(hook, self._plugin_apis.get(name))
                if result is not None and hasattr(result, "__await__"):
                    await result
            except Exception as e:
                print(f"[PluginManager] Deactivation error for {name}: {e}")

        self._active_modules.pop(name, None)
        api = self._plugin_apis.pop(name, None)
        if api:
            api.cleanup()
        state.active = False
        if persist:
            await self.registry.set_enabled(name, False)
        if notify:
            self._notify("info", "Plugin deactivated", state.manifest.display_name)
        return True

    async def approve_permissions(self, name: str) -> bool:
        state = self.registry.get(name)
        if not state:
            return False
        perms = get_permission_registry()
        perms.approve(name, state.manifest.permissions)
        await self._save_permission_approval(name, state.manifest.permissions, True)
        return True

    async def revoke_permissions(self, name: str) -> bool:
        state = self.registry.get(name)
        if not state:
            return False
        if state.active:
                await self.deactivate(name, persist=True)
        perms = get_permission_registry()
        perms.revoke(name)
        await self._save_permission_approval(name, state.manifest.permissions, False)
        return True

    def get_permission_requests(self) -> list[dict]:
        requests = []
        perms = get_permission_registry()
        for state in self.registry.list_all():
            manifest = state.manifest
            grant = perms.get(manifest.name)
            if not grant:
                grant = perms.register(manifest.name, manifest.permissions)
            payload = grant.to_dict()
            payload.update({
                "name": manifest.name,
                "displayName": manifest.display_name,
                "active": state.active,
                "error": state.error or "",
                "requiresApproval": bool(manifest.permissions and not grant.approved),
            })
            requests.append(payload)
        return requests

    @staticmethod
    def _call_lifecycle_hook(hook, api):
        parameters = inspect.signature(hook).parameters
        if parameters:
            return hook(api)
        return hook()

    # ── Hot-reload ─────────────────────────────────────────

    async def reload(self, name: str) -> bool:
        state = self.registry.get(name)
        if not state:
            return False

        was_active = state.active
        if was_active:
            await self.deactivate(name, persist=False, notify=False)

        state.loaded = False
        state.module = None

        if state.manifest.entry:
            importlib.invalidate_caches()

        if was_active:
            return await self.activate(name, persist=False, notify=False)
        return True

    # ── Activate/Deactivate all ────────────────────────────

    async def activate_all(self) -> dict[str, bool]:
        results = {}
        if not self._policy_bool("extensions.autoActivate", True):
            for state in self.registry.list_enabled():
                results[state.manifest.name] = False
            return results
        for state in self.registry.list_enabled():
            results[state.manifest.name] = await self.activate(state.manifest.name, notify=False)
        return results

    async def deactivate_all(self) -> None:
        for name in list(self._active_modules.keys()):
            await self.deactivate(name, persist=False, notify=False)

    async def apply_policies(self) -> bool:
        self.registry.configure(
            allow_user_plugins=self._policy_bool("extensions.allowUserPlugins", True)
        )
        await self._deactivate_policy_blocked_plugins()

        runtime_enabled = self._policy_bool("extensions.enabled", True)
        if runtime_enabled and self._policy_bool("extensions.autoActivate", True):
            await self.activate_all()
        return True

    async def install(self, source: str) -> PluginState | None:
        validation = self.validate_source(source)
        if not validation.get("ok"):
            raise ValueError(validation.get("message") or "Invalid plugin source")
        if not self._policy_bool("extensions.enabled", True):
            raise PermissionError("Plugin runtime is disabled by settings.")
        if self._is_remote_source(source) and not self._policy_bool(
            "extensions.allowNetworkInstall",
            False,
        ):
            raise PermissionError("Network plugin installs are disabled by settings.")
        if not self._is_remote_source(source):
            source_path = os.path.abspath(os.path.expanduser(source))
            repo_root = os.path.abspath(self.registry._repo_plugin_dir)
            user_root = os.path.abspath(self.registry._install_dir)
            inside_repo = os.path.commonpath([repo_root, source_path]) == repo_root
            inside_user = os.path.commonpath([user_root, source_path]) == user_root
            if inside_user and not self._policy_bool("extensions.allowUserPlugins", True):
                raise PermissionError("User plugin installs are disabled by settings.")
            if not inside_repo and not inside_user and not self._policy_bool(
                "extensions.allowUserPlugins",
                True,
            ):
                raise PermissionError("External local plugin installs are disabled by settings.")
        return await self.registry.install(source)

    async def trust_current_manifest(self, name: str) -> bool:
        state = self.registry.get(name)
        if not state:
            return False
        if state.manifest.proprietary:
            state.trusted = True
            state.modified = False
            return True
        return await self.registry.trust_current_manifest(name)

    async def check_update(self, name: str) -> dict:
        return await self.registry.analyze_update(name)

    async def update_from_source(self, name: str) -> PluginState | None:
        state = self.registry.get(name)
        if not state:
            raise ValueError(f"Plugin '{name}' is not installed")
        analysis = await self.registry.analyze_update(name)
        if analysis.get("state") in {"missing", "source_missing", "invalid"}:
            raise ValueError(analysis.get("message") or "Cannot update plugin")
        was_active = state.active
        if was_active:
            await self.deactivate(name, persist=False, notify=False)
        updated = await self.registry.update_from_source(name)
        if updated and was_active:
            await self.activate(updated.manifest.name, persist=False, notify=False)
        return updated

    def get_store_sources(self) -> list[str]:
        sources = self._setting("extensions.marketplace.localSources", [])
        if not isinstance(sources, list):
            return []
        normalized: list[str] = []
        for source in sources:
            value = os.path.abspath(os.path.expanduser(str(source or "")))
            if value and value not in normalized:
                normalized.append(value)
        return normalized

    def get_store_api_url(self) -> str:
        return str(
            self._setting(
                "extensions.marketplace.apiUrl",
                "http://127.0.0.1:9865/api/marketplace",
            )
            or ""
        ).rstrip("/")

    def set_store_api_url(self, api_url: str) -> str:
        clean = str(api_url or "").strip().rstrip("/")
        self._save_global_setting("extensions.marketplace.apiUrl", clean)
        return clean

    def add_store_source(self, source: str) -> list[str]:
        source_path = os.path.abspath(os.path.expanduser(source or ""))
        if not source_path or not os.path.isdir(source_path):
            raise ValueError(f"Store source is not a directory: {source_path}")
        sources = self.get_store_sources()
        if source_path not in sources:
            sources.append(source_path)
            self._save_global_setting("extensions.marketplace.localSources", sources)
        return sources

    def remove_store_source(self, source: str) -> list[str]:
        source_path = os.path.abspath(os.path.expanduser(source or ""))
        sources = [item for item in self.get_store_sources() if item != source_path]
        self._save_global_setting("extensions.marketplace.localSources", sources)
        return sources

    def scan_store(self) -> list[dict]:
        return self.registry.discover_store(self.get_store_sources())

    async def scan_store_async(self) -> list[dict]:
        local_items = self.registry.discover_store(self.get_store_sources())
        remote_items = await self._fetch_marketplace_plugins()
        merged: dict[str, dict] = {}
        for item in local_items:
            merged[item["id"]] = item
        for item in remote_items:
            merged[item["id"]] = item
        return sorted(merged.values(), key=lambda item: item["name"].lower())

    async def install_store_plugin(self, source: str, expected_hash: str = "") -> PluginState | None:
        source = str(source or "").strip()
        if not source:
            raise ValueError("No plugin source provided")
        if self._is_remote_source(source):
            if not self._policy_bool("extensions.allowNetworkInstall", False):
                raise PermissionError("Network plugin installs are disabled by settings.")
            archive_path = await self._download_plugin_archive(source, expected_hash)
            try:
                return await self.install(archive_path)
            finally:
                try:
                    os.remove(archive_path)
                except OSError:
                    pass
        return await self.install(source)

    def validate_source(self, source: str) -> dict:
        source = (source or "").strip()
        if not source:
            return self._validation_error("No plugin source provided.")
        if self._is_remote_source(source):
            if not self._policy_bool("extensions.allowNetworkInstall", False):
                return self._validation_error("Network plugin installs are disabled by settings.")
            return self._validation_error("Network plugin installs are not implemented yet.")

        source_path = os.path.abspath(os.path.expanduser(source))
        try:
            prepared_dir, cleanup = self.registry._prepare_install_source(source_path)
        except Exception as exc:
            return self._validation_error(str(exc))

        try:
            manifest = PluginManifest.from_directory(prepared_dir)
        except Exception as exc:
            cleanup()
            return self._validation_error(f"Invalid manifest: {exc}")

        errors = self._validate_manifest_paths(prepared_dir, manifest)
        cleanup()
        if errors:
            return {
                "ok": False,
                "message": errors[0],
                "errors": errors,
                "source": source_path,
                "manifest": manifest.model_dump(),
            }

        return {
            "ok": True,
            "message": f"{manifest.display_name} is valid.",
            "errors": [],
            "source": source_path,
            "manifest": manifest.model_dump(),
        }

    async def _fetch_marketplace_plugins(self) -> list[dict]:
        if not self._policy_bool("extensions.marketplace.enabled", True):
            return []
        api_url = self.get_store_api_url()
        if not api_url:
            return []
        try:
            import httpx

            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(f"{api_url}/plugins")
                response.raise_for_status()
                payload = response.json()
        except Exception as exc:
            self._notify("warning", "Marketplace unavailable", str(exc))
            return []

        raw_items = payload.get("results", payload if isinstance(payload, list) else [])
        if not isinstance(raw_items, list):
            return []
        items = []
        for raw in raw_items:
            if isinstance(raw, dict):
                item = self._normalize_marketplace_item(raw, api_url)
                if item:
                    items.append(item)
        return items

    def _normalize_marketplace_item(self, raw: dict, api_url: str) -> dict:
        try:
            contract = PluginStoreItem.from_api(raw)
        except Exception as exc:
            print(f"[PluginManager] Invalid marketplace item: {exc}")
            return {}
        manifest = contract.manifest
        plugin_id = contract.id
        if not plugin_id:
            return {}
        installed = self.registry.get(plugin_id)
        download_url = contract.asset.download_url
        if download_url and not self._is_remote_source(download_url):
            download_url = urljoin(api_url + "/", download_url.lstrip("/"))
        version = str(contract.version)
        manifest_hash = str(contract.manifest_hash)
        archive_hash = str(contract.asset.archive_hash)
        signature = str(contract.asset.signature)
        return {
            "id": plugin_id,
            "name": contract.display_name or plugin_id,
            "description": str(contract.description or ""),
            "version": version,
            "author": str(contract.author or "unknown"),
            "source": download_url,
            "sourceKind": "remote",
            "icon": str(raw.get("icon") or manifest.get("icon") or ""),
            "permissions": list(contract.permissions or []),
            "contributions": self._remote_contribution_summary(contract.contributions, manifest),
            "proprietary": bool(raw.get("proprietary") or manifest.get("proprietary") or False),
            "manifestHash": manifest_hash,
            "archiveHash": archive_hash,
            "archiveHashAlgorithm": contract.asset.archive_hash_algorithm,
            "signature": signature,
            "signatureAlgorithm": contract.asset.signature_algorithm,
            "signatureStatus": "signed" if signature else "unsigned",
            "publisher": contract.publisher.model_dump(),
            "publisherName": contract.publisher.name,
            "publisherVerified": bool(contract.publisher.verified or contract.verified),
            "license": contract.license,
            "pricing": contract.pricing,
            "screenshots": list(contract.screenshots),
            "tags": list(contract.tags),
            "installed": installed is not None,
            "active": bool(installed.active) if installed else False,
            "installedVersion": installed.manifest.version if installed else "",
            "installedHash": installed.manifest_hash if installed else "",
            "updateAvailable": bool(
                installed
                and (
                    installed.manifest.version != version
                    or (manifest_hash and installed.manifest_hash != manifest_hash)
                )
            ),
            "remote": True,
        }

    @staticmethod
    def _remote_contribution_summary(summary: dict, manifest: dict) -> dict:
        if isinstance(summary, dict):
            normalized = {}
            for key, value in summary.items():
                if isinstance(value, list):
                    normalized[str(key)] = len(value)
                elif isinstance(value, dict):
                    normalized[str(key)] = int(value.get("count", 0) or 0)
                else:
                    normalized[str(key)] = int(value or 0)
            return normalized
        contributes = manifest.get("contributes") if isinstance(manifest.get("contributes"), dict) else {}
        keys = [
            "commands",
            "views",
            "disabledViews",
            "panels",
            "keybindings",
            "themes",
            "icons",
            "fileIcons",
            "fileIconOverrides",
            "fonts",
            "editorDecorations",
            "aiProviders",
            "lspProviders",
            "searchProviders",
            "sourceControlProviders",
            "fileFormatters",
            "fileActions",
            "fileDecorations",
        ]
        return {key: len(contributes.get(key) or []) for key in keys}

    async def _download_plugin_archive(self, url: str, expected_hash: str = "") -> str:
        import httpx

        suffix = ".zip"
        fd, path = tempfile.mkstemp(prefix="ember-plugin-download-", suffix=suffix)
        os.close(fd)
        try:
            async with httpx.AsyncClient(timeout=60.0, follow_redirects=True) as client:
                async with client.stream("GET", url) as response:
                    response.raise_for_status()
                    with open(path, "wb") as file:
                        async for chunk in response.aiter_bytes():
                            if chunk:
                                file.write(chunk)
            self._verify_archive_hash(path, expected_hash)
            return path
        except Exception:
            try:
                os.remove(path)
            except OSError:
                pass
            raise

    @staticmethod
    def _verify_archive_hash(path: str, expected_hash: str = "") -> None:
        expected = str(expected_hash or "").strip().lower()
        if not expected:
            return
        digest = hashlib.sha256()
        with open(path, "rb") as file:
            for chunk in iter(lambda: file.read(1024 * 1024), b""):
                digest.update(chunk)
        actual = digest.hexdigest()
        if actual != expected:
            raise ValueError(f"Plugin archive hash mismatch: expected {expected}, got {actual}")

    # ── Queries ────────────────────────────────────────────

    def is_active(self, name: str) -> bool:
        return name in self._active_modules

    def get_active_names(self) -> list[str]:
        return list(self._active_modules.keys())

    def _config(self) -> dict:
        if not self._settings_service:
            return {}
        try:
            return self._settings_service.load()
        except Exception:
            return {}

    def _notify(self, level: str, title: str, message: str = "") -> None:
        if not self._notification_vm:
            return
        method = getattr(self._notification_vm, level, None)
        if callable(method):
            method(title, message)

    def _setting(self, key: str, default=None):
        if not self._settings_service:
            return default
        try:
            return self._settings_service.get(self._config(), key, default)
        except Exception:
            return default

    def _save_global_setting(self, key: str, value) -> None:
        if not self._settings_service:
            return
        self._settings_service.save_global(self._settings_service.patch_for(key, value))

    def _policy_bool(self, key: str, default: bool) -> bool:
        if not self._settings_service:
            return default
        try:
            return bool(self._setting(key, default))
        except Exception:
            return default

    def _can_activate(self, state: PluginState) -> bool:
        if self._policy_bool("extensions.enabled", True):
            return True
        if state.manifest.proprietary:
            return True
        state.error = "Plugin runtime disabled by settings"
        return False

    async def _deactivate_policy_blocked_plugins(self) -> None:
        runtime_enabled = self._policy_bool("extensions.enabled", True)
        allow_user_plugins = self._policy_bool("extensions.allowUserPlugins", True)
        for state in list(self.registry.list_active()):
            is_user_plugin = self._is_user_plugin(state)
            if (not runtime_enabled and not state.manifest.proprietary) or (
                is_user_plugin and not allow_user_plugins
            ):
                await self.deactivate(state.manifest.name, persist=False)

    def _is_user_plugin(self, state: PluginState) -> bool:
        try:
            plugin_dir = os.path.abspath(state.directory or "")
            user_root = os.path.abspath(self.registry._install_dir)
            return os.path.commonpath([user_root, plugin_dir]) == user_root
        except Exception:
            return False

    @staticmethod
    def _is_remote_source(source: str) -> bool:
        value = (source or "").strip().lower()
        return value.startswith(("http://", "https://", "git://", "ssh://"))

    @staticmethod
    def _validation_error(message: str) -> dict:
        return {"ok": False, "message": message, "errors": [message], "source": "", "manifest": {}}

    def _validate_manifest_paths(self, plugin_dir: str, manifest: PluginManifest) -> list[str]:
        errors: list[str] = []
        for label, value in (
            ("entry", manifest.entry),
            ("qml", manifest.qml),
            ("icon", manifest.icon),
        ):
            self._validate_relative_asset(plugin_dir, label, value, errors)

        for icon in manifest.contributes.icons:
            self._validate_relative_asset(plugin_dir, f"icon:{icon.id}", icon.path, errors)
        for theme in manifest.contributes.themes:
            self._validate_relative_asset(plugin_dir, f"theme:{theme.id}", theme.path, errors)
        for font in manifest.contributes.fonts:
            if font.path:
                self._validate_relative_asset(plugin_dir, f"font:{font.id}", font.path, errors)
        for view in manifest.contributes.views:
            self._validate_relative_asset(plugin_dir, f"view:{view.id}", view.component, errors)
            self._validate_relative_asset(plugin_dir, f"view-icon:{view.id}", view.icon, errors)
        for command in manifest.contributes.commands:
            self._validate_relative_asset(plugin_dir, f"command-icon:{command.id}", command.icon, errors)
        return errors

    @staticmethod
    def _validate_relative_asset(
        plugin_dir: str,
        label: str,
        value: str | None,
        errors: list[str],
    ) -> None:
        if not value or value.startswith(("/", "file:", "qrc:", "http://", "https://")):
            return
        path = os.path.abspath(os.path.join(plugin_dir, value))
        root = os.path.abspath(plugin_dir)
        try:
            inside_plugin = os.path.commonpath([root, path]) == root
        except ValueError:
            inside_plugin = False
        if not inside_plugin:
            errors.append(f"{label} points outside plugin directory: {value}")
            return
        if not os.path.exists(path):
            errors.append(f"{label} file not found: {value}")

    # ── Contribution registration ─────────────────────────

    def _register_contributions(self, name: str, manifest) -> None:
        c = manifest.contributes
        state = self.registry.get(name)
        plugin_dir = state.directory if state else ""

        for cmd in c.commands:
            self._contributed_commands[cmd.id] = {
                "plugin": name,
                "id": cmd.id,
                "title": cmd.title,
                "keybinding": cmd.keybinding,
                "icon": self._resolve_plugin_icon(plugin_dir, cmd.icon),
            }
            if self._command_vm:
                self._command_vm.register(
                    Command(
                        id=cmd.id,
                        title=cmd.title,
                        category=f"Plugin: {manifest.display_name}",
                        keybinding=cmd.keybinding,
                        action=self._make_command_action(name, cmd.id),
                    )
                )

        for menu in c.menus:
            self._contributed_menus.setdefault(menu.menu, []).append({
                "plugin": name,
                "command": menu.command,
                "group": menu.group or "999_misc",
                "when": menu.when,
            })

        self._disabled_views[name] = set(c.disabledViews or [])

        for view in c.views:
            self._contributed_views.setdefault(view.location, []).append({
                "plugin": name,
                "id": view.id,
                "contributionId": view.id,
                "replaces": view.replaces,
                "component": self._resolve_plugin_path(plugin_dir, view.component),
                "title": view.title or manifest.display_name,
                "label": view.label or (view.title or manifest.display_name).upper(),
                "icon": self._resolve_plugin_icon(plugin_dir, view.icon),
                "location": view.location,
                "source": plugin_dir,
                "order": view.order,
            })

        for panel in c.panels:
            required_permissions = panel.permissions or []
            if required_permissions and not set(required_permissions).issubset(set(manifest.permissions)):
                continue
            self._contributed_panels.setdefault(panel.location, []).append({
                "plugin": name,
                "id": panel.id,
                "label": panel.label or panel.title.upper(),
                "title": panel.title,
                "icon": self._resolve_plugin_icon(plugin_dir, panel.icon),
                "component": self._resolve_plugin_path(plugin_dir, panel.component),
                "location": panel.location,
                "source": "plugin",
                "order": panel.order,
                "permissions": required_permissions,
            })

        for kb in c.keybindings:
            self._contributed_keybindings.setdefault(name, []).append({
                "plugin": name,
                "key": kb.key,
                "command": kb.command,
                "when": kb.when,
            })

        for action in c.actions:
            required_permissions = action.permissions or []
            if required_permissions and not set(required_permissions).issubset(set(manifest.permissions)):
                continue
            exposable = self._is_agent_exposable_permissions(required_permissions) and not bool(action.requiresPayload)
            action_id = action.id
            self._contributed_actions[action_id] = {
                "plugin": name,
                "id": action_id,
                "title": action.title,
                "command": action.command,
                "category": action.category or f"Plugin: {manifest.display_name}",
                "description": action.description,
                "icon": self._resolve_plugin_icon(plugin_dir, action.icon),
                "keybinding": action.keybinding,
                "requiresPayload": bool(action.requiresPayload),
                "permissions": required_permissions,
                "requiresPermission": bool(required_permissions),
                "safeToRun": True,
                "exposable": exposable,
            }
            if action.keybinding:
                self._contributed_keybindings.setdefault(name, []).append({
                    "plugin": name,
                    "key": action.keybinding,
                    "command": action_id,
                    "when": "global",
                    "target": "action",
                })
            if self._action_service:
                self._action_service.register(ActionDefinition(
                    id=action_id,
                    title=action.title,
                    category=action.category or f"Plugin: {manifest.display_name}",
                    description=action.description,
                    source=name,
                    busy_label=f"Running {action.title}…",
                    notify=True,
                    requires_payload=bool(action.requiresPayload),
                    permissions=tuple(required_permissions),
                    safe_to_run=True,
                    exposable=exposable,
                    handler=self._make_action_handler(name, action.command),
                ))

        for action in c.fileActions:
            required_permissions = action.permissions or []
            if required_permissions and not set(required_permissions).issubset(set(manifest.permissions)):
                continue
            self._contributed_file_actions[action.id] = {
                "plugin": name,
                "id": action.id,
                "title": action.title,
                "command": action.command,
                "icon": self._resolve_plugin_icon(plugin_dir, action.icon),
                "group": action.group or "999_plugin",
                "when": action.when or "",
                "appliesTo": action.appliesTo or ["file", "folder"],
                "permissions": required_permissions,
            }

        for formatter in c.fileFormatters:
            required_permissions = formatter.permissions or []
            if required_permissions and not set(required_permissions).issubset(set(manifest.permissions)):
                continue
            self._contributed_file_formatters[formatter.id] = {
                "plugin": name,
                "id": formatter.id,
                "name": formatter.id,
                "label": formatter.label,
                "displayName": formatter.label,
                "description": formatter.description,
                "languages": [item.lower() for item in formatter.languages],
                "extensions": [self._normalize_extension(item) for item in formatter.extensions],
                "command": formatter.command,
                "args": list(formatter.args),
                "env": dict(formatter.env),
                "priority": int(formatter.priority),
                "permissions": required_permissions,
                "configSchema": dict(formatter.configSchema),
                "defaults": dict(formatter.defaults),
                "install": dict(formatter.install),
                "active": True,
            }

        for decoration in c.fileDecorations:
            required_permissions = decoration.permissions or []
            if required_permissions and not set(required_permissions).issubset(set(manifest.permissions)):
                continue
            self._contributed_file_decorations[decoration.id] = {
                "plugin": name,
                "id": decoration.id,
                "title": decoration.title,
                "icon": self._resolve_plugin_icon(plugin_dir, decoration.icon),
                "badge": decoration.badge or "",
                "color": decoration.color or "",
                "tooltip": decoration.tooltip or decoration.title,
                "group": decoration.group or "999_plugin",
                "when": decoration.when or "",
                "appliesTo": decoration.appliesTo or ["file", "folder"],
                "permissions": required_permissions,
            }

        for action in c.searchResultActions:
            required_permissions = action.permissions or []
            if required_permissions and not set(required_permissions).issubset(set(manifest.permissions)):
                continue
            self._contributed_search_result_actions[action.id] = {
                "plugin": name,
                "id": action.id,
                "title": action.title,
                "command": action.command,
                "icon": self._resolve_plugin_icon(plugin_dir, action.icon),
                "group": action.group or "999_plugin",
                "when": action.when or "",
                "providers": action.providers or ["*"],
                "languages": action.languages or ["*"],
                "permissions": required_permissions,
            }

        for icon in c.icons:
            path = self._resolve_plugin_path(plugin_dir, icon.path)
            if path:
                self._contributed_icons[icon.id] = path

        for file_icon in c.fileIcons:
            if file_icon.pattern and file_icon.icon:
                self._contributed_file_icons[file_icon.pattern] = file_icon.icon

        for override in c.fileIconOverrides:
            self._contributed_file_icon_overrides[override.id] = {
                "plugin": name,
                "id": override.id,
                "pattern": override.pattern,
                "icon": override.icon,
                "appliesTo": override.appliesTo or ["file", "folder"],
                "priority": int(override.priority),
                "when": override.when or "",
            }

        for decoration in c.editorDecorations:
            self._contributed_editor_decorations[decoration.id] = {
                "plugin": name,
                "id": decoration.id,
                "type": decoration.type,
                "source": decoration.source,
                "label": decoration.label or decoration.id,
            }

    @staticmethod
    def _resolve_plugin_path(plugin_dir: str, value: str | None) -> str:
        if not value:
            return ""
        if value.startswith(("/", "file:", "qrc:", "http://", "https://")):
            return value
        return os.path.join(plugin_dir, value) if plugin_dir else value

    @staticmethod
    def _resolve_plugin_icon(plugin_dir: str, value: str | None) -> str:
        if not value:
            return ""
        if value.startswith(("/", "file:", "qrc:", "http://", "https://")):
            return value
        if "/" not in value and "." not in value:
            return value
        return os.path.join(plugin_dir, value) if plugin_dir else value

    def _unregister_contributions(self, name: str) -> None:
        if self._command_vm:
            for command_id, command in list(self._contributed_commands.items()):
                if command["plugin"] == name:
                    self._command_vm.unregister(command_id)
        self._contributed_commands = {
            k: v for k, v in self._contributed_commands.items()
            if v["plugin"] != name
        }
        if self._action_service:
            for action_id, action in list(self._contributed_actions.items()):
                if action["plugin"] == name:
                    self._action_service.unregister(action_id)
        self._contributed_actions = {
            k: v for k, v in self._contributed_actions.items()
            if v["plugin"] != name
        }
        for menu_id in list(self._contributed_menus.keys()):
            self._contributed_menus[menu_id] = [
                item for item in self._contributed_menus[menu_id]
                if item["plugin"] != name
            ]
            if not self._contributed_menus[menu_id]:
                del self._contributed_menus[menu_id]
        for loc in list(self._contributed_views.keys()):
            self._contributed_views[loc] = [
                v for v in self._contributed_views[loc]
                if v["plugin"] != name
            ]
            if not self._contributed_views[loc]:
                del self._contributed_views[loc]
        self._disabled_views.pop(name, None)
        for loc in list(self._contributed_panels.keys()):
            self._contributed_panels[loc] = [
                panel for panel in self._contributed_panels[loc]
                if panel["plugin"] != name
            ]
            if not self._contributed_panels[loc]:
                del self._contributed_panels[loc]
        self._contributed_keybindings.pop(name, None)
        self._contributed_editor_decorations = {
            k: v for k, v in self._contributed_editor_decorations.items()
            if v["plugin"] != name
        }
        self._contributed_file_actions = {
            k: v for k, v in self._contributed_file_actions.items()
            if v["plugin"] != name
        }
        self._contributed_file_decorations = {
            k: v for k, v in self._contributed_file_decorations.items()
            if v["plugin"] != name
        }
        self._contributed_file_formatters = {
            k: v for k, v in self._contributed_file_formatters.items()
            if v["plugin"] != name
        }
        self._contributed_file_icon_overrides = {
            k: v for k, v in self._contributed_file_icon_overrides.items()
            if v["plugin"] != name
        }
        self._contributed_search_result_actions = {
            k: v for k, v in self._contributed_search_result_actions.items()
            if v["plugin"] != name
        }
        self._contributed_icons = {}
        self._contributed_file_icons = {}
        for active_name in self.get_active_names():
            if active_name != name:
                state = self.registry.get(active_name)
                if state:
                    self._register_icon_contributions(active_name, state.manifest)

    def _make_command_action(self, plugin_name: str, command_id: str):
        async def _run():
            api = self._plugin_apis.get(plugin_name)
            if not api:
                raise RuntimeError(f"Plugin '{plugin_name}' is not active")
            await api.commands.execute(command_id)

        return _run

    def _make_action_handler(self, plugin_name: str, command_id: str):
        async def _run(payload: dict | None = None):
            api = self._plugin_apis.get(plugin_name)
            if not api:
                raise RuntimeError(f"Plugin '{plugin_name}' is not active")
            return await api.commands.execute(command_id, payload or {})

        return _run

    @staticmethod
    def _is_agent_exposable_permissions(permissions: list[str] | tuple[str, ...]) -> bool:
        sensitive = {
            "editor:write",
            "file:write",
            "terminal:exec",
            "settings:write",
            "network:access",
        }
        return not bool(set(permissions or ()) & sensitive)

    @staticmethod
    def _permission_setting_key(name: str) -> str:
        return f"{PERMISSION_SETTING_PREFIX}{name}"

    async def _load_permission_approval(self, name: str, scopes: list[str]) -> bool:
        from app.data.models import UserSettings

        try:
            setting = await UserSettings.objects.get(key=self._permission_setting_key(name))
            value = setting.value or {}
            return bool(value.get("approved") and sorted(value.get("scopes", [])) == sorted(scopes))
        except Exception:
            return False

    async def _save_permission_approval(self, name: str, scopes: list[str], approved: bool) -> None:
        from app.data.models import UserSettings

        payload = {"plugin": name, "scopes": list(scopes), "approved": approved}
        key = self._permission_setting_key(name)
        try:
            try:
                setting = await UserSettings.objects.get(key=key)
                setting.value = payload
                await setting.save()
            except Exception:
                await UserSettings.objects.create(key=key, value=payload)
        except Exception as exc:
            print(f"[PluginManager] Could not persist permission approval for {name}: {exc}")

    # ── Public queries for the command palette / UI ────────

    def get_commands(self) -> list[dict]:
        return list(self._contributed_commands.values())

    def get_actions(self) -> list[dict]:
        return list(self._contributed_actions.values())

    def get_menus(self, menu_id: str = "editor/context") -> list[dict]:
        items = self._contributed_menus.get(menu_id, [])
        return sorted(items, key=lambda x: x["group"])

    def get_views(self, location: str = "sidebar") -> list[dict]:
        return sorted(
            self._contributed_views.get(location, []),
            key=lambda item: (int(item.get("order", 999)), str(item.get("id", ""))),
        )

    def get_disabled_views(self) -> set[str]:
        disabled: set[str] = set()
        for view_ids in self._disabled_views.values():
            disabled.update(view_ids)
        return disabled

    def get_panels(self, location: str = "bottom") -> list[dict]:
        return sorted(
            self._contributed_panels.get(location, []),
            key=lambda item: (int(item.get("order", 999)), str(item.get("id", ""))),
        )

    def get_file_actions(self, context: dict | None = None) -> list[dict]:
        context = context or {}
        actions = []
        for action in self._contributed_file_actions.values():
            if not self._matches_file_context(action, context):
                continue
            actions.append(dict(action))
        return sorted(actions, key=lambda item: (item.get("group", ""), item.get("title", "")))

    def get_file_decorations(self, context: dict | None = None) -> list[dict]:
        context = context or {}
        decorations = [
            dict(decoration)
            for decoration in self._contributed_file_decorations.values()
            if self._matches_file_context(decoration, context)
        ]
        return sorted(decorations, key=lambda item: (item.get("group", ""), item.get("title", "")))

    def get_file_icon_override(self, context: dict | None = None) -> str:
        context = context or {}
        matches = [
            dict(override)
            for override in self._contributed_file_icon_overrides.values()
            if self._matches_file_context(override, context)
            and self._matches_file_pattern(override.get("pattern", ""), context)
        ]
        if not matches:
            return ""
        matches.sort(key=lambda item: (-int(item.get("priority", 500)), str(item.get("id", ""))))
        return str(matches[0].get("icon") or "")

    def get_file_formatter_options(self, language: str = "", extension: str = "") -> list[dict]:
        language_key = language.strip().lower()
        extension_key = self._normalize_extension(extension)
        fallback_options = [
            {
                "id": "core.ruff-format",
                "name": "core.ruff-format",
                "label": "ruff format",
                "displayName": "ruff format",
                "description": "Core Python formatter using ruff format.",
                "plugin": "core",
                "languages": ["python"],
                "extensions": [".py", ".pyi"],
                "command": "ruff",
                "args": ["format", "{file}"],
                "env": {},
                "priority": 100,
                "permissions": ["file:write"],
                "configSchema": {},
                "defaults": {},
                "install": {},
                "active": True,
            },
            {
                "id": "core.rustfmt",
                "name": "core.rustfmt",
                "label": "rustfmt",
                "displayName": "rustfmt",
                "description": "Core Rust formatter using rustfmt.",
                "plugin": "core",
                "languages": ["rust"],
                "extensions": [".rs"],
                "command": "rustfmt",
                "args": ["{file}"],
                "env": {},
                "priority": 100,
                "permissions": ["file:write"],
                "configSchema": {},
                "defaults": {},
                "install": {},
                "active": True,
            },
        ]
        options = self._dedupe_provider_options([
            *self._contributed_file_formatters.values(),
            *fallback_options,
        ])
        filtered = []
        for option in options:
            languages = [str(item).lower() for item in option.get("languages", [])]
            extensions = [self._normalize_extension(item) for item in option.get("extensions", [])]
            if language_key and language_key not in languages:
                continue
            if extension_key and extension_key not in extensions:
                continue
            filtered.append(dict(option))
        return sorted(filtered, key=lambda item: (-int(item.get("priority", 500)), str(item.get("id", ""))))

    async def execute_file_action(self, action_id: str, context: dict) -> dict:
        action = self._contributed_file_actions.get(action_id)
        if not action:
            return {"ok": False, "message": f"Unknown file action: {action_id}"}
        plugin_name = action.get("plugin", "")
        api = self._plugin_apis.get(plugin_name)
        if not api:
            return {"ok": False, "message": f"Plugin is not active: {plugin_name}"}
        command_id = action.get("command", "")
        try:
            await api.events.emit("fileBrowser:action:before", action=action, context=context)
            result = await api.commands.execute(command_id, dict(context), dict(action))
            await api.events.emit("fileBrowser:action:after", action=action, context=context, result=result)
            if isinstance(result, dict):
                payload = dict(result)
                payload.setdefault("ok", True)
                return payload
            return {"ok": True, "message": str(result or "Action completed")}
        except Exception as exc:
            await api.events.emit("fileBrowser:action:error", action=action, context=context, error=str(exc))
            return {"ok": False, "message": str(exc)}

    def get_search_result_actions(self, context: dict | None = None) -> list[dict]:
        context = context or {}
        provider = str(context.get("provider") or "")
        language = str(context.get("language") or "")
        actions = []
        for action in self._contributed_search_result_actions.values():
            providers = action.get("providers") or ["*"]
            languages = action.get("languages") or ["*"]
            if "*" not in providers and provider not in providers:
                continue
            if "*" not in languages and language not in languages:
                continue
            actions.append(dict(action))
        return sorted(actions, key=lambda item: (item.get("group", ""), item.get("title", "")))

    async def execute_search_result_action(self, action_id: str, context: dict) -> dict:
        action = self._contributed_search_result_actions.get(action_id)
        if not action:
            return {"ok": False, "message": f"Unknown search result action: {action_id}"}
        plugin_name = action.get("plugin", "")
        api = self._plugin_apis.get(plugin_name)
        if not api:
            return {"ok": False, "message": f"Plugin is not active: {plugin_name}"}
        command_id = action.get("command", "")
        try:
            await api.events.emit("search:result:action:before", action=action, context=context)
            result = await api.commands.execute(command_id, dict(context), dict(action))
            await api.events.emit("search:result:action:after", action=action, context=context, result=result)
            if isinstance(result, dict):
                payload = dict(result)
                payload.setdefault("ok", True)
                return payload
            return {"ok": True, "message": str(result or "Action completed")}
        except Exception as exc:
            await api.events.emit("search:result:action:error", action=action, context=context, error=str(exc))
            return {"ok": False, "message": str(exc)}

    def get_keybindings(self) -> list[dict]:
        all_kb = []
        for kb_list in self._contributed_keybindings.values():
            all_kb.extend(kb_list)
        return all_kb

    def get_keybinding_map(self) -> dict[str, str]:
        bindings: dict[str, str] = {}
        for item in self.get_keybindings():
            key = item.get("key")
            command = item.get("command")
            if key and command:
                bindings[key] = command
        return bindings

    def resolve_keybinding(self, sequence: str, fallback_command: str = "") -> str:
        return self._keybindings.resolve(
            sequence,
            fallback_command,
            plugin_bindings=self.get_keybindings(),
            core_bindings=self._command_vm.get_keybinding_map() if self._command_vm else {},
        )

    def get_resolved_keybindings(self) -> list[dict]:
        return self._keybindings.resolved(
            self.get_keybindings(),
            self._command_vm.get_keybinding_map() if self._command_vm else {},
        )

    def get_editor_decorations(self) -> list[dict]:
        return list(self._contributed_editor_decorations.values())

    def has_editor_decoration(self, decoration_id: str) -> bool:
        return decoration_id in self._contributed_editor_decorations

    def get_icons(self) -> dict[str, str]:
        return dict(self._contributed_icons)

    def get_file_icons(self) -> dict[str, str]:
        return dict(self._contributed_file_icons)

    def get_icons_for(self, plugin_name: str) -> dict[str, str]:
        state = self.registry.get(plugin_name)
        if not state:
            return {}
        plugin_dir = state.directory or ""
        icons: dict[str, str] = {}
        for icon in state.manifest.contributes.icons:
            path = self._resolve_plugin_path(plugin_dir, icon.path)
            if path:
                icons[icon.id] = path
        return icons

    def get_file_icons_for(self, plugin_name: str) -> dict[str, str]:
        state = self.registry.get(plugin_name)
        if not state:
            return {}
        return {
            file_icon.pattern: file_icon.icon
            for file_icon in state.manifest.contributes.fileIcons
            if file_icon.pattern and file_icon.icon
        }

    def get_file_icon_overrides_for(self, plugin_name: str) -> list[dict]:
        state = self.registry.get(plugin_name)
        if not state:
            return []
        return [
            {
                "id": item.id,
                "pattern": item.pattern,
                "icon": item.icon,
                "appliesTo": item.appliesTo,
                "priority": item.priority,
                "when": item.when or "",
            }
            for item in state.manifest.contributes.fileIconOverrides
        ]

    def get_fonts_for(self, plugin_name: str) -> list[dict]:
        if plugin_name == "core":
            return [
                {"id": "menlo", "label": "Menlo", "family": "Menlo", "fallbacks": ["Monaco", "Courier New"]},
                {"id": "monaco", "label": "Monaco", "family": "Monaco", "fallbacks": ["Menlo", "Courier New"]},
            ]
        state = self.registry.get(plugin_name)
        if not state:
            return []
        plugin_dir = state.directory or ""
        return [
            {
                "id": font.id,
                "label": font.label,
                "family": font.family,
                "fallbacks": list(font.fallbacks),
                "target": font.target,
                "path": self._resolve_plugin_path(plugin_dir, font.path),
                "downloadUrl": font.downloadUrl or "",
                "license": font.license or "",
            }
            for font in state.manifest.contributes.fonts
        ]

    def load_fonts_for(self, plugin_name: str) -> list[str]:
        loaded: list[str] = []
        fonts = self.get_fonts_for(plugin_name)
        if not fonts:
            return loaded
        try:
            from PySide6.QtGui import QFontDatabase
        except Exception as exc:
            print(f"[PluginManager] Font database unavailable: {exc}")
            return loaded
        for font in fonts:
            path = font.get("path") or ""
            if not path or not os.path.exists(path):
                continue
            font_id = QFontDatabase.addApplicationFont(path)
            if font_id < 0:
                print(f"[PluginManager] Could not load font asset: {path}")
                continue
            families = QFontDatabase.applicationFontFamilies(font_id)
            loaded.extend(families or [font.get("family", "")])
        return [family for family in loaded if family]

    def get_appearance_provider_options(self, aspect: str) -> list[dict]:
        options: list[dict] = []
        if not aspect or aspect == "fonts":
            options.append({
                "name": "core",
                "displayName": "Core",
                "active": True,
                "capabilities": ["fonts"],
            })

        for state in self.registry.list_all():
            manifest = state.manifest
            capabilities = self._appearance_capabilities(manifest)
            if aspect and aspect not in capabilities:
                continue
            if not state.active:
                continue
            options.append({
                "name": manifest.name,
                "displayName": manifest.display_name,
                "active": state.active,
                "capabilities": capabilities,
            })

        fallback_name = "ember-default-theme"
        if aspect != "fonts" and not any(option["name"] == fallback_name for option in options):
            state = self.registry.get(fallback_name)
            if state and state.active:
                options.append({
                    "name": fallback_name,
                    "displayName": state.manifest.display_name,
                    "active": state.active,
                    "capabilities": self._appearance_capabilities(state.manifest),
                })
        return options

    def get_ai_provider_options(self) -> list[dict]:
        options: list[dict] = [
            {
                "id": "ollama",
                "name": "ollama",
                "label": "Ollama",
                "displayName": "Ollama",
                "description": "Local OpenAI-compatible provider.",
                "plugin": "core",
                "providerType": "openai-compatible",
                "endpoint": "http://localhost:11434",
                "defaultModel": "codellama:7b",
                "models": ["codellama:7b", "qwen2.5-coder", "llama3.1"],
                "requiresApiKey": False,
                "configSchema": {},
                "defaults": {},
            },
            {
                "id": "openai",
                "name": "openai",
                "label": "OpenAI",
                "displayName": "OpenAI",
                "description": "OpenAI API provider.",
                "plugin": "core",
                "providerType": "openai",
                "endpoint": "https://api.openai.com/v1",
                "defaultModel": "gpt-4.1-mini",
                "models": ["gpt-4.1-mini", "gpt-4.1", "o4-mini"],
                "requiresApiKey": True,
                "configSchema": {},
                "defaults": {},
            },
            {
                "id": "custom",
                "name": "custom",
                "label": "Custom",
                "displayName": "Custom",
                "description": "Custom OpenAI-compatible endpoint.",
                "plugin": "core",
                "providerType": "openai-compatible",
                "endpoint": "",
                "defaultModel": "",
                "models": [],
                "requiresApiKey": False,
                "configSchema": {},
                "defaults": {},
            },
        ]
        seen = {option["id"] for option in options}
        for state in self.registry.list_all():
            if not state.active:
                continue
            manifest = state.manifest
            for provider in manifest.contributes.aiProviders:
                provider_id = provider.id.strip()
                if not provider_id or provider_id in seen:
                    continue
                options.append({
                    "id": provider_id,
                    "name": provider_id,
                    "label": provider.label,
                    "displayName": provider.label,
                    "description": provider.description,
                    "plugin": manifest.name,
                    "providerType": provider.providerType,
                    "endpoint": provider.endpoint,
                    "defaultModel": provider.defaultModel,
                    "models": list(provider.models),
                    "requiresApiKey": bool(provider.requiresApiKey),
                    "configSchema": dict(provider.configSchema),
                    "defaults": dict(provider.defaults),
                })
                seen.add(provider_id)
        return options

    def get_lsp_provider_options(self, language: str = "") -> list[dict]:
        language_key = language.strip().lower()
        fallback_options: list[dict] = [
            {
                "id": "python.ty",
                "name": "python.ty",
                "label": "ty",
                "displayName": "ty",
                "language": "python",
                "description": "Fast Python type checker and language server.",
                "plugin": "core",
                "command": "ty",
                "args": ["server"],
                "env": {},
                "fileExtensions": [".py", ".pyi"],
                "rootPatterns": ["pyproject.toml", ".git"],
                "capabilities": ["hover", "completion", "diagnostics", "symbols"],
                "configSchema": {},
                "defaults": {},
                "install": {},
                "active": True,
            },
            {
                "id": "python.ruff",
                "name": "python.ruff",
                "label": "ruff",
                "displayName": "ruff",
                "language": "python",
                "description": "Python linting, diagnostics and code actions.",
                "plugin": "core",
                "command": "ruff",
                "args": ["server"],
                "env": {},
                "fileExtensions": [".py", ".pyi"],
                "rootPatterns": ["pyproject.toml", ".git"],
                "capabilities": ["diagnostics", "codeActions", "formatting"],
                "configSchema": {},
                "defaults": {},
                "install": {},
                "active": True,
            },
        ]
        plugin_options: list[dict] = []

        for state in self.registry.list_all():
            if not state.active:
                continue
            manifest = state.manifest
            for provider in manifest.contributes.lspProviders:
                provider_language = provider.language.strip().lower()
                if language_key and provider_language != language_key:
                    continue
                plugin_options.append({
                    "id": provider.id,
                    "name": provider.id,
                    "label": provider.label,
                    "displayName": provider.label,
                    "language": provider.language,
                    "description": provider.description,
                    "plugin": manifest.name,
                    "command": provider.command,
                    "args": list(provider.args),
                    "env": dict(provider.env),
                    "fileExtensions": list(provider.fileExtensions),
                    "rootPatterns": list(provider.rootPatterns),
                    "capabilities": list(provider.capabilities),
                    "configSchema": dict(provider.configSchema),
                    "defaults": dict(provider.defaults),
                    "install": dict(provider.install),
                    "active": state.active,
                })

        options = self._dedupe_lsp_options([*plugin_options, *fallback_options])
        if language_key:
            return [option for option in options if option.get("language", "").lower() == language_key]
        return options

    def get_search_provider_options(self) -> list[dict]:
        fallback_options: list[dict] = [
            {
                "id": "core.python",
                "name": "core.python",
                "label": "Core Python Search",
                "displayName": "Core Python Search",
                "description": "Built-in async workspace text search.",
                "plugin": "core",
                "providerType": "python",
                "command": "",
                "args": [],
                "capabilities": ["text", "workspace", "cancel"],
                "configSchema": {},
                "defaults": {
                    "maxResults": 500,
                    "maxFileSize": 512000,
                    "exclude": [
                        ".git", ".venv", "node_modules", "target", "dist", "build"
                    ],
                },
                "install": {},
                "active": True,
            }
        ]
        plugin_options: list[dict] = []
        for state in self.registry.list_all():
            if not state.active:
                continue
            manifest = state.manifest
            for provider in manifest.contributes.searchProviders:
                plugin_options.append({
                    "id": provider.id,
                    "name": provider.id,
                    "label": provider.label,
                    "displayName": provider.label,
                    "description": provider.description,
                    "plugin": manifest.name,
                    "providerType": provider.providerType,
                    "command": provider.command or "",
                    "args": list(provider.args),
                    "capabilities": list(provider.capabilities),
                    "configSchema": dict(provider.configSchema),
                    "defaults": dict(provider.defaults),
                    "install": dict(provider.install),
                    "active": state.active,
                })
        return self._dedupe_provider_options([*plugin_options, *fallback_options])

    def get_source_control_provider_options(self) -> list[dict]:
        fallback_options: list[dict] = [
            {
                "id": "core.git",
                "name": "core.git",
                "label": "Git",
                "displayName": "Git",
                "description": "Built-in lightweight Git provider using the git CLI.",
                "plugin": "core",
                "providerType": "git",
                "command": "git",
                "capabilities": ["status", "stage", "unstage", "discard", "diff"],
                "rootPatterns": [".git"],
                "configSchema": {},
                "defaults": {},
                "install": {},
                "active": True,
            }
        ]
        plugin_options: list[dict] = []
        for state in self.registry.list_all():
            if not state.active:
                continue
            manifest = state.manifest
            for provider in manifest.contributes.sourceControlProviders:
                plugin_options.append({
                    "id": provider.id,
                    "name": provider.id,
                    "label": provider.label,
                    "displayName": provider.label,
                    "description": provider.description,
                    "plugin": manifest.name,
                    "providerType": provider.providerType,
                    "command": provider.command,
                    "capabilities": list(provider.capabilities),
                    "rootPatterns": list(provider.rootPatterns),
                    "configSchema": dict(provider.configSchema),
                    "defaults": dict(provider.defaults),
                    "install": dict(provider.install),
                    "active": state.active,
                })
        return self._dedupe_provider_options([*plugin_options, *fallback_options])

    @staticmethod
    def _dedupe_lsp_options(options: list[dict]) -> list[dict]:
        return PluginManager._dedupe_provider_options(options)

    @staticmethod
    def _dedupe_provider_options(options: list[dict]) -> list[dict]:
        seen: set[str] = set()
        deduped: list[dict] = []
        for option in options:
            provider_id = str(option.get("id") or option.get("name") or "").strip()
            if not provider_id or provider_id in seen:
                continue
            seen.add(provider_id)
            deduped.append(option)
        return deduped

    @staticmethod
    def _appearance_capabilities(manifest) -> list[str]:
        capabilities: set[str] = set()
        contributes = manifest.contributes
        keywords = {keyword.lower() for keyword in manifest.keywords}
        if contributes.themes:
            capabilities.update({"colors", "editor", "borders"})
        if contributes.icons:
            capabilities.add("icons")
        if contributes.fileIcons or contributes.fileIconOverrides:
            capabilities.add("fileIcons")
        if contributes.fonts or {"font", "fonts"} & keywords:
            capabilities.add("fonts")
        if contributes.panels:
            capabilities.add("panels")
        if {"border", "borders"} & keywords:
            capabilities.add("borders")
        return sorted(capabilities)

    def _register_icon_contributions(self, name: str, manifest) -> None:
        state = self.registry.get(name)
        plugin_dir = state.directory if state else ""
        for icon in manifest.contributes.icons:
            path = self._resolve_plugin_path(plugin_dir, icon.path)
            if path:
                self._contributed_icons[icon.id] = path
        for file_icon in manifest.contributes.fileIcons:
            if file_icon.pattern and file_icon.icon:
                self._contributed_file_icons[file_icon.pattern] = file_icon.icon

    @staticmethod
    def _matches_file_context(contribution: dict, context: dict) -> bool:
        target_type = "folder" if context.get("isDir") or context.get("type") == "folder" else "file"
        applies_to = contribution.get("appliesTo") or ["file", "folder"]
        if target_type not in applies_to and "*" not in applies_to:
            return False
        when = str(contribution.get("when") or "").strip()
        if not when:
            return True
        return PluginManager._matches_file_when(when, context)

    @staticmethod
    def _matches_file_pattern(pattern: str, context: dict) -> bool:
        pattern = str(pattern or "").strip().lower()
        if not pattern or pattern == "*":
            return True
        name = PluginManager._file_basename(context).lower()
        path = str(context.get("path") or "").lower()
        if pattern.startswith("folder:"):
            return bool(context.get("isDir") or context.get("type") == "folder") and name == pattern[7:]
        if pattern.startswith(".") or "." in pattern:
            return name.endswith(pattern) or path.endswith(pattern)
        return name == pattern or name.endswith(f".{pattern}")

    @staticmethod
    def _matches_file_when(when: str, context: dict) -> bool:
        clauses = [clause.strip() for clause in when.replace("&&", " and ").split(" and ") if clause.strip()]
        return all(PluginManager._matches_file_clause(clause, context) for clause in clauses)

    @staticmethod
    def _matches_file_clause(clause: str, context: dict) -> bool:
        normalized = clause.strip()
        is_dir = bool(context.get("isDir") or context.get("type") == "folder")
        name = PluginManager._file_basename(context).lower()
        extension = str(context.get("extension") or "").lower()
        if not extension and "." in name and not is_dir:
            extension = "." + name.rsplit(".", 1)[-1]
        elif extension and not extension.startswith("."):
            extension = "." + extension
        if normalized in {"isFolder", "type == 'folder'", 'type == "folder"'}:
            return is_dir
        if normalized in {"isFile", "type == 'file'", 'type == "file"'}:
            return not is_dir
        for key, value in {
            "name": name,
            "basename": name,
            "ext": extension,
            "extension": extension,
        }.items():
            for operator in ["==", "="]:
                prefix = f"{key} {operator}"
                if normalized.startswith(prefix):
                    expected = normalized[len(prefix):].strip().strip("'\"").lower()
                    return value == expected
        if normalized.startswith("matches(") and normalized.endswith(")"):
            return PluginManager._matches_file_pattern(normalized[8:-1].strip().strip("'\""), context)
        return False

    @staticmethod
    def _file_basename(context: dict) -> str:
        name = str(context.get("name") or "")
        if name:
            return name
        path = str(context.get("path") or "")
        return os.path.basename(path)

    @staticmethod
    def _normalize_extension(extension: str) -> str:
        value = str(extension or "").strip().lower()
        if not value:
            return ""
        return value if value.startswith(".") else f".{value}"
