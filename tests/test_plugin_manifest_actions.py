from __future__ import annotations

import unittest

from app.plugins.manifest import PluginManifest


class PluginManifestActionsTest(unittest.TestCase):
    def test_manifest_accepts_action_contributions(self):
        manifest = PluginManifest(**{
            "name": "test-actions",
            "display_name": "Test Actions",
            "version": "1.0.0",
            "author": "Ember",
            "contributes": {
                "actions": [
                    {
                        "id": "testActions.hello",
                        "title": "Say Hello",
                        "command": "testActions.sayHello",
                        "category": "Tests",
                        "description": "Runs a test action.",
                        "keybinding": "Ctrl+Alt+H",
                        "requiresPayload": False,
                    }
                ]
            },
        })

        self.assertEqual(len(manifest.contributes.actions), 1)
        action = manifest.contributes.actions[0]
        self.assertEqual(action.id, "testActions.hello")
        self.assertEqual(action.command, "testActions.sayHello")
        self.assertEqual(action.keybinding, "Ctrl+Alt+H")
        self.assertFalse(action.requiresPayload)
        self.assertTrue(manifest.contributes.has_any)


if __name__ == "__main__":
    unittest.main()
