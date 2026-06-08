import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

FocusScope {
    id: root
    focus: true

    property var theme: DesignTokens.darkTheme
    property var sessions: ({})
    property var sessionIds: []
    property int activeSession: -1
    property var screenLines: []
    property string plainText: ""
    property var cursor: ({ line: 0, col: 0, visible: false })
    property bool copyMode: false
    property bool selecting: false
    property bool selectionActive: false
    property int selectionAnchorLine: 0
    property int selectionAnchorCol: 0
    property int selectionFocusLine: 0
    property int selectionFocusCol: 0

    readonly property int terminalPadding: 8
    readonly property color panelBg: theme.terminalBg || theme.panel || "#1E1E1E"
    readonly property color headerBg: theme.terminalHeader || theme.panelHeader || theme.terminalBg || theme.panel || "#252526"
    readonly property color terminalBg: theme.terminalBg || theme.panel || "#1E1E1E"
    readonly property color terminalFg: theme.terminalText || theme.text || "#D4D4D4"
    readonly property color textDim: theme.textDim || "#858585"
    readonly property color borderColor: theme.border || "#3E3E42"
    readonly property color accentColor: theme.terminalAccent || theme.accent || theme.success || "#007ACC"
    readonly property color actionHover: theme.buttonHover || theme.accentHover || theme.hover || Qt.rgba(1, 1, 1, 0.08)
    readonly property font terminalFont: Qt.font({
        family: root.fontFamily((typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.terminalFontFamily : "Menlo"),
        pointSize: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.terminalFontSize : 12
    })
    readonly property real cellWidth: Math.max(7, terminalMetrics.advanceWidth / 10 || terminalMetrics.width / 10 || 8)
    readonly property real cellHeight: terminalMetrics.height + 4

    TextMetrics { id: terminalMetrics; font: root.terminalFont; text: "MMMMMMMMMM" }

    function fontFamily(value) {
        var family = String(value || "Menlo").split(",")[0].trim()
        if (family.toLowerCase() === "monospace")
            return "Menlo"
        return family.length > 0 ? family : "Menlo"
    }

    function colorFor(name, background) {
        if (!name || name.length === 0)
            return background ? "transparent" : root.terminalFg
        var suffix = name.charAt(0).toUpperCase() + name.slice(1)
        var key = background ? "terminalAnsi" + suffix : "terminalAnsi" + suffix
        return root.theme[key] || (background ? "transparent" : root.terminalFg)
    }

    function defaultTitle(sid) {
        return "shell " + (sid + 1)
    }

    function ensureSession(sid, title) {
        if (sid < 0)
            return
        if (!sessions[sid])
            sessions[sid] = { title: title || defaultTitle(sid), lines: [], plain: "" }
        else if (title && title.length > 0)
            sessions[sid].title = title
        if (sessionIds.indexOf(sid) < 0)
            sessionIds = sessionIds.concat([sid])
        sessions = Object.assign({}, sessions)
    }

    function createTerminal() {
        if (typeof TerminalVM === "undefined" || !TerminalVM)
            return
        var sid = TerminalVM.createSession()
        ensureSession(sid, "")
        switchSession(sid)
    }

    function switchSession(sid) {
        if (sid < 0) {
            activeSession = -1
            screenLines = []
            plainText = ""
            cursor = ({ line: 0, col: 0, visible: false })
            return
        }
        ensureSession(sid, "")
        activeSession = sid
        if (TerminalVM)
            TerminalVM.activateSession(sid)
        screenLines = sessions[sid].lines || []
        plainText = sessions[sid].plain || ""
        cursor = sessions[sid].cursor || ({ line: 0, col: 0, visible: false })
        Qt.callLater(function() {
            activateTerminal()
            screenView.positionViewAtEnd()
            resizeActivePty()
        })
    }

    function activateTerminal() {
        root.forceActiveFocus()
        terminalSurface.forceActiveFocus()
        if (copyMode)
            copyBuffer.forceActiveFocus()
        else {
            keySink.forceActiveFocus()
            focusKeeper.restart()
        }
    }

    function resizeActivePty() {
        if (activeSession < 0 || typeof TerminalVM === "undefined" || !TerminalVM)
            return
        var cols = Math.max(20, Math.floor((terminalSurface.width - 20) / root.cellWidth))
        var rows = Math.max(4, Math.floor((terminalSurface.height - 16) / root.cellHeight))
        TerminalVM.resizeSession(activeSession, cols, rows)
    }

    function write(data) {
        if (activeSession >= 0 && TerminalVM)
            TerminalVM.writeToSession(activeSession, data)
    }

    function clearSelection() {
        selectionActive = false
        selecting = false
    }

    function lineFromY(y) {
        if (!screenLines || screenLines.length <= 0)
            return 0
        var localY = y - screenView.y + screenView.contentY
        return Math.max(0, Math.min(screenLines.length - 1, Math.floor(localY / root.cellHeight)))
    }

    function colFromX(x) {
        var localX = x - screenView.x + screenView.contentX
        return Math.max(0, Math.floor(localX / root.cellWidth))
    }

    function updateSelection(x, y) {
        selectionFocusLine = lineFromY(y)
        selectionFocusCol = colFromX(x)
        selectionActive = selectionFocusLine !== selectionAnchorLine || selectionFocusCol !== selectionAnchorCol
    }

    function orderedSelection() {
        var startLine = selectionAnchorLine
        var startCol = selectionAnchorCol
        var endLine = selectionFocusLine
        var endCol = selectionFocusCol
        if (endLine < startLine || (endLine === startLine && endCol < startCol)) {
            var line = startLine
            var col = startCol
            startLine = endLine
            startCol = endCol
            endLine = line
            endCol = col
        }
        return { startLine: startLine, startCol: startCol, endLine: endLine, endCol: endCol }
    }

    function selectedText() {
        if (!selectionActive)
            return ""
        var range = orderedSelection()
        var output = []
        for (var line = range.startLine; line <= range.endLine; line++) {
            var text = screenLines[line] ? (screenLines[line].text || "") : ""
            var from = line === range.startLine ? range.startCol : 0
            var to = line === range.endLine ? range.endCol : text.length
            output.push(text.substring(Math.max(0, from), Math.max(0, to)))
        }
        return output.join("\n")
    }

    function maxLineLength() {
        var maxLength = 0
        for (var index = 0; index < screenLines.length; index++)
            maxLength = Math.max(maxLength, (screenLines[index].text || "").length)
        return maxLength
    }

    function lineSelectionStart(line) {
        if (!selectionActive)
            return -1
        var range = orderedSelection()
        if (line < range.startLine || line > range.endLine)
            return -1
        return line === range.startLine ? range.startCol : 0
    }

    function lineSelectionEnd(line, textLength) {
        if (!selectionActive)
            return -1
        var range = orderedSelection()
        if (line < range.startLine || line > range.endLine)
            return -1
        return line === range.endLine ? range.endCol : textLength
    }

    function handleKey(event) {
        if (copyMode || activeSession < 0)
            return false
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
            write(TerminalVM ? TerminalVM.pasteText() : "")
            return true
        }
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_C) {
                if (selectionActive) {
                    if (TerminalVM)
                        TerminalVM.copyText(selectedText())
                    return true
                }
                write("\x03"); return true
            }
            if (event.key === Qt.Key_D) { write("\x04"); return true }
            if (event.key === Qt.Key_L) { write("\x0c"); return true }
            if (event.key === Qt.Key_A) { write("\x01"); return true }
            if (event.key === Qt.Key_E) { write("\x05"); return true }
            if (event.key === Qt.Key_U) { write("\x15"); return true }
            if (event.key === Qt.Key_K) { write("\x0b"); return true }
            if (event.key === Qt.Key_W) { write("\x17"); return true }
            if (event.key === Qt.Key_R) { write("\x12"); return true }
            if (event.key === Qt.Key_Z) { write("\x1a"); return true }
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { write("\r"); return true }
        if (event.key === Qt.Key_Backspace) { write("\x7f"); return true }
        if (event.key === Qt.Key_Tab) { write("\t"); return true }
        if (event.key === Qt.Key_Escape) { write("\x1b"); return true }
        if (event.key === Qt.Key_Left) { write("\x1b[D"); return true }
        if (event.key === Qt.Key_Right) { write("\x1b[C"); return true }
        if (event.key === Qt.Key_Up) { write("\x1b[A"); return true }
        if (event.key === Qt.Key_Down) { write("\x1b[B"); return true }
        if (event.key === Qt.Key_Home) { write("\x1b[H"); return true }
        if (event.key === Qt.Key_End) { write("\x1b[F"); return true }
        if (event.key === Qt.Key_Delete) { write("\x1b[3~"); return true }
        if (event.key === Qt.Key_PageUp) {
            screenView.contentY = Math.max(0, screenView.contentY - screenView.height * 0.85)
            return true
        }
        if (event.key === Qt.Key_PageDown) {
            screenView.contentY = Math.min(screenView.contentHeight - screenView.height, screenView.contentY + screenView.height * 0.85)
            return true
        }
        if (event.text && event.text.length > 0) { write(event.text); return true }
        return false
    }

    function moveSession(from, to) {
        if (from === to || from < 0 || to < 0 || from >= sessionIds.length || to >= sessionIds.length)
            return
        var sid = sessionIds.splice(from, 1)[0]
        sessionIds.splice(to, 0, sid)
        sessionIds = sessionIds.slice()
    }

    Component.onCompleted: Qt.callLater(function() {
        var restored = TerminalVM ? TerminalVM.restoreSessions() : 0
        if (restored <= 0)
            root.createTerminal()
    })
    onVisibleChanged: if (visible) Qt.callLater(root.activateTerminal)
    onCopyModeChanged: Qt.callLater(root.activateTerminal)

    Connections {
        target: TerminalVM
        function onSessionCreated(sid) {
            var info = TerminalVM.sessionInfo(sid)
            root.ensureSession(sid, info && info.title ? info.title : "")
            root.switchSession(sid)
        }
        function onSessionRemoved(sid) {
            delete root.sessions[sid]
            var index = root.sessionIds.indexOf(sid)
            if (index >= 0) {
                root.sessionIds.splice(index, 1)
                root.sessionIds = root.sessionIds.slice()
            }
            root.sessions = Object.assign({}, root.sessions)
            if (root.activeSession === sid)
                root.switchSession(root.sessionIds.length > 0 ? root.sessionIds[0] : -1)
        }
        function onScreenReady(sid, lines, plain, cursorInfo) {
            root.ensureSession(sid, "")
            root.sessions[sid].lines = lines || []
            root.sessions[sid].plain = plain || ""
            root.sessions[sid].cursor = cursorInfo || ({ line: 0, col: 0, visible: false })
            root.sessions = Object.assign({}, root.sessions)
            if (sid === root.activeSession) {
                root.screenLines = root.sessions[sid].lines
                root.plainText = root.sessions[sid].plain
                root.cursor = root.sessions[sid].cursor
                Qt.callLater(screenView.positionViewAtEnd)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.panelBg

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: root.headerBg
                border.color: root.borderColor
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    ListView {
                        id: terminalTabBar
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        orientation: ListView.Horizontal
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.sessionIds.length
                        delegate: TerminalTab {
                            required property int index
                            theme: root.theme
                            sessionId: root.sessionIds[index]
                            tabIndex: index
                            tabCount: root.sessionIds.length
                            title: root.sessions[sessionId] && root.sessions[sessionId].title ? root.sessions[sessionId].title : root.defaultTitle(index)
                            active: root.activeSession === sessionId
                            onActivated: function(sid) { root.switchSession(sid) }
                            onCloseRequested: function(sid, tabIndex) {
                                if (TerminalVM)
                                    TerminalVM.closeSession(sid)
                            }
                            onMoveRequested: function(from, to) { root.moveSession(from, to) }
                        }
                    }

                    UiIconButton {
                        theme: root.theme
                        iconName: root.copyMode ? "terminal" : "copy"
                        tooltip: root.copyMode ? "Back to shell" : "Select and copy"
                        toggled: root.copyMode
                        iconColor: root.copyMode ? root.accentColor : root.textDim
                        hoverColor: root.actionHover
                        onClicked: root.copyMode = !root.copyMode
                    }
                    UiIconButton {
                        theme: root.theme
                        iconName: "plus"
                        tooltip: "New terminal"
                        iconColor: root.accentColor
                        hoverColor: root.actionHover
                        onClicked: root.createTerminal()
                    }
                }
            }

            Rectangle {
                id: terminalSurface
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.terminalBg
                clip: true
                focus: true
                activeFocusOnTab: true
                onWidthChanged: resizeTimer.restart()
                onHeightChanged: resizeTimer.restart()
                Keys.onPressed: function(event) { event.accepted = root.handleKey(event) }

                ListView {
                    id: screenView
                    anchors.fill: parent
                    anchors.margins: root.terminalPadding
                    model: root.screenLines
                    clip: true
                    contentWidth: Math.max(width, root.maxLineLength() * root.cellWidth + root.terminalPadding)
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: !root.copyMode
                    spacing: 0
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle { radius: 4; color: parent.pressed ? (root.theme.scrollbarHover || root.accentColor) : (root.theme.scrollbarThumb || root.borderColor) }
                        background: Rectangle { color: root.theme.scrollbarBg || root.terminalBg }
                    }
                    ScrollBar.horizontal: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle { radius: 4; color: parent.pressed ? (root.theme.scrollbarHover || root.accentColor) : (root.theme.scrollbarThumb || root.borderColor) }
                        background: Rectangle { color: root.theme.scrollbarBg || root.terminalBg }
                    }

                    delegate: Item {
                        id: lineDelegate
                        required property int index
                        required property var modelData
                        width: screenView.width
                        height: root.cellHeight

                        Rectangle {
                            visible: root.lineSelectionStart(lineDelegate.index) >= 0
                            x: Math.max(0, root.lineSelectionStart(lineDelegate.index)) * root.cellWidth
                            y: 1
                            width: Math.max(1, (root.lineSelectionEnd(lineDelegate.index, (modelData.text || "").length) - root.lineSelectionStart(lineDelegate.index)) * root.cellWidth)
                            height: parent.height - 2
                            color: root.theme.selection || root.theme.editorSelection || root.accentColor
                            opacity: 0.55
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Repeater {
                                model: modelData.spans && modelData.spans.length > 0 ? modelData.spans : [{ text: modelData.text || " ", fg: "", bg: "", bold: false, italic: false, underline: false }]
                                delegate: Text {
                                    required property var modelData
                                    text: (modelData.text || " ").replace(/\t/g, "    ")
                                    textFormat: Text.PlainText
                                    font.family: root.terminalFont.family
                                    font.pointSize: root.terminalFont.pointSize
                                    font.bold: !!modelData.bold
                                    font.italic: !!modelData.italic
                                    font.underline: !!modelData.underline
                                    renderType: Text.NativeRendering
                                    width: Math.max(root.cellWidth, (modelData.text || " ").length * root.cellWidth)
                                    color: root.colorFor(modelData.fg || "", false)
                                    height: root.cellHeight
                                    verticalAlignment: Text.AlignVCenter
                                    Rectangle {
                                        anchors.fill: parent
                                        z: -1
                                        visible: !!modelData.bg
                                        color: root.colorFor(modelData.bg || "", true)
                                    }
                                }
                            }
                        }
                    }
                }

                ScrollView {
                    id: copyScrollView
                    visible: root.copyMode
                    anchors.fill: parent
                    anchors.margins: root.terminalPadding
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                    background: Rectangle { color: root.terminalBg }

                    TextArea {
                        id: copyBuffer
                        readOnly: true
                        selectByMouse: true
                        persistentSelection: true
                        textFormat: TextEdit.PlainText
                        wrapMode: TextEdit.NoWrap
                        text: root.plainText
                        color: root.terminalFg
                        selectedTextColor: root.theme.textStrong || root.terminalFg
                        selectionColor: root.theme.selection || root.theme.editorSelection || root.accentColor
                        font: root.terminalFont
                        background: Rectangle { color: root.terminalBg }
                    }
                }

                Item {
                    id: keySink
                    anchors.fill: parent
                    z: root.copyMode ? -1 : 50
                    focus: true
                    enabled: !root.copyMode
                    activeFocusOnTab: true
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: function(event) { event.accepted = root.handleKey(event) }
                }

                Rectangle {
                    visible: !root.copyMode && root.cursor && root.cursor.visible
                    x: screenView.x + Math.max(0, Number(root.cursor.col || 0)) * root.cellWidth - screenView.contentX
                    y: screenView.y + Math.max(0, Number(root.cursor.line || 0)) * root.cellHeight - screenView.contentY
                       + (((typeof SettingsVM !== "undefined" && SettingsVM) && SettingsVM.terminalCursorStyle === "underline") ? root.cellHeight - 4 : 0)
                    width: ((typeof SettingsVM !== "undefined" && SettingsVM) && SettingsVM.terminalCursorStyle === "bar") ? 2 : Math.max(2, root.cellWidth)
                    height: ((typeof SettingsVM !== "undefined" && SettingsVM) && SettingsVM.terminalCursorStyle === "underline") ? 2 : Math.max(2, root.cellHeight - 2)
                    color: root.theme.terminalCursor || root.theme.editorCursor || root.accentColor
                    opacity: cursorBlink.visibleNow ? 0.85 : 0.25
                    z: 80
                }

                MouseArea {
                    anchors.fill: parent
                    z: root.copyMode ? -1 : 100
                    enabled: !root.copyMode
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    onPressed: function(mouse) {
                        root.activateTerminal()
                        root.selecting = true
                        root.selectionAnchorLine = root.lineFromY(mouse.y)
                        root.selectionAnchorCol = root.colFromX(mouse.x)
                        root.selectionFocusLine = root.selectionAnchorLine
                        root.selectionFocusCol = root.selectionAnchorCol
                        root.selectionActive = false
                        mouse.accepted = true
                    }
                    onPositionChanged: function(mouse) {
                        if (!root.selecting)
                            return
                        root.updateSelection(mouse.x, mouse.y)
                    }
                    onReleased: function(mouse) {
                        if (root.selecting)
                            root.updateSelection(mouse.x, mouse.y)
                        root.selecting = false
                        mouse.accepted = true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: root.headerBg
                border.color: root.borderColor
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    Text {
                        text: root.activeSession >= 0 ? "PTY shell" : "No terminal"
                        color: root.accentColor
                        font.pointSize: 10
                    }
                    Text {
                        text: root.activeSession >= 0 ? "session " + root.activeSession : ""
                        color: root.textDim
                        font.pointSize: 10
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.copyMode ? "selection mode" : "interactive"
                        color: root.textDim
                        font.pointSize: 10
                    }
                }
            }
        }
    }

    Timer {
        id: resizeTimer
        interval: 80
        repeat: false
        onTriggered: root.resizeActivePty()
    }

    Timer {
        id: focusKeeper
        interval: 60
        repeat: false
        onTriggered: {
            if (root.visible && !root.copyMode)
                keySink.forceActiveFocus()
        }
    }

    Timer {
        id: cursorBlink
        property bool visibleNow: true
        interval: 540
        repeat: true
        running: root.visible && !root.copyMode
        onTriggered: visibleNow = !visibleNow
    }
}
