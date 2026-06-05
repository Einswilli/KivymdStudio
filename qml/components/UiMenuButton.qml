import QtQuick 2.15
import QtQuick.Controls 2.15

Text {
    id: root

    property var theme: DesignTokens.darkTheme
    property Menu menu: null
    property bool hovered: false

    color: hovered ? (theme.textStrong || "#FFFFFF") : (theme.textDim || "#858585")
    font.pointSize: 11
    leftPadding: 8
    rightPadding: 8
    verticalAlignment: Text.AlignVCenter
    height: 32

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.menu ? root.menu.popup(root, 0, root.height) : null
    }
}
