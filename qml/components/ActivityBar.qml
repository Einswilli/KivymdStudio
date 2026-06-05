import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    implicitWidth: 48
    implicitHeight: parent ? parent.height : 600

    property var theme: ({})
    property int activeIndex: 0
    property bool sidebarOpen: true
    property bool panelOpen: false
    property bool rightPanelOpen: false
    property var items: [
        { id: "core.explorer", icon: "folder", title: "Explorer" },
        { id: "core.search", icon: "search", title: "Search" },
        { id: "core.scm", icon: "git-branch", title: "Source Control" },
        { id: "core.debug", icon: "debug", title: "Run and Debug" },
        { id: "core.extensions", icon: "extensions", title: "Extensions" }
    ]

    signal itemClicked(int index, string id)
    signal sidebarToggleClicked()
    signal terminalToggleClicked()
    signal rightPanelToggleClicked()

    Rectangle {
        anchors.fill: parent
        color: theme.activityBar || "#2C2C2C"

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 4
            spacing: 4

            Repeater {
                model: root.items

                delegate: ActivityBarButton {
                    iconName: modelData.icon
                    tooltip: modelData.title || modelData.label || modelData.id
                    active: index === root.activeIndex
                    iconColor: active ? "#FFFFFF" : (theme.textDim || "#858585")
                    bgColor: theme.sidebar || "#252526"
                    onItemClicked: {
                        root.activeIndex = index
                        root.itemClicked(index, modelData.id)
                    }
                }
            }

            Item { Layout.fillHeight: true }

            LayoutToggleButton {
                iconName: "layout-sidebar-left"
                tooltip: "Toggle Side Bar"
                active: root.sidebarOpen
                onItemClicked: root.sidebarToggleClicked()
            }

            LayoutToggleButton {
                iconName: "panel-bottom"
                tooltip: "Toggle Terminal"
                active: root.panelOpen
                onItemClicked: root.terminalToggleClicked()
            }

            LayoutToggleButton {
                iconName: "panel-right"
                tooltip: "Toggle Right Panel"
                active: root.rightPanelOpen
                onItemClicked: root.rightPanelToggleClicked()
            }

            ActivityBarButton {
                iconName: "settings"
                tooltip: "Settings"
                active: false
                iconColor: theme.textDim || "#858585"
                bgColor: theme.sidebar || "#252526"
                onItemClicked: {
                    root.activeIndex = -1
                    root.itemClicked(5, "settings")
                }
            }
        }
    }

    component LayoutToggleButton: Item {
        id: toggleRoot
        property string iconName: "layout-sidebar-left"
        property string tooltip: ""
        property bool active: false

        signal itemClicked()

        Layout.preferredWidth: 48
        Layout.preferredHeight: 34
        Layout.alignment: Qt.AlignHCenter

        Rectangle {
            anchors.centerIn: parent
            width: 32
            height: 28
            radius: 8
            color: toggleRoot.active
                   ? (root.theme.accentSoft || Qt.rgba(0.0, 0.48, 0.8, 0.12))
                   : (toggleMouse.containsMouse ? (root.theme.hover || Qt.rgba(1, 1, 1, 0.06)) : "transparent")
            border.width: toggleRoot.active ? 1 : 0
            border.color: root.theme.accent || "#61AFEF"

            Behavior on color { ColorAnimation { duration: 120 } }

            Icon {
                anchors.centerIn: parent
                icon: toggleRoot.iconName
                color: toggleRoot.active
                       ? (root.theme.accent || "#61AFEF")
                       : (toggleMouse.containsMouse ? (root.theme.text || "#CCCCCC") : (root.theme.textDim || "#858585"))
                size: 18
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleRoot.itemClicked()
        }

        ToolTip {
            visible: toggleMouse.containsMouse
            text: toggleRoot.tooltip
            delay: 500
            font.pointSize: 11
            background: Rectangle {
                color: root.theme.inputBg || "#3C3C3C"
                border.color: root.theme.border || "#555555"
                border.width: 1
                radius: DesignTokens.metrics.radiusXs
            }
            contentItem: Text {
                text: toggleRoot.tooltip
                color: root.theme.textStrong || "#CCCCCC"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 11
            }
        }
    }

    component ActivityBarButton: Item {
        id: btnRoot
        property string iconName: "folder"
        property string tooltip: ""
        property bool active: false
        property color iconColor: "#858585"
        property color bgColor: "#252526"

        signal itemClicked()

        Layout.preferredWidth: 48
        Layout.preferredHeight: 48
        Layout.alignment: Qt.AlignHCenter

        Rectangle {
            anchors.fill: parent
            color: active ? (root.theme.accentSoft || Qt.rgba(0.0, 0.48, 0.8, 0.14))
                          : (mouseArea.containsMouse ? (root.theme.hover || Qt.rgba(1, 1, 1, 0.06)) : "transparent")
            radius: 10
            anchors.margins: 6

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: active ? undefined : parent.top
            anchors.bottom: active ? parent.bottom : undefined
            width: 2
            height: active ? parent.height : 0
            y: active ? 0 : parent.height * 0.25
            color: root.theme.accent || "#FFFFFF"
            visible: active
        }

        Icon {
            id: ico
            anchors.centerIn: parent
            icon: iconName
            color: iconColor
            size: 22
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onEntered: { ico.color = active ? (root.theme.accent || "#FFFFFF") : (root.theme.text || "#FFFFFF") }
            onExited: { if (!active) ico.color = iconColor }
            onClicked: btnRoot.itemClicked()
            cursorShape: Qt.PointingHandCursor
        }

        ToolTip {
            visible: mouseArea.containsMouse
            text: tooltip
            delay: 500
            font.pointSize: 11
            background: Rectangle {
                color: root.theme.inputBg || "#3C3C3C"
                border.color: root.theme.border || "#555555"
                border.width: 1
                radius: DesignTokens.metrics.radiusXs
            }
            contentItem: Text {
                text: tooltip
                color: root.theme.textStrong || "#CCCCCC"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 11
            }
        }
    }
}
