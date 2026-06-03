from __future__ import annotations

import asyncio

from PySide6.QtGui import QGuiApplication
from PySide6.QtCore import QObject, Property, Signal, Slot

from app.core.async_tasks import schedule
from app.core.events import EventBus
from app.services.search_service import SearchOptions, SearchService


class SearchViewModel(QObject):
    queryChanged = Signal()
    resultsChanged = Signal()
    loadingChanged = Signal()
    messageChanged = Signal()
    providersChanged = Signal()
    optionsChanged = Signal()

    def __init__(
        self,
        events: EventBus | None = None,
        service: SearchService | None = None,
        parent: QObject | None = None,
    ):
        super().__init__(parent)
        self._events = events
        self._service = service or SearchService()
        self._plugin_manager = None
        self._notification_vm = None
        self._workspace = ""
        self._provider_id = "core.python"
        self._case_sensitive = False
        self._regex = False
        self._include_hidden = False
        self._max_results = 500
        self._max_file_size = 512_000
        self._exclude_patterns: tuple[str, ...] = ()
        self._query = ""
        self._results: list[dict] = []
        self._loading = False
        self._message = "Ready"
        self._generation = 0
        self._cancel_event: asyncio.Event | None = None
        if self._events:
            self._events.on("file:external_change", self._on_external_file_change)

    def set_notification_vm(self, notification_vm) -> None:
        self._notification_vm = notification_vm

    def set_plugin_manager(self, manager) -> None:
        self._plugin_manager = manager
        self.providersChanged.emit()

    @Slot(str)
    def setWorkspace(self, path: str) -> None:
        self._workspace = path or ""
        if not self._workspace:
            self.clear()

    @Property(str, notify=queryChanged)
    def query(self) -> str:
        return self._query

    @Property("QVariantList", notify=resultsChanged)
    def results(self) -> list[dict]:
        return list(self._results)

    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        return self._loading

    @Property(str, notify=messageChanged)
    def message(self) -> str:
        return self._message

    @Property(str, notify=providersChanged)
    def providerId(self) -> str:
        return self._provider_id

    @Property("QVariantList", notify=providersChanged)
    def providers(self) -> list[dict]:
        if self._plugin_manager:
            return self._plugin_manager.get_search_provider_options()
        return [{
            "id": "core.python",
            "name": "core.python",
            "label": "Core Python Search",
            "plugin": "core",
            "providerType": "python",
            "capabilities": ["text", "workspace", "cancel"],
        }]

    @Slot(result="QVariantList")
    def getProviders(self) -> list[dict]:
        return self.providers

    @Slot(str)
    def setProvider(self, provider_id: str) -> None:
        next_provider = (provider_id or "core.python").strip() or "core.python"
        if self._provider_id == next_provider:
            return
        self._provider_id = next_provider
        self.providersChanged.emit()

    @Property(bool, notify=optionsChanged)
    def caseSensitive(self) -> bool:
        return self._case_sensitive

    @Property(bool, notify=optionsChanged)
    def regex(self) -> bool:
        return self._regex

    @Property(bool, notify=optionsChanged)
    def includeHidden(self) -> bool:
        return self._include_hidden

    @Slot(bool)
    def setCaseSensitive(self, value: bool) -> None:
        self._set_option("case", bool(value))

    @Slot(bool)
    def setRegex(self, value: bool) -> None:
        self._set_option("regex", bool(value))

    @Slot(bool)
    def setIncludeHidden(self, value: bool) -> None:
        self._set_option("hidden", bool(value))

    @Slot("QVariantMap")
    def applySettings(self, config: dict) -> None:
        config = dict(config or {})
        self._provider_id = str(config.get("provider") or self._provider_id or "core.python")
        self._case_sensitive = bool(config.get("caseSensitive", self._case_sensitive))
        self._regex = bool(config.get("regex", self._regex))
        self._include_hidden = bool(config.get("includeHidden", self._include_hidden))
        self._max_results = max(10, min(10000, int(config.get("maxResults", self._max_results))))
        self._max_file_size = max(
            1024,
            min(50_000_000, int(config.get("maxFileSize", self._max_file_size))),
        )
        self._exclude_patterns = tuple(str(item).strip() for item in config.get("exclude", []) if str(item).strip())
        self.providersChanged.emit()
        self.optionsChanged.emit()

    @Slot(str)
    def search(self, query: str) -> None:
        self._query = query or ""
        self.queryChanged.emit()
        self._generation += 1
        generation = self._generation
        if self._cancel_event:
            self._cancel_event.set()
        self._cancel_event = asyncio.Event()
        if len(self._query.strip()) < 2:
            self._set_results([], "Type at least 2 characters")
            self._set_loading(False)
            return
        if not self._workspace:
            self._set_results([], "Open a folder to search")
            self._set_loading(False)
            return
        self._set_loading(True)
        self._set_message("Searching…")
        schedule(self._search_async(self._query, generation, self._cancel_event))

    @Slot()
    def cancel(self) -> None:
        self._generation += 1
        if self._cancel_event:
            self._cancel_event.set()
        self._set_loading(False)
        self._set_message("Search cancelled")

    @Slot()
    def clear(self) -> None:
        self._generation += 1
        if self._cancel_event:
            self._cancel_event.set()
        self._query = ""
        self.queryChanged.emit()
        self._set_results([], "Ready")
        self._set_loading(False)

    @Slot(str)
    def copyPath(self, path: str) -> None:
        clipboard = QGuiApplication.clipboard()
        if clipboard:
            clipboard.setText(path or "")
        if self._notification_vm and path:
            self._notification_vm.success("Path copied", path, 1800)

    @Slot("QVariantMap")
    def emitResultAction(self, result: dict) -> None:
        payload = dict(result or {})
        if self._events:
            schedule(self._events.emit("search:result:open", payload))

    async def _search_async(self, query: str, generation: int, cancel_event: asyncio.Event) -> None:
        try:
            provider = self._provider()
            provider_type = str(provider.get("providerType") or "python").lower()
            options = SearchOptions(
                max_results=self._max_results,
                max_file_size=self._max_file_size,
                case_sensitive=self._case_sensitive,
                regex=self._regex,
                include_hidden=self._include_hidden,
                exclude=self._exclude_patterns,
            )
            if self._events:
                await self._events.emit(
                    "search:before",
                    {
                        "query": query,
                        "workspace": self._workspace,
                        "provider": provider,
                        "options": {
                            "caseSensitive": self._case_sensitive,
                            "regex": self._regex,
                            "includeHidden": self._include_hidden,
                            "maxResults": self._max_results,
                            "maxFileSize": self._max_file_size,
                        },
                    },
                )
            if provider_type == "ripgrep":
                results = await self._service.search_with_ripgrep(
                    self._workspace,
                    query,
                    options=options,
                    command=str(provider.get("command") or "rg"),
                    args=[str(arg) for arg in provider.get("args") or []],
                    cancel_event=cancel_event,
                )
            elif provider_type == "python":
                results = await self._service.search(
                    self._workspace,
                    query,
                    options=options,
                    cancel_event=cancel_event,
                )
            else:
                raise RuntimeError(f"Search provider type is not supported yet: {provider_type}")
        except Exception as exc:
            if generation != self._generation:
                return
            self._set_loading(False)
            self._set_results([], f"Search failed: {exc}")
            if self._notification_vm:
                self._notification_vm.error("Search failed", str(exc), 5200)
            return
        if generation != self._generation or cancel_event.is_set():
            return
        count = len(results)
        self._set_results(results, f"{count} result{'s' if count != 1 else ''}")
        self._set_loading(False)
        if self._events:
            await self._events.emit(
                "search:after",
                {
                    "query": query,
                    "workspace": self._workspace,
                    "provider": self._provider(),
                    "resultCount": count,
                    "results": results[:50],
                },
            )

    def _provider(self) -> dict:
        for provider in self.providers:
            provider_id = str(provider.get("id") or provider.get("name") or "")
            if provider_id == self._provider_id:
                return dict(provider)
        return {"id": "core.python", "providerType": "python"}

    def _set_option(self, key: str, value: bool) -> None:
        changed = False
        if key == "case" and self._case_sensitive != value:
            self._case_sensitive = value
            changed = True
        elif key == "regex" and self._regex != value:
            self._regex = value
            changed = True
        elif key == "hidden" and self._include_hidden != value:
            self._include_hidden = value
            changed = True
        if not changed:
            return
        self.optionsChanged.emit()
        if self._query.strip():
            self.search(self._query)

    def _set_results(self, results: list[dict], message: str) -> None:
        self._results = results
        self.resultsChanged.emit()
        self._set_message(message)

    def _on_external_file_change(self, path: str = "") -> None:
        if not self._workspace or not self._query.strip() or self._loading:
            return
        try:
            import os
            workspace = os.path.abspath(self._workspace)
            changed = os.path.abspath(path or "")
            if os.path.commonpath([workspace, changed]) != workspace:
                return
        except ValueError:
            return
        self.search(self._query)

    def _set_loading(self, value: bool) -> None:
        value = bool(value)
        if self._loading == value:
            return
        self._loading = value
        self.loadingChanged.emit()

    def _set_message(self, message: str) -> None:
        if self._message == message:
            return
        self._message = message
        self.messageChanged.emit()
