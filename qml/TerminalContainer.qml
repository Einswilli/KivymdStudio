import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "#1E1E1E"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10

            Text {
                text: "Terminal"
                color: "#CCCCCC"
                font.pointSize: 12
                font.bold: true
            }
            Text {
                text: "Terminal panel — Qt6 migration in progress."
                color: "#888"
                font.pointSize: 10
            }
        }
    }
}
