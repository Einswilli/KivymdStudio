import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property string text: ""
    property string iconName: ""
    property string actionId: ""
    property var payload: ({})
    property bool disabled: false
    property bool busy: (typeof ActionVM !== "undefined" && ActionVM && actionId.length > 0)
                        ? ActionVM.isRunning(actionId)
                        : false

    signal clicked()

    implicitHeight: 30
    implicitWidth: Math.max(108, content.implicitWidth + 24)
    radius: DesignTokens.metrics.radiusSm
    opacity: disabled ? 0.48 : 1
    color: mouse.containsMouse && !disabled
           ? (theme.buttonHover || theme.hover || "#374151")
           : (theme.buttonBg || theme.inputBg || "#2A2A2A")
    border.width: 1
    border.color: busy ? (theme.accent || "#3B82F6") : (theme.border || "#3E3E42")

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 7

        BusyIndicator {
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            running: root.busy
            visible: root.busy
        }

        Icon {
            visible: !root.busy && root.iconName.length > 0
            icon: root.iconName
            color: theme.text || "#D1D5DB"
            size: 13
        }

        Text {
            text: root.text
            color: mouse.containsMouse && !root.disabled
                   ? (theme.textStrong || "#FFFFFF")
                   : (theme.text || "#D1D5DB")
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 10
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !root.disabled && !root.busy
        onClicked: function(event) {
            event.accepted = true
            root.clicked()
            if (root.actionId.length > 0 && typeof ActionVM !== "undefined" && ActionVM)
                ActionVM.runAction(root.actionId, root.payload || ({}))
        }
    }
}
