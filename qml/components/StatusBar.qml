import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root

    property string gitBranch: ""
    property string language: "Python"
    property string encoding: "UTF-8"
    property string message: "Ready"
    property int notificationCount: 0
    property bool busy: false
    property int cursorLine: 1
    property int cursorCol: 1
    property int errorCount: 0
    property int warningCount: 0
    property string lspStatus: "LSP idle"
    property string lspDetails: ""
    property var lspServers: []
    property bool lspHealthy: true
    property string activeFile: ""
    property var theme: ({})
    property color bgColor: "#0078D4"
    property color textColor: "#FFFFFF"
    signal lspStartRequested()
    signal lspStopRequested()
    signal lspRestartRequested()

    height: 24
    color: root.bgColor

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 0

        Item {
            width: parent.width * 0.3
            height: parent.height
            visible: root.gitBranch.length > 0

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Icon { icon: "git-branch"; color: root.textColor; size: 14; anchors.verticalCenter: parent.verticalCenter }

                Text {
                    text: root.gitBranch
                    color: root.textColor
                    font.pointSize: 10
                    elide: Text.ElideRight
                    width: parent.parent.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item {
            width: Math.max(80, diagnosticsRow.implicitWidth + 12)
            height: parent.height
            visible: root.errorCount > 0 || root.warningCount > 0

            Row {
                id: diagnosticsRow
                anchors.centerIn: parent
                spacing: 10

                StatusBarItem {
                    visible: root.errorCount > 0
                    icon: "error"
                    iconColor: root.theme.error || "#F48771"
                    label: root.errorCount.toString()
                    fgColor: root.textColor
                }
                StatusBarItem {
                    visible: root.warningCount > 0
                    icon: "warning"
                    iconColor: root.theme.warning || "#E5C07B"
                    label: root.warningCount.toString()
                    fgColor: root.textColor
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: { }
            }
        }

        Item { width: parent.width * 0.2; height: 1 }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            StatusBarItem {
                id: lspStatusItem
                icon: root.lspHealthy ? "check-circle" : "alert-circle"
                iconColor: root.lspHealthy ? (root.theme.success || "#98C379") : (root.theme.warning || "#E5C07B")
                label: root.lspStatus
                fgColor: root.textColor
                tooltip: root.lspDetails
                onClicked: lspPopup.open()
            }
            StatusBarItem {
                icon: root.busy ? "sync" : "bell"
                iconColor: root.busy ? (root.theme.info || "#61AFEF") : (root.notificationCount > 0 ? (root.theme.warning || "#E5C07B") : root.textColor)
                label: root.busy ? "Working" : (root.notificationCount > 0 ? root.notificationCount.toString() : root.message)
                tooltip: root.busy ? "Background work in progress" : "Notifications and editor status"
                fgColor: root.textColor
            }
            StatusBarItem {
                icon: "code"
                iconColor: root.theme.info || "#C678DD"
                label: root.language.length > 0 ? root.language : "text"
                tooltip: "Current file language"
                onClicked: { }
                fgColor: root.textColor
            }
            StatusBarItem {
                label: root.encoding
                onClicked: { }
                fgColor: root.textColor
            }
            StatusBarItem {
                label: "Ln " + root.cursorLine + ", Col " + root.cursorCol
                onClicked: { }
                fgColor: root.textColor
            }
        }
    }

    Popup {
        id: lspPopup
        x: Math.max(8, root.width - width - 12)
        y: -height - 8
        width: 380
        height: Math.min(420, lspPopupContent.implicitHeight + 24)
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: root.theme.panel || "#1F232A"
            border.color: root.theme.border || "#3B4252"
            radius: 10
        }

        Column {
            id: lspPopupContent
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Row {
                width: parent.width
                spacing: 8
                Icon {
                    icon: root.lspHealthy ? "check-circle" : "alert-circle"
                    color: root.lspHealthy ? (root.theme.success || "#98C379") : (root.theme.warning || "#E5C07B")
                    size: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    width: parent.width - 24
                    text: root.lspStatus
                    color: root.theme.textStrong || "#F9FAFB"
                    font.bold: true
                    font.pointSize: 12
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                text: root.lspDetails.length > 0 ? root.lspDetails : "No LSP server information yet."
                color: root.theme.textDim || "#9CA3AF"
                font.pointSize: 9
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Rectangle { width: parent.width; height: 1; color: root.theme.border || "#303744" }

            Repeater {
                model: root.lspServers || []
                delegate: Rectangle {
                    required property var modelData
                    width: lspPopupContent.width
                    height: serverColumn.implicitHeight + 14
                    radius: 8
                    color: root.theme.inputBg || "#252A33"
                    border.color: root.theme.border || "#343C4A"

                    Column {
                        id: serverColumn
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 5

                        Row {
                            width: parent.width
                            spacing: 8
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: modelData.running ? (root.theme.success || "#98C379") : (modelData.available ? (root.theme.warning || "#E5C07B") : (root.theme.error || "#E06C75"))
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                width: parent.width - 16
                                text: modelData.name + " · " + (modelData.running ? "running" : (modelData.available ? "available" : "missing"))
                                color: root.theme.text || "#E5E7EB"
                                font.bold: true
                                font.pointSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            text: modelData.resolvedCommand && modelData.resolvedCommand.length > 0 ? modelData.resolvedCommand : modelData.command
                            color: root.theme.textDim || "#9CA3AF"
                            font.pointSize: 8
                            width: parent.width
                            elide: Text.ElideMiddle
                        }

                        Text {
                            visible: modelData.logs && modelData.logs.length > 0
                            text: (modelData.logs || []).slice(-4).join("\n")
                            color: root.theme.text || "#CBD5E1"
                            font.family: "Menlo"
                            font.pointSize: 8
                            width: parent.width
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }

            Row {
                spacing: 8
                LspActionButton { label: "Run"; onClicked: { root.lspStartRequested(); lspPopup.close() } }
                LspActionButton { label: "Restart"; accent: true; onClicked: { root.lspRestartRequested(); lspPopup.close() } }
                LspActionButton { label: "Stop"; danger: true; onClicked: { root.lspStopRequested(); lspPopup.close() } }
            }
        }
    }

    component LspActionButton: Rectangle {
        id: actionRoot
        property string label: ""
        property bool accent: false
        property bool danger: false
        signal clicked()
        width: actionText.contentWidth + 18
        height: 26
        radius: 6
        color: actionMouse.containsMouse
               ? (danger ? (root.theme.error || "#B91C1C") : (root.theme.accentHover || "#2563EB"))
               : (accent ? (root.theme.accent || "#1D4ED8") : (root.theme.inputBg || "#2D3440"))
        border.color: danger ? (root.theme.error || "#EF4444") : (root.theme.accent || "#3B82F6")
        Text {
            id: actionText
            anchors.centerIn: parent
            text: actionRoot.label
            color: root.theme.textStrong || "#F9FAFB"
            font.pointSize: 9
        }
        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRoot.clicked()
        }
    }

    component StatusBarItem: Item {
        id: statusItem
        property string icon: ""
        property color iconColor: "#FFFFFF"
        property string label: ""
        property color fgColor: "#FFFFFF"
        property string tooltip: ""
        signal clicked()

        height: root.height

        implicitWidth: _icon.width + _label.contentWidth + 4

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Icon {
                id: _icon
                icon: parent.parent.icon || ""
                color: parent.parent.iconColor
                size: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.parent.icon !== ""
            }

            Text {
                id: _label
                text: parent.parent.label
                color: parent.parent.fgColor
                font.pointSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: _mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
            onEntered: parent.opacity = 0.8
            onExited: parent.opacity = 1.0
        }

        ToolTip.visible: _mouse.containsMouse && statusItem.tooltip.length > 0
        ToolTip.text: statusItem.tooltip
        ToolTip.delay: 350
    }
}
