import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property color bgColor: "#1E1E1E"
    property color accentColor: "#007ACC"
    property color textColor: "#CCCCCC"
    property color dimColor: "#888"
    property var theme: ({})
    property var recentFiles: []

    signal openFileRequested()
    signal openFolderRequested()
    signal newFileRequested()
    signal openRecent(string path)

    color: root.bgColor

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        Column {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                text: "Ember"
                font.pointSize: 36
                font.bold: true
                color: root.accentColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Code Editor"
                font.pointSize: 14
                color: root.dimColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            WelcomeButton { label: "New File"; shortcut: "Ctrl+N"; onClicked: root.newFileRequested() }
            WelcomeButton { label: "Open File..."; shortcut: "Ctrl+O"; onClicked: root.openFileRequested() }
            WelcomeButton { label: "Open Folder..."; shortcut: "Ctrl+K"; onClicked: root.openFolderRequested() }
        }

        Column {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            visible: root.recentFiles && root.recentFiles.length > 0

            Text {
                text: "Recent"
                font.pointSize: 11
                color: root.dimColor
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            ListView {
                id: recentList
                Layout.alignment: Qt.AlignHCenter
                width: 400
                height: Math.min(count * 28, 140)
                model: root.recentFiles
                clip: true

                delegate: Rectangle {
                    required property var modelData
                    width: recentList.width
                    height: 28
                    color: mArea.containsMouse ? (root.theme.hover || "#2A2D2E") : "transparent"
                    radius: 4

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8

                        Icon { icon: "file"; color: root.accentColor; size: 14; anchors.verticalCenter: parent.verticalCenter }

                        Text {
                            text: modelData.name || modelData.display_name || ""
                            color: root.accentColor
                            font.pointSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.parent.width * 0.4; elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.path || ""
                            color: root.dimColor
                            font.pointSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.parent.width * 0.5; elide: Text.ElideMiddle
                        }
                    }

                    MouseArea {
                        id: mArea
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.openRecent(modelData.path)
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Ctrl+Shift+P  —  Command Palette  |  Ctrl+J  —  Terminal"
            font.pointSize: 10; color: root.dimColor
        }
    }

    component WelcomeButton: Rectangle {
        property string label: ""; property string shortcut: ""
        signal clicked()

        width: 140; height: 80; radius: 8
        color: buttonMouse.containsMouse ? (root.theme.hover || "#3A3D41") : (root.theme.inputBg || "#2D2D30")
        border.color: root.theme.border || "#3E3E42"
        border.width: 1

        Column {
            anchors.centerIn: parent; spacing: 4
            Text { text: label; color: root.textColor; font.pointSize: 12; font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: shortcut; color: root.dimColor; font.pointSize: 10
                anchors.horizontalCenter: parent.horizontalCenter }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
