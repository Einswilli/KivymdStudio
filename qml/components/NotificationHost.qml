import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var notifications: []
    property bool busy: false
    property var operations: []
    property var theme: ({})
    property color panelColor: "#1F232A"
    property color borderColor: "#343C4A"

    anchors.fill: parent
    z: 9999

    Rectangle {
        id: busyPill
        visible: root.busy
        width: busyRow.implicitWidth + 20
        height: 34
        radius: 17
        color: theme.toastBg || theme.panel || "#111827"
        border.color: theme.border || "#374151"
        border.width: 1
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12
        opacity: visible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 140 } }

        Row {
            id: busyRow
            anchors.centerIn: parent
            spacing: 9

            BusyIndicator {
                running: root.busy
                width: 18
                height: 18
            }

            Text {
                text: root.operations && root.operations.length > 0
                      ? (root.operations[0].label || "Working…")
                      : "Working…"
                color: theme.text || "#E5E7EB"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Column {
        id: stack
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 18
        anchors.rightMargin: 18
        spacing: 10

        Repeater {
            model: root.notifications || []

            delegate: Rectangle {
                id: toast
                required property var modelData
                width: 360
                height: Math.max(78, bodyColumn.implicitHeight + 24)
                radius: 14
                color: theme.toastBg || root.panelColor
                border.color: Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, mouse.containsMouse ? 0.58 : 0.32)
                border.width: 1
                opacity: 0
                x: 26
                scale: 0.985

                readonly property color accent: levelColor(modelData.level || "info")
                readonly property string iconName: levelIcon(modelData.level || "info")

                Component.onCompleted: {
                    enterAnim.start()
                    dismissTimer.interval = modelData.timeout || 4200
                    dismissTimer.start()
                }

                ParallelAnimation {
                    id: enterAnim
                    NumberAnimation { target: toast; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                    NumberAnimation { target: toast; property: "x"; from: 26; to: 0; duration: 190; easing.type: Easing.OutCubic }
                    NumberAnimation { target: toast; property: "scale"; from: 0.985; to: 1; duration: 180; easing.type: Easing.OutCubic }
                }

                SequentialAnimation {
                    id: exitAnim
                    ParallelAnimation {
                        NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 130; easing.type: Easing.InCubic }
                        NumberAnimation { target: toast; property: "x"; to: 26; duration: 130; easing.type: Easing.InCubic }
                        NumberAnimation { target: toast; property: "scale"; to: 0.985; duration: 130; easing.type: Easing.InCubic }
                    }
                    ScriptAction {
                        script: if (NotificationVM) NotificationVM.dismiss(modelData.id)
                    }
                }

                Timer {
                    id: dismissTimer
                    repeat: false
                    onTriggered: exitAnim.start()
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 1.5
                    color: toast.accent
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: dismissTimer.stop()
                    onExited: dismissTimer.restart()
                }

                RowLayout {
                    id: bodyColumn
                    anchors.left: parent.left
                    anchors.right: closeButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    anchors.rightMargin: 10
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        Layout.alignment: Qt.AlignTop
                        radius: 10
                        color: Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, 0.34)

                        Icon {
                            anchors.centerIn: parent
                            icon: toast.iconName
                            color: toast.accent
                            size: 18
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: modelData.title || "Notification"
                            color: theme.textStrong || "#F9FAFB"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.bold: true
                            font.pointSize: 11
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: (modelData.message || "").length > 0
                            text: modelData.message || ""
                            color: theme.text || "#CBD5E1"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 9
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            visible: modelData.actions && modelData.actions.length > 0
                            Layout.fillWidth: true
                            spacing: 7

                            Repeater {
                                model: modelData.actions || []

                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.preferredHeight: 24
                                    Layout.preferredWidth: Math.max(64, actionLabel.implicitWidth + 18)
                                    radius: 7
                                    color: actionMouse.containsMouse ? (theme.accent || "#3B82F6") : Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, 0.14)
                                    border.width: 1
                                    border.color: Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, 0.34)

                                    Text {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        text: modelData.label || "Action"
                                        color: actionMouse.containsMouse ? (theme.accentText || "#FFFFFF") : (theme.textStrong || "#F9FAFB")
                                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                        font.pointSize: 8
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        id: actionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function(mouse) {
                                            mouse.accepted = true
                                            if (typeof ActionVM !== "undefined" && ActionVM)
                                                ActionVM.runAction(modelData.id || "", modelData.payload || ({}))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: closeButton
                    width: 24
                    height: 24
                    radius: 6
                    color: closeMouse.containsMouse ? (theme.hover || "#374151") : "transparent"
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 8
                    anchors.rightMargin: 8

                    Icon {
                        anchors.centerIn: parent
                        icon: "close"
                        color: theme.text || "#D1D5DB"
                        size: 13
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: exitAnim.start()
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2
                    color: Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, 0.18)

                    Rectangle {
                        height: parent.height
                        color: toast.accent
                        width: parent.width
                        NumberAnimation on width {
                            from: parent.width
                            to: 0
                            duration: modelData.timeout || 4200
                            running: true
                        }
                    }
                }
            }
        }
    }

    function levelColor(level) {
        if (level === "success") return theme.success || "#98C379"
        if (level === "warning") return theme.warning || "#E5C07B"
        if (level === "error") return theme.error || "#E06C75"
        return theme.info || "#61AFEF"
    }

    function levelIcon(level) {
        if (level === "success") return "check-circle"
        if (level === "warning") return "warning"
        if (level === "error") return "error"
        return "bell"
    }
}
