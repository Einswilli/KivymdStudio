from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class RestoredEditorSession:
    open_files: list[str]
    active_file: str
    cursor_positions: dict[str, dict[str, int]]


class EditorSessionService:
    async def load_last_session(self, project_path: str = "") -> RestoredEditorSession | None:
        from app.data.models import EditorSession

        try:
            workspace_path = self._clean_workspace_path(project_path)
            if not workspace_path:
                return None
            session = await EditorSession.objects.filter(workspace_path=workspace_path).order_by("-saved_at").first()
        except Exception as exc:
            print(f"[EditorSessionService] load skipped: {exc}")
            return None
        if not session:
            return None
        open_files = [
            path for path in (session.open_files or [])
            if isinstance(path, str) and path and os.path.isfile(path)
        ]
        if not open_files:
            return None
        active_file = session.active_file if session.active_file in open_files else open_files[0]
        cursor_positions = session.cursor_positions or {}
        return RestoredEditorSession(
            open_files=open_files,
            active_file=active_file,
            cursor_positions=cursor_positions,
        )

    async def save_session(
        self,
        open_files: list[str],
        active_file: str = "",
        cursor_positions: dict[str, dict[str, int]] | None = None,
        project_path: str = "",
    ) -> None:
        from app.data.models import EditorSession

        project = await self._project_for_path(project_path)
        workspace_path = self._clean_workspace_path(project_path)
        if not workspace_path:
            return

        clean_files = []
        for path in open_files:
            if isinstance(path, str) and path and os.path.isfile(path) and path not in clean_files:
                clean_files.append(path)
        active = active_file if active_file in clean_files else (clean_files[0] if clean_files else "")
        payload: dict[str, Any] = {
            "project": project,
            "workspace_path": workspace_path,
            "open_files": clean_files,
            "active_file": active,
            "cursor_positions": cursor_positions or {},
        }
        try:
            session = await EditorSession.objects.filter(workspace_path=workspace_path).order_by("-saved_at").first()
            if not session:
                await EditorSession.objects.create(**payload)
                return
            session.project = payload["project"]
            session.workspace_path = payload["workspace_path"]
            session.open_files = payload["open_files"]
            session.active_file = payload["active_file"]
            session.cursor_positions = payload["cursor_positions"]
            await session.save()
        except Exception as exc:
            print(f"[EditorSessionService] save skipped: {exc}")

    @staticmethod
    def _clean_workspace_path(project_path: str) -> str:
        if not project_path:
            return ""
        clean_path = os.path.abspath(os.path.expanduser(project_path))
        return clean_path if os.path.isdir(clean_path) else ""

    @staticmethod
    async def _project_for_path(project_path: str):
        clean_path = EditorSessionService._clean_workspace_path(project_path)
        if not clean_path:
            return None
        from app.data.models import Project
        from app.services.workspace_service import project_avatar, project_color

        try:
            return await Project.objects.get(path=clean_path)
        except Exception:
            name = os.path.basename(clean_path) or clean_path
            try:
                return await Project.objects.create(
                    name=name,
                    path=clean_path,
                    template="Existing",
                    is_active=True,
                    color=project_color(clean_path),
                    avatar=project_avatar(name),
                )
            except Exception:
                return None
