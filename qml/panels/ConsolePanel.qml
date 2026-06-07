import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var entries: []
    property string filterText: ""
    property string selectedLevel: "All"

    signal clearRequested()
    signal copyRequested(string text)

    color: theme.panel || "#1E1E1E"

    function levelColor(level) {
        var value = String(level || "info").toLowerCase()
        if (value === "error") return theme.error || "#E06C75"
        if (value === "warning") return theme.warning || "#D19A66"
        if (value === "success") return theme.success || "#98C379"
        return theme.info || theme.textDim || "#858585"
    }

    function entryText(item) {
        if (!item) return ""
        return "[" + (item.time || "--:--:--") + "] [" + (item.level || "info") + "] " + (item.message || "")
    }

    function allText() {
        var rows = []
        var items = root.filteredEntries()
        for (var index = 0; index < items.length; index++)
            rows.push(entryText(items[index]))
        return rows.join("\n")
    }

    function filteredEntries() {
        var rows = []
        var query = root.filterText.toLowerCase()
        for (var index = 0; index < root.entries.length; index++) {
            var item = root.entries[index] || ({})
            var level = String(item.level || "info").toLowerCase()
            var message = String(item.message || "")
            var source = String(item.source || "system")
            if (root.selectedLevel !== "All" && level !== root.selectedLevel.toLowerCase())
                continue
            if (query.length > 0 && (level + " " + source + " " + message).toLowerCase().indexOf(query) < 0)
                continue
            rows.push(item)
        }
        return rows
    }

    function codeFontFamily(value) {
        var family = String(value || "Menlo").split(",")[0].trim()
        if (family.toLowerCase() === "monospace")
            return "Menlo"
        return family.length > 0 ? family : "Menlo"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelLogHeader {
            theme: root.theme
            title: "Console"
            iconName: "chevron-right"
            count: root.filteredEntries().length
            onCopyRequested: root.copyRequested(root.allText())
            onClearRequested: root.clearRequested()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 8

            ComboBox {
                id: levelCombo
                Layout.preferredWidth: 130
                Layout.preferredHeight: 26
                model: ["All", "info", "success", "warning", "error"]
                currentIndex: Math.max(0, model.indexOf(root.selectedLevel))
                onActivated: root.selectedLevel = currentText
                contentItem: Text {
                    text: levelCombo.displayText
                    color: theme.text || "#CCCCCC"
                    verticalAlignment: Text.AlignVCenter
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 9
                }
                background: Rectangle {
                    radius: DesignTokens.metrics.radiusSm
                    color: theme.inputBg || "#2A2A2A"
                    border.width: 1
                    border.color: theme.border || "#3E3E42"
                }
            }

            TextField {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                text: root.filterText
                placeholderText: "Filter console..."
                color: theme.text || "#CCCCCC"
                placeholderTextColor: theme.textDim || "#858585"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 10
                selectByMouse: true
                onTextChanged: root.filterText = text
                background: Rectangle {
                    radius: DesignTokens.metrics.radiusSm
                    color: theme.inputBg || "#2A2A2A"
                    border.width: 1
                    border.color: parent.activeFocus ? (theme.accent || "#007ACC") : (theme.border || "#3E3E42")
                }
            }
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filteredEntries()
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property int index
                required property var modelData

                width: listView.width
                height: Math.max(30, consoleText.implicitHeight + 12)
                color: index % 2 === 0 ? (theme.panel || "#1E1E1E") : (theme.inputBg || theme.panel || "#242424")

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: root.levelColor(modelData.level)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: modelData.time || "--:--:--"
                        color: theme.textDim || "#858585"
                        font.family: root.codeFontFamily((typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.fontFamily : "Menlo")
                        font.pointSize: 10
                    }

                    Text {
                        text: modelData.level || "info"
                        color: root.levelColor(modelData.level)
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 10
                        font.weight: Font.DemiBold
                    }

                    Text {
                        id: consoleText
                        Layout.fillWidth: true
                        text: modelData.message || ""
                        color: root.levelColor(modelData.level)
                        wrapMode: Text.Wrap
                        font.family: root.codeFontFamily((typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.fontFamily : "Menlo")
                        font.pointSize: 10
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: root.entries.length === 0 ? "No console messages." : "No console messages match the current filters."
                color: theme.textDim || "#858585"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 11
            }
        }
    }
}
