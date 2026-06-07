from __future__ import annotations

import unittest

from app.core.events import EventBus
from app.services.action_service import ActionService
from app.viewmodels.action_vm import ActionViewModel


class FakeStatusViewModel:
    def __init__(self):
        self.copied = []
        self.output_cleared = False

    def copy_text(self, text: str) -> None:
        self.copied.append(text)

    def clear_output(self) -> None:
        self.output_cleared = True

    def clear_console(self) -> None:
        pass

    def clear_diagnostics(self) -> None:
        pass

    def append_console(self, _level: str, _message: str) -> None:
        pass


class FakeSearchViewModel:
    def __init__(self):
        self.searches = []
        self.cleared = False
        self.copied_paths = []
        self.result_actions = []

    def search(self, query: str) -> None:
        self.searches.append(query)

    def clear(self) -> None:
        self.cleared = True

    def copyPath(self, path: str) -> None:
        self.copied_paths.append(path)

    def emitResultAction(self, result: dict) -> None:
        self.result_actions.append(result)


class ActionViewModelWorkbenchActionsTest(unittest.IsolatedAsyncioTestCase):
    async def test_clipboard_copy_uses_status_vm(self):
        service = ActionService(EventBus())
        action_vm = ActionViewModel(service)
        status_vm = FakeStatusViewModel()
        action_vm.set_status_vm(status_vm)

        result = await service.execute("clipboard.copy_text", {"text": "hello"})

        self.assertTrue(result["ok"])
        self.assertEqual(status_vm.copied, ["hello"])

    async def test_search_actions_delegate_to_search_vm(self):
        service = ActionService(EventBus())
        action_vm = ActionViewModel(service)
        search_vm = FakeSearchViewModel()
        action_vm.set_search_vm(search_vm)

        run = await service.execute("search.run", {"query": "token"})
        copy = await service.execute("search.copy_path", {"path": "/tmp/a.py"})
        emit = await service.execute("search.result_action", {"result": {"path": "/tmp/a.py"}})
        clear = await service.execute("search.clear")

        self.assertTrue(run["ok"])
        self.assertTrue(copy["ok"])
        self.assertTrue(emit["ok"])
        self.assertTrue(clear["ok"])
        self.assertEqual(search_vm.searches, ["token"])
        self.assertEqual(search_vm.copied_paths, ["/tmp/a.py"])
        self.assertEqual(search_vm.result_actions, [{"path": "/tmp/a.py"}])
        self.assertTrue(search_vm.cleared)

    async def test_actions_expose_payload_requirement_for_palette_filtering(self):
        service = ActionService(EventBus())
        action_vm = ActionViewModel(service)
        action_vm.set_search_vm(FakeSearchViewModel())
        actions = {item["id"]: item for item in service.list_actions()}

        self.assertTrue(actions["search.run"]["requiresPayload"])
        self.assertTrue(actions["search.copy_path"]["requiresPayload"])
        self.assertFalse(actions["search.clear"]["requiresPayload"])


if __name__ == "__main__":
    unittest.main()
