import os
import platform
import shutil
from pathlib import Path
from typing import List, Dict, Any, Optional
import simplejson as Json


class DisplayablePath(object):
    display_filename_prefix_middle = "├─"
    display_filename_prefix_last = "└─"
    display_parent_prefix_middle = "  "
    display_parent_prefix_last = "│ "

    def __init__(self, path, parent_path, is_last):
        self.path = Path(str(path))
        self.parent = parent_path
        self.is_last = is_last
        if self.parent:
            self.depth = self.parent.depth + 1
        else:
            self.depth = 0

    @property
    def displayname(self):
        if self.path.is_dir():
            return self.path.name + "/"
        return self.path.name

    @classmethod
    def make_tree(cls, root, parent=None, is_last=False, criteria=None):
        root = Path(str(root))
        criteria = criteria or cls._default_criteria

        displayable_root = cls(root, parent, is_last)
        yield displayable_root

        children = sorted(
            list(path for path in root.iterdir() if criteria(path)),
            key=lambda s: str(s).lower(),
        )
        count = 1
        for path in children:
            is_last = count == len(children)
            if path.is_dir():
                yield from cls.make_tree(
                    path, parent=displayable_root, is_last=is_last, criteria=criteria
                )
            else:
                yield cls(path, displayable_root, is_last)
            count += 1

    @classmethod
    def _default_criteria(cls, path):
        return True

    def displayable(self):
        if self.parent is None:
            return self.displayname

        _filename_prefix = (
            self.display_filename_prefix_last
            if self.is_last
            else self.display_filename_prefix_middle
        )

        parts = ["{!s} {!s}".format(_filename_prefix, self.displayname)]

        parent = self.parent
        while parent and parent.parent is not None:
            parts.append(
                self.display_parent_prefix_middle
                if parent.is_last
                else self.display_parent_prefix_last
            )
            parent = parent.parent

        return "".join(reversed(parts))


class FileService:
    """
    Handles file system operations.
    """

    def __init__(self, state):
        self.state = state

    async def create_file(self, filename: str, fpath: str):
        p = str(fpath)[8:] if "windows" in platform.system().lower() else str(fpath)[7:]
        link = os.path.join(p, str(filename))
        with open(link, "x") as f:
            f.write("")

    async def read_file(self, path: str) -> str:
        if not path.startswith("file://"):
            p = (
                path[1:].replace("/", "\\")
                if "windows" in platform.system().lower()
                else path
            )
        else:
            p = (
                path[8:].replace("/", "\\")
                if "windows" in platform.system().lower()
                else path[7:]
            )

        with open(p, "r") as f:
            return f.read()

    async def save_file(self, p: str, fname: str, content: str):
        if str(p).endswith(fname):
            idx = str(p).index(fname)
            p = p[8:idx] if "windows" in platform.system().lower() else p[7:idx]

        cleaned_content = (
            content.replace("\u2029", "\n")
            .replace("\u21e5", "\t")
            .replace("â€©", "\n")
            .replace("    ", "\t")
        )

        with open(os.path.join(p, fname), "w") as f:
            f.write(cleaned_content)

    async def create_folder(self, foldername: str, path_: str):
        p = str(path_)[8:] if "windows" in platform.system().lower() else str(path_)[7:]
        os.mkdir(os.path.join(p, foldername))

    async def list_folder(self, path_: str) -> str:
        paths = DisplayablePath.make_tree(Path(path_[6:]))
        ls = [{"filename": str(path.displayable())} for path in paths]
        return Json.dumps(ls, indent=4)
