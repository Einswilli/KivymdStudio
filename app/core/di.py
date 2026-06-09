from __future__ import annotations

from app.core.events import EventBus
from app.services.project_service import ProjectService
from app.services.workspace_service import WorkspaceService
from app.services.action_service import ActionService
from app.viewmodels.editor_vm import EditorViewModel
from app.viewmodels.file_vm import FileViewModel
from app.viewmodels.terminal_vm import TerminalViewModel
from app.viewmodels.plugin_vm import PluginViewModel
from app.viewmodels.status_vm import StatusViewModel
from app.viewmodels.settings_vm import SettingsViewModel
from app.viewmodels.chat_vm import ChatViewModel
from app.viewmodels.command_vm import CommandViewModel
from app.viewmodels.notification_vm import NotificationViewModel
from app.viewmodels.project_vm import ProjectViewModel
from app.viewmodels.ui_vm import UiViewModel
from app.viewmodels.panel_vm import PanelViewModel
from app.viewmodels.search_vm import SearchViewModel
from app.viewmodels.action_vm import ActionViewModel
from app.viewmodels.source_control_vm import SourceControlViewModel


class ServiceProvider:
    def __init__(self):
        self.events = EventBus()
        self.workspace_service = WorkspaceService()
        self.project_service = ProjectService(self.workspace_service)
        self.action_service = ActionService(self.events)

        self.editor_vm = EditorViewModel(self.events)
        self.file_vm = FileViewModel(self.events, self.workspace_service)
        self.project_vm = ProjectViewModel(self.events, self.project_service)
        self.terminal_vm = TerminalViewModel(self.events)
        self.plugin_vm = PluginViewModel(self.events)
        self.settings_vm = SettingsViewModel(self.events)
        self.status_vm = StatusViewModel(self.events)
        self.notification_vm = NotificationViewModel()
        self.chat_vm = ChatViewModel(self.events)
        self.command_vm = CommandViewModel(self.events)
        self.action_vm = ActionViewModel(self.action_service)
        self.ui_vm = UiViewModel(self.events, self.settings_vm)
        self.panel_vm = PanelViewModel()
        self.search_vm = SearchViewModel(self.events)
        self.source_control_vm = SourceControlViewModel(self.events)
        self.notification_vm.configure(self.settings_vm.getNotificationsConfig())
        self.action_service.set_history_limit(self.settings_vm.auditRetention)

        self.editor_vm.set_notification_vm(self.notification_vm)
        self.file_vm.set_notification_vm(self.notification_vm)
        self.file_vm.set_plugin_vm(self.plugin_vm)
        self.file_vm.set_settings_vm(self.settings_vm)
        self.search_vm.set_notification_vm(self.notification_vm)
        self.source_control_vm.set_notification_vm(self.notification_vm)
        self.search_vm.applySettings(self.settings_vm.getSearchConfig())
        self.settings_vm.set_notification_vm(self.notification_vm)
        self.editor_vm.set_settings_vm(self.settings_vm)
        self.editor_vm.set_plugin_vm(self.plugin_vm)
        self.terminal_vm.set_settings_service(self.settings_vm.settings_service)
        self.action_vm.set_notification_vm(self.notification_vm)
        self.action_vm.set_status_vm(self.status_vm)
        self.action_vm.set_command_vm(self.command_vm)
        self.action_vm.set_plugin_vm(self.plugin_vm)
        self.action_vm.set_editor_vm(self.editor_vm)
        self.action_vm.set_file_vm(self.file_vm)
        self.action_vm.set_search_vm(self.search_vm)
        self.action_vm.set_settings_vm(self.settings_vm)

        self.editor_vm.diagnosticsReady.connect(self.status_vm.set_diagnostics_from_list)
        self.editor_vm.lspStatusReady.connect(self.status_vm.set_lsp_status)
        self.file_vm.folderChanged.connect(self.settings_vm.setProjectPath)
        self.file_vm.folderChanged.connect(self.terminal_vm.set_cwd)
        self.file_vm.folderChanged.connect(self.search_vm.setWorkspace)
        self.file_vm.folderChanged.connect(self.source_control_vm.setWorkspace)
        self.settings_vm.searchConfigChanged.connect(self.search_vm.applySettings)
        self.settings_vm.notificationsChanged.connect(self.notification_vm.configure)
        self.settings_vm.notificationsChanged.connect(
            lambda config: self.action_service.set_history_limit(config.get("auditRetention", 200))
        )
        self.plugin_vm.contributionsChanged.connect(self.panel_vm.refresh)
        self.command_vm.commandExecuted.connect(lambda command: self.status_vm.append_console("success", f"Executed {command}"))
        self.command_vm.commandFailed.connect(lambda command, error: self.status_vm.append_console("error", f"{command}: {error}"))
