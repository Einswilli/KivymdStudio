import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var entries: []
    property string title: "Output"
    property string emptyText: "No output yet."
    property string filterText: ""
    property string selectedSource: "All"

    signal clearRequested()
    signal copyRequested(string text)

    color: theme.panel || "#1E1E1E"

    function entryText(item) {
        if (!item) return ""
        return "[" + (item.time || "--:--:--") + "] [" + (item.source || "system") + "] " + (item.message || "")
    }

    function allText() {
        var rows = []
        var items = root.filteredEntries()
        for (var index = 0; index < items.length; index++)
            rows.push(entryText(items[index]))
        return rows.join("\n")
    }

    function sourceOptions() {
        var seen = { "All": true }
        var output = ["All"]
        for (var index = 0; index < root.entries.length; index++) {
            var source = String((root.entries[index] || {}).source || "system")
            if (!seen[source]) {
                seen[source] = true
                output.push(source)
            }
        }
        return output
    }

    function filteredEntries() {
        var rows = []
        var query = root.filterText.toLowerCase()
        for (var index = 0; index < root.entries.length; index++) {
            var item = root.entries[index] || ({})
            var source = String(item.source || "system")
            var message = String(item.message || "")
            if (root.selectedSource !== "All" && source !== root.selectedSource)
                continue
            if (query.length > 0 && (source + " " + message).toLowerCase().indexOf(query) < 0)
                continue
            rows.push(item)
        }
        return rows
    }

    function levelColor(level) {
        var value = String(level || "info").toLowerCase()
        if (value === "error") return theme.error || "#E06C75"
        if (value === "warning") return theme.warning || "#D19A66"
        if (value === "success") return theme.success || "#98C379"
        return theme.textDim || "#858585"
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
            title: root.title
            iconName: "syntax"
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
                id: sourceCombo
                Layout.preferredWidth: 150
                Layout.preferredHeight: 26
                model: root.sourceOptions()
                currentIndex: Math.max(0, root.sourceOptions().indexOf(root.selectedSource))
                onActivated: root.selectedSource = currentText
                contentItem: Text {
                    text: sourceCombo.displayText
                    color: theme.text || "#CCCCCC"
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
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
                placeholderText: "Filter output..."
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
                height: Math.max(30, outputText.implicitHeight + 12)
                color: index % 2 === 0 ? (theme.panel || "#1E1E1E") : (theme.inputBg || theme.panel || "#242424")

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
                        text: modelData.source || "system"
                        color: root.levelColor(modelData.level)
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 10
                        font.weight: Font.DemiBold
                    }

                    Text {
                        id: outputText
                        Layout.fillWidth: true
                        text: modelData.message || ""
                        color: theme.text || "#CCCCCC"
                        wrapMode: Text.Wrap
                        font.family: root.codeFontFamily((typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.fontFamily : "Menlo")
                        font.pointSize: 10
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: root.entries.length === 0 ? root.emptyText : "No output matches the current filters."
                color: theme.textDim || "#858585"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 11
            }
        }
    }
}
