from __future__ import annotations

from PySide6.QtCore import QObject, Signal, Slot, Property


class PanelViewModel(QObject):
    panelsChanged = Signal()
    activeBottomPanelChanged = Signal(int)
    activeRightPanelChanged = Signal(int)

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)
        self._manager = None
        self._active_bottom_panel = 0
        self._active_right_panel = 0
        self._core_bottom_panels = [
            {
                "id": "core.terminal",
                "label": "TERMINAL",
                "title": "Terminal",
                "icon": "terminal",
                "component": "TerminalPanel",
                "location": "bottom",
                "source": "core",
                "order": 100,
                "badge": 0,
            },
            {
                "id": "core.problems",
                "label": "PROBLEMS",
                "title": "Problems",
                "icon": "warning",
                "component": "ProblemsPanel",
                "location": "bottom",
                "source": "core",
                "order": 200,
                "badge": 0,
            },
            {
                "id": "core.output",
                "label": "OUTPUT",
                "title": "Output",
                "icon": "syntax",
                "component": "OutputPanel",
                "location": "bottom",
                "source": "core",
                "order": 300,
                "badge": 0,
            },
            {
                "id": "core.console",
                "label": "CONSOLE",
                "title": "Console",
                "icon": "chevron-right",
                "component": "ConsolePanel",
                "location": "bottom",
                "source": "core",
                "order": 500,
                "badge": 0,
            },
            {
                "id": "core.actions",
                "label": "ACTIONS",
                "title": "Actions",
                "icon": "bolt",
                "component": "ActionsPanel",
                "location": "bottom",
                "source": "core",
                "order": 400,
                "badge": 0,
            },
            {
                "id": "core.references",
                "label": "REFERENCES",
                "title": "References",
                "icon": "link",
                "component": "ReferencesPanel",
                "location": "bottom",
                "source": "core",
                "order": 450,
                "badge": 0,
            },
        ]
        self._core_right_panels = [
            {
                "id": "core.outline",
                "label": "OUTLINE",
                "title": "Outline",
                "icon": "syntax",
                "component": "OutlinePanel",
                "location": "right",
                "source": "core",
                "order": 100,
                "badge": 0,
            },
        ]
        self._core_sidebar_views = [
            {
                "id": "core.explorer",
                "label": "EXPLORER",
                "title": "Explorer",
                "icon": "folder",
                "component": "FileExplorer",
                "location": "sidebar",
                "source": "core",
                "order": 100,
            },
            {
                "id": "core.search",
                "label": "SEARCH",
                "title": "Search",
                "icon": "search",
                "component": "SearchPanel",
                "location": "sidebar",
                "source": "core",
                "order": 200,
            },
            {
                "id": "core.scm",
                "label": "SOURCE CONTROL",
                "title": "Source Control",
                "icon": "git-branch",
                "component": "SourceControlPanel",
                "location": "sidebar",
                "source": "core",
                "order": 300,
            },
            {
                "id": "core.debug",
                "label": "RUN",
                "title": "Run and Debug",
                "icon": "debug",
                "component": "DebugPanel",
                "location": "sidebar",
                "source": "core",
                "order": 400,
            },
            {
                "id": "core.extensions",
                "label": "EXTENSIONS",
                "title": "Extensions",
                "icon": "extensions",
                "component": "ExtensionsPanel",
                "location": "sidebar",
                "source": "core",
                "order": 500,
            },
        ]

    def set_manager(self, manager) -> None:
        self._manager = manager
        self.panelsChanged.emit()

    def refresh(self) -> None:
        self.panelsChanged.emit()

    def _panels_for(self, location: str) -> list[dict]:
        core_panels = self._core_bottom_panels + self._core_right_panels
        panels = [dict(panel) for panel in core_panels if panel["location"] == location]
        if self._manager:
            for panel in self._manager.get_panels(location):
                payload = dict(panel)
                payload["dynamic"] = True
                panels.append(payload)
        return sorted(panels, key=lambda item: (int(item.get("order", 999)), str(item.get("id", ""))))

    def _views_for(self, location: str) -> list[dict]:
        disabled = self._manager.get_disabled_views() if self._manager else set()
        view_by_id = {
            view["id"]: dict(view)
            for view in self._core_sidebar_views
            if view["location"] == location and view["id"] not in disabled
        }
        extra_views: list[dict] = []
        if self._manager:
            for view in self._manager.get_views(location):
                payload = dict(view)
                payload["dynamic"] = True
                replaced_id = payload.get("replaces")
                if replaced_id:
                    payload["id"] = replaced_id
                    payload["replacement"] = True
                    view_by_id[replaced_id] = payload
                else:
                    extra_views.append(payload)
        views = list(view_by_id.values()) + extra_views
        return sorted(views, key=lambda item: (int(item.get("order", 999)), str(item.get("id", ""))))

    @Property("QVariantList", notify=panelsChanged)
    def bottomPanels(self) -> list[dict]:
        return self._panels_for("bottom")

    @Property("QVariantList", notify=panelsChanged)
    def rightPanels(self) -> list[dict]:
        return self._panels_for("right")

    @Property("QVariantList", notify=panelsChanged)
    def sidebarViews(self) -> list[dict]:
        return self._views_for("sidebar")

    @Property(int, notify=activeBottomPanelChanged)
    def activeBottomPanel(self) -> int:
        return self._active_bottom_panel

    @Slot(int)
    def setActiveBottomPanel(self, index: int) -> None:
        panels = self.bottomPanels
        if not panels:
            index = 0
        else:
            index = max(0, min(len(panels) - 1, int(index)))
        if self._active_bottom_panel == index:
            return
        self._active_bottom_panel = index
        self.activeBottomPanelChanged.emit(index)

    @Property(int, notify=activeRightPanelChanged)
    def activeRightPanel(self) -> int:
        return self._active_right_panel

    @Slot(int)
    def setActiveRightPanel(self, index: int) -> None:
        panels = self.rightPanels
        if not panels:
            index = 0
        else:
            index = max(0, min(len(panels) - 1, int(index)))
        if self._active_right_panel == index:
            return
        self._active_right_panel = index
        self.activeRightPanelChanged.emit(index)
