import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var metrics: DesignTokens.metrics
    property var tokenColors: DesignTokens.tokenColors
    property var tabs: []
    property var dirtyTabs: ({})
    property int currentTabIndex: -1
    property var recentFiles: []
    property real lineSpacing: 6

    readonly property bool editorVisible: codeEditor.visible
    readonly property string filePath: codeEditor.filePath
    readonly property string plainText: codeEditor.plainText
    readonly property bool isDirty: codeEditor.isDirty
    readonly property int cursorLine: codeEditor.cursorLine
    readonly property int cursorCol: codeEditor.cursorCol

    signal tabActivated(int index)
    signal tabCloseRequested(int index)
    signal tabMoveRequested(int from, int to)
    signal openFileRequested()
    signal openFolderRequested()
    signal newFileRequested()
    signal openRecentRequested(string path)
    signal cursorPositionChanged()

    color: theme.tabBg

    onThemeChanged: {
        if (settingsLoader.item && settingsLoader.item.hasOwnProperty("theme"))
            settingsLoader.item.theme = root.theme
    }

    onCurrentTabIndexChanged: {
        if (currentTabIndex >= 0)
            Qt.callLater(function() { tabRow.positionViewAtIndex(currentTabIndex, ListView.Contain) })
    }

    function switchToTab(title, content) {
        codeEditor.resetTransientUi()
        var showWelcome = title === "Welcome"
        var showSettings = title === "Settings"
        var showEditor = !showWelcome && !showSettings
        welcomeScreen.visible = showWelcome
        settingsLoader.visible = showSettings
        codeEditor.visible = showEditor
        if (showEditor && typeof content === "string" && content.length > 0) {
            codeEditor.enabled = true
            codeEditor.loadFile(content)
        }
    }

    function resetTransientUi() {
        codeEditor.resetTransientUi()
    }

    function goToLocation(line, col) {
        if (codeEditor.visible && codeEditor.goToLocation)
            codeEditor.goToLocation(line, col)
    }

    function requestQuickFixAt(line, col) {
        if (codeEditor.visible && codeEditor.requestQuickFixAt)
            codeEditor.requestQuickFixAt(line, col)
    }

    function requestQuickFixPreviewAt(line, col) {
        if (codeEditor.visible && codeEditor.requestQuickFixPreviewAt)
            codeEditor.requestQuickFixPreviewAt(line, col)
    }

    function selectPreviousWord() {
        if (codeEditor.visible && codeEditor._selectPreviousWordFromShortcut)
            codeEditor._selectPreviousWordFromShortcut()
    }

    function selectNextWord() {
        if (codeEditor.visible && codeEditor._selectNextWordFromShortcut)
            codeEditor._selectNextWordFromShortcut()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.metrics.tabHeight
            color: root.theme.tabBg

            ListView {
                id: tabRow
                anchors.fill: parent
                orientation: ListView.Horizontal
                boundsBehavior: Flickable.StopAtBounds
                boundsMovement: Flickable.StopAtBounds
                interactive: true
                clip: true
                spacing: 0
                model: root.tabs
                onCountChanged: {
                    if (root.currentTabIndex >= 0)
                        Qt.callLater(function() { positionViewAtIndex(root.currentTabIndex, ListView.Contain) })
                }

                delegate: EditorTab {
                    required property var modelData
                    required property int index
                    theme: root.theme
                    title: modelData.title
                    iconName: _tabIcon(modelData.title)
                    tabIndex: index
                    tabCount: root.tabs.length
                    active: root.currentTabIndex === index
                    dirty: !!root.dirtyTabs[modelData.id]
                    onActivated: function(tabIndex) { root.tabActivated(tabIndex) }
                    onCloseRequested: function(tabIndex) { root.tabCloseRequested(tabIndex) }
                    onMoveRequested: function(from, to) { root.tabMoveRequested(from, to) }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: root.theme.bg

            WelcomeScreen {
                id: welcomeScreen
                anchors.fill: parent
                bgColor: root.theme.bg
                accentColor: root.theme.accent
                textColor: root.theme.text
                dimColor: root.theme.textDim
                theme: root.theme
                recentFiles: root.recentFiles
                onOpenFileRequested: root.openFileRequested()
                onOpenFolderRequested: root.openFolderRequested()
                onNewFileRequested: root.newFileRequested()
                onOpenRecent: function(path) { root.openRecentRequested(path) }
            }

            CodeEditor {
                id: codeEditor
                anchors.fill: parent
                visible: false
                theme: root.theme
                metrics: root.metrics
                tokenColors: root.tokenColors
                lineSpacing: root.lineSpacing
                filePath: ""
                plainText: ""
            }

            Loader {
                id: settingsLoader
                anchors.fill: parent
                visible: false
                source: "../settings/Preferences.qml"
                onLoaded: {
                    if (item && item.hasOwnProperty("theme"))
                        item.theme = root.theme
                }
            }
        }
    }

    Connections {
        target: codeEditor
        function onCursorPositionChanged() { root.cursorPositionChanged() }
    }

    function _tabIcon(title) {
        if (title === "Welcome" || title === "Settings")
            return "file"
        return IconRegistry.fileIcon(title, false)
    }
}
