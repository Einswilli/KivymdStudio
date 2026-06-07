import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root

    default property alias content: contentHost.data

    property var theme: DesignTokens.darkTheme
    property bool open: true
    property bool horizontal: true
    property real preferredSize: 280
    property real minimumSize: 180
    property real maximumSize: 520
    property bool showTopBorder: false
    property bool showLeftBorder: false

    visible: open
    clip: true
    color: theme.panel || "#1E1E1E"

    SplitView.preferredWidth: horizontal ? (open ? preferredSize : 0) : -1
    SplitView.minimumWidth: horizontal ? (open ? minimumSize : 0) : -1
    SplitView.maximumWidth: horizontal ? (open ? maximumSize : 0) : -1
    SplitView.preferredHeight: horizontal ? -1 : (open ? preferredSize : 0)
    SplitView.minimumHeight: horizontal ? -1 : (open ? minimumSize : 0)
    SplitView.maximumHeight: horizontal ? -1 : (open ? maximumSize : 0)

    Rectangle {
        visible: root.showTopBorder
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: root.theme.border
        z: 2
    }

    Rectangle {
        visible: root.showLeftBorder
        anchors.left: parent.left
        width: 1
        height: parent.height
        color: root.theme.border
        z: 2
    }

    Item {
        id: contentHost
        anchors.fill: parent
    }
}
