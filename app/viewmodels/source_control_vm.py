from __future__ import annotations

from PySide6.QtCore import QObject, Property, Signal, Slot

from app.core.async_tasks import schedule
from app.core.events import EventBus
from app.services.git_service import GitService, GitStatus


class SourceControlViewModel(QObject):
    statusChanged = Signal()
    loadingChanged = Signal()
    messageChanged = Signal()
    diffChanged = Signal()
    diffLoadingChanged = Signal()

    def __init__(
        self,
        events: EventBus | None = None,
        service: GitService | None = None,
        parent: QObject | None = None,
    ):
        super().__init__(parent)
        self._events = events
        self._service = service or GitService()
        self._notification_vm = None
        self._workspace = ""
        self._root = ""
        self._branch = ""
        self._upstream = ""
        self._ahead = 0
        self._behind = 0
        self._files: list[dict] = []
        self._loading = False
        self._message = "No repository"
        self._generation = 0
        self._diff_path = ""
        self._diff_text = ""
        self._diff_staged = False
        self._diff_loading = False
        self._diff_error = ""

    def set_notification_vm(self, notification_vm) -> None:
        self._notification_vm = notification_vm

    @Slot(str)
    def setWorkspace(self, path: str) -> None:
        self._workspace = path or ""
        self.refresh()

    @Slot()
    def refresh(self) -> None:
        self._generation += 1
        generation = self._generation
        self._set_loading(True)
        schedule(self._refresh_async(generation))

    @Slot(str)
    def stage(self, path: str) -> None:
        self._run_action("Staging file…", self._stage_async(path))

    @Slot(str)
    def unstage(self, path: str) -> None:
        self._run_action("Unstaging file…", self._unstage_async(path))

    @Slot(str)
    def discard(self, path: str) -> None:
        self._run_action("Discarding changes…", self._discard_async(path))

    @Slot(str, bool)
    def showDiff(self, path: str, staged: bool = False) -> None:
        self._diff_path = path or ""
        self._diff_staged = bool(staged)
        self._diff_text = ""
        self._diff_error = ""
        self.diffChanged.emit()
        if not self._diff_path:
            return
        self._set_diff_loading(True)
        schedule(self._show_diff_async(self._diff_path, self._diff_staged))

    @Slot()
    def clearDiff(self) -> None:
        if not (self._diff_path or self._diff_text or self._diff_error or self._diff_loading):
            return
        self._diff_path = ""
        self._diff_text = ""
        self._diff_error = ""
        self._diff_staged = False
        self._set_diff_loading(False)
        self.diffChanged.emit()

    @Property(str, notify=statusChanged)
    def root(self) -> str:
        return self._root

    @Property(str, notify=statusChanged)
    def branch(self) -> str:
        return self._branch

    @Property(str, notify=statusChanged)
    def upstream(self) -> str:
        return self._upstream

    @Property(int, notify=statusChanged)
    def ahead(self) -> int:
        return self._ahead

    @Property(int, notify=statusChanged)
    def behind(self) -> int:
        return self._behind

    @Property("QVariantList", notify=statusChanged)
    def files(self) -> list[dict]:
        return list(self._files)

    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        return self._loading

    @Property(str, notify=messageChanged)
    def message(self) -> str:
        return self._message

    @Property(str, notify=diffChanged)
    def diffPath(self) -> str:
        return self._diff_path

    @Property(str, notify=diffChanged)
    def diffTitle(self) -> str:
        if not self._diff_path:
            return "Diff Preview"
        mode = "Staged" if self._diff_staged else "Working Tree"
        return f"{mode} · {self._diff_path.rsplit('/', 1)[-1]}"

    @Property(str, notify=diffChanged)
    def diffText(self) -> str:
        return self._diff_text

    @Property(str, notify=diffChanged)
    def diffError(self) -> str:
        return self._diff_error

    @Property(bool, notify=diffChanged)
    def diffStaged(self) -> bool:
        return self._diff_staged

    @Property(bool, notify=diffLoadingChanged)
    def diffLoading(self) -> bool:
        return self._diff_loading

    @Property(int, notify=statusChanged)
    def changedCount(self) -> int:
        return len(self._files)

    @Property(int, notify=statusChanged)
    def stagedCount(self) -> int:
        return len([item for item in self._files if item.get("section") == "staged"])

    @Property(int, notify=statusChanged)
    def unstagedCount(self) -> int:
        return len([item for item in self._files if item.get("section") == "unstaged"])

    @Property(int, notify=statusChanged)
    def untrackedCount(self) -> int:
        return len([item for item in self._files if item.get("section") == "untracked"])

    async def _refresh_async(self, generation: int) -> None:
        try:
            status = await self._service.status(self._workspace)
            if generation != self._generation:
                return
            self._apply_status(status)
        finally:
            if generation == self._generation:
                self._set_loading(False)

    async def _stage_async(self, path: str) -> None:
        await self._service.stage(self._workspace, path)
        self.refresh()

    async def _unstage_async(self, path: str) -> None:
        await self._service.unstage(self._workspace, path)
        self.refresh()

    async def _discard_async(self, path: str) -> None:
        await self._service.discard(self._workspace, path)
        self.refresh()

    async def _show_diff_async(self, path: str, staged: bool) -> None:
        try:
            item = next((file for file in self._files if file.get("path") == path), None)
            if item and item.get("section") == "untracked" and not staged:
                self._diff_text = ""
                self._diff_error = "Untracked files do not have a working-tree diff yet. Stage the file to preview its first diff."
            else:
                diff = await self._service.diff(self._workspace, path, staged)
                self._diff_text = diff or "No diff available for this file."
                self._diff_error = ""
        except Exception as exc:
            self._diff_text = ""
            self._diff_error = str(exc)
            if self._notification_vm:
                self._notification_vm.error("Diff Preview", str(exc), 4200)
        finally:
            self._set_diff_loading(False)
            self.diffChanged.emit()

    def _run_action(self, busy_message: str, coro) -> None:
        self._set_message(busy_message)
        schedule(self._run_action_async(coro))

    async def _run_action_async(self, coro) -> None:
        try:
            await coro
        except Exception as exc:
            self._set_message(str(exc))
            if self._notification_vm:
                self._notification_vm.error("Source Control", str(exc), 4200)

    def _apply_status(self, status: GitStatus) -> None:
        self._root = status.root
        self._branch = status.branch if status.branch and status.branch != "(detached)" else "detached"
        self._upstream = status.upstream
        self._ahead = status.ahead
        self._behind = status.behind
        self._files = [
            {
                "path": item.path,
                "name": item.path.rsplit("/", 1)[-1],
                "index": item.index,
                "worktree": item.worktree,
                "section": item.section,
                "absolutePath": f"{status.root}/{item.path}" if status.root else item.path,
            }
            for item in (status.files or [])
        ]
        if status.error:
            self._set_message(status.error)
        elif not self._files:
            self._set_message(f"{self._branch or 'Repository'} clean")
        else:
            self._set_message(f"{len(self._files)} change(s)")
        self.statusChanged.emit()
        if self._events:
            schedule(self._events.emit("git:statusChanged", status=self.status_payload()))

    def status_payload(self) -> dict:
        return {
            "root": self._root,
            "branch": self._branch,
            "upstream": self._upstream,
            "ahead": self._ahead,
            "behind": self._behind,
            "files": list(self._files),
        }

    def _set_loading(self, value: bool) -> None:
        if self._loading == value:
            return
        self._loading = value
        self.loadingChanged.emit()

    def _set_message(self, value: str) -> None:
        if self._message == value:
            return
        self._message = value
        self.messageChanged.emit()

    def _set_diff_loading(self, value: bool) -> None:
        if self._diff_loading == value:
            return
        self._diff_loading = value
        self.diffLoadingChanged.emit()
