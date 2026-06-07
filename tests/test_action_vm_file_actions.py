from __future__ import annotations

import unittest

from app.core.events import EventBus
from app.services.action_service import ActionService
from app.viewmodels.action_vm import ActionViewModel


class FakeFileViewModel:
    def __init__(self):
        self.calls: list[tuple[str, tuple[str, ...]]] = []

    def copyLink(self, path: str) -> dict:
        self.calls.append(("copyLink", (path,)))
        return {"ok": True, "message": "copied", "path": path}

    def renamePath(self, path: str, name: str) -> dict:
        self.calls.append(("renamePath", (path, name)))
        return {"ok": True, "message": "renamed", "path": f"/tmp/{name}"}


class FakePluginViewModel:
    def __init__(self):
        self.calls: list[tuple[str, dict]] = []

    def executeFileBrowserAction(self, action_id: str, context: dict) -> bool:
        self.calls.append((action_id, context))
        return True


class ActionViewModelFileActionsTest(unittest.IsolatedAsyncioTestCase):
    async def test_file_action_runs_file_vm_operation(self):
        service = ActionService(EventBus())
        action_vm = ActionViewModel(service)
        fake_file_vm = FakeFileViewModel()
        action_vm.set_file_vm(fake_file_vm)

        result = await service.execute("file_browser.copy_link", {"path": "/tmp/example.py"})

        self.assertTrue(result["ok"])
        self.assertEqual(result["value"]["result"]["message"], "copied")
        self.assertEqual(fake_file_vm.calls, [("copyLink", ("/tmp/example.py",))])

    async def test_file_action_validates_required_payload(self):
        service = ActionService(EventBus())
        action_vm = ActionViewModel(service)
        action_vm.set_file_vm(FakeFileViewModel())

        result = await service.execute("file_browser.rename", {"path": "/tmp/a.py"})

        self.assertFalse(result["ok"])
        self.assertIn("Missing file action field", result["message"])

    async def test_file_plugin_action_delegates_to_plugin_vm(self):
        service = ActionService(EventBus())
        action_vm = ActionViewModel(service)
        fake_plugin_vm = FakePluginViewModel()
        action_vm.set_plugin_vm(fake_plugin_vm)

        result = await service.execute(
            "file_browser.plugin_action",
            {"actionId": "plugin.format", "context": {"path": "/tmp/a.py"}},
        )

        self.assertTrue(result["ok"])
        self.assertEqual(fake_plugin_vm.calls, [("plugin.format", {"path": "/tmp/a.py"})])


if __name__ == "__main__":
    unittest.main()
