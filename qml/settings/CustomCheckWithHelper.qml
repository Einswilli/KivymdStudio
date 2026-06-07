import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property string helper: "Helper text"
    property alias selected: check.checked
    property color activeColor: "#EEEFFF"

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Row {
            anchors.fill: parent
            spacing: 20

            Rectangle {
                width: parent.width * 0.25 - 10
                height: parent.height
                color: "transparent"

                CheckBox {
                    id: check
                    height: 20
                    width: parent.width - 25
                    checked: true
                    anchors.verticalCenter: parent.verticalCenter
                    indicator: Row {
                        height: parent.height
                        spacing: 8
                        width: (parent.width / 3) - 5
                        Rectangle {
                            height: 25
                            width: 25
                            radius: 5
                            color: "#2E2F30"
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "✓"
                                color: root.activeColor
                                font.pointSize: 14
                                anchors.centerIn: parent
                                visible: check.checked
                            }
                        }
                        Text {
                            text: check.checked ? "YES" : "NO"
                            font.pointSize: 12
                            color: "#DDDDDD"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width * 0.25 - 10
                height: parent.height
                color: "transparent"
                Text {
                    text: helper
                    font.pointSize: 10
                    color: "#AAAAAA"
                    wrapMode: Text.WordWrap
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                }
            }
        }
    }
}
