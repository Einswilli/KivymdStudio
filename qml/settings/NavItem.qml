import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property bool active: false
    property string label: "My navItem"
    property color accentColor: "#EEEFFF"
    property string iconChar: ""
    property string icon: ""

    signal tapped()

    Rectangle {
        height: 30
        width: parent.width * 0.75
        color: active ? Qt.rgba(1,1,1,0.08) : "transparent"
        radius: 4
        anchors.centerIn: parent

        Row {
            spacing: 10
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: root.iconChar
                font.pointSize: 13
                color: root.active ? root.accentColor : "#AAAAAA"
                width: 20
                height: 20
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: root.label
                font.pointSize: 11
                color: root.active ? root.accentColor : "#AAAAAA"
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tapped()
        }
    }
}
