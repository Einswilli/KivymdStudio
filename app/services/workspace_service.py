from __future__ import annotations

import os
import json
import hashlib
from dataclasses import dataclass
from typing import Any


ACTIVE_WORKSPACE_KEY = "workspace.active_path"


@dataclass(slots=True)
class WorkspaceState:
    name: str
    path: str
    template: str = "Existing"
    is_active: bool = True
    color: str = "#3B82F6"
    avatar: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "path": self.path,
            "template": self.template,
            "isActive": self.is_active,
            "color": self.color,
            "avatar": self.avatar or project_avatar(self.name),
        }


class WorkspaceService:
    async def open_workspace(self, path: str, template: str = "Existing") -> WorkspaceState:
        from app.data.models import Project, UserSettings

        clean_path = os.path.abspath(os.path.expanduser(path))
        if not os.path.isdir(clean_path):
            raise ValueError(f"Workspace path is not a directory: {path}")

        name = os.path.basename(clean_path) or clean_path

        try:
            active_projects = await Project.objects.filter(is_active=True).all()
            for project in active_projects:
                project.is_active = False
                await project.save()
        except Exception as exc:
            print(f"[WorkspaceService] active project cleanup skipped: {exc}")

        try:
            project = await Project.objects.get(path=clean_path)
            project.name = name
            project.template = template or project.template or "Existing"
            project.is_active = True
            if not getattr(project, "color", ""):
                project.color = project_color(clean_path)
            if not getattr(project, "avatar", ""):
                project.avatar = project_avatar(name)
            await project.save()
        except Exception:
            project = await Project.objects.create(
                name=name,
                path=clean_path,
                template=template or "Existing",
                is_active=True,
                color=project_color(clean_path),
                avatar=project_avatar(name),
            )

        await self._set_setting(UserSettings, ACTIVE_WORKSPACE_KEY, clean_path)
        return self._state_from_project(project)

    async def get_active_workspace(self) -> WorkspaceState | None:
        from app.data.models import Project, UserSettings

        active_path = await self._get_setting(UserSettings, ACTIVE_WORKSPACE_KEY)
        if isinstance(active_path, str) and os.path.isdir(active_path):
            try:
                project = await Project.objects.get(path=active_path)
                return self._state_from_project(project)
            except Exception:
                return WorkspaceState(
                    name=os.path.basename(active_path) or active_path,
                    path=active_path,
                    template="Existing",
                    is_active=True,
                )

        try:
            project = await Project.objects.filter(is_active=True).order_by("-opened_at").first()
            if project and os.path.isdir(project.path):
                return self._state_from_project(project)
        except Exception as exc:
            print(f"[WorkspaceService] active workspace lookup skipped: {exc}")
        return None

    async def recent_workspaces(self, limit: int = 20) -> list[WorkspaceState]:
        from app.data.models import Project

        try:
            projects = await Project.objects.order_by("-opened_at").limit(limit).all()
        except Exception as exc:
            print(f"[WorkspaceService] recent workspace lookup skipped: {exc}")
            return []
        return [
            self._state_from_project(project)
            for project in projects
            if isinstance(project.path, str) and os.path.isdir(project.path)
        ]

    async def close_workspace(self) -> None:
        from app.data.models import Project, UserSettings

        try:
            active_projects = await Project.objects.filter(is_active=True).all()
            for project in active_projects:
                project.is_active = False
                await project.save()
        except Exception as exc:
            print(f"[WorkspaceService] close workspace skipped: {exc}")
        await self._set_setting(UserSettings, ACTIVE_WORKSPACE_KEY, "")

    @staticmethod
    def _state_from_project(project) -> WorkspaceState:
        return WorkspaceState(
            name=project.name,
            path=project.path,
            template=getattr(project, "template", "Existing") or "Existing",
            is_active=bool(getattr(project, "is_active", True)),
            color=getattr(project, "color", "") or project_color(project.path),
            avatar=getattr(project, "avatar", "") or project_avatar(project.name),
        )

    @staticmethod
    async def _get_setting(settings_model, key: str) -> Any:
        try:
            setting = await settings_model.objects.get(key=key)
            return setting.value
        except Exception:
            return None

    @staticmethod
    async def _set_setting(settings_model, key: str, value: Any) -> None:
        stored_value = json.dumps(value) if isinstance(value, str) else value
        try:
            setting = await settings_model.objects.get(key=key)
            setting.value = stored_value
            await setting.save()
        except Exception:
            await settings_model.objects.create(key=key, value=stored_value)


PROJECT_COLORS = (
    "#3B82F6", "#8B5CF6", "#EC4899", "#F97316", "#22C55E",
    "#06B6D4", "#EAB308", "#EF4444", "#14B8A6", "#A855F7",
)


def project_color(seed: str) -> str:
    digest = hashlib.sha256(seed.encode("utf-8")).digest()
    return PROJECT_COLORS[int.from_bytes(digest[:2], "big") % len(PROJECT_COLORS)]


def project_avatar(name: str) -> str:
    clean = "".join(char for char in name.strip() if char.isalnum())
    if not clean:
        return "•"
    return clean[:2].upper()
