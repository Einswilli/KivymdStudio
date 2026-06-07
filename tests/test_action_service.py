from __future__ import annotations

import asyncio
import unittest

from app.core.events import EventBus
from app.services.action_service import ActionDefinition, ActionService


class ActionServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_tracks_success_history_and_running_state(self):
        service = ActionService(EventBus())
        observed = []
        release = asyncio.Event()

        async def handler(payload):
            observed.append(service.is_running("test.slow"))
            release.set()
            await asyncio.sleep(0)
            return {"message": f"done:{payload['value']}"}

        service.register(ActionDefinition(
            id="test.slow",
            title="Slow Test",
            handler=handler,
        ))

        result = await service.execute("test.slow", {"value": 42})

        self.assertTrue(release.is_set())
        self.assertEqual(observed, [True])
        self.assertTrue(result["ok"])
        self.assertEqual(result["message"], "done:42")
        self.assertFalse(service.is_running("test.slow"))
        self.assertEqual(service.history()[-1]["id"], "test.slow")

    async def test_records_unknown_and_failed_actions(self):
        service = ActionService(EventBus())

        async def failing(_payload):
            raise RuntimeError("boom")

        service.register(ActionDefinition(
            id="test.fail",
            title="Failing Test",
            handler=failing,
        ))

        unknown = await service.execute("missing.action")
        failed = await service.execute("test.fail")

        self.assertFalse(unknown["ok"])
        self.assertIn("Unknown action", unknown["message"])
        self.assertFalse(failed["ok"])
        self.assertEqual(failed["message"], "boom")
        self.assertEqual(
            [item["id"] for item in service.history()],
            ["missing.action", "test.fail"],
        )


if __name__ == "__main__":
    unittest.main()
