import QtQuick 2.15

Rectangle {

    property alias model: completionsHint.model

    color: "#333333"
    radius: 5
    border {
        width: 1
        color: "#333333"
    }

    //anchors.top: inputField.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 10

    ListView {

        anchors.fill: parent
        anchors.margins: 5
        clip: true
        spacing: 4

        id: completionsHint
        delegate: PreviewDelegate {
            text: model.name
        }
    }
}
