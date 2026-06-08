import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var runningActions: []
    property var history: []
    property string filterText: ""

    signal clearRequested()
    signal copyRequested(string text)

    color: theme.panel || "#1E1E1E"

    function rows() {
        var output = []
        var query = filterText.toLowerCase()
        for (var r = 0; r < runningActions.length; r++) {
            var running = runningActions[r] || ({})
            output.push({
                "_kind": "running",
                "id": running.id || "",
                "title": running.title || "",
                "label": running.label || "",
                "message": running.label || "",
                "state": "running",
                "startedAt": running.startedAt || 0,
                "category": running.category || "",
                "source": running.source || ""
            })
        }
        for (var h = 0; h < history.length; h++) {
            var item = history[h] || ({})
            output.push({
                "_kind": "history",
                "id": item.id || "",
                "title": item.title || item.id || "",
                "label": "",
                "message": item.message || "",
                "state": item.state || "",
                "durationMs": item.durationMs || 0,
                "category": item.category || "",
                "source": item.source || "",
                "payload": item.payload || ({}),
                "permissions": item.permissions || [],
                "requiresPermission": item.requiresPermission || false,
                "exposable": item.exposable !== false
            })
        }
        if (query.length === 0)
            return output
        var filtered = []
        for (var i = 0; i < output.length; i++) {
            var row = output[i] || ({})
            var haystack = String(row.id || "") + " " + String(row.title || "") + " " + String(row.message || "") + " " + String(row.state || "") + " " + String(row.source || "") + " " + String(row.category || "")
            if (haystack.toLowerCase().indexOf(query) >= 0)
                filtered.push(row)
        }
        return filtered
    }

    function statusColor(row) {
        if ((row._kind || "") === "running") return theme.accent || "#61AFEF"
        if ((row.state || "") === "error") return theme.error || "#E06C75"
        if ((row.state || "") === "success") return theme.success || "#98C379"
        return theme.textDim || "#858585"
    }

    function allText() {
        var lines = []
        var items = rows()
        for (var i = 0; i < items.length; i++) {
            var row = items[i] || ({})
            lines.push("[" + (row.state || row._kind || "action") + "] " + (row.id || "") + " · " + (row.source || "core") + " · " + (row.message || row.label || ""))
        }
        return lines.join("\n")
    }

    function compactJson(value) {
        try {
            var text = JSON.stringify(value || {})
            return text === "{}" ? "" : text
        } catch (err) {
            return ""
        }
    }

    function metaText(row) {
        var parts = []
        if (row.source) parts.push(row.source)
        if (row.category) parts.push(row.category)
        if ((row._kind || "") === "running") parts.push("running")
        else parts.push(String(row.durationMs || 0) + "ms")
        if (row.permissions && row.permissions.length > 0)
            parts.push("permissions: " + row.permissions.join(", "))
        return parts.join(" · ")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelLogHeader {
            theme: root.theme
            title: "Actions"
            iconName: "bolt"
            count: root.rows().length
            onCopyRequested: root.copyRequested(root.allText())
            onClearRequested: root.clearRequested()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 8

            TextField {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                text: root.filterText
                placeholderText: "Filter actions..."
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
            model: root.rows()
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property int index
                required property var modelData

                width: listView.width
                height: Math.max(48, body.implicitHeight + 14)
                color: index % 2 === 0 ? (theme.panel || "#1E1E1E") : (theme.inputBg || theme.panel || "#242424")

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: root.statusColor(modelData)
                }

                RowLayout {
                    id: body
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    BusyIndicator {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        running: (modelData._kind || "") === "running"
                        visible: running
                    }

                    Icon {
                        visible: (modelData._kind || "") !== "running"
                        icon: (modelData.state || "") === "error" ? "error" : "check-circle"
                        color: root.statusColor(modelData)
                        size: 15
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title || modelData.id || "action"
                            color: theme.textStrong || theme.text || "#E5E7EB"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.metaText(modelData)
                            color: theme.textMuted || theme.textDim || "#858585"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 8
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.message || modelData.label || ""
                            color: theme.textDim || "#858585"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 9
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: root.compactJson(modelData.payload)
                            color: theme.textMuted || theme.textDim || "#858585"
                            font.family: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.editorFontFamily : "Menlo"
                            font.pointSize: 8
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: (modelData._kind || "") === "running"
                              ? "running"
                              : String(modelData.durationMs || 0) + "ms"
                        color: root.statusColor(modelData)
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 9
                    }
                }
            }
        }
    }
}
