import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Ember.Editor 1.0

Item {
    id: root
    focus: true

    property alias  filePath:     doc.filePath
    property alias  language:     doc.language
    property alias  aiSuggestion: doc.aiSuggestion
    property alias  isDirty:      doc.isDirty
    property string plainText: ""
    property var    diagnostics:  []
    property real   lineSpacing: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.editorLineSpacing : 6
    property var    metrics: ({})
    property var    tokenColors: ({})
    property var    theme: ({})
    property int cursorLine: _cursorLine + 1
    property int cursorCol: _cursorCol + 1
    signal cursorPositionChanged()

    readonly property int tabSize: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.tabSize : 4
    readonly property bool autoSaveEnabled: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.autoSaveEnabled : false
    readonly property int autoSaveDelayMs: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.autoSaveDelayMs : 1200
    readonly property bool wordWrapEnabled: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.wordWrap : false
    readonly property real lineHeight: lineMetrics.height + lineSpacing
    readonly property real charWidth: Math.max(1, lineMetrics.advanceWidth || lineMetrics.width || 7.2)
    readonly property font editorFont: Qt.font({
        family: root.fontFamily((typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.fontFamily : "Menlo"),
        pointSize: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.fontSize : 12
    })
    readonly property int gutterWidth: metrics.gutterWidth || 56
    readonly property int contentPadding: metrics.editorContentPadding || 8

    property bool _loadingFile: false
    property bool _syncingFromDoc: false
    property var _lineItems: []
    property var _lines: []
    property var _lineStarts: [0]
    property int _cursorLine: 0
    property int _cursorCol: 0
    property int _selectionStart: 0
    property int _selectionEnd: 0
    property real _contentWidth: width
    property string _pendingFilePath: ""
    property int _hoverPos: -1
    property real _hoverX: 0
    property real _hoverY: 0
    property real _hoverAnchorX: 0
    property real _hoverAnchorY: 0
    property string _hoverTitle: ""
    property string _hoverSubtitle: ""
    property string _hoverBody: ""
    property bool _hoverBodyRich: false
    property string _hoverSeverity: "info"
    property string _hoverMode: "symbol"
    property bool _tokenInfoHovered: false
    property bool _editorHovered: false
    property bool _hoverCloseRequested: false
    property var _codeActions: []

    function fontFamily(value) {
        var family = String(value || "Menlo").split(",")[0].trim()
        if (family.toLowerCase() === "monospace")
            return "Menlo"
        return family.length > 0 ? family : "Menlo"
    }
    property var _pendingHoverHit: null
    property var documentSymbols: []
    property bool inlineDiagnosticsEnabled: false

    onWidthChanged: _updateContentWidth()
    onWordWrapEnabledChanged: _updateContentWidth()
    onVisibleChanged: if (!visible) resetTransientUi()
    onActiveFocusChanged: if (!activeFocus) suggestionBox.close()
    onAutoSaveDelayMsChanged: autoSaveTimer.interval = Math.max(250, autoSaveDelayMs)

    function loadFile(path) {
        _loadingFile = true
        filePath = path
        _pendingFilePath = path
        resetTransientUi()
        doc.loadText("")
        if (EditorVM && EditorVM.openFileAsync)
            EditorVM.openFileAsync(path)
        Qt.callLater(function() { root.forceActiveFocus() })
    }

    function _applyLoadedFile(path, content) {
        if (path !== root._pendingFilePath && path !== root.filePath)
            return
        doc.loadText(content || "")
        root._lineItems = doc.lines
        root._lines = root._lineItems.map(function(item) { return item.text || "" })
        root._rebuildLineStarts()
        root._updateContentWidth()
        lineView.contentX = 0
        lineView.contentY = 0
        _loadingFile = false
        root._triggerLanguageFeatures()
    }

    function resetTransientUi() {
        suggestionBox.close()
        root._codeActions = []
        hoverHideTimer.stop()
        tokenInfo.visible = false
        _hoverPos = -1
        _hoverCloseRequested = false
        _pendingHoverHit = null
        _hoverBodyRich = false
        _hoverMode = "symbol"
        doc.rejectSuggestion()
    }

    TextMetrics {
        id: lineMetrics
        font: root.editorFont
        text: "M"
    }

    onPlainTextChanged: {
        if (!_syncingFromDoc && plainText !== doc.plainText())
            doc.loadText(plainText)
    }

    function _posFromLineCol(line, col) {
        line = Math.max(0, Math.min(line, _lineItems.length - 1))
        var pos = _lineStarts[line] || 0
        if (line < _lineItems.length)
            pos += Math.min(col, (_lineItems[line].text || "").length)
        return pos
    }

    function goToLocation(line, col) {
        var zeroLine = Math.max(0, (line || 1) - 1)
        var zeroCol = Math.max(0, col || 0)
        doc.moveCursor(_posFromLineCol(zeroLine, zeroCol))
        _ensureCursorVisible()
        forceActiveFocus()
    }

    function requestQuickFixAt(line, col) {
        goToLocation(line, col)
        Qt.callLater(function() { root._requestCursorCodeActions() })
    }

    function _lineStart(line) {
        return _lineStarts[line] || 0
    }

    function _rebuildLineStarts() {
        var starts = []
        var pos = 0
        for (var i = 0; i < _lineItems.length; i++) {
            starts.push(pos)
            pos += (_lineItems[i].text || "").length + 1
        }
        _lineStarts = starts
    }

    function _visualColFromLogical(line, col) {
        var text = line >= 0 && line < _lineItems.length ? (_lineItems[line].text || "") : ""
        var visual = 0
        var limit = Math.max(0, Math.min(col, text.length))
        for (var i = 0; i < limit; i++) {
            if (text.charAt(i) === "\t")
                visual += root.tabSize - (visual % root.tabSize)
            else
                visual += 1
        }
        return visual
    }

    function _logicalColFromVisual(line, visualCol) {
        var text = line >= 0 && line < _lineItems.length ? (_lineItems[line].text || "") : ""
        var visual = 0
        for (var i = 0; i < text.length; i++) {
            var step = text.charAt(i) === "\t" ? root.tabSize - (visual % root.tabSize) : 1
            if (visualCol < visual + step)
                return i
            visual += step
        }
        return text.length
    }

    function _lineColFromPoint(x, y) {
        var line = Math.floor((y + lineView.contentY) / root.lineHeight)
        line = Math.max(0, Math.min(line, root._lineItems.length - 1))
        var visualCol = Math.floor((x + lineView.contentX - root.gutterWidth - root.contentPadding) / root.charWidth)
        var col = root._logicalColFromVisual(line, Math.max(0, visualCol))
        var maxCol = root._lineItems.length > 0 ? (root._lineItems[line].text || "").length : 0
        col = Math.max(0, Math.min(col, maxCol))
        return { "line": line, "col": col, "pos": root._posFromLineCol(line, col) }
    }

    function _hoverHitFromPoint(x, y) {
        if (root._lineItems.length === 0)
            return { "valid": false, "line": 0, "col": 0, "pos": -1 }

        var hit = root._lineColFromPoint(x, y)
        var text = root._lineItems[hit.line] ? (root._lineItems[hit.line].text || "") : ""
        if (text.length === 0)
            return { "valid": false, "line": hit.line, "col": 0, "pos": -1 }

        var contentX = x + lineView.contentX - root.gutterWidth - root.contentPadding
        if (contentX < 0)
            return { "valid": false, "line": hit.line, "col": hit.col, "pos": -1 }

        var lineWidth = root._visualColFromLogical(hit.line, text.length) * root.charWidth
        if (contentX >= lineWidth)
            return { "valid": false, "line": hit.line, "col": hit.col, "pos": -1 }

        var token = {}
        try { token = JSON.parse(doc.getTokenAt(hit.pos) || "{}") } catch (e) { token = {} }
        if (!token.kind || token.kind === "default")
            return { "valid": false, "line": hit.line, "col": hit.col, "pos": -1 }

        var tokenStart = Math.max(0, Number(token.start || hit.col))
        var tokenEnd = Math.max(tokenStart, Number(token.end || hit.col))
        var tokenText = text.slice(tokenStart, tokenEnd)
        return {
            "valid": true,
            "line": hit.line,
            "col": hit.col,
            "pos": hit.pos,
            "tokenStart": tokenStart,
            "tokenEnd": tokenEnd,
            "tokenText": tokenText,
            "kind": token.kind || "default"
        }
    }

    function _popupPositionForToken(hit) {
        var x = root.gutterWidth + root.contentPadding + root._visualColFromLogical(hit.line, hit.tokenStart || hit.col) * root.charWidth - lineView.contentX + 12
        var y = (hit.line + 1) * root.lineHeight - lineView.contentY + 6
        return {
            "x": Math.min(root.width - tokenInfo.width - 8, Math.max(8, x)),
            "y": Math.min(root.height - tokenInfo.height - 8, Math.max(8, y))
        }
    }

    function _showTokenFallback(hit) {
        if (!hit || !hit.valid) return
        var pos = root._popupPositionForToken(hit)
        root._hoverMode = "symbol"
        root._hoverSeverity = "info"
        root._hoverTitle = hit.tokenText && hit.tokenText.length > 0 ? hit.tokenText : hit.kind
        root._hoverSubtitle = hit.kind + " · line " + (hit.line + 1) + ", col " + ((hit.tokenStart || hit.col) + 1)
        root._hoverBody = root._tokenDescription(hit.kind, hit.tokenText)
        root._hoverBodyRich = false
        root._codeActions = []
        root._hoverCloseRequested = false
        root._hoverAnchorX = pos.x
        root._hoverAnchorY = pos.y
        tokenInfo.x = pos.x
        tokenInfo.y = pos.y
        tokenInfo.visible = true
    }

    function _selectionStartCol(line) {
        if (_selectionEnd <= _selectionStart) return -1
        var start = _lineStart(line)
        var end = start + (_lineItems[line].text || "").length
        var selectedStart = Math.max(_selectionStart, start)
        var selectedEnd = Math.min(_selectionEnd, end)
        return selectedEnd > selectedStart ? root._visualColFromLogical(line, selectedStart - start) : -1
    }

    function _selectionEndCol(line) {
        if (_selectionEnd <= _selectionStart) return -1
        var start = _lineStart(line)
        var end = start + (_lineItems[line].text || "").length
        var selectedStart = Math.max(_selectionStart, start)
        var selectedEnd = Math.min(_selectionEnd, end)
        return selectedEnd > selectedStart ? root._visualColFromLogical(line, selectedEnd - start) : -1
    }

    function _longestLineWidth() {
        var maxChars = 1
        for (var i = 0; i < _lineItems.length; i++) {
            var text = _lineItems[i].text || ""
            if (text.length > maxChars) maxChars = text.length
        }
        if (root.inlineDiagnosticsEnabled && root.diagnostics) {
            for (var j = 0; j < root.diagnostics.length; j++) {
                var d = root.diagnostics[j]
                var lineIndex = Math.max(0, (d.line || 1) - 1)
                var lineText = lineIndex < _lineItems.length ? (_lineItems[lineIndex].text || "") : ""
                var message = d.message || ""
                maxChars = Math.max(maxChars, lineText.length + message.length + 4)
            }
        }
        return root.gutterWidth + root.contentPadding + maxChars * root.charWidth + 32
    }

    function _diagnosticRank(severity) {
        if (severity === "error") return 0
        if (severity === "warning") return 1
        if (severity === "info") return 2
        return 3
    }

    function _inlineDiagnosticForLine(lineIndex) {
        if (!root.inlineDiagnosticsEnabled || !root.diagnostics)
            return ({})
        var best = null
        for (var i = 0; i < root.diagnostics.length; i++) {
            var diagnostic = root.diagnostics[i]
            if (Math.max(0, (diagnostic.line || 1) - 1) !== lineIndex)
                continue
            if (!best || root._diagnosticRank(diagnostic.severity) < root._diagnosticRank(best.severity))
                best = diagnostic
        }
        return best || ({})
    }

    function _updateContentWidth() {
        root._contentWidth = root.wordWrapEnabled ? Math.max(scrollView.width, width - (minimap.visible ? minimap.width : 0)) : Math.max(scrollView.width, root._longestLineWidth())
        if (root.wordWrapEnabled)
            lineView.contentX = 0
    }

    function _scrollTo(x, y) {
        var maxX = Math.max(0, lineView.contentWidth - lineView.width)
        var maxY = Math.max(0, lineView.contentHeight - lineView.height)
        lineView.contentX = Math.max(0, Math.min(x, maxX))
        lineView.contentY = Math.max(0, Math.min(y, maxY))
    }

    function _severityColor(severity) {
        if (severity === "error") return "#E06C75"
        if (severity === "warning") return "#D19A66"
        if (severity === "hint") return "#98C379"
        return "#61AFEF"
    }

    function _tokenDescription(kind, text) {
        var descriptions = {
            "builtin": "Built-in language symbol available without an explicit import.",
            "class": "Class or type declaration in the current document.",
            "comment": "Comment token ignored by runtime execution.",
            "decorator": "Decorator expression applied to a class or function.",
            "docstring": "Documentation string attached to a Python module, class, or function.",
            "function": "Callable function or method symbol.",
            "identifier": "User-defined identifier: variable, symbol, or local name.",
            "keyword": "Reserved language keyword.",
            "module": "Imported module or namespace reference.",
            "number": "Numeric literal.",
            "operator": "Operator or syntax punctuation.",
            "property": "Property, object key, or attribute.",
            "string": "String literal.",
            "type": "Type or type identifier.",
            "variable": "Local variable, binding, or value reference."
        }
        var label = text && text.length > 0 ? "`" + text + "`" : "This token"
        return label + " — " + (descriptions[kind] || "Syntax token detected by Ferrite.")
    }

    function _showDiagnosticTooltip(diagnostic, mouseX, mouseY) {
        if (!diagnostic) return
        var severity = diagnostic.severity || "info"
        root._hoverMode = "diagnostic"
        root._hoverCloseRequested = false
        root._hoverSeverity = severity
        root._hoverTitle = (diagnostic.code && diagnostic.code.length > 0 ? diagnostic.code : severity.toUpperCase())
        root._hoverSubtitle = severity + " · line " + (diagnostic.line || 1) + ", col " + ((diagnostic.col || 0) + 1)
        root._hoverBody = diagnostic.message || "Diagnostic has no message."
        root._hoverBodyRich = false
        var diagLine = Math.max(0, (diagnostic.line || 1) - 1)
        var diagCol = Math.max(0, diagnostic.col || 0)
        var diagEndCol = Math.max(diagCol + 1, diagnostic.endCol || diagCol + 1)
        var anchor = root._popupPositionForToken({
            "line": diagLine,
            "col": diagCol,
            "tokenStart": diagCol,
            "tokenEnd": diagEndCol
        })
        root._hoverAnchorX = anchor.x
        root._hoverAnchorY = anchor.y
        tokenInfo.x = anchor.x
        tokenInfo.y = anchor.y
        tokenInfo.visible = true
        var pos = root._posFromLineCol(diagLine, diagCol)
        root._requestCodeActionsAt(pos, anchor.x, anchor.y)
    }

    function _requestCodeActionsAt(pos, popupX, popupY) {
        if (!EditorVM || root._loadingFile || root.filePath.length === 0) return
        root._codeActions = []
        if (!tokenInfo.visible) {
            root._hoverMode = "actions"
            root._hoverSeverity = "info"
            root._hoverTitle = "Quick fixes"
            root._hoverSubtitle = "Resolving code actions…"
            root._hoverBody = "Waiting for LSP providers."
            root._hoverBodyRich = false
            tokenInfo.x = Math.min(root.width - tokenInfo.width - 8, Math.max(8, popupX))
            tokenInfo.y = Math.min(root.height - tokenInfo.height - 8, Math.max(8, popupY))
            tokenInfo.visible = true
        }
        EditorVM.requestCodeActions(doc.plainText(), pos)
    }

    function _applyCodeAction(action) {
        if (!action) return
        if (EditorVM)
            EditorVM.applyCodeAction(action, doc.plainText())
        tokenInfo.visible = false
    }

    function _requestCursorCodeActions() {
        var x = root.gutterWidth + root.contentPadding + root._visualColFromLogical(root._cursorLine, root._cursorCol) * root.charWidth - lineView.contentX + 14
        var y = (root._cursorLine + 1) * root.lineHeight - lineView.contentY + 6
        root._requestCodeActionsAt(doc.cursorPosition, x, y)
    }

    function _formatHoverBody(text) {
        var value = String(text || "")
        value = value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        value = value.replace(/```([\s\S]*?)```/g, "<pre style='margin:0; color:#DCDCAA;'>$1</pre>")
        value = value.replace(/`([^`]+)`/g, "<span style='color:#DCDCAA;'>$1</span>")
        value = value.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
        value = value.replace(/^### (.*)$/gm, "<span style='color:#E5C07B; font-weight:600;'>$1</span>")
        value = value.replace(/^## (.*)$/gm, "<span style='color:#E5C07B; font-weight:600;'>$1</span>")
        value = value.replace(/^# (.*)$/gm, "<span style='color:#E5C07B; font-weight:600;'>$1</span>")
        value = value.replace(/\n/g, "<br>")
        return value
    }

    function rulerColumns() {
        return []
    }

    function _currentWordPrefix() {
        if (root._lineItems.length === 0)
            return ""
        var lineText = root._lineItems[root._cursorLine] ? (root._lineItems[root._cursorLine].text || "") : ""
        var col = Math.max(0, Math.min(root._cursorCol, lineText.length))
        var start = col
        while (start > 0 && /[A-Za-z0-9_$]/.test(lineText.charAt(start - 1)))
            start--
        return lineText.slice(start, col)
    }

    function _completionInsertText(item) {
        var value = item.insertText || item.text || item.label || ""
        if (!value)
            return ""
        var prefix = root._currentWordPrefix()
        if (prefix.length > 0 && value.indexOf(prefix) === 0)
            return value.slice(prefix.length)
        return value
    }

    Item {
        id: scrollView
        anchors.left: parent.left
        anchors.right: minimap.visible ? minimap.left : parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        clip: true

        WheelHandler {
            target: null
            onWheel: function(event) {
                if (event.modifiers & Qt.ShiftModifier || Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)) {
                    var nextX = lineView.contentX - (event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y) / 120 * root.charWidth * 8
                    root._scrollTo(nextX, lineView.contentY)
                } else {
                    var nextY = lineView.contentY - event.angleDelta.y / 120 * root.lineHeight * 3
                    root._scrollTo(lineView.contentX, nextY)
                }
                event.accepted = true
            }
        }

        ListView {
            id: lineView
            anchors.fill: parent
            contentWidth: root._contentWidth
            model: root._lineItems
            spacing: 0
            cacheBuffer: 100
            boundsBehavior: Flickable.StopAtBounds
            boundsMovement: Flickable.StopAtBounds
            interactive: false
            clip: true
            footer: Item { width: 1; height: Math.max(root.lineHeight * 2, hScroll.visible ? hScroll.height + root.lineHeight : root.lineHeight) }

            delegate: TokenLine {
                width: lineView.contentWidth
                height: root.lineHeight
                lineText: modelData.text || ""
                lineSpans: modelData.spans || []
                lineNumber: modelData.lineNumber || index + 1
                editorFont: root.editorFont
                fontWidth: root.charWidth
                gutterWidth: root.gutterWidth
                contentPadding: root.contentPadding
                theme: root.theme
                tokenColors: root.tokenColors
                inlineDiagnostic: root._inlineDiagnosticForLine(index)
                selectionStartCol: root._selectionStartCol(index)
                selectionEndCol: root._selectionEndCol(index)
                isActiveLine: index === root._cursorLine
                hoverEnabled: true

                onTokenHovered: function(kind, text, start, end, mx, my) {
                    // Centralized in editorHitArea to keep hover anchored to token coordinates.
                }
            }

            ScrollBar.vertical: ScrollBar { id: internalVBar; policy: ScrollBar.AlwaysOff }
            ScrollBar.horizontal: ScrollBar { id: internalHBar; policy: ScrollBar.AlwaysOff }
        }

        Repeater {
            model: root.rulerColumns()
            delegate: Rectangle {
                required property int modelData
                x: root.gutterWidth + root.contentPadding + modelData * root.charWidth - lineView.contentX
                y: 0
                width: 1
                height: scrollView.height
                visible: x >= root.gutterWidth && x <= scrollView.width
                color: Qt.rgba(root.theme.border.r, root.theme.border.g, root.theme.border.b, 0.42)
                z: 2
            }
        }

        MouseArea {
            id: editorHitArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            preventStealing: true
            property bool selecting: false

            onPressed: function(mouse) {
                root.forceActiveFocus()
                if (root._lineItems.length === 0) return
                var hit = root._lineColFromPoint(mouse.x, mouse.y)
                doc.moveCursor(hit.pos)
                selecting = true
            }

            onPositionChanged: function(mouse) {
                root._editorHovered = true
                if (root._lineItems.length === 0) return
                if (selecting) {
                    var hit = root._lineColFromPoint(mouse.x, mouse.y)
                    doc.moveCursorSelect(hit.pos)
                    return
                }
                var diagnostic = diagnosticsOverlay.diagnosticAt(mouse.x, mouse.y)
                if (diagnostic) {
                    hoverTimer.stop()
                    root._pendingHoverHit = null
                    root._hoverPos = -1
                    root._hoverCloseRequested = false
                    diagnosticsOverlay.hoveredDiagnostic = diagnostic
                    diagnosticsOverlay.requestPaint()
                    hoverHideTimer.stop()
                    root._showDiagnosticTooltip(diagnostic, mouse.x, mouse.y)
                    return
                } else if (diagnosticsOverlay.hoveredDiagnostic) {
                    diagnosticsOverlay.hoveredDiagnostic = null
                    diagnosticsOverlay.requestPaint()
                }
                var hit = root._hoverHitFromPoint(mouse.x, mouse.y)
                if (!hit.valid) {
                    hoverTimer.stop()
                    root._pendingHoverHit = null
                    root._hoverPos = -1
                    root._hoverCloseRequested = true
                    hoverHideTimer.restart()
                    return
                }
                hoverHideTimer.stop()
                root._hoverCloseRequested = false
                if (root._hoverPos !== hit.pos) {
                    root._hoverPos = hit.pos
                    root._hoverX = mouse.x
                    root._hoverY = mouse.y
                    root._pendingHoverHit = hit
                    hoverTimer.restart()
                }
            }

            onExited: {
                root._editorHovered = false
                hoverTimer.stop()
                root._pendingHoverHit = null
                root._hoverCloseRequested = true
                diagnosticsOverlay.hoveredDiagnostic = null
                diagnosticsOverlay.requestPaint()
                hoverHideTimer.restart()
            }
            onReleased: function(mouse) { selecting = false }
            onWheel: function(wheel) {
                if (wheel.modifiers & Qt.ShiftModifier || Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)) {
                    root._scrollTo(lineView.contentX - (wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y) / 120 * root.charWidth * 8, lineView.contentY)
                } else {
                    root._scrollTo(lineView.contentX, lineView.contentY - wheel.angleDelta.y / 120 * root.lineHeight * 3)
                }
                wheel.accepted = true
            }
        }

        ScrollBar {
            id: vScroll
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: hScroll.top
            orientation: Qt.Vertical
            policy: lineView.contentHeight > lineView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            size: lineView.contentHeight > 0 ? Math.min(1, lineView.height / lineView.contentHeight) : 1
            position: lineView.contentHeight > lineView.height ? lineView.contentY / (lineView.contentHeight - lineView.height) * (1 - size) : 0
            onPositionChanged: {
                if (pressed)
                    root._scrollTo(lineView.contentX, position / Math.max(0.0001, 1 - size) * Math.max(0, lineView.contentHeight - lineView.height))
            }
        }

        ScrollBar {
            id: hScroll
            anchors.left: parent.left
            anchors.right: vScroll.left
            anchors.bottom: parent.bottom
            orientation: Qt.Horizontal
            policy: !root.wordWrapEnabled && lineView.contentWidth > lineView.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            size: lineView.contentWidth > 0 ? Math.min(1, lineView.width / lineView.contentWidth) : 1
            position: lineView.contentWidth > lineView.width ? lineView.contentX / (lineView.contentWidth - lineView.width) * (1 - size) : 0
            onPositionChanged: {
                if (pressed)
                    root._scrollTo(position / Math.max(0.0001, 1 - size) * Math.max(0, lineView.contentWidth - lineView.width), lineView.contentY)
            }
        }
    }

    Rectangle {
        id: minimap
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.minimapWidth : (root.metrics.minimapWidth || 96)
        color: root.theme.panel || "#141414"
        border.color: root.theme.border || "#303030"
        visible: root._lineItems.length > 0 && ((typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.minimapEnabled : true)

        Canvas {
            id: minimapCanvas
            anchors.fill: parent
            anchors.margins: 4
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var gradient = ctx.createLinearGradient(0, 0, width, 0)
                gradient.addColorStop(0, "#3C5A78")
                gradient.addColorStop(0.65, "#6A6A6A")
                gradient.addColorStop(1, "#A0A0A0")
                ctx.fillStyle = gradient
                var step = Math.max(1, root._lineItems.length / height)
                for (var y = 0; y < height; y++) {
                    var line = Math.floor(y * step)
                    if (line >= root._lineItems.length) break
                    var text = root._lineItems[line].text || ""
                    var w = Math.min(width, Math.max(2, text.length * 0.45))
                    ctx.globalAlpha = line === root._cursorLine ? 0.95 : 0.28
                    ctx.fillRect(0, y, w, 1)
                }
                ctx.globalAlpha = 1
                if (((typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.minimapDiagnostics : true) && root.diagnostics && root.diagnostics.length > 0) {
                    for (var i = 0; i < root.diagnostics.length; i++) {
                        var d = root.diagnostics[i]
                        var diagLine = Math.max(0, (d.line || 1) - 1)
                        var diagY = Math.max(0, Math.min(height - 2, diagLine / Math.max(1, root._lineItems.length) * height))
                        ctx.fillStyle = d.severity === "error" ? "#E06C75" :
                                        (d.severity === "warning" ? "#D7BA7D" : "#61AFEF") // #D19A66 : "#98C379" : "#61AFEF"
                        ctx.globalAlpha = 0.95
                        ctx.fillRect(width - 8, diagY, 6, 2)
                    }
                    ctx.globalAlpha = 1
                }
            }
            Connections {
                target: root
                function onPlainTextChanged() { minimapCanvas.requestPaint() }
                function onDiagnosticsChanged() { minimapCanvas.requestPaint() }
            }
        }

        Rectangle {
            width: parent.width
            height: Math.max(24, parent.height * lineView.visibleArea.heightRatio)
            y: parent.height * lineView.visibleArea.yPosition
            radius: 3
            color: Qt.rgba(0.0, 0.47, 0.83, 0.20)
            border.color: Qt.rgba(0.3, 0.7, 1.0, 0.32)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) {
                if (lineView.contentHeight <= lineView.height) return
                lineView.contentY = Math.max(0, Math.min(lineView.contentHeight - lineView.height, mouse.y / height * lineView.contentHeight))
            }
        }
    }

    // ── Cursor ─────────────────────────────────────────

    Rectangle {
        id: cursorBlink
        width: 2; height: root.lineHeight
        color: root.theme.editorCursor || "#FFFFFF"
        visible: root.activeFocus && _lineItems.length > 0
        z: 10

        x: root.gutterWidth + root.contentPadding + root._visualColFromLogical(root._cursorLine, root._cursorCol) * root.charWidth - lineView.contentX
        y: root._cursorLine * root.lineHeight - lineView.contentY

        Timer {
            interval: 500; running: cursorBlink.visible; repeat: true
            onTriggered: cursorBlink.opacity = cursorBlink.opacity > 0.5 ? 0.2 : 1.0
        }
    }

    // ── Selection overlay ──────────────────────────────

    // ── Token tooltip ──────────────────────────────────

    Rectangle {
        id: tokenInfo
        visible: false
        color: root.theme.panel || "#252526"
        border.color: root._severityColor(root._hoverSeverity)
        border.width: 1
        radius: 8
        width: 420
        readonly property real maxPopupHeight: 420
        readonly property real minBodyHeight: 28
        readonly property real maxBodyHeight: 260
        readonly property real chromeHeight: hoverHeader.implicitHeight + quickFixSection.implicitHeight + hoverActions.implicitHeight + 51
        readonly property real bodyHeight: Math.min(maxBodyHeight, Math.max(minBodyHeight, hoverBodyText.contentHeight))
        height: Math.max(112, Math.min(maxPopupHeight, chromeHeight + bodyHeight))
        z: 100

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse
            onHoveredChanged: {
                if (hovered) {
                    hoverHideTimer.stop()
                    root._tokenInfoHovered = true
                    root._hoverCloseRequested = false
                } else {
                    root._tokenInfoHovered = false
                    root._hoverCloseRequested = true
                    hoverHideTimer.restart()
                }
            }
        }

        Column {
            id: hoverColumn
            anchors.fill: parent
            anchors.margins: 9
            spacing: 8

            Row {
                id: hoverHeader
                width: parent.width
                spacing: 8

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root._severityColor(root._hoverSeverity)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - 24
                    spacing: 2
                    Text {
                        text: root._hoverTitle
                        color: root.theme.textStrong || "#F3F4F6"
                        font.bold: true
                        font.pointSize: 11
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: root._hoverSubtitle
                        color: root.theme.textDim || "#9CA3AF"
                        font.pointSize: 9
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.theme.border || "#333842" }

            ScrollView {
                id: hoverBodyScroll
                width: parent.width
                height: Math.max(tokenInfo.minBodyHeight, tokenInfo.height - tokenInfo.chromeHeight)
                implicitHeight: height
                clip: true

                TextArea {
                    id: hoverBodyText
                    text: root._hoverBody
                    color: root.theme.text || "#D4D4D4"
                    font.family: root.editorFont.family
                    font.pointSize: Math.max(9, root.editorFont.pointSize - 1)
                    textFormat: root._hoverBodyRich ? TextEdit.RichText : TextEdit.MarkdownText
                    wrapMode: Text.WordWrap
                    readOnly: true
                    selectByMouse: true
                    selectedTextColor: "#FFFFFF"
                    selectionColor: "#264F78"
                    background: null
                    padding: 0
                    width: hoverBodyScroll.width - 12
                }
            }

            Column {
                id: quickFixSection
                visible: root._codeActions && root._codeActions.length > 0
                width: parent.width
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 7

                    Rectangle {
                        width: 19
                        height: 18
                        radius: 5
                        color: Qt.rgba(0.23, 0.51, 0.96, 0.18)
                        border.color: Qt.rgba(0.38, 0.64, 1.0, 0.45)
                        Text {
                            anchors.centerIn: parent
                            text: "FX"
                            color: root.theme.info || "#93C5FD"
                            font.pixelSize: 8
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        width: parent.width - 26
                        text: "Quick fixes"
                        color: root.theme.textStrong || "#BFDBFE"
                        font.pointSize: 9
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root._codeActions && root._codeActions.length > 0 ? root._codeActions.slice(0, 5) : []

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool disabled: modelData.disabled && Object.keys(modelData.disabled).length > 0
                            width: quickFixSection.width
                            height: disabled ? 42 : 34
                            radius: 6
                            opacity: disabled ? 0.62 : 1
                            color: quickFixMouse.containsMouse && !disabled ? Qt.rgba(0.23, 0.51, 0.96, 0.22) : Qt.rgba(255, 255, 255, 0.035)
                            border.color: quickFixMouse.containsMouse ? Qt.rgba(0.38, 0.64, 1.0, 0.45) : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9
                                spacing: 8

                                Text {
                                    text: modelData.isPreferred ? "P" : "•"
                                    color: modelData.isPreferred ? "#A7F3D0" : "#93C5FD"
                                    font.pixelSize: modelData.isPreferred ? 9 : 14
                                    font.weight: Font.Bold
                                    width: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Column {
                                    width: parent.width - 28
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Text {
                                        text: modelData.title || "Quick Fix"
                                        color: root.theme.textStrong || "#F3F4F6"
                                        font.pointSize: 9
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Text {
                                        visible: disabled || (modelData.kind && modelData.kind.length > 0)
                                        text: disabled ? (modelData.disabled.reason || "Unavailable") : (modelData.kind || "")
                                        color: root.theme.textDim || "#9CA3AF"
                                        font.pointSize: 8
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }

                            MouseArea {
                                id: quickFixMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: parent.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                onClicked: if (!parent.disabled) root._applyCodeAction(modelData)
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.theme.border || "#333842" }
            }

            Row {
                id: hoverActions
                spacing: 8
                HoverActionButton {
                    label: "Select"
                    onClicked: {
                        hoverBodyText.forceActiveFocus()
                        hoverBodyText.selectAll()
                    }
                }
                HoverActionButton {
                    label: "Dismiss"
                    onClicked: tokenInfo.visible = false
                }
            }
        }
    }

    component HoverActionButton: Rectangle {
        id: actionRoot
        property string label: ""
        signal clicked()
        width: Math.max(76, Math.min(160, actionText.contentWidth + 20))
        height: 24
        radius: 5
        color: actionMouse.containsMouse ? (root.theme.accent || "#3B82F6") : (root.theme.inputBg || "#2D2D30")
        border.color: actionMouse.containsMouse ? (root.theme.accentHover || "#60A5FA") : (root.theme.border || "#454545")

        Text {
            id: actionText
            anchors.centerIn: parent
            text: actionRoot.label
            color: root.theme.textStrong || "#F3F4F6"
            font.pointSize: 9
            font.weight: Font.DemiBold
            width: actionRoot.width - 12
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRoot.clicked()
        }
    }

    // ── Suggestion box ─────────────────────────────────

    SuggestionBox {
        id: suggestionBox
        theme: root.theme
        tokenColors: root.tokenColors
        width: 320; implicitHeight: 220
        y: (root._cursorLine + 1) * root.lineHeight - lineView.contentY
        x: root.gutterWidth + root.contentPadding + root._visualColFromLogical(root._cursorLine, root._cursorCol) * root.charWidth - lineView.contentX
        visible: false
        editor: root

        onItemSelected: function(item) {
            var insertText = root._completionInsertText(item)
            if (insertText.length > 0)
                doc.typeText(insertText)
            suggestionBox.visible = false
            root.forceActiveFocus()
        }
    }

    // ── Inline suggestion (ghost text) ─────────────────

    Text {
        id: inlineHint
        visible: doc.aiSuggestion.length > 0
        font: root.editorFont; color: root.theme.textDim || "#5A5A5A"
        x: root.gutterWidth + root.contentPadding + root._visualColFromLogical(root._cursorLine, root._cursorCol) * root.charWidth - lineView.contentX
        y: root._cursorLine * root.lineHeight - lineView.contentY
        text: doc.aiSuggestion
        z: 5
    }

    // ── Diagnostics overlay ────────────────────────────

    DiagnosticsOverlay {
        id: diagnosticsOverlay
        anchors.fill: scrollView
        editorLineCount: root._lineItems.length
        editorLineHeight: root.lineHeight
        diagnostics: root.diagnostics
        visibleAreaY: lineView.contentY
        contentX: lineView.contentX
        charWidth: root.charWidth
        gutterWidth: root.gutterWidth
        contentPadding: root.contentPadding
        visible: root.diagnostics && root.diagnostics.length > 0

        onDiagnosticHovered: function(diagnostic, mouseX, mouseY) {
            root._showDiagnosticTooltip(diagnostic, mouseX, mouseY)
        }
        onDiagnosticExited: {
            root._hoverPos = -1
            root._hoverCloseRequested = true
            hoverHideTimer.restart()
        }
    }

    // ── Key handling ──────────────────────────────────

    Keys.onPressed: function(event) {
        if (event.matches(StandardKey.Copy)) {
            event.accepted = true; doc.copySelection(); return
        }
        if (event.matches(StandardKey.Cut)) {
            event.accepted = true; doc.cutSelection(); root._triggerCompletions(); return
        }
        if (event.matches(StandardKey.Paste)) {
            event.accepted = true; doc.pasteClipboard(); root._triggerCompletions(); return
        }
        if (event.matches(StandardKey.Undo)) {
            event.accepted = true; doc.undo(); root._triggerCompletions(); return
        }
        if (event.matches(StandardKey.Redo)) {
            event.accepted = true; doc.redo(); root._triggerCompletions(); return
        }
        if (event.matches(StandardKey.SelectAll)) {
            event.accepted = true; doc.selectAll(); return
        }

        if (event.key === Qt.Key_Space && (event.modifiers & Qt.ControlModifier)) {
            event.accepted = true
            root._forceSuggestions()
            return
        }

        if (event.key === Qt.Key_Period && (event.modifiers & Qt.ControlModifier)) {
            event.accepted = true
            root._requestCursorCodeActions()
            return
        }

        if (suggestionBox.visible) {
            if (event.key === Qt.Key_Down) { suggestionBox.selectNext(); event.accepted = true; return }
            if (event.key === Qt.Key_Up) { suggestionBox.selectPrevious(); event.accepted = true; return }
            if (event.key === Qt.Key_Space && ((typeof SettingsVM === "undefined" || !SettingsVM) || SettingsVM.suggestionsDetailsOnSpace)) { suggestionBox.toggleDetails(); event.accepted = true; return }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                suggestionBox.acceptSelected(); event.accepted = true; return
            }
        }

        if (event.key === Qt.Key_Tab) {
            event.accepted = true
            if (doc.aiSuggestion.length > 0) { doc.acceptSuggestion(); return }
            doc.doTab()
            return
        }

        if (event.key === Qt.Key_Escape && doc.aiSuggestion.length > 0) {
            event.accepted = true; doc.rejectSuggestion(); return
        }

        // Navigation
        if (event.key === Qt.Key_Left) {
            event.accepted = true
            if (event.modifiers & Qt.ShiftModifier) doc.moveCursorSelect(doc.cursorPosition - 1)
            else doc.moveCursor(doc.cursorPosition - 1)
            return
        }
        if (event.key === Qt.Key_Right) {
            event.accepted = true
            if (event.modifiers & Qt.ShiftModifier) doc.moveCursorSelect(doc.cursorPosition + 1)
            else doc.moveCursor(doc.cursorPosition + 1)
            return
        }
        if (event.key === Qt.Key_Up) {
            event.accepted = true
            var upPos = _posFromLineCol(_cursorLine - 1, _cursorCol)
            if (event.modifiers & Qt.ShiftModifier) doc.moveCursorSelect(upPos)
            else doc.moveCursor(upPos)
            return
        }
        if (event.key === Qt.Key_Down) {
            event.accepted = true
            var downPos = _posFromLineCol(_cursorLine + 1, _cursorCol)
            if (event.modifiers & Qt.ShiftModifier) doc.moveCursorSelect(downPos)
            else doc.moveCursor(downPos)
            return
        }
        if (event.key === Qt.Key_Home) {
            event.accepted = true
            var homePos = _posFromLineCol(_cursorLine, 0)
            if (event.modifiers & Qt.ShiftModifier) doc.moveCursorSelect(homePos)
            else doc.moveCursor(homePos)
            return
        }
        if (event.key === Qt.Key_End) {
            event.accepted = true
            var endPos = _posFromLineCol(_cursorLine, (_lineItems[_cursorLine].text || "").length)
            if (event.modifiers & Qt.ShiftModifier) doc.moveCursorSelect(endPos)
            else doc.moveCursor(endPos)
            return
        }
        if (event.key === Qt.Key_PageUp) {
            event.accepted = true
            var linesUp = Math.floor(scrollView.height / root.lineHeight)
            var puPos = _posFromLineCol(_cursorLine - linesUp, _cursorCol)
            doc.moveCursor(puPos); return
        }
        if (event.key === Qt.Key_PageDown) {
            event.accepted = true
            var linesDown = Math.floor(scrollView.height / root.lineHeight)
            var pdPos = _posFromLineCol(_cursorLine + linesDown, _cursorCol)
            doc.moveCursor(pdPos); return
        }

        // Editing
        if (event.key === Qt.Key_Backspace) {
            event.accepted = true; doc.doBackspace(); _triggerCompletions(); return
        }
        if (event.key === Qt.Key_Delete) {
            event.accepted = true; doc.doDelete(); _triggerCompletions(); return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true; doc.doNewline(); _triggerCompletions(); return
        }

        // Text input (printable characters)
        var text = event.text
        var textModifiers = event.modifiers & ~(Qt.ShiftModifier | Qt.KeypadModifier)
        if (text.length > 0 && text.charCodeAt(0) >= 32 && text.charCodeAt(0) !== 127 && textModifiers === Qt.NoModifier) {
            event.accepted = true; doc.typeText(text); _triggerCompletions(); return
        }
    }

    // ── Data sync from backend ─────────────────────────

    Connections {
        target: doc
        function onTokensChanged(jsonStr) {
            minimapCanvas.requestPaint()
        }
        function onLinesChanged() {
            var keepX = lineView.contentX
            var keepY = lineView.contentY
            root._lineItems = doc.lines
            root._lines = root._lineItems.map(function(item) { return item.text || "" })
            root._rebuildLineStarts()
            root._updateContentWidth()
            lineView.contentX = keepX
            lineView.contentY = keepY
            minimapCanvas.requestPaint()
            root._triggerLanguageFeatures()
        }
        function onCursorChanged(line, col) {
            root._cursorLine = line; root._cursorCol = col
            root.cursorPositionChanged()
            suggestionBox.close()
            _ensureCursorVisible()
        }
        function onSelectionChanged() {
            root._selectionStart = doc.selectionStart
            root._selectionEnd = doc.selectionEnd
        }
        function onTextChanged() {
            root._syncingFromDoc = true
            root.plainText = doc.plainText()
            root._syncingFromDoc = false
            if (!root._loadingFile && root.autoSaveEnabled && root.filePath.length > 0 && doc.isDirty)
                autoSaveTimer.restart()
        }
        function onSuggestionChanged(text) {
            if (text.length > 0) inlineHint.visible = true
            else inlineHint.visible = false
        }
    }

    Timer {
        id: autoSaveTimer
        interval: Math.max(250, root.autoSaveDelayMs)
        repeat: false
        onTriggered: {
            if (!root.visible || root._loadingFile || !root.autoSaveEnabled || root.filePath.length === 0 || !doc.isDirty)
                return
            EditorVM.savefile(root.filePath, EditorVM.get_filename(root.filePath), doc.plainText())
        }
    }

    function _ensureCursorVisible() {
        var cy = root._cursorLine * root.lineHeight
        var vh = scrollView.height
        var maxY = Math.max(0, lineView.contentHeight - vh)
        if (cy < lineView.contentY) lineView.contentY = Math.max(0, cy)
        if (cy + root.lineHeight > lineView.contentY + vh)
            lineView.contentY = Math.min(maxY, cy + root.lineHeight - vh + 20)
        var cx = root.gutterWidth + root.contentPadding + root._visualColFromLogical(root._cursorLine, root._cursorCol) * root.charWidth
        var maxX = Math.max(0, lineView.contentWidth - lineView.width)
        if (cx < lineView.contentX + root.gutterWidth)
            lineView.contentX = Math.max(0, cx - root.gutterWidth - root.contentPadding)
        if (cx + root.charWidth > lineView.contentX + lineView.width)
            lineView.contentX = Math.min(maxX, cx + root.charWidth - lineView.width + 20)
    }

    function _triggerCompletions() {
        if (_loadingFile) return
        if (!root.activeFocus) return
        if (root._hoverMode === "actions")
            tokenInfo.visible = false
        root._codeActions = []
        if ((typeof SettingsVM === "undefined" || !SettingsVM) || SettingsVM.lspEnabled)
            lspSyncTimer.restart()
        if ((typeof SettingsVM === "undefined" || !SettingsVM) || SettingsVM.aiInlineSuggestions)
            aiTimer.restart()
        if ((typeof SettingsVM === "undefined" || !SettingsVM) || SettingsVM.suggestionsAuto)
            completionTimer.restart()
        if ((typeof SettingsVM === "undefined" || !SettingsVM) || SettingsVM.diagnosticsOnType)
            diagnosticsTimer.restart()
    }

    function _forceSuggestions() {
        if (_loadingFile || !root.visible) return
        EditorVM.requestCompletionsForced(doc.plainText(), doc.cursorPosition)
        suggestionBox.open()
    }

    function _triggerLanguageFeatures() {
        if (_loadingFile) return
        if ((typeof SettingsVM === "undefined" || !SettingsVM) || SettingsVM.lspEnabled)
            lspSyncTimer.restart()
        symbolsTimer.restart()
        if ((typeof SettingsVM === "undefined" || !SettingsVM) || SettingsVM.diagnosticsOnType)
            diagnosticsTimer.restart()
    }

    // ── AI completions ─────────────────────────────────

    Timer {
        id: aiTimer; interval: 400; repeat: false
        onTriggered: {
            if ((typeof SettingsVM !== "undefined" && SettingsVM) && !SettingsVM.aiInlineSuggestions) return
            var text = doc.plainText()
            var cursor = doc.cursorPosition
            if (text.length > 0 && cursor > 0)
                EditorVM.requestAiSuggestion(text, cursor)
        }
    }

    Timer {
        id: completionTimer
        interval: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.suggestionsDelayMs : 260
        repeat: false
        onTriggered: {
            if ((typeof SettingsVM !== "undefined" && SettingsVM) && !SettingsVM.suggestionsAuto) return
            var text = doc.plainText()
            var cursor = doc.cursorPosition
            if (text.length > 0 && cursor > 0)
                EditorVM.requestCompletions(text, cursor)
        }
    }

    Timer {
        id: lspSyncTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (root._loadingFile || !root.visible || root.filePath.length === 0) return
            if ((typeof SettingsVM !== "undefined" && SettingsVM) && !SettingsVM.lspEnabled) return
            EditorVM.syncDocument(root.filePath, doc.plainText())
        }
    }

    Timer {
        id: hoverTimer
        interval: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.hoverDelayMs : 1000
        repeat: false
        onTriggered: {
            if (root._hoverPos < 0 || root._loadingFile || !root.visible) return
            if (!root._pendingHoverHit || root._pendingHoverHit.pos !== root._hoverPos) return
            root._showTokenFallback(root._pendingHoverHit)
            if ((typeof SettingsVM !== "undefined" && SettingsVM) && !SettingsVM.lspEnabled) return
            EditorVM.requestHover(doc.plainText(), root._hoverPos)
        }
    }

    Timer {
        id: hoverHideTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (root._hoverCloseRequested && !root._tokenInfoHovered) {
                tokenInfo.visible = false
                root._hoverCloseRequested = false
                root._hoverPos = -1
                root._pendingHoverHit = null
            }
        }
    }

    Timer {
        id: symbolsTimer
        interval: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.symbolsDelayMs : 1400
        repeat: false
        onTriggered: {
            if ((typeof SettingsVM !== "undefined" && SettingsVM) && !SettingsVM.lspEnabled) return
            if (root._loadingFile || !root.visible) return
            EditorVM.requestDocumentSymbols(doc.plainText())
            EditorVM.refreshLspStatus()
        }
    }

    Timer {
        id: diagnosticsTimer
        interval: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.diagnosticsDelayMs : 1600
        repeat: false
        onTriggered: {
            if (root._loadingFile || !root.visible || root.filePath.length === 0) return
            if ((typeof SettingsVM !== "undefined" && SettingsVM) && (!SettingsVM.lspEnabled || !SettingsVM.diagnosticsOnType)) return
            EditorVM.requestDiagnosticsForCode(root.filePath, doc.plainText())
        }
    }

    Connections {
        target: EditorVM
        function onCompleterReady(jsonStr) {
            if (root.activeFocus && root.visible) suggestionBox.updateFromJson(jsonStr)
        }
        function onSuggestionReady(suggestion) { doc.setAiSuggestion(suggestion) }
        function onDiagnosticsReady(diags) {
            root.diagnostics = diags
            root._updateContentWidth()
        }
        function onCodeActionsReady(actions) {
            if (!root.visible) return
            root._codeActions = actions || []
            if (root._hoverMode === "actions") {
                root._hoverSubtitle = root._codeActions.length > 0
                                    ? root._codeActions.length + " action" + (root._codeActions.length > 1 ? "s" : "") + " available"
                                    : "No code action available"
                root._hoverBody = root._codeActions.length > 0
                                ? "Select a quick fix below to apply it to the current document."
                                : "No LSP provider returned a fix for this position."
                tokenInfo.visible = true
            }
        }
        function onCodeActionApplied(path, content) {
            if (path !== root.filePath) return
            var keepX = lineView.contentX
            var keepY = lineView.contentY
            doc.loadText(content || "")
            lineView.contentX = keepX
            lineView.contentY = keepY
            tokenInfo.visible = false
            root._codeActions = []
            root._triggerLanguageFeatures()
            root.forceActiveFocus()
        }
        function onFileFormatted(path, content) {
            if (path !== root.filePath) return
            var keepX = lineView.contentX
            var keepY = lineView.contentY
            doc.loadText(content || "")
            lineView.contentX = keepX
            lineView.contentY = keepY
            root._triggerLanguageFeatures()
            root.forceActiveFocus()
        }
        function onFileSaved(path) {
            if (path !== root.filePath) return
            doc.markClean()
        }
        function onHoverReady(info) {
            if (!root.visible || root._hoverPos < 0 || !info || !info.contents) return
            var token = {}
            try { token = JSON.parse(doc.getTokenAt(root._hoverPos) || "{}") } catch (e) { token = {} }
            var hoverHit = root._lineColFromPoint(root._hoverX, root._hoverY)
            var displayName = info.name || info.symbol || info.word || ""
            root._hoverMode = "symbol"
            root._hoverSeverity = "info"
            root._hoverTitle = displayName.length > 0 ? displayName : (token.kind ? token.kind : (info.kind || "symbol"))
            root._hoverSubtitle = (info.kind || token.kind || "symbol") + " · " + (info.language || root.language || "text") + " · line " + (hoverHit.line + 1) + ", col " + (hoverHit.col + 1)
            root._hoverBody = info.documentation || info.signature || info.description || info.contents
            if (info.signature && info.documentation)
                root._hoverBody = info.signature + "\n\n" + info.documentation
            if (info.bodyHtml && info.bodyHtml.length > 0) {
                root._hoverBody = info.bodyHtml
                root._hoverBodyRich = true
            } else {
                root._hoverBodyRich = false
            }
            tokenInfo.x = Math.min(root.width - tokenInfo.width - 8, Math.max(8, root._hoverAnchorX))
            tokenInfo.y = Math.min(root.height - tokenInfo.height - 8, Math.max(8, root._hoverAnchorY))
            tokenInfo.visible = true
        }
        function onSymbolsReady(symbols) { root.documentSymbols = symbols || [] }
        function onFileContentReady(path, content) { root._applyLoadedFile(path, content) }
        function onFileOpenFailed(path, message) {
            if (path === root._pendingFilePath) {
                root._loadingFile = false
                root._applyLoadedFile(path, "")
            }
        }
    }

    Connections {
        target: PluginVM
        enabled: typeof PluginVM !== "undefined" && PluginVM
        function onContributionsChanged() {
            root.inlineDiagnosticsEnabled = PluginVM.hasEditorDecoration("ember.inlineDiagnostics")
            root._updateContentWidth()
        }
    }

    Component.onCompleted: {
        if (typeof PluginVM !== "undefined" && PluginVM) {
            root.inlineDiagnosticsEnabled = PluginVM.hasEditorDecoration("ember.inlineDiagnostics")
            root._updateContentWidth()
        }
    }

    EditorDocument { id: doc }
}
