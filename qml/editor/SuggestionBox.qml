import QtQuick 2.15
import QtQuick.Controls 2.15

Popup {
    id: root

    property var items: []
    property string filterText: ""
    property var editor: null
    property var theme: ({})
    property var tokenColors: ({})
    property bool detailsVisible: false
    property font editorFont: Qt.font({
        family: root.fontFamily((typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.fontFamily : "Menlo"),
        pointSize: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.fontSize : 12
    })
    readonly property var selectedItem: listView.currentIndex >= 0 && listView.currentIndex < root.items.length
                                       ? root.items[listView.currentIndex]
                                       : null

    signal itemSelected(var item)

    function fontFamily(value) {
        var family = String(value || "Menlo").split(",")[0].trim()
        if (family.toLowerCase() === "monospace")
            return "Menlo"
        return family.length > 0 ? family : "Menlo"
    }

    width: 380
    height: opened ? Math.min(280, Math.max(42, listView.contentHeight + 10)) : 0
    padding: 0
    closePolicy: Popup.CloseOnEscape
    modal: false
    opacity: opened ? 1 : 0
    scale: opened ? 1 : 0.98

    background: Rectangle {
        color: root.theme.panel || "#202126"
        border.color: root.theme.border || "#3A3D46"
        border.width: 1
        radius: 10
    }

    Behavior on height {
        SpringAnimation { spring: 2.2; damping: 0.28; epsilon: 0.2 }
    }
    Behavior on opacity { NumberAnimation { duration: 90 } }
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    contentItem: Item {
        implicitHeight: root.height
        clip: true

        ListView {
            id: listView
            anchors.fill: parent
            anchors.margins: 5
            model: root.items
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 95
            highlightResizeDuration: 95
            highlight: Rectangle {
                color: root.theme.hover || "#2D3440"
                radius: 7
                border.color: root.theme.accent || "#3B82F6"
                border.width: 1
            }
            currentIndex: 0
            clip: true
            onCurrentIndexChanged: {
                if (root.detailsVisible && root.opened)
                    detailsPopup.open()
            }

            delegate: Item {
                id: del
                width: listView.width
                height: 34

                property bool isCurrent: ListView.isCurrentItem

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: del.isCurrent ? (root.theme.hover || "#2D3440") : (ma.containsMouse ? (root.theme.hover || "#272B33") : "transparent")
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Item {
                        width: 20; height: parent.height
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            anchors.centerIn: parent
                            color: _typeColor(modelData.type || "default")
                        }
                    }

                    Text {
                        text: modelData.name || modelData.text || ""
                        color: del.isCurrent ? (root.theme.textStrong || "#FFFFFF") : (root.theme.text || "#D4D4D4")
                        font.family: root.editorFont.family
                        font.pointSize: Math.max(10, root.editorFont.pointSize - 1)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 154
                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.type || ""
                        color: _typeColor(modelData.type || "default")
                        font.pointSize: 10
                        font.italic: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: modelData.detail || modelData.description || ""
                        color: root.theme.textDim || "#808080"
                        font.pointSize: 9
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: 64
                    }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        listView.currentIndex = index
                        root.acceptSelected()
                    }
                }
            }
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 90 }
        NumberAnimation { property: "y"; from: root.y + 8; to: root.y; duration: 110; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.98; to: 1; duration: 110; easing.type: Easing.OutCubic }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 }
    }

    function acceptSelected() {
        if (listView.currentIndex >= 0 && listView.currentIndex < root.items.length) {
            root.itemSelected(root.items[listView.currentIndex])
        }
    }

    function selectNext() {
        if (listView.currentIndex < listView.count - 1)
            listView.currentIndex++
        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
    }

    function selectPrevious() {
        if (listView.currentIndex > 0)
            listView.currentIndex--
        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
    }

    function toggleDetails() {
        root.detailsVisible = !root.detailsVisible
        if (root.detailsVisible && root.selectedItem)
            detailsPopup.open()
        else
            detailsPopup.close()
    }

    function updateFromJson(jsonStr) {
        try {
            var parsed = JSON.parse(jsonStr)
            root.items = Array.isArray(parsed) ? parsed : []
            listView.currentIndex = 0
        } catch(e) {
            root.items = []
        }
        if (root.items.length > 0) {
            root.open()
            if (root.detailsVisible) detailsPopup.open()
        } else {
            root.close()
            detailsPopup.close()
        }
    }

    function _detailsText(item) {
        if (!item) return ""
        return item.documentation || item.doc || item.detail || item.description || item.labelDetails || "Aucun détail disponible pour cette suggestion."
    }

    function _typeColor(type) {
        var m = {
            "class": root.tokenColors["class"] || "#E5C07B", "function": root.tokenColors["function"] || "#61AFEF", "method": root.tokenColors["function"] || "#61AFEF",
            "keyword": root.tokenColors["keyword"] || "#C678DD", "module": root.tokenColors["module"] || "#56B6C2", "instance": root.tokenColors["class"] || "#E5C07B",
            "statement": root.tokenColors["keyword"] || "#C678DD", "param": root.tokenColors["parameter"] || "#E06C75", "path": root.tokenColors["module"] || "#56B6C2",
            "property": root.tokenColors["property"] || "#ABB2BF", "variable": root.tokenColors["variable"] || "#E06C75", "constant": root.tokenColors["number"] || "#D19A66",
            "string": root.tokenColors["string"] || "#98C379", "number": root.tokenColors["number"] || "#D19A66", "decorator": root.tokenColors["decorator"] || "#61AFEF",
            "default": root.tokenColors["default"] || "#ABB2BF"
        }
        return m[type] || m["default"]
    }

    onClosed: detailsPopup.close()

    Popup {
        id: detailsPopup
        x: root.width + 8
        y: 0
        width: 360
        height: Math.min(260, detailsColumn.implicitHeight + 22)
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        visible: root.opened && root.detailsVisible && root.selectedItem !== null
        background: Rectangle {
            color: root.theme.panel || "#1F232A"
            border.color: root.theme.border || "#3A3D46"
            border.width: 1
            radius: 10
        }

        Column {
            id: detailsColumn
            anchors.fill: parent
            anchors.margins: 11
            spacing: 8

            Row {
                width: parent.width
                spacing: 8
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root._typeColor(root.selectedItem ? (root.selectedItem.type || "default") : "default")
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    width: parent.width - 16
                    text: root.selectedItem ? (root.selectedItem.name || root.selectedItem.text || "Suggestion") : ""
                    color: root.theme.textStrong || "#F9FAFB"
                    font.family: root.editorFont.family
                    font.bold: true
                    font.pointSize: 11
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                text: root.selectedItem ? (root.selectedItem.type || "symbol") : ""
                color: root.theme.textDim || "#9CA3AF"
                font.pointSize: 9
            }

            Rectangle { width: parent.width; height: 1; color: root.theme.border || "#303744" }

            Text {
                width: parent.width
                text: root._detailsText(root.selectedItem)
                color: root.theme.text || "#D4D4D4"
                font.pointSize: 10
                // textFormat: TextEdit.RichText
                // readOnly: true
                wrapMode: Text.WordWrap
                maximumLineCount: 10
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: "↑/↓ navigate · Space details · Enter insert"
                color: root.theme.textDim || "#6B7280"
                font.pointSize: 8
            }
        }
    }
}
