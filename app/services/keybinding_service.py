from __future__ import annotations

from collections import defaultdict
from typing import Any

from app.services.settings_service import SettingsService


class KeybindingService:
    def __init__(self, settings: SettingsService | None = None):
        self._settings = settings or SettingsService()

    def set_settings(self, settings: SettingsService) -> None:
        self._settings = settings

    def resolve(
        self,
        sequence: str,
        fallback_command: str = "",
        *,
        plugin_bindings: list[dict] | None = None,
        core_bindings: dict[str, str] | None = None,
    ) -> str:
        key = self._normalize_sequence(sequence)
        for binding in self.resolved(plugin_bindings or [], core_bindings or {}):
            if binding["key"] == key and binding.get("active", False):
                return str(binding.get("command") or fallback_command)
        return fallback_command

    def resolved(
        self,
        plugin_bindings: list[dict],
        core_bindings: dict[str, str],
    ) -> list[dict]:
        config = self._settings.load()
        entries: list[dict] = []

        entries.extend(self._override_entries(config))
        entries.extend(self._custom_entries(config))
        entries.extend(self._plugin_entries(plugin_bindings))
        entries.extend(self._core_entries(core_bindings))
        entries = self._hide_shadowed_core_entries(entries)

        grouped: dict[tuple[str, str], list[dict]] = defaultdict(list)
        for entry in entries:
            grouped[(entry["key"], entry["when"])].append(entry)

        resolved_entries: list[dict] = []
        for group_entries in grouped.values():
            group_entries.sort(key=lambda item: item["priority"])
            enabled_entries = [item for item in group_entries if not item.get("disabled")]
            active = enabled_entries[0] if enabled_entries else None
            conflict = len(enabled_entries) > 1
            for item in group_entries:
                payload = dict(item)
                payload["active"] = active is not None and item is active
                payload["conflict"] = conflict
                payload["conflicts"] = [
                    self._conflict_label(other)
                    for other in group_entries
                    if other is not item and not other.get("disabled")
                ]
                resolved_entries.append(payload)

        resolved_entries.sort(key=lambda item: (not item["active"], item["key"], item["when"]))
        return resolved_entries

    def _hide_shadowed_core_entries(self, entries: list[dict]) -> list[dict]:
        occupied = {
            (entry["key"], entry["when"])
            for entry in entries
            if entry.get("source") != "core"
        }
        return [
            entry for entry in entries
            if entry.get("source") != "core" or (entry["key"], entry["when"]) not in occupied
        ]

    def _override_entries(self, config: dict[str, Any]) -> list[dict]:
        overrides = SettingsService.get(config, "keybindings.overrides", {}) or {}
        entries: list[dict] = []
        for sequence, value in overrides.items():
            if not isinstance(value, dict) or value.get("disabled"):
                continue
            command = str(value.get("command") or "")
            if not command:
                continue
            entries.append(self._entry(
                key=sequence,
                command=command,
                when=str(value.get("when") or "global"),
                source="override",
                plugin="user",
                priority=0,
                binding_id=str(value.get("id") or sequence),
                title=str(value.get("title") or ""),
                action_type=str(value.get("actionType") or "command"),
                payload=value.get("payload") or {},
            ))
        return entries

    def _custom_entries(self, config: dict[str, Any]) -> list[dict]:
        custom = SettingsService.get(config, "keybindings.custom", []) or []
        entries: list[dict] = []
        for value in custom:
            if not isinstance(value, dict):
                continue
            command = str(value.get("command") or "")
            sequence = str(value.get("key") or value.get("sequence") or "")
            if not command or not sequence:
                continue
            entries.append(self._entry(
                key=sequence,
                command=command,
                when=str(value.get("when") or "global"),
                source="custom",
                plugin="user",
                priority=1,
                binding_id=str(value.get("id") or sequence),
                title=str(value.get("title") or ""),
                action_type=str(value.get("actionType") or "command"),
                payload=value.get("payload") or {},
                disabled=bool(value.get("disabled")),
            ))
        return entries

    def _plugin_entries(self, plugin_bindings: list[dict]) -> list[dict]:
        entries: list[dict] = []
        for value in plugin_bindings:
            command = str(value.get("command") or "")
            sequence = str(value.get("key") or "")
            if not command or not sequence:
                continue
            entries.append(self._entry(
                key=sequence,
                command=command,
                when=str(value.get("when") or "global"),
                source="plugin",
                plugin=str(value.get("plugin") or "plugin"),
                priority=10,
                binding_id=str(value.get("id") or f"{value.get('plugin') or 'plugin'}:{sequence}:{command}"),
                title=str(value.get("title") or ""),
            ))
        return entries

    def _core_entries(self, core_bindings: dict[str, str]) -> list[dict]:
        return [
            self._entry(
                key=sequence,
                command=command,
                when="global",
                source="core",
                plugin="core",
                priority=100,
                binding_id=f"core:{sequence}:{command}",
            )
            for sequence, command in core_bindings.items()
        ]

    def _entry(
        self,
        *,
        key: str,
        command: str,
        when: str,
        source: str,
        plugin: str,
        priority: int,
        binding_id: str = "",
        title: str = "",
        action_type: str = "command",
        payload: Any = None,
        disabled: bool = False,
    ) -> dict:
        return {
            "key": self._normalize_sequence(key),
            "command": command,
            "when": when or "global",
            "source": source,
            "plugin": plugin,
            "priority": priority,
            "id": binding_id,
            "title": title,
            "actionType": action_type,
            "payload": payload or {},
            "disabled": disabled,
        }

    @staticmethod
    def _normalize_sequence(sequence: str) -> str:
        return str(sequence or "").strip()

    @staticmethod
    def _conflict_label(entry: dict) -> str:
        return f"{entry.get('key')} → {entry.get('command')} ({entry.get('source')}/{entry.get('plugin')})"
