import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property int sessionId: -1
    property int tabIndex: -1
    property int tabCount: 0
    property string title: "shell"
    property bool active: false
    property bool hovered: mouse.containsMouse || closeMouse.containsMouse
    property real pressX: 0
    readonly property color tabBg: root.active
        ? (root.theme.tabActiveBg || root.theme.terminalBg || root.theme.panel || "#1E1E1E")
        : (root.hovered ? (root.theme.hover || root.theme.tabInactiveBg || Qt.rgba(1, 1, 1, 0.06)) : "transparent")
    readonly property color accentColor: root.theme.terminalAccent || root.theme.accent || root.theme.success || "#007ACC"
    readonly property color textColor: root.active
        ? (root.theme.tabActiveText || root.theme.terminalText || root.theme.textStrong || root.theme.text || "#E5E5E5")
        : (root.theme.tabInactiveText || root.theme.textDim || "#858585")
    readonly property color closeBg: closeMouse.containsMouse ? (root.theme.errorSoft || Qt.rgba(1, 0, 0, 0.22)) : "transparent"

    signal activated(int sessionId)
    signal closeRequested(int sessionId, int index)
    signal moveRequested(int from, int to)

    function fontFamily(value) {
        var family = String(value || "Inter").split(",")[0].trim()
        if (family.toLowerCase() === "monospace")
            return "Inter"
        return family.length > 0 ? family : "Inter"
    }

    implicitWidth: Math.max(86, titleText.implicitWidth + 42)
    height: parent ? parent.height : 24
    color: root.tabBg

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: root.active ? root.accentColor : "transparent"
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.rightMargin: 20
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.pressX = mouse.x
        onClicked: root.activated(root.sessionId)
        onReleased: {
            if (Math.abs(mouse.x - root.pressX) < 12)
                return
            var list = root.ListView.view
            if (!list)
                return
            var targetIndex = list.indexAt(mouse.x + root.x, list.height / 2)
            if (targetIndex >= 0 && targetIndex !== root.tabIndex)
                root.moveRequested(root.tabIndex, targetIndex)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 2
        spacing: 5

        Icon {
            icon: "terminal"
            color: root.active ? root.accentColor : root.textColor
            size: 12
        }

        Text {
            id: titleText
            text: root.title
            color: root.textColor
            font.family: root.fontFamily((typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter")
            font.pointSize: 10
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Rectangle {
            implicitWidth: 16
            implicitHeight: 16
            radius: DesignTokens.metrics.radiusXs
            color: root.closeBg
            visible: root.active || root.hovered || closeMouse.containsMouse

            Icon {
                anchors.centerIn: parent
                icon: "close"
                size: 10
                color: closeMouse.containsMouse ? (root.theme.error || "#FF5555") : root.textColor
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function(event) {
                    event.accepted = true
                    root.closeRequested(root.sessionId, root.tabIndex)
                }
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height - 8
        color: root.theme.border || "#2D2D30"
        visible: root.tabIndex < root.tabCount - 1
    }
}
