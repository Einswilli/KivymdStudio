import QtQuick 2.15

Item {
    id: root

    property string lineText: ""
    property var spans: []
    property font terminalFont: Qt.font({ family: "Menlo", pointSize: 12 })
    property color fallbackColor: "#D4D4D4"
    property color selectionColor: "#264F78"
    property int contentPadding: 8
    property real fontWidth: 8

    implicitHeight: lineMetrics.height + 3
    implicitWidth: Math.max(spanRow.implicitWidth + contentPadding * 2, 1)

    TextMetrics {
        id: lineMetrics
        font: root.terminalFont
        text: "M"
    }

    Row {
        id: spanRow
        anchors.left: parent.left
        anchors.leftMargin: root.contentPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            model: root.spans && root.spans.length > 0
                   ? root.spans
                   : [{ "text": root.lineText.length > 0 ? root.lineText : " ", "fg": root.fallbackColor, "bg": "transparent", "bold": false, "italic": false, "underline": false }]

            delegate: Text {
                required property var modelData

                text: (modelData.text || " ").replace(/\t/g, "    ")
                textFormat: Text.PlainText
                font.family: root.terminalFont.family
                font.pointSize: root.terminalFont.pointSize
                font.bold: !!modelData.bold
                font.italic: !!modelData.italic
                font.underline: !!modelData.underline
                color: modelData.fg || root.fallbackColor
                renderType: Text.NativeRendering
                verticalAlignment: Text.AlignVCenter
                height: root.height

                Rectangle {
                    anchors.fill: parent
                    z: -1
                    visible: !!modelData.bg && modelData.bg !== "transparent"
                    color: modelData.bg || "transparent"
                }
            }
        }
    }
}
