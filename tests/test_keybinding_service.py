from __future__ import annotations

import unittest

from app.services.keybinding_service import KeybindingService


class FakeSettings:
    def __init__(self, config):
        self._config = config

    def load(self):
        return self._config


class KeybindingServiceTest(unittest.TestCase):
    def test_override_can_resolve_to_action_id(self):
        service = KeybindingService(FakeSettings({
            "keybindings": {
                "overrides": {
                    "Ctrl+Alt+D": {
                        "command": "plugin.inlineDiagnostics.toggle",
                        "when": "global",
                        "actionType": "action",
                    }
                }
            }
        }))

        command = service.resolve(
            "Ctrl+Alt+D",
            "",
            plugin_bindings=[],
            core_bindings={},
        )

        self.assertEqual(command, "plugin.inlineDiagnostics.toggle")

    def test_conflicting_bindings_mark_only_highest_priority_active(self):
        service = KeybindingService(FakeSettings({
            "keybindings": {
                "custom": [
                    {
                        "id": "user-binding",
                        "key": "Ctrl+K",
                        "command": "user.action",
                        "when": "global",
                    }
                ]
            }
        }))

        rows = service.resolved(
            [{"plugin": "default", "key": "Ctrl+K", "command": "plugin.action", "when": "global"}],
            {"Ctrl+K": "core.action"},
        )

        active = [item for item in rows if item["active"]]
        self.assertEqual(len(active), 1)
        self.assertEqual(active[0]["command"], "user.action")
        self.assertTrue(active[0]["conflict"])


if __name__ == "__main__":
    unittest.main()
