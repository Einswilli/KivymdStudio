import QtQuick 2.15

Item {
    id: root

    property string lineText: ""
    property var lineSpans: []
    property int lineNumber: 0
    property real fontWidth: 7
    property int gutterWidth: 56
    property int contentPadding: 8
    property real horizontalOffset: 0
    property int selectionStartCol: -1
    property int selectionEndCol: -1
    property bool isActiveLine: false
    property bool hoverEnabled: true
    property bool foldable: false
    property bool folded: false
    property font editorFont: Qt.font({ family: "Menlo", pointSize: 12 })
    property var tokenColors: defaultTokenColors
    property var theme: ({})
    property var inlineDiagnostic: ({})
    property var findHighlights: []
    property var bracketHighlights: []
    property var indentGuides: []

    signal tokenClicked(int start, int end, string kind, int line)
    signal tokenHovered(string kind, string text, int start, int end, int mouseX, int mouseY)
    signal foldClicked(int line)

    readonly property var defaultTokenColors: ({
        "comment": "#6A9955",
        "docstring": "#6A9955",
        "string": "#CE9178",
        "number": "#B5CEA8",
        "keyword": "#569CD6",
        "function": "#DCDCAA",
        "class": "#4EC9B0",
        "decorator": "#D7BA7D", // #C586C0
        "type": "#4EC9B0",
        "tag": "#569CD6",
        "attribute": "#9CDCFE",
        "selector": "#D7BA7D",
        "value": "#CE9178",
        "operator": "#D4D4D4",
        "identifier": "#9CDCFE",
        "module": "#4EC9B0", // #C586C0
        "variable": "#9CDCFE",
        "parameter": "#9CDCFE",
        "property": "#9CDCFE",
        "builtin": "#DCDCAA",
        "default": "#D4D4D4",
    })

    function colorFor(kind) {
        // console.log("Getting color for token kind:", kind);
        var key = kind || "default"
        if (root.tokenColors && root.tokenColors[key])
            return root.tokenColors[key]
        if (root.defaultTokenColors[key])
            return root.defaultTokenColors[key]
        if (root.tokenColors && root.tokenColors.default)
            return root.tokenColors.default
        return root.defaultTokenColors.default
    }

    function diagnosticColor(severity) {
        if (severity === "error")
            return root.theme.error || root.theme.diagnosticsError || "#E06C75"
        if (severity === "warning")
            return root.theme.warning || root.theme.diagnosticsWarning || "#D19A66"
        if (severity === "info")
            return root.theme.info || root.theme.diagnosticsInfo || "#61AFEF"
        return root.theme.textDim || "#858585"
    }

    Rectangle {
        anchors.fill: parent
        color: root.isActiveLine ? (root.theme.editorLineHighlight || Qt.rgba(1, 1, 1, 0.035)) : "transparent"
        z: 0
    }

    Rectangle {
        x: root.horizontalOffset
        y: 0
        width: root.gutterWidth
        height: parent.height
        color: root.isActiveLine ? (root.theme.editorLineHighlight || Qt.rgba(1, 1, 1, 0.035)) : (root.theme.bg || root.theme.editorBg || "#1E1E1E")
        z: 4
    }

    Text {
        id: gutter
        x: root.horizontalOffset
        y: 0
        width: root.gutterWidth
        height: parent.height
        rightPadding: 12
        text: root.lineNumber
        textFormat: Text.PlainText
        font: root.editorFont
        color: root.isActiveLine ? (root.theme.activeLineNumber || "#C6C6C6") : (root.theme.lineNumbers || "#858585")
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
        z: 5
    }

    Text {
        id: foldMarker
        visible: root.foldable
        x: root.horizontalOffset + 4
        y: 0
        width: 18
        height: parent.height
        text: root.folded ? "›" : "⌄"
        color: foldMouse.containsMouse ? (root.theme.textStrong || "#E5E7EB") : (root.theme.textDim || "#858585")
        font: root.editorFont
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        z: 7

        MouseArea {
            id: foldMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.foldClicked(root.lineNumber)
        }
    }

    Rectangle {
        x: root.horizontalOffset + root.gutterWidth - 1
        y: 0
        height: parent.height
        width: 1
        color: root.theme.border || "#2B2B2B"
        z: 6
    }

    Rectangle {
        visible: root.selectionStartCol >= 0 && root.selectionEndCol > root.selectionStartCol
        x: root.gutterWidth + root.contentPadding + root.selectionStartCol * root.fontWidth
        y: 1
        width: Math.max(1, (root.selectionEndCol - root.selectionStartCol) * root.fontWidth)
        height: parent.height - 2
        color: root.theme.editorSelection || "#264F78"
        opacity: 0.75
        z: 2
    }

    Repeater {
        model: root.indentGuides || []
        delegate: Rectangle {
            required property var modelData
            x: root.gutterWidth + root.contentPadding + Number(modelData.col || 0) * root.fontWidth
            y: 0
            width: 1
            height: parent.height
            color: modelData.active
                   ? (root.theme.activeIndentGuide || Qt.rgba(1, 1, 1, 0.26))
                   : (root.theme.indentGuide || Qt.rgba(1, 1, 1, 0.10))
            opacity: modelData.active ? 1.0 : 0.8
            z: 1
        }
    }

    Repeater {
        model: root.findHighlights || []
        delegate: Rectangle {
            required property var modelData
            x: root.gutterWidth + root.contentPadding + Number(modelData.startCol || 0) * root.fontWidth
            y: 2
            width: Math.max(2, (Number(modelData.endCol || 0) - Number(modelData.startCol || 0)) * root.fontWidth)
            height: parent.height - 4
            radius: 3
            color: modelData.current
                   ? (root.theme.findCurrent || Qt.rgba(0.95, 0.68, 0.24, 0.34))
                   : (root.theme.findMatch || Qt.rgba(0.95, 0.68, 0.24, 0.18))
            border.width: modelData.current ? 1 : 0
            border.color: root.theme.warning || "#D19A66"
            z: 2
        }
    }

    Repeater {
        model: root.bracketHighlights || []
        delegate: Rectangle {
            required property var modelData
            x: root.gutterWidth + root.contentPadding + Number(modelData.col || 0) * root.fontWidth
            y: 2
            width: Math.max(2, root.fontWidth)
            height: parent.height - 4
            radius: 3
            color: modelData.matched === false
                   ? Qt.rgba(0.88, 0.25, 0.29, 0.16)
                   : Qt.rgba(0.38, 0.64, 1.0, 0.13)
            border.width: 1
            border.color: modelData.matched === false
                          ? (root.theme.error || "#E06C75")
                          : (root.theme.accent || "#60A5FA")
            z: 2
        }
    }

    Row {
        id: spanRow
        anchors.left: parent.left
        anchors.leftMargin: root.gutterWidth + root.contentPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        z: 3

        Repeater {
            model: root.lineSpans && root.lineSpans.length > 0
                   ? root.lineSpans
                   : [{ "start": 0, "end": root.lineText.length, "kind": "default", "text": root.lineText.length > 0 ? root.lineText : " " }]

            delegate: Text {
                required property var modelData
                text: (modelData.text || " ").replace(/\t/g, "    ")
                textFormat: Text.PlainText
                font: root.editorFont
                color: root.colorFor(modelData.kind)
                renderType: Text.NativeRendering
                verticalAlignment: Text.AlignVCenter
                height: root.height

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: root.hoverEnabled
                    acceptedButtons: Qt.NoButton
                    cursorShape: Qt.IBeamCursor
                    onPositionChanged: function(mouse) {
                        root.tokenHovered(
                            modelData.kind || "default",
                            modelData.text || "",
                            Number(modelData.start || 0),
                            Number(modelData.end || 0),
                            mouse.x + parent.x,
                            mouse.y + parent.y
                        )
                    }
                }
            }
        }
    }

    Text {
        id: inlineDiagnosticText
        visible: !!(root.inlineDiagnostic && root.inlineDiagnostic.message)
        x: root.gutterWidth + root.contentPadding + (root.lineText.length + 2) * root.fontWidth
        y: 0
        height: root.height
        width: Math.max(0, root.width - x - 24)
        text: root.inlineDiagnostic && root.inlineDiagnostic.message
              ? "— " + root.inlineDiagnostic.message
              : ""
        textFormat: Text.PlainText
        color: root.diagnosticColor(root.inlineDiagnostic ? root.inlineDiagnostic.severity : "info")
        opacity: 0.82
        font.family: root.editorFont.family
        font.pointSize: root.editorFont.pointSize
        font.italic: true
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
        z: 3
    }
}
