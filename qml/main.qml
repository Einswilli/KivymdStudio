import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "settings"
import "components"
import "editor"
import "terminal"
import "filebrowser"
import "panels"
import "sidebar/fallbacks"

ApplicationWindow {
    id: root
    width: 1200; height: 800; visible: true; title: "Ember"

    property var theme: DesignTokens.darkTheme
        property var tokenColors: DesignTokens.tokenColors
            readonly property var metrics: DesignTokens.metrics
                property font uiFont: Qt.font({
                    family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter",
                    pointSize: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontSize : 12
                })
                font: uiFont

                property string currentFolder: ""
                    property bool activityBarOpen: true
                        property bool sidebarOpen: true
                            property bool panelOpen: false
                                property bool rightPanelOpen: false
                                    property int sidebarWidth: 280
                                        property int panelHeight: 240
                                            property int rightPanelWidth: 320
                                                property int activeActivity: 0
                                                    property int activePanelTab: 0
                                                    property var bottomPanels: (typeof PanelVM !== "undefined" && PanelVM) ? PanelVM.bottomPanels : [
                                                        {id:"core.terminal", label:"TERMINAL", icon:"terminal", component:"TerminalPanel"},
                                                        {id:"core.problems", label:"PROBLEMS", icon:"warning", component:"ProblemsPanel"},
                                                        {id:"core.output", label:"OUTPUT", icon:"syntax", component:"OutputPanel"},
                                                        {id:"core.actions", label:"ACTIONS", icon:"bolt", component:"ActionsPanel"},
                                                        {id:"core.console", label:"CONSOLE", icon:"chevron-right", component:"ConsolePanel"}
                                                    ]
                                                    property var rightPanels: (typeof PanelVM !== "undefined" && PanelVM) ? PanelVM.rightPanels : []
                                                    property int activeRightPanelTab: 0
                                                    property var sidebarViews: (typeof PanelVM !== "undefined" && PanelVM) ? PanelVM.sidebarViews : [
                                                        {id:"core.explorer", label:"EXPLORER", title:"Explorer", icon:"folder", component:"FileExplorer"},
                                                        {id:"core.search", label:"SEARCH", title:"Search", icon:"search", component:"SearchPanel"},
                                                        {id:"core.scm", label:"SOURCE CONTROL", title:"Source Control", icon:"git-branch", component:"SourceControlPanel"},
                                                        {id:"core.debug", label:"RUN", title:"Run and Debug", icon:"debug", component:"DebugPanel"},
                                                        {id:"core.extensions", label:"EXTENSIONS", title:"Extensions", icon:"extensions", component:"ExtensionsPanel"}
                                                    ]
                                                        property var recentFiles: []
                                                        property var recentProjects: []
                                                        property var currentProject: ({})
                                                        property var runtimeKeybindings: []
                                                        property int cursorLine: 1
                                                            property int cursorCol: 1
                                                            property string externalChangedPath: ""
                                                            property string externalChangedName: ""
                                                            property bool externalChangedDirty: false
                                                            property string pendingProblemPath: ""
                                                            property int pendingProblemLine: 1
                                                            property int pendingProblemCol: 0
                                                            property int pendingProblemAttempts: 0
                                                            property bool pendingQuickFix: false
                                                            property string pendingRevealPath: ""
                                                            property int pendingRevealAttempts: 0
                                                            property string pendingSensitiveActionId: ""
                                                            property var pendingSensitiveAction: ({})

                                                                property int _dragFrom: -1

                                                                    color: theme.bg

                                                                    function _loadTheme() {
                                                                    var colors = null
                                                                    var tokens = null
                                                                    if (typeof SettingsVM !== 'undefined' && SettingsVM)
                                                                    {
                                                                        colors = SettingsVM.getThemeColors()
                                                                        tokens = SettingsVM.getTokenColors()
                                                                    }
                                                                    theme = DesignTokens.mergeTheme(colors)
                                                                    tokenColors = DesignTokens.mergeTokenColors(tokens)
                                                                }

                                                                function _loadRecent() {
                                                                if (typeof FileVM !== 'undefined' && FileVM) FileVM.loadHistory()
                                                                    }

                                                                Component.onCompleted: { _loadTheme(); _loadPluginAssets(); _syncWorkbenchSettings(); _loadRuntimeKeybindings(); _loadRecent(); FileVM.loadWorkspace(); EditorVM.loadEditorSession() }

                                                            function _loadPluginAssets() {
                                                                if (typeof PluginVM === "undefined" || !PluginVM)
                                                                    return
                                                                var providers = SettingsVM ? SettingsVM.getAppearanceProviders() : ({})
                                                                var iconProvider = providers.icons || "ember-default-theme"
                                                                var fileIconProvider = providers.fileIcons || "ember-file-icons"
                                                                var icons = PluginVM.getPluginIconsFor(iconProvider) || ({})
                                                                var fileProviderIcons = PluginVM.getPluginIconsFor(fileIconProvider) || ({})
                                                                for (var iconId in fileProviderIcons)
                                                                    icons[iconId] = fileProviderIcons[iconId]
                                                                IconRegistry.setIcons(icons)
                                                                IconRegistry.setFileIcons(PluginVM.getFileIconAssociationsFor(fileIconProvider))
                                                            }

                                                            Connections {
                                                                target: FileVM
                                                                function onHistoryChanged()
                                                                { root.recentFiles = FileVM.recentFiles }
                                                                    function onRecentProjectsChanged()
                                                                    { root.recentProjects = FileVM.recentProjects }
                                                                        function onProjectChanged(project)
                                                                        { root.currentProject = project || ({}) }
                                                                            function onFolderChanged(path)
                                                                            {
                                                                                root.currentFolder = path || ""
                                                                                if (typeof TerminalVM !== "undefined" && TerminalVM)
                                                                                    TerminalVM.set_cwd(root.currentFolder)
                                                                            }
                                                                                function onWorkspaceRestored(path)
                                                                                {
                                                                                    root.currentFolder = path || ""
                                                                                    root._setActiveSidebarView("core.explorer")
                                                                                    root._setSidebarOpen(!!path, false)
                                                                                    if (EditorVM)
                                                                                        EditorVM.switchWorkspaceSession(path || "")
                                                                                }
                                                                            }

                                                                            Connections {
                                                                                target: SettingsVM
                                                                                function onThemeChanged(colors)
                                                                                {
                                                                                    root.theme = DesignTokens.mergeTheme(colors)
                                                                                    root.tokenColors = DesignTokens.mergeTokenColors(SettingsVM.getTokenColors())
                                                                                    root._loadPluginAssets()
                                                                                }
                                                                                function onConfigChanged(config)
                                                                                {
                                                                                    root._loadRuntimeKeybindings()
                                                                                }
                                                                                function onKeybindingsChanged()
                                                                                {
                                                                                    root._loadRuntimeKeybindings()
                                                                                }
                                                                                function onWorkbenchChanged()
                                                                                {
                                                                                    root._syncWorkbenchSettings()
                                                                                }
                                                                            }

                                                                            Connections {
                                                                                target: PluginVM
                                                                                function onContributionsChanged()
                                                                                {
                                                                                    root._loadPluginAssets()
                                                                                    root._loadRuntimeKeybindings()
                                                                                    root.bottomPanels = (typeof PanelVM !== "undefined" && PanelVM) ? PanelVM.bottomPanels : root.bottomPanels
                                                                                    root.rightPanels = (typeof PanelVM !== "undefined" && PanelVM) ? PanelVM.rightPanels : root.rightPanels
                                                                                    root.sidebarViews = (typeof PanelVM !== "undefined" && PanelVM) ? PanelVM.sidebarViews : root.sidebarViews
                                                                                    root._setActivePanelTab(root.activePanelTab)
                                                                                }
                                                                            }

                                                                            Connections {
                                                                                target: PanelVM
                                                                                function onPanelsChanged()
                                                                                {
                                                                                    root.bottomPanels = PanelVM.bottomPanels
                                                                                    root.rightPanels = PanelVM.rightPanels
                                                                                    root.sidebarViews = PanelVM.sidebarViews
                                                                                    root._setActivePanelTab(root.activePanelTab)
                                                                                    root._setActiveRightPanelTab(root.activeRightPanelTab)
                                                                                }
                                                                            }

                                                                            Connections {
                                                                                target: ProjectVM
                                                                                function onProjectChanged(project)
                                                                                {
                                                                                    var path = project && project.path ? project.path : ""
                                                                                    if (path)
                                                                                        root._activateFolder(path, true)
                                                                                }
                                                                            }

                                                                            Connections {
                                                                                target: EditorVM
                                                                                function onCurrentTabChanged(index)
                                                                                {
                                                                                    root._switchToTab(index)
                                                                                }
                                                                                function onExternalFileChanged(payload)
                                                                                {
                                                                                    if (!payload || !payload.path) return
                                                                                    root.externalChangedPath = payload.path || ""
                                                                                    root.externalChangedName = payload.name || root.externalChangedPath
                                                                                    root.externalChangedDirty = !!payload.dirty
                                                                                    externalFileDialog.open()
                                                                                }
                                                                                function onReferencesReady(locations)
                                                                                {
                                                                                    if (locations && locations.length > 0)
                                                                                        root._openReferencesPanel()
                                                                                }
                                                                                function onSymbolsReady(symbols)
                                                                                {
                                                                                    if (root.rightPanelOpen && symbols && symbols.length > 0)
                                                                                        root._openOutlinePanel()
                                                                                }
                                                                                function onNavigationReady(location)
                                                                                {
                                                                                    root._openEditorLocation(location)
                                                                                }
                                                                            }

                                                                            function _updateCursor() {
                                                                            root.cursorLine = editorWorkspace.cursorLine
                                                                            root.cursorCol = editorWorkspace.cursorCol
                                                                        }

                                                                        function _syncWorkbenchSettings() {
                                                                        if (typeof SettingsVM === "undefined" || !SettingsVM) return
                                                                        root.activityBarOpen = SettingsVM.activityBarVisible
                                                                        root.sidebarOpen = SettingsVM.sidebarVisible
                                                                        root.panelOpen = SettingsVM.panelVisible
                                                                        root.rightPanelOpen = SettingsVM.rightPanelVisible
                                                                        root.sidebarWidth = SettingsVM.sidebarWidth
                                                                        root.panelHeight = root._boundedPanelHeight(SettingsVM.panelHeight)
                                                                        root.rightPanelWidth = SettingsVM.rightPanelWidth
                                                                    }

                                                                    function _maxPanelHeight() {
                                                                    return Math.max(160, Math.round(root.height * 0.80))
                                                                }

                                                                function _boundedPanelHeight(value) {
                                                                return Math.max(120, Math.min(root._maxPanelHeight(), Math.round(value || 240)))
                                                            }

                                                            function _defaultRuntimeKeybindings() {
                                                            return [
                                                            { "key": "Ctrl+Shift+P", "command": "view.command_palette", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+O", "command": "file.open", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+N", "command": "file.new", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+K", "command": "file.open_folder", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+S", "command": "file.save", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+W", "command": "file.close", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+B", "command": "view.sidebar", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+, ", "command": "settings.open", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+J", "command": "view.terminal", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+Shift+E", "command": "view.explorer", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+Shift+F", "command": "view.search", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+Shift+G", "command": "view.scm", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+=", "command": "view.zoom_in", "source": "core", "plugin": "core", "when": "global", "active": true },
                                                            { "key": "Ctrl+-", "command": "view.zoom_out", "source": "core", "plugin": "core", "when": "global", "active": true }
                                                            ]
                                                        }

                                                        function _isRuntimeShortcut(binding) {
                                                        if (!binding || binding.active === false)
                                                            return false
                                                        var sequence = binding.key || ""
                                                        var command = binding.command || ""
                                                        if (sequence.length === 0 || command.length === 0)
                                                            return false
                                                        if (command.indexOf("edit.") === 0 || command.indexOf("editor.") === 0)
                                                            return false
                                                        return true
                                                    }

                                                    function _loadRuntimeKeybindings() {
                                                    var bindings = []
                                                    if (typeof PluginVM !== "undefined" && PluginVM)
                                                        bindings = PluginVM.getResolvedKeybindings()
                                                    if (!bindings || bindings.length === 0)
                                                        bindings = _defaultRuntimeKeybindings()

                                                    var runtime = []
                                                    var seen = ({})
                                                    for (var i = 0; i < bindings.length; i++) {
                                                        var item = bindings[i]
                                                        if (!_isRuntimeShortcut(item))
                                                            continue
                                                        var key = (item.key || "") + "::" + (item.when || "global")
                                                        if (seen[key])
                                                            continue
                                                        seen[key] = true
                                                        runtime.push(item)
                                                    }
                                                    root.runtimeKeybindings = runtime
                                                }

                                                function _setActivityBarOpen(value, persist) {
                                                root.activityBarOpen = !!value
                                                if (persist !== false && typeof SettingsVM !== "undefined" && SettingsVM)
                                                    SettingsVM.setActivityBarVisible(root.activityBarOpen)
                                            }

                                            function _setSidebarOpen(value, persist) {
                                            root.sidebarOpen = !!value
                                            if (persist !== false && typeof SettingsVM !== "undefined" && SettingsVM)
                                                SettingsVM.setSidebarVisible(root.sidebarOpen)
                                        }

                                        function _setPanelOpen(value, persist) {
                                        root.panelOpen = !!value
                                        if (root.panelOpen)
                                            root.panelHeight = root._boundedPanelHeight(root.panelHeight)
                                        if (persist !== false && typeof SettingsVM !== "undefined" && SettingsVM)
                                            SettingsVM.setPanelVisible(root.panelOpen)
                                    }

                                    function _setPanelHeight(value, persist) {
                                    var nextHeight = root._boundedPanelHeight(value || root.panelHeight)
                                    if (Math.abs(root.panelHeight - nextHeight) < 1)
                                        return
                                    root.panelHeight = nextHeight
                                    if (persist !== false)
                                        panelHeightSaveTimer.restart()
                                }

                            function _setActivePanelTab(index) {
                                var maxIndex = Math.max(0, root.bottomPanels.length - 1)
                                root.activePanelTab = Math.max(0, Math.min(maxIndex, index))
                                if (typeof PanelVM !== "undefined" && PanelVM)
                                    PanelVM.setActiveBottomPanel(root.activePanelTab)
                                if ((root.bottomPanels[root.activePanelTab] || {}).component === "TerminalPanel")
                                    Qt.callLater(root._activateCurrentPanel)
                            }

                            function _toggleTerminalPanel() {
                            root._setActivePanelTab(0)
                            root._setPanelOpen(!root.panelOpen)
                        }

	function _activateCurrentPanel() {
	if (!panelRepeater)
	    return
	var loader = panelRepeater.itemAt(root.activePanelTab)
	if (loader && loader.item && loader.item.activateTerminal)
	    loader.item.activateTerminal()
}

function _sidebarViewIndex(viewId) {
    for (var i = 0; i < root.sidebarViews.length; i++) {
        if ((root.sidebarViews[i] || {}).id === viewId)
            return i
    }
    return -1
}

function _setActiveSidebarView(viewId) {
    var index = root._sidebarViewIndex(viewId)
    if (index >= 0)
        root.activeActivity = index
}

function _revealInExplorer(path) {
    if (!path) return
    if (root.currentFolder && path !== root.currentFolder && !path.startsWith(root.currentFolder + "/"))
        return
    root.pendingRevealPath = path
    root.pendingRevealAttempts = 0
    root._setActiveSidebarView("core.explorer")
    root._setSidebarOpen(true)
    revealInExplorerTimer.restart()
}

function _openProblemLocation(problem) {
    if (!problem || !problem.path) {
        if (NotificationVM) NotificationVM.warning("Problem action unavailable", "This diagnostic has no file path.", 3600)
        return
    }
    root.pendingProblemPath = problem.path
    root.pendingProblemLine = problem.line || 1
    root.pendingProblemCol = problem.col || 0
    root.pendingProblemAttempts = 0
    root.pendingQuickFix = false
    root._openFileByPath(problem.path)
    root._revealInExplorer(problem.path)
    problemGotoTimer.restart()
}

function _openEditorLocation(location) {
    if (!location) return
    var path = location.path || ""
    var line = location.line || 1
    var col = location.col || 0
    if (EditorVM && editorWorkspace.filePath)
        EditorVM.pushNavigationLocation(editorWorkspace.filePath, editorWorkspace.cursorLine, Math.max(0, editorWorkspace.cursorCol - 1))
    if (path && path !== editorWorkspace.filePath) {
        root.pendingProblemPath = path
        root.pendingProblemLine = line
        root.pendingProblemCol = col
        root.pendingProblemAttempts = 0
        root.pendingQuickFix = false
        root._openFileByPath(path)
        problemGotoTimer.restart()
    } else {
        editorWorkspace.goToLocation(line, col)
    }
}

function _openReferencesPanel() {
    for (var i = 0; i < root.bottomPanels.length; i++) {
        if ((root.bottomPanels[i] || {}).component === "ReferencesPanel") {
            root._setActivePanelTab(i)
            root._setPanelOpen(true)
            return
        }
    }
}

function _openOutlinePanel() {
    for (var i = 0; i < root.rightPanels.length; i++) {
        if ((root.rightPanels[i] || {}).component === "OutlinePanel") {
            root._setActiveRightPanelTab(i)
            root._setRightPanelOpen(true, true)
            return
        }
    }
}

function _quickFixProblem(problem) {
    if (!problem || !problem.path) {
        if (NotificationVM) NotificationVM.warning("Quick Fix unavailable", "This diagnostic has no file path.", 3600)
        return
    }
    root._openProblemLocation(problem)
    root.pendingQuickFix = true
}

function _sidebarComponentFor(view) {
    var component = (view || {}).component || ""
    if (component === "FileExplorer") return _feComp
    if (component === "SearchPanel") return _srchComp
    if (component === "SourceControlPanel") return _gitComp
    if (component === "DebugPanel") return _dbgComp
    if (component === "ExtensionsPanel") return _extComp
    return pluginPanelHostComponent
}

function _setActiveRightPanelTab(index) {
                        var maxIndex = Math.max(0, root.rightPanels.length - 1)
                        root.activeRightPanelTab = Math.max(0, Math.min(maxIndex, index))
                        if (typeof PanelVM !== "undefined" && PanelVM)
                            PanelVM.setActiveRightPanel(root.activeRightPanelTab)
                    }

                        function _setRightPanelOpen(value, persist) {
                        root.rightPanelOpen = !!value
                        if (persist !== false && typeof SettingsVM !== "undefined" && SettingsVM)
                            SettingsVM.setRightPanelVisible(root.rightPanelOpen)
                    }

                    Timer {
                        id: panelHeightSaveTimer
                        interval: 250
                        repeat: false
                        onTriggered: {
                            if (typeof SettingsVM !== "undefined" && SettingsVM)
                                SettingsVM.setPanelHeight(root.panelHeight)
                        }
                    }

                    function _addTab(title, content) {
                    if (!EditorVM) return
                    var index = EditorVM.addTab(title, content)
                    _switchToTab(index)
                }

                function _moveTab(from, to) {
                if (!EditorVM) return
                EditorVM.moveTab(from, to)
            }

            function _closeTab(index) {
            if (!EditorVM) return
            EditorVM.closeTab(index)
        }

        function _switchToTab(index) {
        if (!EditorVM) return
        if (index < 0 || index >= EditorVM.tabCount()) return
        editorWorkspace.switchToTab(EditorVM.tabTitle(index), EditorVM.tabContent(index))
    }

    function _openFile() {
    var p = FileVM.openFileDialog()
    if (!p) return
    _openFileByPath(p)
}

function _openFileByPath(p) {
if (FileVM && FileVM.is_dir(p))
{
    _activateFolder(p, true)
    return
}
var n = EditorVM.get_filename(p)
_addTab(n, p)
if (FileVM && FileVM.notifyFileOpened)
    FileVM.notifyFileOpened(p)
}

function _activateFolder(p, resetEditors) {
if (!p || !FileVM || !FileVM.openFolder(p)) return false
if (resetEditors && EditorVM)
    EditorVM.switchWorkspaceSession(p)
root.currentFolder = p
root._setActiveSidebarView("core.explorer")
root._setSidebarOpen(true, false)
Qt.callLater(function() {
if (sidebarContent.item)
{
    sidebarContent.item.folder = root.currentFolder
    if (sidebarContent.item.refresh) sidebarContent.item.refresh()
        }
})
return true
}

function _openFolder() {
var p = FileVM.openFolderDialog()
if (!p) return
_activateFolder(p, true)
}

function _newFile() {
var p = FileVM.saveFileDialog()
if (!p) return
_addTab(EditorVM.get_filename(p), p)
}

function _saveFile() {
if (!editorWorkspace.editorVisible || !editorWorkspace.filePath) return
EditorVM.savefile(editorWorkspace.filePath, EditorVM.get_filename(editorWorkspace.filePath), editorWorkspace.plainText)
}

function _formatDocument() {
if (!editorWorkspace.editorVisible || !editorWorkspace.filePath) return
EditorVM.formatDocument(editorWorkspace.filePath, editorWorkspace.plainText)
}

function _aiAction(action) {
if (!editorWorkspace.editorVisible || !editorWorkspace.plainText) return
if (typeof ChatVM !== 'undefined' && ChatVM)
{
    var lang = EditorVM.getLanguage(editorWorkspace.filePath)
    if (action === "explain") ChatVM.explainCode(editorWorkspace.plainText, lang)
        else if (action === "refactor") ChatVM.refactorCode(editorWorkspace.plainText, lang)
    else if (action === "tests") ChatVM.generateTests(editorWorkspace.plainText, lang)
    }
}

function _resolveShortcut(sequence, fallbackCommand) {
if (typeof PluginVM !== "undefined" && PluginVM)
    return PluginVM.resolveKeybinding(sequence || "", fallbackCommand || "")
return fallbackCommand || ""
}

function _dispatchShortcut(commandId, sequence) {
if (typeof UiVM !== "undefined" && UiVM)
    UiVM.dispatchShortcut(commandId, sequence || "")
}

function _actionById(actionId) {
    var actions = (typeof ActionVM !== "undefined" && ActionVM) ? ActionVM.actions : []
    for (var i = 0; actions && i < actions.length; i++) {
        if ((actions[i].id || "") === actionId)
            return actions[i]
    }
    return null
}

function _runActionWithPolicy(actionId, payload) {
    if (!ActionVM || !actionId)
        return false
    var action = _actionById(actionId)
    if (!action)
        return false
    if (action.safeToRun === false) {
        if (NotificationVM)
            NotificationVM.error("Action blocked", "This action is not marked safe to run.")
        return true
    }
    var permissions = action.permissions || []
    if (permissions.length > 0 && actionId !== root.pendingSensitiveActionId) {
        root.pendingSensitiveActionId = actionId
        root.pendingSensitiveAction = action
        sensitiveActionDialog.open()
        return true
    }
    root.pendingSensitiveActionId = ""
    root.pendingSensitiveAction = ({})
    return ActionVM.runAction(actionId, payload || ({}))
}

function _runShortcut(sequence, fallbackCommand) {
var commandId = _resolveShortcut(sequence, fallbackCommand)
_executeShortcutCommand(commandId, sequence)
return commandId
}

function _runCoreShortcut(sequence, fallbackCommand) {
_runShortcut(sequence, fallbackCommand)
}

function _executeShortcutCommand(commandId, sequence) {
if (!commandId || commandId.length === 0)
    return
_dispatchShortcut(commandId, sequence || "")
if (_runActionWithPolicy(commandId, ({})))
    return
switch (commandId) {
    case "view.command_palette": commandPalette.open(); break
    case "file.open": _openFile(); break
    case "file.new": _newFile(); break
    case "file.open_folder": _openFolder(); break
    case "file.save": _saveFile(); break
    case "file.close": if (EditorVM && EditorVM.tabCount() > 0) _closeTab(EditorVM.currentTabIndex); break
    case "view.sidebar": root._setSidebarOpen(!root.sidebarOpen); break
    case "settings.open": _addTab("Settings", "settings"); break
    case "view.terminal": root._toggleTerminalPanel(); break
    case "view.explorer": root._setActiveSidebarView("core.explorer"); root._setSidebarOpen(true); break
    case "view.search": root._setActiveSidebarView("core.search"); root._setSidebarOpen(true); break
    case "view.scm": root._setActiveSidebarView("core.scm"); root._setSidebarOpen(true); break
    case "view.zoom_in":
    case "view.zoom_out":
    if (ActionVM && CommandVM && CommandVM.canExecuteCommand(commandId)) ActionVM.runAction("command.execute", {"command": commandId})
    else if (CommandVM) CommandVM.executeCommand(commandId)
        break
    default:
    if (ActionVM && CommandVM && CommandVM.canExecuteCommand(commandId)) ActionVM.runAction("command.execute", {"command": commandId})
    else if (CommandVM) CommandVM.executeCommand(commandId)
        }
}

Connections {
    target: editorWorkspace
    function onCursorPositionChanged()
    {
        root._updateCursor()
        sessionSaveTimer.restart()
    }
}

Connections {
    target: editorWorkspace
    function onIsDirtyChanged()
    {
        if (EditorVM && EditorVM.currentTabIndex >= 0)
            EditorVM.setTabDirty(EditorVM.currentTabIndex, editorWorkspace.isDirty)
    }
}

Timer {
    id: sessionSaveTimer
    interval: 800
    repeat: false
    onTriggered: {
        if (editorWorkspace.editorVisible)
            EditorVM.saveEditorSession(editorWorkspace.filePath, editorWorkspace.cursorLine, editorWorkspace.cursorCol)
    }
}

ColumnLayout {
    anchors.fill: parent; spacing: 0

    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 32
        color: theme.titleBar; z: 10
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 2
            ProjectSwitcher {
                theme: root.theme
                currentProject: root.currentProject
                recentProjects: root.recentProjects
                recentFiles: root.recentFiles
                onProjectSelected: function(path) { root._activateFolder(path, true) }
                onFileSelected: function(path) { root._openFileByPath(path) }
                onOpenFolderRequested: root._openFolder()
                onCopyPathRequested: function(path) {
                    if (ActionVM) ActionVM.runAction("file_browser.copy_link", {"path": path})
                    else if (FileVM) FileVM.copyLink(path)
                }
                onRevealPathRequested: function(path) {
                    if (!path || !FileVM) return
                    var folder = FileVM.is_dir(path) ? path : path.substring(0, path.lastIndexOf("/"))
                    if (folder) root._activateFolder(folder, false)
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: theme.border
                opacity: 0.7
            }

            Repeater {
                model: [
                {label:"File", menu:fileMenu}, {label:"Edit", menu:editMenu},
                {label:"View", menu:viewMenu}, {label:"Tools", menu:toolsMenu},
                {label:"Help", menu:helpMenu},
                ]
                delegate: UiMenuButton { text: modelData.label; menu: modelData.menu; theme: root.theme }
            }
            Item { Layout.fillWidth: true }

            Row {
                spacing: 2; Layout.rightMargin: 4
                UiIconButton { theme: root.theme; iconName: "layout-sidebar-left"; iconSize: 15; toggled: root.sidebarOpen; tooltip: root.sidebarOpen ? "Hide left sidebar" : "Show left sidebar"; onClicked: root._setSidebarOpen(!root.sidebarOpen) }
                UiIconButton { theme: root.theme; iconName: "panel-bottom"; iconSize: 15; toggled: root.panelOpen; tooltip: root.panelOpen ? "Hide bottom panel" : "Show bottom panel"; onClicked: root._toggleTerminalPanel() }
                UiIconButton { theme: root.theme; iconName: "panel-right"; iconSize: 15; toggled: root.rightPanelOpen; tooltip: root.rightPanelOpen ? "Hide right panel" : "Show right panel"; onClicked: root._setRightPanelOpen(!root.rightPanelOpen) }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

        ActivityBar {
            id: activityBar
            Layout.preferredWidth: root.activityBarOpen ? metrics.activityBarWidth : 0; Layout.fillHeight: true
            visible: root.activityBarOpen
            theme: root.theme; activeIndex: root.activeActivity
            items: root.sidebarViews
            sidebarOpen: root.sidebarOpen
            panelOpen: root.panelOpen
            rightPanelOpen: root.rightPanelOpen
            onSidebarToggleClicked: root._setSidebarOpen(!root.sidebarOpen)
            onTerminalToggleClicked: root._toggleTerminalPanel()
            onRightPanelToggleClicked: root._setRightPanelOpen(!root.rightPanelOpen)
            onItemClicked: function(index, id) {
            if (id === "settings")
            {
                root.activeActivity = -1
                _addTab("Settings", "settings")
            } else if (index === root.activeActivity && root.sidebarOpen) {
            root._setSidebarOpen(false)
        } else {
        root.activeActivity = index
        root._setSidebarOpen(true)
    }
}
}

SplitView {
    orientation: Qt.Horizontal
    Layout.fillWidth: true; Layout.fillHeight: true

    handle: UiSplitHandle { theme: root.theme; vertical: true }

    DockPanel {
        id: sidebar
        theme: root.theme
        open: root.sidebarOpen
        horizontal: true
        preferredSize: root.sidebarWidth
        minimumSize: 180
        maximumSize: 520
        color: theme.sidebar

        Loader {
            id: sidebarContent
            anchors.fill: parent
            property var activeView: root.sidebarViews[root.activeActivity] || ({})
            sourceComponent: root._sidebarComponentFor(activeView)
            function injectProps() {
                if (item && "theme" in item)
                    item.theme = root.theme
                if (item && "panel" in item)
                    item.panel = activeView
            }
            onLoaded: injectProps()
            Connections {
                target: root
                function onThemeChanged() { sidebarContent.injectProps() }
            }
        }
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true
        SplitView.minimumWidth: 360

        handle: UiSplitHandle { theme: root.theme; vertical: false }

        EditorWorkspace {
            id: editorWorkspace
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            SplitView.minimumHeight: 180
            theme: root.theme
            metrics: root.metrics
            tokenColors: root.tokenColors
            tabs: EditorVM ? EditorVM.tabs : []
            dirtyTabs: EditorVM ? EditorVM.dirtyTabs : []
            currentTabIndex: EditorVM ? EditorVM.currentTabIndex : -1
            recentFiles: root.recentFiles
            lineSpacing: SettingsVM ? SettingsVM.editorLineSpacing : 6
            onTabActivated: function(index) {
            EditorVM.setCurrentTab(index)
        }
        onTabCloseRequested: function(index) { root._closeTab(index) }
        onTabMoveRequested: function(from, to) { root._moveTab(from, to) }
        onOpenFileRequested: _openFile()
        onOpenFolderRequested: _openFolder()
        onNewFileRequested: _newFile()
        onOpenRecentRequested: function(path) { _openFileByPath(path) }
    }

    DockPanel {
        id: panelArea
        theme: root.theme
        open: root.panelOpen
        onOpenChanged: {
            if (open && (root.bottomPanels[root.activePanelTab] || {}).component === "TerminalPanel")
            Qt.callLater(root._activateCurrentPanel)
        }
        horizontal: false
        preferredSize: root.panelHeight
        minimumSize: 120
        maximumSize: root._maxPanelHeight()
        SplitView.fillHeight: false
        showTopBorder: true
        color: theme.panel || "#1E1E1E"

        ColumnLayout {
            anchors.fill: parent; spacing: 0

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: metrics.panelHeaderHeight; color: theme.panelHeader
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 0; anchors.rightMargin: 8; spacing: 0
                    ListView {
                        id: bottomPanelTabs
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        orientation: ListView.Horizontal
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.bottomPanels
                        delegate: UiPanelTab {
                            required property int index
                            required property var modelData
                            theme: root.theme
                            label: modelData.label
                            iconName: modelData.icon
                            panelIndex: index
                            active: root.activePanelTab === index
                            onClicked: root._setActivePanelTab(panelIndex)
                            onActivated: function(panelIndex) { root._setActivePanelTab(panelIndex) }
                        }
                    }
                    UiIconButton {
                        theme: root.theme
                        iconName: "close"
                        tooltip: "Close Panel"
                        iconSize: 12
                        onClicked: root._setPanelOpen(false)
                    }
                }
            }

            StackLayout {
                id: panelStack; Layout.fillWidth: true; Layout.fillHeight: true
                currentIndex: root.activePanelTab

                Repeater {
                    id: panelRepeater
                    model: root.bottomPanels
                    delegate: Loader {
                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent: {
                            if (modelData.component === "TerminalPanel") return terminalPanelComponent
                            if (modelData.component === "ProblemsPanel") return problemsPanelComponent
                            if (modelData.component === "OutputPanel") return outputPanelComponent
                            if (modelData.component === "ActionsPanel") return actionsPanelComponent
                            if (modelData.component === "ReferencesPanel") return referencesPanelComponent
                            if (modelData.component === "ConsolePanel") return consolePanelComponent
                            return pluginPanelHostComponent
                        }
                        function injectProps() {
                            if (item && "theme" in item)
                                item.theme = root.theme
                            if (item && "panel" in item)
                                item.panel = modelData
                        }
                        onLoaded: injectProps()
                        Connections {
                            target: root
                            function onThemeChanged() { injectProps() }
                        }
                    }
                }
            }
        }
    }
}

Component {
    id: terminalPanelComponent
    TerminalPanel {
        theme: root.theme
    }
}

Component {
    id: problemsPanelComponent
    ProblemsPanel {
        theme: root.theme
        problems: StatusVM ? StatusVM.problems : []
        onClearRequested: {
            if (ActionVM) ActionVM.runAction("problems.clear")
            else if (StatusVM) StatusVM.clear_diagnostics()
        }
        onCopyRequested: function(text) {
            if (ActionVM) ActionVM.runAction("clipboard.copy_text", {"text": text})
            else if (StatusVM) StatusVM.copy_text(text)
            if (NotificationVM) NotificationVM.success("Problem copied", "Diagnostic copied to clipboard.", 2200)
        }
        onProblemActivated: function(problem) {
            root._openProblemLocation(problem)
        }
        onProblemRevealRequested: function(problem) {
            if (problem && problem.path)
                root._revealInExplorer(problem.path)
            else if (NotificationVM)
                NotificationVM.warning("Reveal unavailable", "This diagnostic has no file path.", 3600)
        }
        onQuickFixRequested: function(problem) {
            root._quickFixProblem(problem)
        }
    }
}

Component {
    id: outputPanelComponent
    OutputPanel {
        theme: root.theme
        title: "Output"
        entries: StatusVM ? StatusVM.output : []
        onClearRequested: {
            if (ActionVM) ActionVM.runAction("output.clear")
            else if (StatusVM) StatusVM.clear_output()
        }
        onCopyRequested: function(text) {
            if (ActionVM) ActionVM.runAction("clipboard.copy_text", {"text": text})
            else if (StatusVM) StatusVM.copy_text(text)
        }
    }
}

Component {
    id: consolePanelComponent
    ConsolePanel {
        theme: root.theme
        entries: StatusVM ? StatusVM.console : []
        onClearRequested: {
            if (ActionVM) ActionVM.runAction("console.clear")
            else if (StatusVM) StatusVM.clear_console()
        }
        onCopyRequested: function(text) {
            if (ActionVM) ActionVM.runAction("clipboard.copy_text", {"text": text})
            else if (StatusVM) StatusVM.copy_text(text)
        }
    }
}

Component {
    id: actionsPanelComponent
    ActionsPanel {
        theme: root.theme
        runningActions: ActionVM ? ActionVM.runningActions : []
        history: ActionVM ? ActionVM.history : []
        onClearRequested: {
            if (ActionVM) ActionVM.runAction("actions.clear_history")
        }
        onCopyRequested: function(text) {
            if (ActionVM) ActionVM.runAction("clipboard.copy_text", {"text": text})
            else if (StatusVM) StatusVM.copy_text(text)
        }
    }
}

Component {
    id: referencesPanelComponent
    ReferencesPanel {
        theme: root.theme
        references: EditorVM ? EditorVM.references : []
        currentPath: EditorVM ? EditorVM.currentPath : ""
        onLocationActivated: function(location) { root._openEditorLocation(location) }
        onClearRequested: {
            if (NotificationVM) NotificationVM.info("References", "References are refreshed from the editor with Shift+F12.", 2600)
        }
        onCopyRequested: function(text) {
            if (ActionVM) ActionVM.runAction("clipboard.copy_text", {"text": text})
            else if (StatusVM) StatusVM.copy_text(text)
        }
    }
}

Component {
    id: pluginPanelHostComponent
    PluginPanelHost {
        theme: root.theme
    }
}

Component {
    id: outlinePanelComponent
    OutlinePanel {
        theme: root.theme
        symbols: EditorVM ? EditorVM.symbols : []
        onSymbolActivated: function(symbol) { root._openEditorLocation(symbol) }
        onRefreshRequested: {
            if (editorWorkspace.plainText && EditorVM)
                EditorVM.requestDocumentSymbols(editorWorkspace.plainText)
        }
    }
}

DockPanel {
    id: rightPanel
    theme: root.theme
    open: root.rightPanelOpen
    horizontal: true
    preferredSize: root.rightPanelWidth
    minimumSize: 180
    maximumSize: 520
    showLeftBorder: true
    color: theme.sidebar

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: metrics.panelHeaderHeight
            color: theme.panelHeader || theme.sidebar
            visible: root.rightPanels.length > 1

            ListView {
                anchors.fill: parent
                orientation: ListView.Horizontal
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.rightPanels
                delegate: UiPanelTab {
                    required property int index
                    required property var modelData
                    theme: root.theme
                    label: modelData.label
                    iconName: modelData.icon
                    panelIndex: index
                    active: root.activeRightPanelTab === index
                    onClicked: root._setActiveRightPanelTab(panelIndex)
                    onActivated: function(panelIndex) { root._setActiveRightPanelTab(panelIndex) }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.activeRightPanelTab
            visible: root.rightPanels.length > 0

            Repeater {
                model: root.rightPanels
                delegate: Loader {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: {
                        if (modelData.component === "OutlinePanel") return outlinePanelComponent
                        return pluginPanelHostComponent
                    }
                    function injectProps() {
                        if (item && "theme" in item)
                            item.theme = root.theme
                        if (item && "panel" in item)
                            item.panel = modelData
                    }
                    onLoaded: injectProps()
                    Connections {
                        target: root
                        function onThemeChanged() { injectProps() }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            visible: root.rightPanels.length === 0

            Item { Layout.fillHeight: true }
            Icon {
                icon: "layout"
                color: theme.textDim || "#858585"
                size: 32
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "No right panel provider"
                color: theme.text || "#CCCCCC"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 12
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
            Text {
                text: "Plugins can contribute panels with location: right."
                color: theme.textDim || "#858585"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 10
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
        }
    }
}
}
}

StatusBar {
    id: statusBar
    Layout.fillWidth: true; Layout.preferredHeight: metrics.statusBarHeight
    theme: root.theme
    bgColor: theme.statusBar; textColor: theme.statusBarText
    language: StatusVM ? StatusVM.language : "Python"
    message: StatusVM ? StatusVM.message : "Ready"
    notificationCount: NotificationVM && NotificationVM.notifications ? NotificationVM.notifications.length : 0
    busy: NotificationVM ? NotificationVM.busy : false
    errorCount: StatusVM ? StatusVM.errorCount : 0
    warningCount: StatusVM ? StatusVM.warningCount : 0
    lspStatus: StatusVM ? StatusVM.lspStatus : "LSP idle"
    lspDetails: StatusVM ? StatusVM.lspDetails : ""
    lspServers: StatusVM ? StatusVM.lspServers : []
    lspHealthy: StatusVM ? StatusVM.lspHealthy : true
    cursorLine: root.cursorLine; cursorCol: root.cursorCol
    onLspStartRequested: EditorVM.startLsp()
    onLspStopRequested: EditorVM.stopLsp()
    onLspRestartRequested: EditorVM.restartLsp()
}
}

Instantiator {
    model: root.runtimeKeybindings

    delegate: Shortcut {
        required property var modelData
        property string keySequence: modelData.key || ""
            property string commandId: modelData.command || ""

                sequence: keySequence
                enabled: keySequence.length > 0 && commandId.length > 0
                context: Qt.ApplicationShortcut
                onActivated: root._executeShortcutCommand(commandId, keySequence)
            }
        }

        Shortcut {
            sequence: StandardKey.SelectPreviousWord
            context: Qt.ApplicationShortcut
            enabled: editorWorkspace && editorWorkspace.editorVisible
            onActivated: editorWorkspace.selectPreviousWord()
            onActivatedAmbiguously: editorWorkspace.selectPreviousWord()
        }

        Shortcut {
            sequence: StandardKey.SelectNextWord
            context: Qt.ApplicationShortcut
            enabled: editorWorkspace && editorWorkspace.editorVisible
            onActivated: editorWorkspace.selectNextWord()
            onActivatedAmbiguously: editorWorkspace.selectNextWord()
        }

        Shortcut {
            sequence: "Ctrl+Shift+Left"
            context: Qt.ApplicationShortcut
            enabled: editorWorkspace && editorWorkspace.editorVisible
            onActivated: editorWorkspace.selectPreviousWord()
            onActivatedAmbiguously: editorWorkspace.selectPreviousWord()
        }

        Shortcut {
            sequence: "Ctrl+Shift+Right"
            context: Qt.ApplicationShortcut
            enabled: editorWorkspace && editorWorkspace.editorVisible
            onActivated: editorWorkspace.selectNextWord()
            onActivatedAmbiguously: editorWorkspace.selectNextWord()
        }

        Shortcut {
            sequence: "Meta+Shift+Left"
            context: Qt.ApplicationShortcut
            enabled: editorWorkspace && editorWorkspace.editorVisible
            onActivated: editorWorkspace.selectPreviousWord()
            onActivatedAmbiguously: editorWorkspace.selectPreviousWord()
        }

        Shortcut {
            sequence: "Meta+Shift+Right"
            context: Qt.ApplicationShortcut
            enabled: editorWorkspace && editorWorkspace.editorVisible
            onActivated: editorWorkspace.selectNextWord()
            onActivatedAmbiguously: editorWorkspace.selectNextWord()
        }

        NotificationHost {
            anchors.fill: parent
            theme: root.theme
            position: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.notificationPosition : "top-right"
            notifications: NotificationVM ? NotificationVM.notifications : []
            busy: NotificationVM ? NotificationVM.busy : false
            operations: NotificationVM ? NotificationVM.operations : []
        }

        Dialog {
            id: externalFileDialog
            modal: true
            width: Math.min(460, root.width - 48)
            x: Math.max(24, (root.width - width) / 2)
            y: 96
            closePolicy: Popup.CloseOnEscape
            title: "File changed on disk"

            background: Rectangle {
                color: root.theme.panel || root.theme.toastBg || "#1F232A"
                border.color: root.theme.border || "#343C4A"
                border.width: 1
                radius: 14
            }

            contentItem: ColumnLayout {
                spacing: 14

                Text {
                    Layout.fillWidth: true
                    text: root.externalChangedName
                    color: root.theme.textStrong || "#F9FAFB"
                    font.family: root.uiFont.family
                    font.pointSize: 13
                    font.bold: true
                    elide: Text.ElideMiddle
                }

                Text {
                    Layout.fillWidth: true
                    text: root.externalChangedDirty
                          ? "This file changed outside Ember while local edits are unsaved. Reloading will replace the editor content."
                          : "This file changed outside Ember. Reload it from disk or keep the current editor content."
                    color: root.theme.text || "#CBD5E1"
                    font.family: root.uiFont.family
                    font.pointSize: 10
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: root.externalChangedPath
                    color: root.theme.textDim || "#94A3B8"
                    font.family: root.uiFont.family
                    font.pointSize: 9
                    elide: Text.ElideMiddle
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Keep local"
                        onClicked: {
                            if (EditorVM) EditorVM.keepLocalFile(root.externalChangedPath)
                            externalFileDialog.close()
                        }
                    }

                    Button {
                        text: "Reload from disk"
                        highlighted: true
                        onClicked: {
                            if (EditorVM) EditorVM.reloadFileFromDisk(root.externalChangedPath)
                            externalFileDialog.close()
                        }
                    }
                }
            }
        }

        Menu { id: fileMenu
            MenuItem { text: "New File"; onTriggered: _newFile() }
            MenuItem { text: "Open File..."; onTriggered: _openFile() }
            MenuItem { text: "Open Folder..."; onTriggered: _openFolder() }
            MenuSeparator { } MenuItem { text: "Save"; onTriggered: _saveFile() }
            MenuSeparator { }
            MenuItem { text: "Close Tab"; onTriggered: { if (EditorVM && EditorVM.tabCount() > 0) _closeTab(EditorVM.currentTabIndex) } }
            MenuItem { text: "Close All Tabs"; onTriggered: if (EditorVM) EditorVM.closeAllTabs() }
            MenuSeparator { } MenuItem { text: "Exit"; onTriggered: Qt.quit() }
        }
        Menu { id: editMenu
            MenuItem { text: "Undo" } MenuItem { text: "Redo" } MenuSeparator { }
            MenuItem { text: "Cut" } MenuItem { text: "Copy" } MenuItem { text: "Paste" }
        }
        Menu { id: viewMenu
            MenuItem { text: "Command Palette..."; onTriggered: commandPalette.open() }
            MenuItem { text: "Toggle Sidebar"; onTriggered: root._setSidebarOpen(!root.sidebarOpen) }
            MenuItem { text: "Toggle Panel"; onTriggered: root._setPanelOpen(!root.panelOpen) }
            MenuItem { text: "Toggle Right Panel"; onTriggered: root._setRightPanelOpen(!root.rightPanelOpen) }
            MenuSeparator { } MenuItem { text: "Zoom In" } MenuItem { text: "Zoom Out" }
        }
        Menu { id: toolsMenu
            MenuItem { text: "AI: Explain Code"; onTriggered: _aiAction("explain") }
            MenuItem { text: "AI: Refactor"; onTriggered: _aiAction("refactor") }
            MenuItem { text: "AI: Generate Tests"; onTriggered: _aiAction("tests") }
            MenuSeparator { } MenuItem { text: "Format Document"; onTriggered: _formatDocument() }
        }
        Menu { id: helpMenu
            MenuItem { text: "About Ember" }
        }

        CommandPalette { id: commandPalette
            theme: root.theme
            commands: CommandVM ? CommandVM.commands : []
            actions: ActionVM ? ActionVM.actions : []
            onActionSelected: function(actionId) {
                root._runActionWithPolicy(actionId, ({}))
            }
            onCommandSelected: function(cmdId) {
            _dispatchShortcut(cmdId, "")
            if (ActionVM && CommandVM && CommandVM.canExecuteCommand(cmdId) && ActionVM.runAction("command.execute", {"command": cmdId})) return
            if (CommandVM && CommandVM.executeCommand(cmdId)) return
            switch (cmdId) {
                case "file.open": _openFile(); break
                case "file.open_folder": _openFolder(); break
                case "project.open": _openFolder(); break
                case "project.close": FileVM.closeWorkspace(); if (EditorVM) EditorVM.closeAllTabs(); break
                case "file.new": _newFile(); break
                case "file.save": _saveFile(); break
                case "editor.format": _formatDocument(); break
                case "file.close": if (EditorVM && EditorVM.tabCount() > 0) _closeTab(EditorVM.currentTabIndex); break
                case "view.sidebar": root._setSidebarOpen(!root.sidebarOpen); break
                case "view.terminal": root._toggleTerminalPanel(); break
                case "settings.open": _addTab("Settings", "settings"); break
            }
    }
}

Dialog {
    id: sensitiveActionDialog
    modal: true
    width: Math.min(460, root.width - 48)
    x: Math.max(24, (root.width - width) / 2)
    y: 110
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    title: "Confirm plugin action"

    background: Rectangle {
        color: root.theme.panel || root.theme.toastBg || "#1F232A"
        border.color: root.theme.border || "#343C4A"
        border.width: 1
        radius: 14
    }

    contentItem: ColumnLayout {
        spacing: 14

        Text {
            Layout.fillWidth: true
            text: root.pendingSensitiveAction.title || root.pendingSensitiveActionId
            color: root.theme.textStrong || "#F9FAFB"
            font.family: root.uiFont.family
            font.pointSize: 13
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: "This action requests elevated plugin permissions. Run it only if you trust the provider."
            color: root.theme.text || "#CBD5E1"
            font.family: root.uiFont.family
            font.pointSize: 10
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 10
            color: root.theme.inputBg || "#111827"
            border.width: 1
            border.color: root.theme.warning || "#F59E0B"

            Text {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: "Permissions: " + ((root.pendingSensitiveAction.permissions || []).join(", ") || "none")
                color: root.theme.warning || "#F59E0B"
                font.family: root.uiFont.family
                font.pointSize: 10
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Item { Layout.fillWidth: true }

            Button {
                text: "Cancel"
                onClicked: {
                    root.pendingSensitiveActionId = ""
                    root.pendingSensitiveAction = ({})
                    sensitiveActionDialog.close()
                }
            }

            Button {
                text: "Run action"
                highlighted: true
                onClicked: {
                    var actionId = root.pendingSensitiveActionId
                    root.pendingSensitiveActionId = ""
                    root.pendingSensitiveAction = ({})
                    sensitiveActionDialog.close()
                    if (ActionVM)
                        ActionVM.runAction(actionId, ({}))
                }
            }
        }
    }
}

Timer {
    id: problemGotoTimer
    interval: 180
    repeat: false
    onTriggered: {
        if (!root.pendingProblemPath)
            return
        if (editorWorkspace.filePath !== root.pendingProblemPath) {
            root.pendingProblemAttempts += 1
            if (root.pendingProblemAttempts < 20)
                problemGotoTimer.restart()
            else
                root.pendingProblemPath = ""
            return
        }
        editorWorkspace.goToLocation(root.pendingProblemLine, root.pendingProblemCol)
        if (root.pendingQuickFix)
            editorWorkspace.requestQuickFixPreviewAt(root.pendingProblemLine, root.pendingProblemCol)
        root.pendingQuickFix = false
        root.pendingProblemPath = ""
    }
}

Timer {
    id: revealInExplorerTimer
    interval: 80
    repeat: false
    onTriggered: {
        if (!root.pendingRevealPath)
            return
        root.pendingRevealAttempts += 1
        if (!sidebarContent.item || !sidebarContent.item.revealFile) {
            if (root.pendingRevealAttempts < 25)
                revealInExplorerTimer.restart()
            else
                root.pendingRevealPath = ""
            return
        }
        if (!sidebarContent.item.revealFile(root.pendingRevealPath) && root.pendingRevealAttempts < 25) {
            revealInExplorerTimer.restart()
            return
        }
        root.pendingRevealPath = ""
    }
}

        Component {
            id: _feComp
        ExplorerFallback {
            theme: root.theme
            currentFolder: root.currentFolder
            activeFilePath: editorWorkspace.filePath
            onFileSelected: function(path) { _openFileByPath(path) }
            onFolderOpened: function(path) { _activateFolder(path, true) }
        }
    }

    Component {
        id: _srchComp
        SearchFallback {
            theme: root.theme
            onOpenFileRequested: function(path) { root._openFileByPath(path) }
            onRevealFileRequested: function(path) { root._revealInExplorer(path) }
        }
    }

    Component {
        id: _gitComp
        SourceControlFallback {
            theme: root.theme
            onOpenFileRequested: function(path) { root._openFileByPath(path) }
        }
    }

    Component {
        id: _dbgComp
        DebugFallback { theme: root.theme }
    }

    Component {
        id: _extComp
        ExtensionsFallback { theme: root.theme }
    }
}
