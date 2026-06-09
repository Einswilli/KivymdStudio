import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Ember.Editor 1.0
import "../components"

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
    property bool _hoverTokenHovered: false
    property bool _editorHovered: false
    property bool _hoverCloseRequested: false
    property var _codeActions: []
    property bool _autoPreviewNextCodeAction: false
    property bool _shiftKeyDown: false
    property bool _suppressWordNavigationEvent: false
    property var _foldedRanges: ({})
    property var _locationResults: []
    property string _locationPopupTitle: "Locations"
    property var _pendingCodeAction: ({})
    property string _codeActionPreviewTitle: ""
    property string _codeActionPreviewMessage: ""
    property string _codeActionPreviewText: ""
    property var _codeActionPickerActions: []
    property string _codeActionPickerTitle: "Quick Fixes"
    property string _codeActionPickerSubtitle: ""
    property bool _findPanelVisible: false
    property bool _replacePanelVisible: false
    property string _findQuery: ""
    property string _replaceQuery: ""
    property bool _findCaseSensitive: false
    property var _findMatches: []
    property int _findIndex: -1
    property bool _goToLinePanelVisible: false
    property string _goToLineValue: ""
    property var _bracketHighlights: []

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

    Timer {
        id: suppressWordNavigationTimer
        interval: 80
        repeat: false
        onTriggered: root._suppressWordNavigationEvent = false
    }

    function _selectPreviousWordFromShortcut() {
        root._suppressWordNavigationEvent = true
        suppressWordNavigationTimer.restart()
        doc.moveWordLeft(true)
        Qt.callLater(function() { root._ensureCursorVisible() })
    }

    function _selectNextWordFromShortcut() {
        root._suppressWordNavigationEvent = true
        suppressWordNavigationTimer.restart()
        doc.moveWordRight(true)
        Qt.callLater(function() { root._ensureCursorVisible() })
    }

    Shortcut { sequence: StandardKey.SelectPreviousWord; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root._selectPreviousWordFromShortcut(); onActivatedAmbiguously: root._selectPreviousWordFromShortcut() }
    Shortcut { sequence: StandardKey.SelectNextWord; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root._selectNextWordFromShortcut(); onActivatedAmbiguously: root._selectNextWordFromShortcut() }
    Shortcut { sequence: "Ctrl+Shift+Left"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root._selectPreviousWordFromShortcut(); onActivatedAmbiguously: root._selectPreviousWordFromShortcut() }
    Shortcut { sequence: "Ctrl+Shift+Right"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root._selectNextWordFromShortcut(); onActivatedAmbiguously: root._selectNextWordFromShortcut() }
    Shortcut { sequence: "Meta+Shift+Left"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root._selectPreviousWordFromShortcut(); onActivatedAmbiguously: root._selectPreviousWordFromShortcut() }
    Shortcut { sequence: "Meta+Shift+Right"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root._selectNextWordFromShortcut(); onActivatedAmbiguously: root._selectNextWordFromShortcut() }
    Shortcut { sequence: "Cmd+Shift+Left"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root._selectPreviousWordFromShortcut(); onActivatedAmbiguously: root._selectPreviousWordFromShortcut() }
    Shortcut { sequence: "Cmd+Shift+Right"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root._selectNextWordFromShortcut(); onActivatedAmbiguously: root._selectNextWordFromShortcut() }

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
        root._foldedRanges = {}
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
        _hoverTokenHovered = false
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

    function openGoToLinePanel() {
        root._goToLineValue = String(root.cursorLine)
        root._goToLinePanelVisible = true
        Qt.callLater(function() {
            goToLineInput.forceActiveFocus()
            goToLineInput.selectAll()
        })
    }

    function closeGoToLinePanel() {
        root._goToLinePanelVisible = false
        root.forceActiveFocus()
    }

    function submitGoToLine() {
        var raw = String(root._goToLineValue || "").trim()
        if (!raw) {
            root.closeGoToLinePanel()
            return
        }
        var parts = raw.split(":")
        var line = parseInt(parts[0], 10)
        var col = parts.length > 1 ? parseInt(parts[1], 10) - 1 : 0
        if (isNaN(line))
            line = root.cursorLine
        if (isNaN(col))
            col = 0
        line = Math.max(1, Math.min(line, root._lineItems.length || 1))
        col = Math.max(0, col)
        root.goToLocation(line, col)
        root.closeGoToLinePanel()
    }

    function selectCurrentLine() {
        if (root._lineItems.length === 0)
            return
        doc.selectLineAt(root._cursorLine)
        root._ensureCursorVisible()
        root.forceActiveFocus()
    }

    function _bracketInfoAt(pos) {
        var text = doc.plainText()
        if (pos < 0 || pos >= text.length)
            return null
        var ch = text.charAt(pos)
        var open = "([{"
        var close = ")]}"
        var openIndex = open.indexOf(ch)
        if (openIndex >= 0)
            return { "pos": pos, "char": ch, "pair": close.charAt(openIndex), "direction": 1 }
        var closeIndex = close.indexOf(ch)
        if (closeIndex >= 0)
            return { "pos": pos, "char": ch, "pair": open.charAt(closeIndex), "direction": -1 }
        return null
    }

    function _findBracketPair(info) {
        var text = doc.plainText()
        var depth = 0
        var index = info.pos
        while (true) {
            index += info.direction
            if (index < 0 || index >= text.length)
                return -1
            var ch = text.charAt(index)
            if (ch === info.char)
                depth += 1
            else if (ch === info.pair) {
                if (depth === 0)
                    return index
                depth -= 1
            }
        }
    }

    function _updateBracketHighlights() {
        var cursor = doc.cursorPosition
        var info = root._bracketInfoAt(cursor)
        if (!info)
            info = root._bracketInfoAt(cursor - 1)
        if (!info) {
            root._bracketHighlights = []
            return
        }
        var own = root._lineColFromPos(info.pos)
        var pairPos = root._findBracketPair(info)
        if (pairPos < 0) {
            root._bracketHighlights = [{ "line": own.line, "col": own.col, "matched": false }]
            return
        }
        var pair = root._lineColFromPos(pairPos)
        root._bracketHighlights = [
            { "line": own.line, "col": own.col, "matched": true },
            { "line": pair.line, "col": pair.col, "matched": true }
        ]
    }

    function _bracketHighlightsForLine(lineIndex) {
        var items = []
        for (var i = 0; i < root._bracketHighlights.length; i++) {
            var item = root._bracketHighlights[i]
            if (item.line === lineIndex)
                items.push(item)
        }
        return items
    }

    function _lineColFromPos(pos) {
        pos = Math.max(0, Math.min(pos, doc.plainText().length))
        var line = 0
        for (var i = 0; i < root._lineStarts.length; i++) {
            if (root._lineStarts[i] <= pos)
                line = i
            else
                break
        }
        var col = pos - (root._lineStarts[line] || 0)
        var text = root._lineItems[line] ? (root._lineItems[line].text || "") : ""
        return { "line": line, "col": Math.max(0, Math.min(col, text.length)) }
    }

    function openFindPanel(replaceMode) {
        root._replacePanelVisible = !!replaceMode
        root._findPanelVisible = true
        root._syncFindQueryFromSelection()
        root._rebuildFindMatches()
        Qt.callLater(function() {
            findInput.forceActiveFocus()
            findInput.selectAll()
        })
    }

    function _syncFindQueryFromSelection() {
        if (!doc.hasSelection())
            return false
        var selected = doc.selectedText().replace(/\n/g, "")
        if (selected.length <= 0)
            return false
        if (root._findQuery === selected)
            return false
        root._findQuery = selected
        return true
    }

    function closeFindPanel() {
        root._findPanelVisible = false
        root._replacePanelVisible = false
        root._findMatches = []
        root._findIndex = -1
        root._requestMinimapPaint()
        root.forceActiveFocus()
    }

    function _requestMinimapPaint() {
        Qt.callLater(function() {
            if (minimapCanvas)
                minimapCanvas.requestPaint()
        })
    }

    function _rebuildFindMatches() {
        var query = root._findQuery || ""
        if (!query) {
            root._findMatches = []
            root._findIndex = -1
            root._requestMinimapPaint()
            return
        }
        var text = doc.plainText()
        var haystack = root._findCaseSensitive ? text : text.toLowerCase()
        var needle = root._findCaseSensitive ? query : query.toLowerCase()
        var results = []
        var index = 0
        while (needle.length > 0) {
            index = haystack.indexOf(needle, index)
            if (index < 0)
                break
            var start = root._lineColFromPos(index)
            var end = root._lineColFromPos(index + query.length)
            if (start.line === end.line) {
                results.push({
                    "start": index,
                    "end": index + query.length,
                    "line": start.line,
                    "startCol": start.col,
                    "endCol": end.col
                })
            }
            index += Math.max(1, query.length)
        }
        root._findMatches = results
        if (results.length === 0) {
            root._findIndex = -1
            root._requestMinimapPaint()
            return
        }
        var cursor = doc.cursorPosition
        var selected = 0
        for (var i = 0; i < results.length; i++) {
            if (results[i].start >= cursor) {
                selected = i
                break
            }
        }
        root._findIndex = Math.max(0, Math.min(selected, results.length - 1))
        root._requestMinimapPaint()
    }

    function _selectFindMatch(index) {
        if (root._findMatches.length === 0)
            return
        root._findIndex = (index + root._findMatches.length) % root._findMatches.length
        var item = root._findMatches[root._findIndex]
        doc.moveCursor(item.start)
        doc.moveCursorSelect(item.end)
        root._ensureCursorVisible()
        root._requestMinimapPaint()
        root.forceActiveFocus()
    }

    function findNext() {
        if (!root._findPanelVisible)
            root.openFindPanel(false)
        root._rebuildFindMatches()
        if (root._findMatches.length > 0)
            root._selectFindMatch(root._findIndex + 1)
    }

    function findPrevious() {
        root._rebuildFindMatches()
        if (root._findMatches.length > 0)
            root._selectFindMatch(root._findIndex - 1)
    }

    function replaceCurrentFindMatch() {
        if (root._findMatches.length === 0 || root._findIndex < 0)
            return
        var item = root._findMatches[root._findIndex]
        doc.replaceRange(item.start, item.end, root._replaceQuery)
        root._rebuildFindMatches()
        if (root._findMatches.length > 0)
            root._selectFindMatch(Math.min(root._findIndex, root._findMatches.length - 1))
    }

    function replaceAllFindMatches() {
        var count = doc.replaceAllLiteral(root._findQuery, root._replaceQuery, root._findCaseSensitive)
        root._rebuildFindMatches()
        if (typeof NotificationVM !== "undefined" && NotificationVM)
            NotificationVM.success("Replace complete", count + " occurrence" + (count === 1 ? "" : "s") + " replaced.", 2400)
    }

    function _findHighlightsForLine(lineIndex) {
        var items = []
        for (var i = 0; i < root._findMatches.length; i++) {
            var item = root._findMatches[i]
            if (item.line === lineIndex) {
                items.push({
                    "startCol": root._visualColFromLogical(lineIndex, item.startCol),
                    "endCol": root._visualColFromLogical(lineIndex, item.endCol),
                    "current": i === root._findIndex
                })
            }
        }
        return items
    }

    function requestQuickFixAt(line, col) {
        goToLocation(line, col)
        root._autoPreviewNextCodeAction = false
        Qt.callLater(function() { root._requestCursorCodeActions() })
    }

    function requestQuickFixPreviewAt(line, col) {
        goToLocation(line, col)
        root._autoPreviewNextCodeAction = true
        Qt.callLater(function() { root._requestCursorCodeActions() })
    }

    function _lineStart(line) {
        return _lineStarts[line] || 0
    }

    function _lineIndent(line) {
        if (line < 0 || line >= _lineItems.length) return 0
        var text = _lineItems[line].text || ""
        var visual = 0
        for (var i = 0; i < text.length; i++) {
            var ch = text.charAt(i)
            if (ch === " ") visual += 1
            else if (ch === "\t") visual += root.tabSize - (visual % root.tabSize)
            else break
        }
        return visual
    }

    function _activeIndentLevel() {
        return Math.max(0, Math.floor(root._lineIndent(root._cursorLine) / Math.max(1, root.tabSize)) - 1)
    }

    function _indentGuidesForLine(lineIndex) {
        var indent = root._lineIndent(lineIndex)
        if (indent <= 0)
            return []
        var activeLevel = root._activeIndentLevel()
        var items = []
        for (var col = 0; col < indent; col += root.tabSize) {
            var level = Math.floor(col / Math.max(1, root.tabSize))
            items.push({ "col": col, "active": level === activeLevel && activeLevel >= 0 })
        }
        return items
    }

    function _isLineFolded(lineIndex) {
        for (var key in root._foldedRanges) {
            var range = root._foldedRanges[key]
            if (range && lineIndex > range.start && lineIndex <= range.end)
                return true
        }
        return false
    }

    function _foldRangeForLine(lineIndex) {
        if (lineIndex < 0 || lineIndex >= _lineItems.length - 1) return null
        var text = _lineItems[lineIndex].text || ""
        if (text.trim().length === 0) return null
        var indent = root._lineIndent(lineIndex)
        var nextLine = lineIndex + 1
        while (nextLine < _lineItems.length && ((_lineItems[nextLine].text || "").trim().length === 0))
            nextLine++
        if (nextLine >= _lineItems.length || root._lineIndent(nextLine) <= indent)
            return null
        var end = nextLine
        for (var i = nextLine + 1; i < _lineItems.length; i++) {
            var lineText = _lineItems[i].text || ""
            if (lineText.trim().length > 0 && root._lineIndent(i) <= indent)
                break
            end = i
        }
        return end > lineIndex ? {"start": lineIndex, "end": end} : null
    }

    function _toggleFold(lineNumber) {
        var lineIndex = Math.max(0, lineNumber - 1)
        var next = {}
        for (var key in root._foldedRanges)
            next[key] = root._foldedRanges[key]
        if (next[lineIndex]) delete next[lineIndex]
        else {
            var range = root._foldRangeForLine(lineIndex)
            if (range) next[lineIndex] = range
        }
        root._foldedRanges = next
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

    function _codeHitFromPoint(x, y) {
        if (root._lineItems.length === 0)
            return { "valid": false, "line": 0, "col": 0, "pos": -1 }

        var hit = root._lineColFromPoint(x, y)
        var text = root._lineItems[hit.line] ? (root._lineItems[hit.line].text || "") : ""
        var contentX = x + lineView.contentX - root.gutterWidth - root.contentPadding
        var lineWidth = root._visualColFromLogical(hit.line, text.length) * root.charWidth
        if (contentX < 0 || contentX >= lineWidth || text.length === 0)
            return { "valid": false, "line": hit.line, "col": hit.col, "pos": -1 }
        var character = hit.col < text.length ? text.charAt(hit.col) : ""
        if (!character || character.trim().length === 0)
            return { "valid": false, "line": hit.line, "col": hit.col, "pos": -1 }
        return { "valid": true, "line": hit.line, "col": hit.col, "pos": hit.pos }
    }

    function _hasModifier(modifiers, modifier) {
        return (modifiers & modifier) !== 0
    }

    function _hasPrimaryModifier(modifiers) {
        return root._hasModifier(modifiers, Qt.ControlModifier) || root._hasModifier(modifiers, Qt.MetaModifier)
    }

    function _hasShiftModifier(modifiers) {
        var appModifiers = (typeof UiVM !== "undefined" && UiVM && UiVM.keyboardModifiers) ? UiVM.keyboardModifiers() : 0
        var uiShiftDown = (typeof UiVM !== "undefined" && UiVM && UiVM.shiftKeyDown) ? UiVM.shiftKeyDown() : false
        return root._hasModifier(modifiers, Qt.ShiftModifier)
            || root._hasModifier(appModifiers, Qt.ShiftModifier)
            || uiShiftDown
            || root._shiftKeyDown
    }

    function _foldLineAtPoint(x, y) {
        if (root._lineItems.length === 0)
            return -1
        var line = Math.floor((y + lineView.contentY) / root.lineHeight)
        line = Math.max(0, Math.min(line, root._lineItems.length - 1))
        return root._foldRangeForLine(line) === null ? -1 : line
    }

    function _isFoldMarkerPoint(x, y) {
        return x >= 0 && x <= Math.min(26, root.gutterWidth) && root._foldLineAtPoint(x, y) >= 0
    }

    function _tryToggleFoldAtPoint(x, y) {
        if (!root._isFoldMarkerPoint(x, y))
            return false
        var line = root._foldLineAtPoint(x, y)
        root._toggleFold(line + 1)
        return true
    }

    function _isFoldGutterPoint(x, y) {
        return root._isFoldMarkerPoint(x, y)
    }

    function _cursorShapeForPoint(x, y, modifiers) {
        if (root._isFoldGutterPoint(x, y))
            return Qt.PointingHandCursor
        if (x <= root.gutterWidth)
            return Qt.ArrowCursor
        if (root._hasPrimaryModifier(modifiers))
            return root._codeHitFromPoint(x, y).valid ? Qt.PointingHandCursor : Qt.IBeamCursor
        return Qt.IBeamCursor
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
        root._hoverBody = root._formatHoverBody(root._tokenDescription(hit.kind, hit.tokenText))
        root._hoverBodyRich = true
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
        var maxX = Math.max(0, lineView.contentWidth - root._editorViewportWidth())
        var maxY = Math.max(0, lineView.contentHeight - root._editorViewportHeight())
        lineView.contentX = Math.max(0, Math.min(x, maxX))
        lineView.contentY = Math.max(0, Math.min(y, maxY))
    }

    function _editorViewportWidth() {
        return Math.max(1, scrollView.width - (vScroll.visible ? vScroll.width : 0))
    }

    function _editorViewportHeight() {
        return Math.max(1, scrollView.height - (hScroll.visible ? hScroll.height : 0))
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

    function _previewCodeAction(action) {
        if (!action || !EditorVM) return
        root._pendingCodeAction = action
        EditorVM.previewCodeAction(action, doc.plainText())
    }

    function _showCodeActionPicker(actions) {
        var items = actions || []
        if (items.length === 0) {
            if (typeof NotificationVM !== "undefined" && NotificationVM)
                NotificationVM.info("No quick fix", "No code action is available for this diagnostic.", 2600)
            return
        }
        if (items.length === 1) {
            root._previewCodeAction(items[0])
            return
        }
        root._codeActionPickerActions = items
        root._codeActionPickerTitle = items.length + " quick fixes available"
        root._codeActionPickerSubtitle = "Choose an action to preview before applying it."
        codeActionPickerPopup.open()
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

    function _selectionWrapPair(text) {
        if (text === "(") return [ "(", ")" ]
        if (text === "[") return [ "[", "]" ]
        if (text === "{") return [ "{", "}" ]
        if (text === "\"") return [ "\"", "\"" ]
        if (text === "'") return [ "'", "'" ]
        if (text === "`") return [ "`", "`" ]
        return null
    }

    function _isClosingPairText(text) {
        return text === ")" || text === "]" || text === "}" || text === "\"" || text === "'" || text === "`"
    }

    function _requestDefinition() {
        if (!EditorVM || root._loadingFile || !root.visible) return
        EditorVM.requestDefinition(doc.plainText(), doc.cursorPosition)
    }

    function _requestReferences() {
        if (!EditorVM || root._loadingFile || !root.visible) return
        EditorVM.requestReferences(doc.plainText(), doc.cursorPosition)
    }

    function _showLocationResults(title, items) {
        root._locationPopupTitle = title
        root._locationResults = items || []
        if (root._locationResults.length > 0)
            locationPopup.open()
    }

    function _activateLocation(item) {
        if (!item) return
        var targetPath = item.path || ""
        if (EditorVM && root.filePath)
            EditorVM.pushNavigationLocation(root.filePath, root.cursorLine, Math.max(0, root.cursorCol - 1))
        if (targetPath.length > 0 && targetPath !== root.filePath) {
            root.loadFile(targetPath)
            Qt.callLater(function() { root.goToLocation(item.line || 1, item.col || 0) })
        } else {
            root.goToLocation(item.line || 1, item.col || 0)
        }
        locationPopup.close()
    }

    Rectangle {
        id: findPanel
        visible: root._findPanelVisible
        z: 80
        width: Math.min(root.width - 28, 520)
        height: root._replacePanelVisible ? 104 : 58
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: minimap.visible ? minimap.width + 12 : 12
        radius: 12
        color: root.theme.panel || "#252526"
        border.color: root.theme.border || "#3A3D46"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    id: findInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    text: root._findQuery
                    placeholderText: "Find in file"
                    selectByMouse: true
                    color: root.theme.textStrong || "#F3F4F6"
                    placeholderTextColor: root.theme.textDim || "#9CA3AF"
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 10
                    background: Rectangle {
                        radius: 8
                        color: root.theme.inputBg || Qt.rgba(255, 255, 255, 0.045)
                        border.color: findInput.activeFocus ? (root.theme.accent || "#60A5FA") : (root.theme.border || "#3A3D46")
                    }
                    onTextChanged: {
                        root._findQuery = text
                        root._rebuildFindMatches()
                    }
                    onAccepted: root.findNext()
                }

                Text {
                    Layout.preferredWidth: 56
                    text: root._findMatches.length === 0
                          ? "0 / 0"
                          : ((root._findIndex + 1) + " / " + root._findMatches.length)
                    color: root.theme.textDim || "#9CA3AF"
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 9
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                ToolButton {
                    text: "Aa"
                    checkable: true
                    checked: root._findCaseSensitive
                    ToolTip.visible: hovered
                    ToolTip.text: "Match case"
                    onClicked: {
                        root._findCaseSensitive = checked
                        root._rebuildFindMatches()
                    }
                }

                ToolButton { text: "↑"; onClicked: root.findPrevious(); ToolTip.visible: hovered; ToolTip.text: "Previous" }
                ToolButton { text: "↓"; onClicked: root.findNext(); ToolTip.visible: hovered; ToolTip.text: "Next" }
                ToolButton { text: root._replacePanelVisible ? "−" : "+"; onClicked: root._replacePanelVisible = !root._replacePanelVisible; ToolTip.visible: hovered; ToolTip.text: "Toggle replace" }
                ToolButton { text: "×"; onClicked: root.closeFindPanel(); ToolTip.visible: hovered; ToolTip.text: "Close" }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root._replacePanelVisible
                spacing: 8

                TextField {
                    id: replaceInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    text: root._replaceQuery
                    placeholderText: "Replace"
                    selectByMouse: true
                    color: root.theme.textStrong || "#F3F4F6"
                    placeholderTextColor: root.theme.textDim || "#9CA3AF"
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 10
                    background: Rectangle {
                        radius: 8
                        color: root.theme.inputBg || Qt.rgba(255, 255, 255, 0.045)
                        border.color: replaceInput.activeFocus ? (root.theme.accent || "#60A5FA") : (root.theme.border || "#3A3D46")
                    }
                    onTextChanged: root._replaceQuery = text
                    onAccepted: root.replaceCurrentFindMatch()
                }

                Button {
                    text: "Replace"
                    enabled: root._findMatches.length > 0
                    onClicked: root.replaceCurrentFindMatch()
                }

                Button {
                    text: "All"
                    enabled: root._findMatches.length > 0
                    onClicked: root.replaceAllFindMatches()
                }
            }
        }
    }

    Rectangle {
        id: goToLinePanel
        visible: root._goToLinePanelVisible
        z: 82
        width: Math.min(root.width - 28, 320)
        height: 58
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: minimap.visible ? minimap.width + 12 : 12
        radius: 12
        color: root.theme.panel || "#252526"
        border.color: root.theme.border || "#3A3D46"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Text {
                text: "Line"
                color: root.theme.textDim || "#9CA3AF"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 9
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: goToLineInput
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                text: root._goToLineValue
                placeholderText: "line[:column]"
                selectByMouse: true
                inputMethodHints: Qt.ImhPreferNumbers
                color: root.theme.textStrong || "#F3F4F6"
                placeholderTextColor: root.theme.textDim || "#9CA3AF"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 10
                background: Rectangle {
                    radius: 8
                    color: root.theme.inputBg || Qt.rgba(255, 255, 255, 0.045)
                    border.color: goToLineInput.activeFocus ? (root.theme.accent || "#60A5FA") : (root.theme.border || "#3A3D46")
                }
                onTextChanged: root._goToLineValue = text
                onAccepted: root.submitGoToLine()
            }

            ToolButton {
                text: "Go"
                onClicked: root.submitGoToLine()
            }

            ToolButton {
                text: "×"
                onClicked: root.closeGoToLinePanel()
            }
        }
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
            footer: Item { width: 1; height: Math.max(root.lineHeight, hScroll.visible ? hScroll.height + 6 : 6) }

            delegate: TokenLine {
                width: lineView.contentWidth
                lineText: modelData.text || ""
                lineSpans: modelData.spans || []
                lineNumber: modelData.lineNumber || index + 1
                editorFont: root.editorFont
                fontWidth: root.charWidth
                gutterWidth: root.gutterWidth
                contentPadding: root.contentPadding
                horizontalOffset: lineView.contentX
                theme: root.theme
                tokenColors: root.tokenColors
                inlineDiagnostic: root._inlineDiagnosticForLine(index)
                findHighlights: root._findHighlightsForLine(index)
                bracketHighlights: root._bracketHighlightsForLine(index)
                indentGuides: root._indentGuidesForLine(index)
                selectionStartCol: root._selectionStartCol(index)
                selectionEndCol: root._selectionEndCol(index)
                isActiveLine: index === root._cursorLine
                foldable: root._foldRangeForLine(index) !== null
                folded: !!root._foldedRanges[index]
                visible: !root._isLineFolded(index)
                height: visible ? root.lineHeight : 0
                hoverEnabled: true

                onTokenHovered: function(kind, text, start, end, mx, my) {
                    // Centralized in editorHitArea to keep hover anchored to token coordinates.
                }
                onFoldClicked: function(line) { root._toggleFold(line) }
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
                if (root._tryToggleFoldAtPoint(mouse.x, mouse.y)) {
                    mouse.accepted = true
                    selecting = false
                    return
                }
                if (root._hasPrimaryModifier(mouse.modifiers)) {
                    var codeHit = root._codeHitFromPoint(mouse.x, mouse.y)
                    if (codeHit.valid) {
                        doc.moveCursor(codeHit.pos)
                        root._requestDefinition()
                        mouse.accepted = true
                        selecting = false
                        return
                    }
                }
                var hit = root._lineColFromPoint(mouse.x, mouse.y)
                doc.moveCursor(hit.pos)
                selecting = true
            }

            onDoubleClicked: function(mouse) {
                root.forceActiveFocus()
                if (root._lineItems.length === 0) return
                var hit = root._lineColFromPoint(mouse.x, mouse.y)
                doc.selectWordAt(hit.pos)
                mouse.accepted = true
                selecting = false
            }

            onPositionChanged: function(mouse) {
                root._editorHovered = true
                if (root._lineItems.length === 0) return
                editorHitArea.cursorShape = root._cursorShapeForPoint(mouse.x, mouse.y, mouse.modifiers)
                if (root._tokenInfoHovered) {
                    hoverTimer.stop()
                    root._pendingHoverHit = null
                    root._hoverTokenHovered = false
                    diagnosticsOverlay.hoveredDiagnostic = null
                    diagnosticsOverlay.requestPaint()
                    return
                }
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
                    root._hoverTokenHovered = true
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
                    root._hoverTokenHovered = false
                    root._hoverCloseRequested = true
                    hoverHideTimer.restart()
                    return
                }
                hoverHideTimer.stop()
                root._hoverTokenHovered = true
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
                root._hoverTokenHovered = false
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

        MouseArea {
            id: gutterHitArea
            x: 0
            y: 0
            width: root.gutterWidth
            height: parent.height
            z: 30
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: root._isFoldGutterPoint(mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor
            property bool selectingLines: false
            property int selectionStartLine: -1

            function lineFromMouse(y) {
                if (root._lineItems.length === 0)
                    return 0
                var line = Math.floor((y + lineView.contentY) / root.lineHeight)
                return Math.max(0, Math.min(line, root._lineItems.length - 1))
            }

            onPressed: function(mouse) {
                root.forceActiveFocus()
                if (root._tryToggleFoldAtPoint(mouse.x, mouse.y)) {
                    selectingLines = false
                    mouse.accepted = true
                    return
                }
                selectionStartLine = lineFromMouse(mouse.y)
                selectingLines = true
                doc.selectLineAt(selectionStartLine)
                mouse.accepted = true
            }

            onPositionChanged: function(mouse) {
                if (!selectingLines)
                    return
                doc.selectLineRange(selectionStartLine, lineFromMouse(mouse.y))
            }

            onReleased: function(mouse) {
                selectingLines = false
            }

            onWheel: function(wheel) {
                root._scrollTo(lineView.contentX, lineView.contentY - wheel.angleDelta.y / 120 * root.lineHeight * 3)
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
            size: lineView.contentHeight > 0 ? Math.min(1, root._editorViewportHeight() / lineView.contentHeight) : 1
            position: lineView.contentHeight > root._editorViewportHeight() ? lineView.contentY / Math.max(1, lineView.contentHeight - root._editorViewportHeight()) * (1 - size) : 0
            onPositionChanged: {
                if (pressed)
                    root._scrollTo(lineView.contentX, position / Math.max(0.0001, 1 - size) * Math.max(0, lineView.contentHeight - root._editorViewportHeight()))
            }
        }

        ScrollBar {
            id: hScroll
            anchors.left: parent.left
            anchors.right: vScroll.left
            anchors.bottom: parent.bottom
            orientation: Qt.Horizontal
            policy: !root.wordWrapEnabled && lineView.contentWidth > lineView.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            size: lineView.contentWidth > 0 ? Math.min(1, root._editorViewportWidth() / lineView.contentWidth) : 1
            position: lineView.contentWidth > root._editorViewportWidth() ? lineView.contentX / Math.max(1, lineView.contentWidth - root._editorViewportWidth()) * (1 - size) : 0
            onPositionChanged: {
                if (pressed)
                    root._scrollTo(position / Math.max(0.0001, 1 - size) * Math.max(0, lineView.contentWidth - root._editorViewportWidth()), lineView.contentY)
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
                if (root._findMatches && root._findMatches.length > 0) {
                    ctx.fillStyle = root.theme.minimapFindMatch || root.theme.findCurrent || "#F2C94C"
                    ctx.globalAlpha = 0.92
                    for (var m = 0; m < root._findMatches.length; m++) {
                        var match = root._findMatches[m]
                        var matchLine = Math.max(0, Number(match.line || 0))
                        var matchY = Math.max(0, Math.min(height - 2, matchLine / Math.max(1, root._lineItems.length) * height))
                        var isCurrent = m === root._findIndex
                        ctx.fillRect(width - (isCurrent ? 17 : 15), matchY, isCurrent ? 9 : 6, isCurrent ? 3 : 2)
                    }
                    ctx.globalAlpha = 1
                }
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
            height: Math.max(24, parent.height * Math.min(1, root._editorViewportHeight() / Math.max(1, lineView.contentHeight)))
            y: parent.height * (lineView.contentHeight > root._editorViewportHeight()
                                ? lineView.contentY / Math.max(1, lineView.contentHeight - root._editorViewportHeight()) * (1 - height / parent.height)
                                : 0)
            radius: 3
            color: Qt.rgba(0.0, 0.47, 0.83, 0.20)
            border.color: Qt.rgba(0.3, 0.7, 1.0, 0.32)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) {
                if (lineView.contentHeight <= root._editorViewportHeight()) return
                root._scrollTo(
                    lineView.contentX,
                    Math.max(0, Math.min(lineView.contentHeight - root._editorViewportHeight(), mouse.y / height * lineView.contentHeight))
                )
            }
        }
    }

    // ── Cursor ─────────────────────────────────────────

    Rectangle {
        id: cursorBlink
        readonly property real cursorX: root.gutterWidth + root.contentPadding + root._visualColFromLogical(root._cursorLine, root._cursorCol) * root.charWidth - lineView.contentX
        readonly property real cursorY: root._cursorLine * root.lineHeight - lineView.contentY
        readonly property bool inViewport: cursorX >= root.gutterWidth
                                           && cursorX <= scrollView.width
                                           && cursorY + root.lineHeight > 0
                                           && cursorY < scrollView.height
        width: 2; height: root.lineHeight
        color: root.theme.editorCursor || "#FFFFFF"
        visible: root.activeFocus && _lineItems.length > 0 && inViewport
        z: 10

        x: cursorX
        y: cursorY

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
        readonly property real minBodyHeight: 24
        readonly property real maxBodyHeight: 260
        readonly property real quickFixMaxHeight: 132
        readonly property real contentWidth: Math.max(0, width - 18)
        readonly property real chromeHeight: hoverHeader.implicitHeight
                                             + headerDivider.height
                                             + (quickFixSection.visible ? Math.min(quickFixMaxHeight, quickFixSection.implicitHeight) : 0)
                                             + hoverActions.implicitHeight
                                             + hoverColumn.spacing * 3
                                             + 18
        readonly property real availableBodyHeight: Math.max(minBodyHeight, maxPopupHeight - chromeHeight)
        readonly property real bodyHeight: Math.min(maxBodyHeight, availableBodyHeight, Math.max(minBodyHeight, hoverBodyText.contentHeight + 8))
        height: Math.max(92, Math.min(maxPopupHeight, chromeHeight + bodyHeight))
        z: 100

        MouseArea {
            id: tokenInfoHoverArea
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            z: 1000
            onContainsMouseChanged: {
                root._tokenInfoHovered = containsMouse
                if (containsMouse) {
                    hoverTimer.stop()
                    hoverHideTimer.stop()
                    root._hoverTokenHovered = false
                    root._pendingHoverHit = null
                    root._hoverCloseRequested = false
                } else if (!root._hoverTokenHovered) {
                    root._hoverCloseRequested = true
                    hoverHideTimer.restart()
                }
            }
        }

        Column {
            id: hoverColumn
            z: 2
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

            Rectangle {
                id: headerDivider
                width: parent.width
                height: 1
                color: root.theme.border || "#333842"
            }

            ScrollView {
                id: hoverBodyScroll
                width: parent.width
                height: tokenInfo.bodyHeight
                implicitHeight: height
                clip: true
                ScrollBar.vertical.policy: hoverBodyText.contentHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                TextArea {
                    id: hoverBodyText
                    height: Math.max(tokenInfo.minBodyHeight, contentHeight + 8)
                    text: root._hoverBody
                    color: root.theme.text || "#D4D4D4"
                    font.family: root.editorFont.family
                    font.pointSize: Math.max(9, root.editorFont.pointSize - 1)
                    textFormat: root._hoverBodyRich ? TextEdit.RichText : TextEdit.PlainText
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
                height: Math.min(tokenInfo.quickFixMaxHeight, implicitHeight)
                clip: true
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
                        model: root._codeActions && root._codeActions.length > 0 ? root._codeActions.slice(0, 3) : []

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
                                onClicked: if (!parent.disabled) root._previewCodeAction(modelData)
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.theme.border || "#333842" }
            }

            Row {
                id: hoverActions
                width: parent.width
                height: 24
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

    Popup {
        id: locationPopup
        width: 380
        height: Math.min(320, Math.max(92, locationList.contentHeight + 52))
        x: Math.min(root.width - width - 10, Math.max(10, root.gutterWidth + root.contentPadding + root._visualColFromLogical(root._cursorLine, root._cursorCol) * root.charWidth - lineView.contentX))
        y: Math.min(root.height - height - 10, Math.max(10, (root._cursorLine + 1) * root.lineHeight - lineView.contentY + 8))
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: root.theme.panel || "#252526"
            border.color: root.theme.border || "#3A3D46"
            border.width: 1
            radius: 10
        }

        contentItem: Column {
            spacing: 0

            Text {
                width: locationPopup.width
                height: 36
                leftPadding: 12
                rightPadding: 12
                text: root._locationPopupTitle + " · " + root._locationResults.length
                color: root.theme.textStrong || "#F3F4F6"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 10
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Rectangle { width: locationPopup.width; height: 1; color: root.theme.border || "#333842" }

            ListView {
                id: locationList
                width: locationPopup.width
                height: locationPopup.height - 37
                clip: true
                model: root._locationResults
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    width: locationList.width
                    height: 42
                    radius: 0
                    color: locMouse.containsMouse ? (root.theme.hover || "#2D3440") : "transparent"

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 5
                        spacing: 2

                        Text {
                            width: parent.width
                            text: modelData.name || modelData.kind || modelData.path || "location"
                            color: root.theme.textStrong || "#F3F4F6"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 9
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: (modelData.path || root.filePath || "") + ":" + (modelData.line || 1) + ":" + ((modelData.col || 0) + 1)
                            color: root.theme.textDim || "#9CA3AF"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 8
                            elide: Text.ElideLeft
                        }
                    }

                    MouseArea {
                        id: locMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._activateLocation(modelData)
                    }
                }
            }
        }
    }

    Popup {
        id: codeActionPreviewPopup
        width: Math.min(720, root.width - 32)
        height: Math.min(520, root.height - 32)
        x: Math.max(16, (root.width - width) / 2)
        y: Math.max(16, (root.height - height) / 2)
        modal: true
        padding: 0
        closePolicy: Popup.CloseOnEscape

        background: Rectangle {
            color: root.theme.panel || "#252526"
            border.color: root.theme.border || "#3A3D46"
            border.width: 1
            radius: 12
        }

        contentItem: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                Layout.leftMargin: 14
                Layout.rightMargin: 10
                spacing: 10

                Icon {
                    icon: "bolt"
                    size: 17
                    color: root.theme.accent || "#61AFEF"
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: root._codeActionPreviewTitle || "Quick Fix Preview"
                        color: root.theme.textStrong || "#F3F4F6"
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root._codeActionPreviewMessage || ""
                        color: root.theme.textDim || "#9CA3AF"
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 8
                        elide: Text.ElideRight
                    }
                }
                HoverActionButton {
                    label: "Close"
                    onClicked: codeActionPreviewPopup.close()
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.border || "#333842" }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                TextArea {
                    text: root._codeActionPreviewText || "No preview available."
                    readOnly: true
                    selectByMouse: true
                    wrapMode: Text.NoWrap
                    textFormat: TextEdit.PlainText
                    color: root.theme.text || "#D4D4D4"
                    selectedTextColor: "#FFFFFF"
                    selectionColor: root.theme.selection || "#264F78"
                    font.family: root.fontFamily((typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.fontFamily : "Menlo")
                    font.pointSize: Math.max(9, ((typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.fontSize : 12) - 1)
                    background: Rectangle { color: root.theme.bg || "#1E1E1E" }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                spacing: 8
                Item { Layout.fillWidth: true }
                HoverActionButton {
                    label: "Cancel"
                    onClicked: codeActionPreviewPopup.close()
                }
                HoverActionButton {
                    label: "Apply"
                    onClicked: {
                        root._applyCodeAction(root._pendingCodeAction)
                        codeActionPreviewPopup.close()
                    }
                }
            }
        }
    }

    Popup {
        id: codeActionPickerPopup
        width: Math.min(520, root.width - 32)
        height: Math.min(420, Math.max(190, pickerList.contentHeight + 104))
        x: Math.max(16, (root.width - width) / 2)
        y: Math.max(16, (root.height - height) / 2)
        modal: true
        padding: 0
        closePolicy: Popup.CloseOnEscape

        background: Rectangle {
            color: root.theme.panel || "#252526"
            border.color: root.theme.border || "#3A3D46"
            border.width: 1
            radius: 12
        }

        contentItem: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                Layout.leftMargin: 14
                Layout.rightMargin: 10
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 10
                    color: Qt.rgba(0.23, 0.51, 0.96, 0.18)
                    border.color: Qt.rgba(0.38, 0.64, 1.0, 0.38)
                    Icon {
                        anchors.centerIn: parent
                        icon: "bolt"
                        size: 16
                        color: root.theme.info || "#93C5FD"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: root._codeActionPickerTitle
                        color: root.theme.textStrong || "#F3F4F6"
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root._codeActionPickerSubtitle
                        color: root.theme.textDim || "#9CA3AF"
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 8
                        elide: Text.ElideRight
                    }
                }

                HoverActionButton {
                    label: "Close"
                    onClicked: codeActionPickerPopup.close()
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.border || "#333842" }

            ListView {
                id: pickerList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                topMargin: 10
                bottomMargin: 10
                leftMargin: 10
                rightMargin: 10
                boundsBehavior: Flickable.StopAtBounds
                model: root._codeActionPickerActions || []
                ScrollBar.vertical: ScrollBar { policy: pickerList.contentHeight > pickerList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool disabled: modelData.disabled && Object.keys(modelData.disabled).length > 0
                    width: pickerList.width - 20
                    height: disabled ? 58 : 50
                    radius: 9
                    opacity: disabled ? 0.58 : 1
                    color: pickerMouse.containsMouse && !disabled ? Qt.rgba(0.23, 0.51, 0.96, 0.18) : Qt.rgba(255, 255, 255, 0.035)
                    border.width: 1
                    border.color: pickerMouse.containsMouse && !disabled ? Qt.rgba(0.38, 0.64, 1.0, 0.42) : Qt.rgba(255, 255, 255, 0.06)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 8
                            color: modelData.isPreferred ? Qt.rgba(0.2, 0.78, 0.48, 0.18) : Qt.rgba(0.23, 0.51, 0.96, 0.14)
                            border.color: modelData.isPreferred ? Qt.rgba(0.4, 0.95, 0.65, 0.36) : Qt.rgba(0.38, 0.64, 1.0, 0.32)
                            Text {
                                anchors.centerIn: parent
                                text: modelData.isPreferred ? "P" : "FX"
                                color: modelData.isPreferred ? "#A7F3D0" : "#BFDBFE"
                                font.pixelSize: modelData.isPreferred ? 10 : 8
                                font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title || "Quick Fix"
                                color: root.theme.textStrong || "#F3F4F6"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pointSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: disabled ? (modelData.disabled.reason || "Unavailable")
                                               : ((modelData.kind || "quickfix") + (modelData.source ? " · " + modelData.source : ""))
                                color: disabled ? (root.theme.warning || "#D19A66") : (root.theme.textDim || "#9CA3AF")
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pointSize: 8
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: pickerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (parent.disabled)
                                return
                            codeActionPickerPopup.close()
                            root._previewCodeAction(modelData)
                        }
                    }
                }
            }
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
            root._hoverTokenHovered = false
            root._hoverCloseRequested = true
            hoverHideTimer.restart()
        }
    }

    // ── Key handling ──────────────────────────────────

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Shift) {
            root._shiftKeyDown = true
            return
        }

        if (event.matches(StandardKey.Find)) {
            event.accepted = true
            root.openFindPanel(false)
            return
        }
        if (event.key === Qt.Key_H && root._hasPrimaryModifier(event.modifiers)) {
            event.accepted = true
            root.openFindPanel(true)
            return
        }
        if (event.key === Qt.Key_F3) {
            event.accepted = true
            if (root._hasShiftModifier(event.modifiers)) root.findPrevious()
            else root.findNext()
            return
        }
        if (event.key === Qt.Key_Escape && root._findPanelVisible) {
            event.accepted = true
            root.closeFindPanel()
            return
        }
        if (event.key === Qt.Key_Escape && root._goToLinePanelVisible) {
            event.accepted = true
            root.closeGoToLinePanel()
            return
        }
        if (event.key === Qt.Key_G && root._hasPrimaryModifier(event.modifiers)) {
            event.accepted = true
            root.openGoToLinePanel()
            return
        }
        if (event.key === Qt.Key_D && root._hasPrimaryModifier(event.modifiers)) {
            event.accepted = true
            doc.selectNextOccurrence()
            root._ensureCursorVisible()
            return
        }
        if (event.key === Qt.Key_L && root._hasPrimaryModifier(event.modifiers)) {
            event.accepted = true
            root.selectCurrentLine()
            return
        }

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

        if (event.key === Qt.Key_F12 && !(event.modifiers & Qt.ShiftModifier)) {
            event.accepted = true
            root._requestDefinition()
            return
        }

        if (event.key === Qt.Key_F12 && (event.modifiers & Qt.ShiftModifier)) {
            event.accepted = true
            root._requestReferences()
            return
        }

        if (event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            event.accepted = true
            root._showLocationResults("Document symbols", root.documentSymbols)
            if (root.documentSymbols.length === 0)
                EditorVM.requestDocumentSymbols(doc.plainText())
            return
        }

        if (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier)) {
            event.accepted = true
            if (EditorVM) EditorVM.jumpBack()
            return
        }

        if (event.key === Qt.Key_Right && (event.modifiers & Qt.AltModifier)) {
            event.accepted = true
            if (EditorVM) EditorVM.jumpForward()
            return
        }

        if (event.key === Qt.Key_Slash && (event.modifiers & Qt.ControlModifier)) {
            event.accepted = true
            doc.toggleLineComment()
            root._triggerCompletions()
            return
        }

        if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            event.accepted = true
            doc.deleteLineOrSelection()
            root._triggerCompletions()
            return
        }

        if (event.key === Qt.Key_Down && (event.modifiers & Qt.AltModifier) && (event.modifiers & Qt.ShiftModifier)) {
            event.accepted = true
            doc.duplicateLineOrSelection()
            root._triggerCompletions()
            return
        }

        if (event.key === Qt.Key_Up && (event.modifiers & Qt.AltModifier)) {
            event.accepted = true
            doc.moveLineOrSelectionUp()
            root._triggerCompletions()
            return
        }

        if (event.key === Qt.Key_Down && (event.modifiers & Qt.AltModifier)) {
            event.accepted = true
            doc.moveLineOrSelectionDown()
            root._triggerCompletions()
            return
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

        if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
            event.accepted = true
            doc.outdentSelectionOrLine()
            root._triggerCompletions()
            return
        }

        if (event.key === Qt.Key_Tab) {
            event.accepted = true
            if (doc.aiSuggestion.length > 0) { doc.acceptSuggestion(); return }
            if (doc.hasSelection()) doc.indentSelectionOrLine()
            else doc.doTab()
            root._triggerCompletions()
            return
        }

        if (event.key === Qt.Key_Escape && doc.aiSuggestion.length > 0) {
            event.accepted = true; doc.rejectSuggestion(); return
        }

        // Navigation
        if (event.key === Qt.Key_Left) {
            event.accepted = true
            if (root._suppressWordNavigationEvent && root._hasPrimaryModifier(event.modifiers)) {
                root._suppressWordNavigationEvent = false
                return
            }
            if (root._hasPrimaryModifier(event.modifiers)) {
                doc.moveWordLeft(root._hasShiftModifier(event.modifiers))
                return
            }
            if (root._hasShiftModifier(event.modifiers)) doc.moveCursorSelect(doc.cursorPosition - 1)
            else doc.moveCursor(doc.cursorPosition - 1)
            return
        }
        if (event.key === Qt.Key_Right) {
            event.accepted = true
            if (root._suppressWordNavigationEvent && root._hasPrimaryModifier(event.modifiers)) {
                root._suppressWordNavigationEvent = false
                return
            }
            if (root._hasPrimaryModifier(event.modifiers)) {
                doc.moveWordRight(root._hasShiftModifier(event.modifiers))
                return
            }
            if (root._hasShiftModifier(event.modifiers)) doc.moveCursorSelect(doc.cursorPosition + 1)
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
            if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.MetaModifier) {
                event.accepted = true; doc.deleteWordLeft(); _triggerCompletions(); return
            }
            event.accepted = true; doc.doBackspace(); _triggerCompletions(); return
        }
        if (event.key === Qt.Key_Delete) {
            if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.MetaModifier) {
                event.accepted = true; doc.deleteWordRight(); _triggerCompletions(); return
            }
            event.accepted = true; doc.doDelete(); _triggerCompletions(); return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true; doc.doNewline(); _triggerCompletions(); return
        }

        // Text input (printable characters)
        var text = event.text
        var textModifiers = event.modifiers & ~(Qt.ShiftModifier | Qt.KeypadModifier)
        if (text.length > 0 && text.charCodeAt(0) >= 32 && text.charCodeAt(0) !== 127 && textModifiers === Qt.NoModifier) {
            var pair = root._selectionWrapPair(text)
            if (pair) {
                event.accepted = true
                if (doc.hasSelection()) doc.wrapSelection(pair[0], pair[1])
                else doc.insertPair(pair[0], pair[1])
                root._triggerCompletions()
                return
            }
            if (root._isClosingPairText(text) && doc.skipNextIf(text)) {
                event.accepted = true
                root._triggerCompletions()
                return
            }
            event.accepted = true; doc.typeText(text); _triggerCompletions(); return
        }
    }

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Shift)
            root._shiftKeyDown = false
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
            root._cursorLine = doc.cursorLine
            root._cursorCol = doc.cursorColumn
            root._selectionStart = doc.selectionStart
            root._selectionEnd = doc.selectionEnd
            root._lineItems = doc.lines
            root._lines = root._lineItems.map(function(item) { return item.text || "" })
            root._rebuildLineStarts()
            root._updateContentWidth()
            root._updateBracketHighlights()
            if (root._findPanelVisible)
                root._rebuildFindMatches()
            lineView.contentX = keepX
            lineView.contentY = keepY
            Qt.callLater(function() { root._ensureCursorVisible() })
            minimapCanvas.requestPaint()
            root._triggerLanguageFeatures()
        }
        function onCursorChanged(line, col) {
            root._cursorLine = line; root._cursorCol = col
            root._updateBracketHighlights()
            root.cursorPositionChanged()
            suggestionBox.close()
            Qt.callLater(function() { root._ensureCursorVisible() })
        }
        function onSelectionChanged() {
            root._selectionStart = doc.selectionStart
            root._selectionEnd = doc.selectionEnd
            if (root._findPanelVisible && root._syncFindQueryFromSelection())
                root._rebuildFindMatches()
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
        var vh = root._editorViewportHeight()
        var maxY = Math.max(0, lineView.contentHeight - vh)
        if (cy < lineView.contentY) root._scrollTo(lineView.contentX, cy)
        if (cy + root.lineHeight > lineView.contentY + vh)
            root._scrollTo(lineView.contentX, Math.min(maxY, cy + root.lineHeight - vh + 20))
        var cx = root.gutterWidth + root.contentPadding + root._visualColFromLogical(root._cursorLine, root._cursorCol) * root.charWidth
        var vw = root._editorViewportWidth()
        var maxX = Math.max(0, lineView.contentWidth - vw)
        if (cx < lineView.contentX + root.gutterWidth)
            root._scrollTo(Math.max(0, cx - root.gutterWidth - root.contentPadding), lineView.contentY)
        if (cx + root.charWidth > lineView.contentX + vw)
            root._scrollTo(Math.min(maxX, cx + root.charWidth - vw + 20), lineView.contentY)
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
        interval: 1400
        repeat: false
        onTriggered: {
            if (root._hoverCloseRequested && !root._tokenInfoHovered && !root._hoverTokenHovered) {
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
            if (root._autoPreviewNextCodeAction) {
                root._autoPreviewNextCodeAction = false
                root._showCodeActionPicker(root._codeActions)
                return
            }
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
        function onCodeActionPreviewReady(payload) {
            if (!root.visible) return
            payload = payload || ({})
            root._pendingCodeAction = payload.action || root._pendingCodeAction
            root._codeActionPreviewTitle = payload.title || "Quick Fix Preview"
            root._codeActionPreviewMessage = payload.message || ""
            root._codeActionPreviewText = payload.preview || payload.message || "No preview available."
            codeActionPreviewPopup.open()
        }
        function onDefinitionReady(locations) {
            if (!root.visible) return
            var items = locations || []
            if (items.length === 1) root._activateLocation(items[0])
            else root._showLocationResults("Definitions", items)
        }
        function onReferencesReady(locations) {
            if (!root.visible) return
            root._showLocationResults("References", locations || [])
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
                root._hoverBody = root._formatHoverBody(root._hoverBody)
                root._hoverBodyRich = true
            }
            tokenInfo.x = Math.min(root.width - tokenInfo.width - 8, Math.max(8, root._hoverAnchorX))
            tokenInfo.y = Math.min(root.height - tokenInfo.height - 8, Math.max(8, root._hoverAnchorY))
            tokenInfo.visible = true
        }
        function onSymbolsReady(symbols) {
            root.documentSymbols = symbols || []
            if (locationPopup.opened && root._locationPopupTitle === "Document symbols")
                root._locationResults = root.documentSymbols
        }
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
