from __future__ import annotations

import os
from typing import List, Dict, Any, Optional
import ryx
from ryx import Model, CharField, DateTimeField
from ryx.migrations import MigrationRunner
from app.core.settings import DATABASE_URL


class History(Model):
    link = CharField(max_length=1024)
    created = DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created"]


class CurrentProject(Model):
    url = CharField(max_length=1024, unique=True)


class DatabaseService:
    """
    Legacy database service — delegates to app.data.models for new operations.
    Kept for backward compatibility with existing QML code.
    """

    def __init__(self):
        self.db_url = DATABASE_URL
        self._initialized = False

    async def initialize(self):
        if not self._initialized:
            if not ryx.is_connected():
                await ryx.setup(self.db_url)
            await MigrationRunner([History, CurrentProject], no_interactive=True).migrate()
            self._initialized = True

    async def get_history(self) -> List[Dict[str, Any]]:
        await self.initialize()
        posts = await History.objects.all()
        return [{"id": p.id, "link": p.link} for p in posts]

    async def save_to_history(self, path: str):
        await self.initialize()
        exists = await History.objects.filter(link=path).exists()
        if not exists:
            await History.objects.create(link=path)

    async def get_current_project(self) -> Optional[str]:
        await self.initialize()
        proj = await CurrentProject.objects.first()
        return proj.url if proj else None

    async def set_current_project(self, url: str):
        await self.initialize()
        proj, created = await CurrentProject.objects.get_or_create(url=url)
        return proj
