from __future__ import annotations

import json

from PySide6.QtCore import QObject, Property, Signal, Slot

from app.core.async_tasks import schedule
from app.core.events import EventBus
from app.services.project_service import ProjectCreateOptions, ProjectService


class ProjectViewModel(QObject):
    projectChanged = Signal("QVariantMap")
    projectCreated = Signal("QVariantMap")
    recentProjectsChanged = Signal()
    projectError = Signal(str)

    def __init__(
        self,
        events: EventBus,
        project_service: ProjectService | None = None,
        parent: QObject | None = None,
    ):
        super().__init__(parent)
        self._events = events
        self._project_service = project_service or ProjectService()
        self._current_project: dict = {}
        self._recent_projects: list[dict] = []

    @Slot(str, str, str, bool, bool, bool, bool, result=bool)
    def createProject(
        self,
        name: str,
        parent_path: str,
        template: str = "Empty",
        add_app: bool = False,
        add_lib: bool = False,
        add_examples: bool = False,
        add_git: bool = False,
    ) -> bool:
        options = ProjectCreateOptions(
            name=name,
            parent_path=parent_path,
            template=template or "Empty",
            add_app=add_app,
            add_lib=add_lib,
            add_examples=add_examples,
            add_git=add_git,
            open_after_create=True,
        )
        schedule(self._create_project_async(options))
        return True

    @Slot(str, result=bool)
    def openProject(self, path: str) -> bool:
        schedule(self._open_project_async(path))
        return True

    @Slot()
    def closeProject(self) -> None:
        schedule(self._close_project_async())

    @Slot()
    def loadRecentProjects(self) -> None:
        schedule(self._load_recent_projects_async())

    @Slot(result="QVariantList")
    def availableTemplates(self) -> list[str]:
        return self._project_service.available_templates()

    @Slot(result=str)
    def defaultParentDir(self) -> str:
        return self._project_service.default_parent_dir()

    @Slot(result=str)
    def recentProjectsJson(self) -> str:
        return json.dumps(self._recent_projects)

    @Property("QVariantMap", notify=projectChanged)
    def currentProject(self) -> dict:
        return self._current_project

    @Property("QVariantList", notify=recentProjectsChanged)
    def recentProjects(self) -> list[dict]:
        return self._recent_projects

    async def _create_project_async(self, options: ProjectCreateOptions) -> None:
        try:
            result = await self._project_service.create_project(options)
            payload = result.to_dict()
            self._current_project = {
                "name": result.name,
                "path": result.path,
                "template": result.template,
                "isActive": True,
            }
            self.projectCreated.emit(payload)
            self.projectChanged.emit(self._current_project)
            await self._events.emit("project:created", **payload)
            await self._events.emit("workspace:open", **self._current_project)
            await self._load_recent_projects_async()
        except Exception as exc:
            message = str(exc)
            self.projectError.emit(message)
            print(f"[ProjectVM] create error: {message}")

    async def _open_project_async(self, path: str) -> None:
        try:
            self._current_project = await self._project_service.open_project(path)
            self.projectChanged.emit(self._current_project)
            await self._events.emit("workspace:open", **self._current_project)
            await self._load_recent_projects_async()
        except Exception as exc:
            message = str(exc)
            self.projectError.emit(message)
            print(f"[ProjectVM] open error: {message}")

    async def _close_project_async(self) -> None:
        try:
            await self._project_service.close_project()
            self._current_project = {}
            self.projectChanged.emit({})
            await self._events.emit("workspace:close")
        except Exception as exc:
            message = str(exc)
            self.projectError.emit(message)
            print(f"[ProjectVM] close error: {message}")

    async def _load_recent_projects_async(self) -> None:
        try:
            self._recent_projects = await self._project_service.recent_projects()
            self.recentProjectsChanged.emit()
        except Exception as exc:
            print(f"[ProjectVM] recent error: {exc}")
