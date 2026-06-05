import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property string iconName: ""
    property string tooltip: ""
    property string actionId: ""
    property var actionPayload: ({})
    readonly property bool busy: actionId.length > 0 && typeof ActionVM !== "undefined" && ActionVM ? ActionVM.isRunning(actionId) : false
    property bool toggled: false
    property int iconSize: 14
    property color iconColor: toggled ? (theme.accent || theme.text) : (theme.textDim || "#858585")
    property color hoverColor: theme.hover || Qt.rgba(0.5, 0.5, 0.5, 0.24)
    property color activeBgColor: theme.accentSoft || Qt.rgba(0.0, 0.48, 0.8, 0.16)
    property color activeBorderColor: theme.accent || Qt.rgba(1, 1, 1, 0.2)

    signal clicked()

    implicitWidth: 28
    implicitHeight: 28
    radius: DesignTokens.metrics.radiusSm
    color: toggled ? activeBgColor : (mouse.containsMouse ? hoverColor : "transparent")

    border.width: toggled || mouse.containsMouse ? 1 : 0
    border.color: toggled ? activeBorderColor : (theme.border || Qt.rgba(1, 1, 1, 0.12))

    opacity: enabled ? 1.0 : 0.42

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Icon {
        anchors.centerIn: parent
        icon: root.iconName
        color: root.toggled ? (root.theme.accent || root.theme.textStrong || root.iconColor)
              : (mouse.containsMouse ? (root.theme.text || root.iconColor) : root.iconColor)
        size: root.iconSize
        rotation: root.busy ? 360 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: 650
                loops: root.busy ? Animation.Infinite : 1
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !root.busy
        onClicked: {
            root.clicked()
            if (root.actionId.length > 0 && typeof ActionVM !== "undefined" && ActionVM)
                ActionVM.runAction(root.actionId, root.actionPayload || ({}))
        }
    }

    ToolTip {
        visible: mouse.containsMouse && root.tooltip.length > 0
        text: root.tooltip
        delay: 450
        background: Rectangle {
            color: root.theme.inputBg || "#3C3C3C"
            border.color: root.theme.inputBorder || "#555555"
            radius: DesignTokens.metrics.radiusXs
        }
        contentItem: Text {
            text: root.tooltip
            color: root.theme.textStrong || "#FFFFFF"
            font.pointSize: 9
        }
    }
}
