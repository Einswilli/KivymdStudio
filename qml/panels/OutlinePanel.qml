import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var symbols: []
    property string filterText: ""

    signal symbolActivated(var symbol)
    signal refreshRequested()

    color: theme.sidebar || theme.panel || "#1E1E1E"

    function iconFor(kind) {
        var value = String(kind || "").toLowerCase()
        if (value === "class" || value === "struct" || value === "trait" || value === "interface") return "code"
        if (value === "function" || value === "method") return "syntax"
        if (value === "module") return "folder"
        return "code"
    }

    function rows() {
        var query = filterText.toLowerCase()
        if (!query) return symbols || []
        var out = []
        for (var i = 0; i < symbols.length; i++) {
            var item = symbols[i] || ({})
            var haystack = String(item.name || "") + " " + String(item.kind || "")
            if (haystack.toLowerCase().indexOf(query) >= 0)
                out.push(item)
        }
        return out
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            Layout.leftMargin: 10
            Layout.rightMargin: 8
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Outline"
                color: root.theme.textStrong || "#F3F4F6"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 10
                font.weight: Font.DemiBold
            }

            UiIconButton {
                theme: root.theme
                iconName: "refresh"
                iconSize: 13
                tooltip: "Refresh outline"
                onClicked: root.refreshRequested()
            }
        }

        TextField {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            text: root.filterText
            placeholderText: "Filter symbols..."
            color: root.theme.text || "#D4D4D4"
            placeholderTextColor: root.theme.textDim || "#858585"
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 9
            selectByMouse: true
            onTextChanged: root.filterText = text
            background: Rectangle {
                radius: DesignTokens.metrics.radiusSm
                color: root.theme.inputBg || "#2A2A2A"
                border.width: 1
                border.color: parent.activeFocus ? (root.theme.accent || "#007ACC") : (root.theme.border || "#3E3E42")
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            clip: true
            model: root.rows()
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property int index
                required property var modelData

                width: list.width
                height: 36
                color: symMouse.containsMouse ? (root.theme.hover || "#2A2D34") : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Icon {
                        icon: root.iconFor(modelData.kind)
                        size: 15
                        color: root.theme.accent || "#61AFEF"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.name || "symbol"
                        color: root.theme.text || "#D4D4D4"
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 9
                        elide: Text.ElideRight
                    }
                    Text {
                        text: String(modelData.kind || "")
                        color: root.theme.textDim || "#858585"
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 8
                    }
                }

                MouseArea {
                    id: symMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.symbolActivated(modelData)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.rows().length === 0
                text: "No symbols."
                color: root.theme.textDim || "#858585"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 10
            }
        }
    }
}
