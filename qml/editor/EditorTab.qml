import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property string title: ""
    property string iconName: "file"
    property int tabIndex: -1
    property int tabCount: 0
    property bool active: false
    property bool dirty: false
    property bool hovered: mouse.containsMouse || closeMouse.containsMouse
    property real pressX: 0

    signal activated(int index)
    signal closeRequested(int index)
    signal moveRequested(int from, int to)

    width: Math.min(220, Math.max(120, title.length * 8 + 68))
    height: parent ? parent.height : DesignTokens.metrics.tabHeight
    color: active ? theme.tabActiveBg : (hovered ? theme.hover : theme.tabInactiveBg)

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.active ? root.theme.accent : "transparent"
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.active ? root.theme.tabActiveBg : root.theme.border
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.rightMargin: 30
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: function(mouseEvent) { root.pressX = mouseEvent.x }
        onClicked: root.activated(root.tabIndex)
        onReleased: function(mouseEvent) {
            if (Math.abs(mouseEvent.x - root.pressX) < 12)
                return
            var list = root.ListView.view
            if (!list)
                return
            var targetIndex = list.indexAt(mouseEvent.x + root.x, list.height / 2)
            if (targetIndex >= 0 && targetIndex !== root.tabIndex)
                root.moveRequested(root.tabIndex, targetIndex)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 4
        spacing: 6

        Icon {
            icon: root.iconName
            color: root.active ? root.theme.text : root.theme.textDim
            size: 14
        }

        Text {
            text: root.title
            color: root.active ? root.theme.text : root.theme.textDim
            font.pointSize: 11
            font.weight: root.active ? Font.Medium : Font.Normal
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Rectangle {
            implicitWidth: 22
            implicitHeight: 22
            radius: DesignTokens.metrics.radiusSm
            color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
            visible: root.active || root.hovered || closeMouse.containsMouse

            Icon {
                anchors.centerIn: parent
                icon: "close"
                size: 11
                color: closeMouse.containsMouse ? root.theme.textStrong : Qt.rgba(1, 1, 1, 0.5)
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouseEvent) {
                    mouseEvent.accepted = true
                    root.closeRequested(root.tabIndex)
                }
            }
        }

        Text {
            text: "\u25CF"
            color: root.dirty ? root.theme.warning : "transparent"
            font.pointSize: 10
            visible: root.dirty && !(root.active || root.hovered)
        }
    }

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height - 10
        color: root.theme.border
        visible: root.tabIndex < root.tabCount - 1
    }
}
