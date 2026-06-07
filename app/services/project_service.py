from __future__ import annotations

import asyncio
import os
import re
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import aiofiles

from app.core.settings import PATHS, TEMPLATES
from app.services.workspace_service import WorkspaceService


@dataclass(slots=True)
class ProjectCreateOptions:
    name: str
    parent_path: str
    template: str = "Empty"
    add_app: bool = False
    add_lib: bool = False
    add_examples: bool = False
    add_tests: bool = True
    add_git: bool = False
    open_after_create: bool = True


@dataclass(slots=True)
class ProjectResult:
    name: str
    path: str
    template: str
    files: list[str]
    directories: list[str]
    success: bool = True

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "path": self.path,
            "template": self.template,
            "files": list(self.files),
            "directories": list(self.directories),
            "success": self.success,
        }


class ProjectService:
    def __init__(self, workspace_service: WorkspaceService | None = None):
        self._workspace_service = workspace_service or WorkspaceService()

    async def create_project(self, options: ProjectCreateOptions) -> ProjectResult:
        parent = Path(options.parent_path or PATHS["PROJECTS"]).expanduser().resolve()
        project_name = self._validate_project_name(options.name)
        project_dir = parent / project_name

        if project_dir.exists() and any(project_dir.iterdir()):
            raise FileExistsError(f"Project directory is not empty: {project_dir}")

        project_dir.mkdir(parents=True, exist_ok=True)
        files: list[str] = []
        directories: list[str] = [os.fspath(project_dir)]

        await self._write_text(project_dir / "main.py", self._main_py(options.template, project_name))
        files.append(os.fspath(project_dir / "main.py"))

        await self._write_text(project_dir / "main.kv", self._main_kv(options.template))
        files.append(os.fspath(project_dir / "main.kv"))

        await self._write_text(project_dir / "README.md", self._readme(project_name, options.template))
        files.append(os.fspath(project_dir / "README.md"))

        await self._write_text(project_dir / ".gitignore", self._gitignore())
        files.append(os.fspath(project_dir / ".gitignore"))

        for enabled, dirname in (
            (options.add_app, "app"),
            (options.add_lib, "lib"),
            (options.add_examples, "examples"),
            (options.add_tests, "tests"),
        ):
            if enabled:
                directory = project_dir / dirname
                directory.mkdir(exist_ok=True)
                directories.append(os.fspath(directory))
                if dirname == "tests":
                    await self._write_text(directory / "test_smoke.py", "def test_smoke():\n    assert True\n")
                    files.append(os.fspath(directory / "test_smoke.py"))

        if options.add_git and shutil.which("git"):
            await self._init_git(project_dir)

        if options.open_after_create:
            await self._workspace_service.open_workspace(os.fspath(project_dir), options.template)

        return ProjectResult(
            name=project_name,
            path=os.fspath(project_dir),
            template=options.template,
            files=files,
            directories=directories,
        )

    async def open_project(self, path: str) -> dict[str, Any]:
        state = await self._workspace_service.open_workspace(path)
        return state.to_dict()

    async def close_project(self) -> None:
        await self._workspace_service.close_workspace()

    async def recent_projects(self, limit: int = 20) -> list[dict[str, Any]]:
        states = await self._workspace_service.recent_workspaces(limit)
        return [state.to_dict() for state in states]

    @staticmethod
    def available_templates() -> list[str]:
        return sorted(set(TEMPLATES.keys()) | {"Empty"})

    @staticmethod
    def default_parent_dir() -> str:
        return PATHS["PROJECTS"]

    @staticmethod
    def _validate_project_name(name: str) -> str:
        clean = (name or "").strip()
        if not clean:
            raise ValueError("Project name is required")
        if clean in {".", ".."} or "/" in clean or "\\" in clean:
            raise ValueError(f"Invalid project name: {name}")
        if not re.match(r"^[A-Za-z0-9][A-Za-z0-9._ -]*$", clean):
            raise ValueError(f"Invalid project name: {name}")
        return clean

    @staticmethod
    async def _write_text(path: Path, content: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        async with aiofiles.open(path, "w", encoding="utf-8") as handle:
            await handle.write(content)

    @staticmethod
    async def _init_git(project_dir: Path) -> None:
        process = await asyncio.create_subprocess_exec(
            "git",
            "init",
            cwd=os.fspath(project_dir),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await process.communicate()

    @staticmethod
    def _main_py(template: str, project_name: str) -> str:
        template_content = TEMPLATES.get(template, "")
        if template_content:
            return template_content
        class_name = re.sub(r"[^A-Za-z0-9]", "", project_name.title()) or "EmberProject"
        return (
            "from kivymd.app import MDApp\n"
            "from kivy.lang import Builder\n\n\n"
            f"class {class_name}App(MDApp):\n"
            "    def build(self):\n"
            "        return Builder.load_file('main.kv')\n\n\n"
            "if __name__ == '__main__':\n"
            f"    {class_name}App().run()\n"
        )

    @staticmethod
    def _main_kv(template: str) -> str:
        if template != "Empty":
            return "ScreenManager:\n    Screen:\n        name: 'main'\n"
        return (
            "ScreenManager:\n"
            "    Screen:\n"
            "        name: 'main'\n"
            "        MDLabel:\n"
            "            text: 'Hello from Ember'\n"
            "            halign: 'center'\n"
        )

    @staticmethod
    def _readme(project_name: str, template: str) -> str:
        return (
            f"# {project_name}\n\n"
            f"Created with Ember using the `{template}` template.\n\n"
            "## Run\n\n"
            "```bash\n"
            "python main.py\n"
            "```\n"
        )

    @staticmethod
    def _gitignore() -> str:
        return (
            "__pycache__/\n"
            "*.py[cod]\n"
            ".venv/\n"
            ".env\n"
            ".DS_Store\n"
            ".pytest_cache/\n"
            ".mypy_cache/\n"
            ".ruff_cache/\n"
        )


class NewProjectService(ProjectService):
    async def create(
        self,
        name: str,
        path: str,
        template: str = "Empty",
        add_app: bool = False,
        add_lib: bool = False,
        add_examples: bool = False,
        add_git: bool = False,
    ) -> dict[str, Any]:
        result = await self.create_project(
            ProjectCreateOptions(
                name=name,
                parent_path=path,
                template=template,
                add_app=add_app,
                add_lib=add_lib,
                add_examples=add_examples,
                add_git=add_git,
            )
        )
        return result.to_dict()
