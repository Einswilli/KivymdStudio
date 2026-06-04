import os
import platform
import shutil
from pathlib import Path
import utils


class ProjectService:
    """
    Handles project creation and management.
    """

    async def create_project(self, n, p, t, a, l, e, g, pt):
        from core import projectCreator

        # projectCreator is still legacy, but we wrap it in a service
        return projectCreator.newProject(n, p, t, a, l, e, g, pt)
