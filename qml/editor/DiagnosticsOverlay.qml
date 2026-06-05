import QtQuick 2.15

/*
 * DiagnosticsOverlay — Squiggly underlines for errors and warnings.
 *
 * Rendered as a Canvas overlay on top of the TextEdit.
 * Each diagnostic is a wavy line at the appropriate position.
 *
 * Usage:
 *   DiagnosticsOverlay {
 *       editor: myTextEdit
 *       diagnostics: [{line: 5, col: 0, message: "...", severity: "error"}]
 *   }
 */

Canvas {
    id: root

    property var editor: null
    property var editorFlickable: null
    property int editorLineCount: editor ? editor.lineCount : 0
    property real editorLineHeight: editor && editor.cursorRectangle ? editor.cursorRectangle.height : 22
    property real visibleAreaY: 0
    property real contentX: 0
    property real charWidth: 7.2
    property int gutterWidth: 56
    property int contentPadding: 8
    property var diagnostics: []
    property color errorColor: "#E06C75"
    property color warningColor: "#D19A66"
    property color infoColor: "#61AFEF"
    property var hoveredDiagnostic: null

    signal diagnosticHovered(var diagnostic, real mouseX, real mouseY)
    signal diagnosticExited()

    anchors.fill: parent
    z: 5

    onDiagnosticsChanged: requestPaint()
    onEditorChanged: requestPaint()
    onEditorLineCountChanged: requestPaint()
    onEditorLineHeightChanged: requestPaint()
    onVisibleAreaYChanged: requestPaint()
    onContentXChanged: requestPaint()
    onCharWidthChanged: requestPaint()
    onGutterWidthChanged: requestPaint()
    onContentPaddingChanged: requestPaint()

    Connections {
        target: root.editorFlickable
        enabled: root.editorFlickable !== null
        function onContentItemChanged() {
            if (root.editorFlickable && root.editorFlickable.contentItem)
                root.editorFlickable.contentItem.contentYChanged.connect(requestPaint)
        }
    }

    onEditorFlickableChanged: requestPaint()

    Connections {
        target: root.editor
        enabled: root.editor !== null
        function onCursorRectangleChanged() { requestPaint() }
        function onLineCountChanged() { requestPaint() }
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        if (!root.diagnostics || root.diagnostics.length === 0) return

        var diags = JSON.parse(JSON.stringify(root.diagnostics))
        var lineHeight = root.editorLineHeight
        var scrollOffset = root.visibleAreaY

        for (var i = 0; i < diags.length; i++) {
            var d = diags[i]
            var line = (d.line || d.row || 1) - 1
            var y = (line * lineHeight) - scrollOffset + lineHeight - 3

            if (y < 0 || y > root.height) continue

            var color = d.severity === "error" ? root.errorColor :
                       (d.severity === "warning" ? root.warningColor : root.infoColor)

            ctx.strokeStyle = color
            ctx.lineWidth = 1.5
            ctx.beginPath()

            var amplitude = 1.25
            var frequency = 9
            var startCol = Math.max(0, Number(d.col || 0))
            var endCol = Math.max(startCol + 1, Number(d.endCol || startCol + 1))
            if ((d.endLine || d.line || 1) !== (d.line || 1))
                endCol = startCol + Math.max(1, Number(d.length || 24))
            var startX = root.gutterWidth + root.contentPadding + startCol * root.charWidth - root.contentX
            var endX = root.gutterWidth + root.contentPadding + endCol * root.charWidth - root.contentX
            startX = Math.max(root.gutterWidth + 2, Math.min(root.width - 4, startX))
            endX = Math.max(startX + root.charWidth, Math.min(root.width - 4, endX))

            for (var x = startX; x <= endX; x += 2) {
                var waveY = y + Math.sin(x * frequency * 0.05) * amplitude
                if (x === startX) ctx.moveTo(x, waveY)
                else ctx.lineTo(x, waveY)
            }
            ctx.stroke()

            if (root.hoveredDiagnostic && root.hoveredDiagnostic.message === d.message && root.hoveredDiagnostic.line === d.line && root.hoveredDiagnostic.col === d.col) {
                ctx.fillStyle = color
                ctx.globalAlpha = 0.12
                ctx.fillRect(startX, y - lineHeight + 6, endX - startX, lineHeight - 2)
                ctx.globalAlpha = 1
            }
        }
    }

    function diagnosticAt(mouseX, mouseY) {
        if (!root.diagnostics || root.diagnostics.length === 0) return null
        var lineHeight = root.editorLineHeight
        var scrollOffset = root.visibleAreaY
        for (var i = 0; i < root.diagnostics.length; i++) {
            var d = root.diagnostics[i]
            var line = (d.line || d.row || 1) - 1
            var yTop = line * lineHeight - scrollOffset
            var yBottom = yTop + lineHeight
            if (mouseY < yTop || mouseY > yBottom) continue
            var startCol = Math.max(0, Number(d.col || 0))
            var endCol = Math.max(startCol + 1, Number(d.endCol || startCol + 1))
            var startX = root.gutterWidth + root.contentPadding + startCol * root.charWidth - root.contentX
            var endX = root.gutterWidth + root.contentPadding + endCol * root.charWidth - root.contentX
            if (mouseX >= startX - 2 && mouseX <= endX + 2)
                return d
        }
        return null
    }

    // Passive hover region (does NOT eat mouse events)
    MouseArea {
        anchors.fill: parent
        enabled: false
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onPositionChanged: function(mouse) {
            var d = root.diagnosticAt(mouse.x, mouse.y)
            if (d) {
                root.hoveredDiagnostic = d
                root.diagnosticHovered(d, mouse.x, mouse.y)
                root.requestPaint()
            } else if (root.hoveredDiagnostic) {
                root.hoveredDiagnostic = null
                root.diagnosticExited()
                root.requestPaint()
            }
        }
        onExited: {
            root.hoveredDiagnostic = null
            root.diagnosticExited()
            root.requestPaint()
        }
    }
}
