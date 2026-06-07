import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property string label: ""
    property string iconName: ""
    property bool active: false
    property int panelIndex: -1
    property bool hovered: mouse.containsMouse
    readonly property string uiFontFamily: {
        var family = (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
        family = String(family || "Inter").split(",")[0].trim()
        return family.length > 0 ? family : "Inter"
    }
    readonly property int uiFontSize: Math.max(9, ((typeof UiVM !== "undefined" && UiVM) ? UiVM.fontSize : 12) - 2)

    signal clicked()
    signal activated(int panelIndex)

    implicitWidth: title.implicitWidth + 34
    implicitHeight: DesignTokens.metrics.panelHeaderHeight
    Layout.preferredWidth: implicitWidth
    Layout.fillHeight: true
    height: parent ? parent.height : DesignTokens.metrics.panelHeaderHeight
    z: mouse.containsMouse ? 20 : 1
    color: active ? (theme.panel || "#1E1E1E") : (hovered ? (theme.hover || Qt.rgba(1, 1, 1, 0.06)) : "transparent")

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: root.active ? root.theme.accent : "transparent"
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 4

        Icon {
            icon: root.iconName
            color: root.active ? (root.theme.text || "#D4D4D4") : (root.theme.textDim || "#858585")
            size: 12
        }

        Text {
            id: title
            text: root.label
            color: root.active ? (root.theme.text || "#D4D4D4") : (root.theme.textDim || "#858585")
            font.family: root.uiFontFamily
            font.pointSize: root.uiFontSize
            font.weight: Font.Bold
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        z: 50
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouseEvent) {
            mouseEvent.accepted = true
            root.clicked()
            root.activated(root.panelIndex)
        }
    }
}
