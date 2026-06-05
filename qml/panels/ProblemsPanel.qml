import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var problems: []
    property bool showErrors: true
    property bool showWarnings: true
    property bool showInfo: true
    property string selectedProblemKey: ""
    readonly property color accentColor: theme.accent || "#61AFEF"

    signal clearRequested()
    signal copyRequested(string text)
    signal problemActivated(var problem)
    signal problemRevealRequested(var problem)
    signal quickFixRequested(var problem)

    color: theme.panel || "#1E1E1E"

    function severityColor(severity) {
        var value = String(severity || "info").toLowerCase()
        if (value === "error") return theme.error || "#E06C75"
        if (value === "warning") return theme.warning || "#D19A66"
        if (value === "hint") return theme.textDim || "#858585"
        return theme.info || "#61AFEF"
    }

    function problemText(item) {
        if (!item) return ""
        return (item.severity || "info").toUpperCase()
            + " · line " + (item.line || 1) + ":" + ((item.col || 0) + 1)
            + (item.code ? " · " + item.code : "")
            + " — " + (item.message || "")
    }

    function problemKey(item) {
        if (!item) return ""
        return [item.path || "", item.line || 1, item.col || 0, item.message || ""].join("|")
    }

    function allText() {
        var rows = []
        var items = root.filteredProblems()
        for (var index = 0; index < items.length; index++)
            rows.push(problemText(items[index]))
        return rows.join("\n")
    }

    function filteredProblems() {
        var rows = []
        for (var index = 0; index < root.problems.length; index++) {
            var item = root.problems[index] || ({})
            var severity = String(item.severity || "info").toLowerCase()
            if (severity === "error" && !root.showErrors) continue
            if (severity === "warning" && !root.showWarnings) continue
            if (severity !== "error" && severity !== "warning" && !root.showInfo) continue
            rows.push(item)
        }
        return rows
    }

    function severityCount(severity) {
        var count = 0
        for (var index = 0; index < root.problems.length; index++) {
            if (String((root.problems[index] || {}).severity || "info").toLowerCase() === severity)
                count++
        }
        return count
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            color: theme.panelHeader || theme.panel || "#252526"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Icon { icon: "warning"; color: root.problems.length > 0 ? root.severityColor("warning") : (theme.textDim || "#858585"); size: 15 }
                Text {
                    text: root.problems.length + " problem" + (root.problems.length === 1 ? "" : "s")
                    color: theme.text || "#CCCCCC"
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 11
                    font.weight: Font.DemiBold
                }
                ProblemFilterButton {
                    theme: root.theme
                    label: "Errors"
                    count: root.severityCount("error")
                    checked: root.showErrors
                    colorValue: root.severityColor("error")
                    onClicked: root.showErrors = !root.showErrors
                }
                ProblemFilterButton {
                    theme: root.theme
                    label: "Warnings"
                    count: root.severityCount("warning")
                    checked: root.showWarnings
                    colorValue: root.severityColor("warning")
                    onClicked: root.showWarnings = !root.showWarnings
                }
                ProblemFilterButton {
                    theme: root.theme
                    label: "Info"
                    count: root.problems.length - root.severityCount("error") - root.severityCount("warning")
                    checked: root.showInfo
                    colorValue: root.severityColor("info")
                    onClicked: root.showInfo = !root.showInfo
                }
                Item { Layout.fillWidth: true }
                UiIconButton {
                    theme: root.theme
                    iconName: "copy"
                    iconSize: 13
                    tooltip: "Copy Problems"
                    enabled: root.problems.length > 0
                    iconColor: enabled ? (theme.textDim || "#858585") : (theme.disabled || "#555555")
                    onClicked: root.copyRequested(root.allText())
                }
                UiIconButton {
                    theme: root.theme
                    iconName: "delete"
                    iconSize: 13
                    tooltip: "Clear Problems"
                    enabled: root.problems.length > 0
                    iconColor: enabled ? (theme.textDim || "#858585") : (theme.disabled || "#555555")
                    onClicked: root.clearRequested()
                }
            }
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filteredProblems()
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property int index
                required property var modelData

                width: listView.width
                height: Math.max(72, messageText.implicitHeight + actionRow.implicitHeight + 22)
                readonly property bool selected: root.problemKey(modelData) === root.selectedProblemKey
                color: selected
                    ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.13)
                    : hoverHandler.hovered
                    ? (theme.hover || "#2A2D2E")
                    : (index % 2 === 0 ? (theme.panel || "#1E1E1E") : (theme.inputBg || theme.panel || "#242424"))
                border.width: selected ? 1 : 0
                border.color: root.accentColor

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    color: root.severityColor(modelData.severity)
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 7
                    anchors.bottomMargin: 7
                    spacing: 2

                    Text {
                        text: (modelData.severity || "info").toUpperCase()
                            + " · line " + (modelData.line || 1) + ":" + ((modelData.col || 0) + 1)
                            + (modelData.code ? " · " + modelData.code : "")
                        color: root.severityColor(modelData.severity)
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 10
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }

                    Text {
                        id: messageText
                        text: modelData.message || ""
                        color: theme.text || "#CCCCCC"
                        wrapMode: Text.Wrap
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pointSize: 11
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        id: actionRow
                        z: 2
                        Layout.fillWidth: true
                        spacing: 6

                        ProblemActionButton {
                            theme: root.theme
                            text: "Open"
                            onClicked: {
                                root.selectedProblemKey = root.problemKey(modelData)
                                root.problemActivated(modelData)
                            }
                        }

                        ProblemActionButton {
                            theme: root.theme
                            text: "Reveal"
                            onClicked: {
                                root.selectedProblemKey = root.problemKey(modelData)
                                root.problemRevealRequested(modelData)
                            }
                        }

                        ProblemActionButton {
                            theme: root.theme
                            text: "Copy"
                            onClicked: {
                                root.selectedProblemKey = root.problemKey(modelData)
                                root.copyRequested(root.problemText(modelData))
                            }
                        }

                        ProblemActionButton {
                            theme: root.theme
                            text: "Quick Fix"
                            onClicked: {
                                root.selectedProblemKey = root.problemKey(modelData)
                                root.quickFixRequested(modelData)
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                HoverHandler {
                    id: hoverHandler
                    cursorShape: Qt.PointingHandCursor
                }

            }

            Text {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: root.problems.length === 0 ? "No problems detected." : "No problems match the current filters."
                color: theme.textDim || "#858585"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 11
            }
        }
    }

    component ProblemFilterButton: Rectangle {
        id: filter

        property var theme: root.theme
        property string label: ""
        property int count: 0
        property bool checked: true
        property color colorValue: theme.info || "#61AFEF"

        signal clicked()

        Layout.preferredHeight: 22
        Layout.preferredWidth: Math.max(54, filterText.implicitWidth + 18)
        radius: 11
        color: checked ? Qt.rgba(colorValue.r, colorValue.g, colorValue.b, 0.14) : "transparent"
        border.width: 1
        border.color: checked ? colorValue : (theme.border || "#3E3E42")

        Text {
            id: filterText
            anchors.centerIn: parent
            text: filter.label + " " + filter.count
            color: filter.checked ? (theme.textStrong || "#FFFFFF") : (theme.textDim || "#858585")
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 9
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: filter.clicked()
        }
    }

    component ProblemActionButton: Rectangle {
        id: actionButton

        property var theme: root.theme
        property string text: ""
        signal clicked()

        Layout.preferredHeight: 22
        Layout.preferredWidth: Math.max(58, label.implicitWidth + 16)
        radius: 11
        color: actionMouse.containsMouse ? (theme.hover || "#374151") : (theme.inputBg || "#252526")
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
            acceptedButtons: Qt.LeftButton
            onClicked: function(mouse) {
                mouse.accepted = true
                actionButton.clicked()
            }
        }
    }
}
