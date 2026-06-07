import QtQuick 2.15
import QtQuick.Controls 2.15

/*
 * MiniMap — Code overview minimap.
 *
 * Renders a scaled-down copy of the editor content.
 * Drag the viewport indicator to scroll the editor.
 */

Item {
    id: root

    property var editor: null
    property color bgColor: "#1E1E1E"
    property color viewportColor: "#3E3E42"
    property color textColor: "#555555"
    property real scaleFactor: 0.15

    width: 80
    clip: true

    Rectangle {
        anchors.fill: parent
        color: root.bgColor
    }

    // Scaled content
    Text {
        id: minimapText
        anchors.fill: parent
        anchors.margins: 2
        text: root.editor ? root.editor.text : ""
        color: root.textColor
        font: root.editor ? Qt.font({
            family: root.editor.font.family,
            pointSize: root.editor.font.pointSize * root.scaleFactor
        }) : Qt.font({ family: "Menlo", pointSize: 2 })
        wrapMode: Text.NoWrap
        clip: true
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft
    }

    // Viewport indicator
    Rectangle {
        id: viewport
        color: "transparent"
        border.color: root.viewportColor
        border.width: 1
        x: 0
        y: 0
        width: parent.width
        height: 30
        visible: root.editor !== null
        z: 10

        Rectangle {
            anchors.fill: parent
            color: root.viewportColor
            opacity: 0.25
        }
    }

    // Sync viewport position from editor scroll
    Connections {
        target: root.editor
        enabled: root.editor !== null
        function onContentYChanged() {
            _syncViewport()
        }
        function onContentHeightChanged() {
            _syncViewport()
        }
    }

    // Drag to scroll
    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: viewport
        drag.axis: Drag.YAxis
        drag.minimumY: 0
        drag.maximumY: parent.height - viewport.height

        onPressed: function(mouse) {
            if (root.editor && root.editor.Flickable) {
                var flickable = root.editor.Flickable || root.editor.parent
                var ratio = viewport.y / (parent.height - viewport.height)
                // approximate scroll
            }
        }

        onMouseYChanged: {
            if (drag.active && root.editor) {
                var flickable = root.editor.Flickable
                if (!flickable && root.editor.parent && root.editor.parent.hasOwnProperty('contentY')) {
                    flickable = root.editor.parent
                }
                if (flickable) {
                    var ratio = viewport.y / Math.max(1, parent.height - viewport.height)
                    flickable.contentY = ratio * (flickable.contentHeight - flickable.height)
                }
            }
        }
    }

    function _syncViewport() {
        if (!root.editor) return
        var flickable = root.editor.Flickable
        if (!flickable && root.editor.parent) flickable = root.editor.parent

        if (flickable && flickable.contentHeight > 0 && flickable.height > 0) {
            var ratio = flickable.contentY / Math.max(1, flickable.contentHeight - flickable.height)
            viewport.y = ratio * Math.max(1, parent.height - viewport.height)
            viewport.height = Math.max(10, (flickable.height / flickable.contentHeight) * parent.height)
        }
    }

    Component.onCompleted: _syncViewport()
}
