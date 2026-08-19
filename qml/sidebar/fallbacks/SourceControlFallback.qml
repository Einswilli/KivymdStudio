import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var panel: ({})

    signal openFileRequested(string path)

    color: theme.sidebar || "#252526"

    function sectionLabel(section) {
        if (section === "staged") return "Staged"
        if (section === "unstaged") return "Changes"
        if (section === "untracked") return "Untracked"
        if (section === "conflicts") return "Conflicts"
        return "Changes"
    }

    function sectionCount(section) {
        if (!SourceControlVM) return 0
        var count = 0
        for (var i = 0; i < SourceControlVM.files.length; i++) {
            if (SourceControlVM.files[i].section === section)
                count++
        }
        return count
    }

    function statusColor(item) {
        if (!item) return theme.textDim || "#858585"
        if (item.section === "conflicts") return theme.error || "#F85149"
        if (item.section === "untracked") return theme.success || "#3FB950"
        if (item.section === "staged") return theme.accent || "#58A6FF"
        return theme.warning || "#D29922"
    }

    Component.onCompleted: if (SourceControlVM) SourceControlVM.refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon { icon: "git-branch"; size: 16; color: theme.accent || "#58A6FF" }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: "Source Control"
                    color: theme.text || "#CCCCCC"
                    elide: Text.ElideRight
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 12
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: SourceControlVM && SourceControlVM.branch ? SourceControlVM.branch : "No repository"
                    color: theme.textDim || "#858585"
                    elide: Text.ElideRight
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 10
                }
            }

            ToolButton {
                implicitWidth: 28
                implicitHeight: 28
                enabled: !!SourceControlVM && !SourceControlVM.loading
                onClicked: SourceControlVM.refresh()
                background: Rectangle {
                    radius: 6
                    color: parent.hovered ? (theme.hover || "#30363D") : "transparent"
                }
                contentItem: Icon {
                    icon: SourceControlVM && SourceControlVM.loading ? "sync" : "refresh"
                    size: 15
                    color: theme.text || "#CCCCCC"
                }
                ToolTip.visible: hovered
                ToolTip.text: "Refresh"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 8
            color: theme.panel || "#1F2428"
            border.width: 1
            border.color: theme.border || "#30363D"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: SourceControlVM ? SourceControlVM.message : "Unavailable"
                    color: theme.textDim || "#858585"
                    elide: Text.ElideRight
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 10
                }
                Text {
                    visible: SourceControlVM && (SourceControlVM.ahead > 0 || SourceControlVM.behind > 0)
                    text: "↑" + SourceControlVM.ahead + " ↓" + SourceControlVM.behind
                    color: theme.text || "#CCCCCC"
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 10
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: 12

                Repeater {
                    model: ["conflicts", "staged", "unstaged", "untracked"]
                    delegate: ColumnLayout {
                        id: sectionRoot
                        required property string modelData
                        property string sectionName: modelData
                        Layout.fillWidth: true
                        spacing: 5
                        visible: root.sectionCount(modelData) > 0

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: root.sectionLabel(modelData).toUpperCase()
                                color: theme.textDim || "#858585"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pointSize: 9
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: root.sectionCount(modelData)
                                color: theme.textMuted || theme.textDim || "#858585"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pointSize: 9
                            }
                        }

                        Repeater {
                            model: SourceControlVM ? SourceControlVM.files : []
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: visible ? 42 : 0
                                visible: modelData.section === sectionRoot.sectionName
                                radius: 8
                                color: fileMouse.containsMouse ? (theme.hover || "#30363D") : "transparent"
                                border.width: fileMouse.containsMouse ? 1 : 0
                                border.color: theme.border || "#30363D"

                                MouseArea {
                                    id: fileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.openFileRequested(modelData.absolutePath || modelData.path)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 9
                                    anchors.rightMargin: 6
                                    spacing: 8

                                    Text {
                                        text: modelData.section === "staged" ? "S"
                                            : modelData.section === "untracked" ? "U"
                                            : modelData.section === "conflicts" ? "!"
                                            : "M"
                                        color: root.statusColor(modelData)
                                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                        font.pointSize: 10
                                        font.weight: Font.Bold
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name || modelData.path
                                            color: theme.text || "#CCCCCC"
                                            elide: Text.ElideRight
                                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                            font.pointSize: 10
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.path || ""
                                            color: theme.textDim || "#858585"
                                            elide: Text.ElideLeft
                                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                            font.pointSize: 9
                                        }
                                    }

                                    RowLayout {
                                        spacing: 1
                                        visible: fileMouse.containsMouse
                                        ToolButton {
                                            implicitWidth: 24; implicitHeight: 24
                                            onClicked: SourceControlVM.showDiff(modelData.path, modelData.section === "staged")
                                            background: Rectangle { radius: 5; color: parent.hovered ? (theme.active || "#39414A") : "transparent" }
                                            contentItem: Icon { icon: "syntax"; size: 13; color: theme.text || "#CCCCCC" }
                                            ToolTip.visible: hovered
                                            ToolTip.text: "Preview diff"
                                        }
                                        ToolButton {
                                            implicitWidth: 24; implicitHeight: 24
                                            onClicked: modelData.section === "staged" ? SourceControlVM.unstage(modelData.path) : SourceControlVM.stage(modelData.path)
                                            background: Rectangle { radius: 5; color: parent.hovered ? (theme.active || "#39414A") : "transparent" }
                                            contentItem: Icon { icon: modelData.section === "staged" ? "close" : "plus"; size: 13; color: theme.text || "#CCCCCC" }
                                            ToolTip.visible: hovered
                                            ToolTip.text: modelData.section === "staged" ? "Unstage" : "Stage"
                                        }
                                        ToolButton {
                                            implicitWidth: 24; implicitHeight: 24
                                            visible: modelData.section !== "staged" && modelData.section !== "untracked"
                                            onClicked: SourceControlVM.discard(modelData.path)
                                            background: Rectangle { radius: 5; color: parent.hovered ? (theme.active || "#39414A") : "transparent" }
                                            contentItem: Icon { icon: "close"; size: 13; color: theme.error || "#F85149" }
                                            ToolTip.visible: hovered
                                            ToolTip.text: "Discard"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 160
                    visible: SourceControlVM && SourceControlVM.changedCount === 0
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 8
                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "git-branch"
                            size: 26
                            color: theme.textDim || "#858585"
                            opacity: 0.65
                        }
                        Text {
                            Layout.fillWidth: true
                            text: SourceControlVM && SourceControlVM.root ? "Working tree clean" : "Open a Git repository folder"
                            color: theme.textDim || "#858585"
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 11
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: SourceControlVM
        function onDiffChanged() {
            if (!SourceControlVM)
                return
            if (SourceControlVM.diffPath || SourceControlVM.diffText || SourceControlVM.diffError || SourceControlVM.diffLoading)
                diffPopup.open()
        }
    }

    Popup {
        id: diffPopup
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.max(300, root.width - 24)
        height: Math.min(root.height - 32, 520)
        x: Math.max(8, (root.width - width) / 2)
        y: 16
        padding: 0
        background: Rectangle {
            radius: 12
            color: theme.popup || theme.panel || "#1F2428"
            border.width: 1
            border.color: theme.border || "#30363D"
        }
        onClosed: if (SourceControlVM) SourceControlVM.clearDiff()

        contentItem: ColumnLayout {
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Icon {
                        icon: "syntax"
                        size: 16
                        color: theme.accent || "#58A6FF"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: SourceControlVM ? SourceControlVM.diffTitle : "Diff Preview"
                            color: theme.text || "#CCCCCC"
                            elide: Text.ElideRight
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 11
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: SourceControlVM ? SourceControlVM.diffPath : ""
                            color: theme.textDim || "#858585"
                            elide: Text.ElideLeft
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 9
                        }
                    }

                    ToolButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        onClicked: diffPopup.close()
                        background: Rectangle {
                            radius: 6
                            color: parent.hovered ? (theme.hover || "#30363D") : "transparent"
                        }
                        contentItem: Icon {
                            icon: "close"
                            size: 14
                            color: theme.text || "#CCCCCC"
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: "Close"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: theme.border || "#30363D"
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded

                TextArea {
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.NoWrap
                    text: SourceControlVM && SourceControlVM.diffLoading
                        ? "Loading diff…"
                        : SourceControlVM && SourceControlVM.diffError
                            ? SourceControlVM.diffError
                            : SourceControlVM ? SourceControlVM.diffText : ""
                    color: SourceControlVM && SourceControlVM.diffError ? (theme.error || "#F85149") : (theme.text || "#CCCCCC")
                    selectedTextColor: theme.selectionText || "#FFFFFF"
                    selectionColor: theme.selection || theme.accent || "#264F78"
                    font.family: (typeof SettingsVM !== "undefined" && SettingsVM) ? SettingsVM.editorFontFamily : "JetBrains Mono"
                    font.pointSize: 10
                    background: Rectangle {
                        color: theme.editorBackground || theme.background || "#0D1117"
                    }
                    leftPadding: 12
                    rightPadding: 12
                    topPadding: 10
                    bottomPadding: 10
                }
            }
        }
    }
}
