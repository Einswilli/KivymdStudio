import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property var    editor: null
    property var    editorFlickable: null
    property var    flickable: null
    property int    lineCount: editor ? editor.lineCount : 0
    property real   lineHeight: editor ? editor.cursorRectangle.height : 22
    property int    currentLine: 1
    property color  bgColor: "#1E1E1E"
    property color  fgColor: "#858585"
    property color  activeFgColor: "#C6C6C6"

    Rectangle {
        anchors.fill: parent
        color: root.bgColor
    }

    ListView {
        id: lineList
        anchors.fill: parent
        model: root.lineCount
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        delegate: Text {
            width: lineList.width - 10
            height: root.lineHeight
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: index + 1
            color: index + 1 === root.currentLine ? root.activeFgColor : root.fgColor
            font: root.editor ? root.editor.font : Qt.font({ family: "Menlo", pointSize: 12 })
            rightPadding: 12
        }
    }

    Connections {
        id: scrollConn
        function onContentYChanged() {
            if (target)
                lineList.contentY = target.contentY
        }
    }

    onFlickableChanged: {
        scrollConn.target = root.flickable
    }

    onEditorFlickableChanged: {
        if (!root.flickable) scrollConn.target = root.editorFlickable
    }

    Component.onCompleted: {
        scrollConn.target = root.flickable || root.editorFlickable
    }
}
