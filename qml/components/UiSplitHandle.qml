import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property bool vertical: false

    implicitWidth: vertical ? 4 : 1
    implicitHeight: vertical ? 1 : 4
    color: SplitHandle.pressed ? theme.accent : "transparent"

    Rectangle {
        anchors.centerIn: parent
        width: root.vertical ? 1 : parent.width
        height: root.vertical ? parent.height : 1
        color: root.theme.border
        visible: SplitHandle.hovered || SplitHandle.pressed
    }
}
