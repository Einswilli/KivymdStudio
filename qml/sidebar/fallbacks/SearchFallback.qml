import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var panel: ({})
    readonly property color accentColor: theme.accent || "#61AFEF"
    readonly property color borderColor: theme.border || "#3E3E42"
    signal openFileRequested(string path)
    signal revealFileRequested(string path)

    color: theme.sidebar || "#252526"

    function triggerSearch() {
        if (typeof SearchVM === "undefined" || !SearchVM)
            return
        if (typeof ActionVM !== "undefined" && ActionVM)
            ActionVM.runAction("search.run", {"query": searchInput.text})
        else
            SearchVM.search(searchInput.text)
    }

    function relativeLabel(result) {
        return result.relativePath || result.path || result.name || ""
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Search"
                color: theme.textStrong || theme.text || "#E5E7EB"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 12
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            ToolButton {
                text: "↻"
                implicitWidth: 26
                implicitHeight: 26
                enabled: typeof SearchVM !== "undefined" && SearchVM && SearchVM.query.length > 0
                opacity: typeof ActionVM !== "undefined" && ActionVM && ActionVM.isRunning("search.run") ? 0.55 : 1
                onClicked: root.triggerSearch()
                ToolTip.visible: hovered
                ToolTip.text: "Refresh search"
            }

            ToolButton {
                text: "×"
                implicitWidth: 26
                implicitHeight: 26
                enabled: typeof SearchVM !== "undefined" && SearchVM
                onClicked: {
                    if (typeof ActionVM !== "undefined" && ActionVM)
                        ActionVM.runAction("search.clear")
                    else if (SearchVM)
                        SearchVM.clear()
                }
                ToolTip.visible: hovered
                ToolTip.text: "Clear results"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: DesignTokens.metrics.radiusSm
            color: theme.inputBg || "#2A2A2A"
            border.width: 1
            border.color: searchInput.activeFocus ? (theme.accent || "#007ACC") : (theme.inputBorder || theme.border || "#3E3E42")

            TextField {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter
                placeholderText: "Search in workspace"
                color: theme.text || "#CCCCCC"
                placeholderTextColor: theme.textDim || "#858585"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 11
                background: Rectangle { color: "transparent" }
                onAccepted: root.triggerSearch()
                onTextChanged: {
                    searchDelay.restart()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ToggleChip {
                label: "Aa"
                checked: typeof SearchVM !== "undefined" && SearchVM ? SearchVM.caseSensitive : false
                tooltip: "Match case"
                onClicked: if (SearchVM) SearchVM.setCaseSensitive(!SearchVM.caseSensitive)
            }

            ToggleChip {
                label: ".*"
                checked: typeof SearchVM !== "undefined" && SearchVM ? SearchVM.regex : false
                tooltip: "Use regex"
                onClicked: if (SearchVM) SearchVM.setRegex(!SearchVM.regex)
            }

            ToggleChip {
                label: "Hidden"
                checked: typeof SearchVM !== "undefined" && SearchVM ? SearchVM.includeHidden : false
                tooltip: "Include hidden files"
                onClicked: if (SearchVM) SearchVM.setIncludeHidden(!SearchVM.includeHidden)
            }

            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            text: typeof SearchVM !== "undefined" && SearchVM ? SearchVM.message : "Open a folder to search"
            color: theme.textDim || "#858585"
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 10
            elide: Text.ElideRight
        }

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: typeof SearchVM !== "undefined" && SearchVM ? SearchVM.loading : false
            visible: running
        }

        ListView {
            id: resultsView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: typeof SearchVM !== "undefined" && SearchVM ? SearchVM.results : []

            delegate: Rectangle {
                id: itemRoot
                required property var modelData
                width: resultsView.width
                height: Math.max(76, resultColumn.implicitHeight + 18)
                radius: DesignTokens.metrics.radiusMd
                color: resultMouse.containsMouse ? (theme.hover || "#2D333B") : Qt.rgba(1, 1, 1, 0.02)
                border.width: 1
                border.color: resultMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.38)
                                                      : Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, 0.55)

                ColumnLayout {
                    id: resultColumn
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Icon {
                            icon: "file"
                            color: theme.textDim || "#9CA3AF"
                            size: 14
                        }

                        Text {
                            text: root.relativeLabel(modelData)
                            color: theme.textStrong || theme.text || "#E5E7EB"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        Text {
                            text: (modelData.line || 1) + ":" + (modelData.column || 1)
                            color: theme.textDim || "#9CA3AF"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 9
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.RichText
                        text: "<span style='color:" + (theme.textDim || "#9CA3AF") + "'>" +
                              String(modelData.previewBefore || "").replace(/&/g, "&amp;").replace(/</g, "&lt;") +
                              "</span><span style='color:" + root.accentColor + "; font-weight:600;'>" +
                              String(modelData.previewMatch || "").replace(/&/g, "&amp;").replace(/</g, "&lt;") +
                              "</span><span style='color:" + (theme.textDim || "#9CA3AF") + "'>" +
                              String(modelData.previewAfter || "").replace(/&/g, "&amp;").replace(/</g, "&lt;") +
                              "</span>"
                        font.family: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.fontFamily : "Menlo"
                        font.pointSize: 9
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ResultActionButton {
                            text: "Open"
                            onClicked: root.openFileRequested(modelData.path || "")
                        }

                        ResultActionButton {
                            text: "Copy path"
                            onClicked: {
                                if (typeof ActionVM !== "undefined" && ActionVM)
                                    ActionVM.runAction("search.copy_path", {"path": modelData.path || ""})
                                else if (SearchVM)
                                    SearchVM.copyPath(modelData.path || "")
                            }
                        }

                        ResultActionButton {
                            text: "Reveal"
                            onClicked: {
                                root.revealFileRequested(modelData.path || "")
                                if (typeof ActionVM !== "undefined" && ActionVM)
                                    ActionVM.runAction("search.result_action", {"result": modelData})
                                else if (SearchVM)
                                    SearchVM.emitResultAction(modelData)
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                MouseArea {
                    id: resultMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onDoubleClicked: root.openFileRequested(modelData.path || "")
                    z: -1
                }
            }
        }
    }

    Timer {
        id: searchDelay
        interval: 280
        repeat: false
        onTriggered: {
            if (searchInput.text.trim().length >= 2)
                root.triggerSearch()
            else if (typeof ActionVM !== "undefined" && ActionVM)
                ActionVM.runAction("search.clear")
            else if (SearchVM)
                SearchVM.clear()
        }
    }

    component ToggleChip: Rectangle {
        id: chip
        property string label: ""
        property bool checked: false
        property string tooltip: ""
        signal clicked()

        Layout.preferredHeight: 24
        Layout.preferredWidth: Math.max(36, chipText.implicitWidth + 18)
        radius: 12
        color: checked ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                       : (theme.inputBg || "#2A2A2A")
        border.width: 1
        border.color: checked ? root.accentColor : root.borderColor

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: checked ? (theme.textStrong || "#FFFFFF") : (theme.textDim || "#9CA3AF")
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 9
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
            ToolTip.visible: containsMouse && chip.tooltip.length > 0
            ToolTip.text: chip.tooltip
        }
    }

    component ResultActionButton: Rectangle {
        id: actionButton
        property string text: ""
        signal clicked()

        Layout.preferredHeight: 22
        Layout.preferredWidth: Math.max(58, label.implicitWidth + 16)
        radius: 11
        color: actionMouse.containsMouse ? (theme.hover || "#374151") : (theme.inputBg || "#2A2A2A")
        border.width: 1
        border.color: theme.border || "#3E3E42"

        Text {
            id: label
            anchors.centerIn: parent
            text: actionButton.text
            color: theme.text || "#D1D5DB"
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 9
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.clicked()
        }
    }
}
