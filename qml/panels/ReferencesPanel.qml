import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var references: []
    property string currentPath: ""

    signal locationActivated(var location)
    signal copyRequested(string text)
    signal clearRequested()

    color: theme.panel || "#1E1E1E"

    function basename(path) {
        var value = String(path || "")
        var slash = Math.max(value.lastIndexOf("/"), value.lastIndexOf("\\"))
        return slash >= 0 ? value.substring(slash + 1) : value
    }

    function compactPath(path) {
        var value = String(path || "")
        if (!value) return ""
        if (value.length <= 64) return value
        return "…" + value.substring(value.length - 63)
    }

    function allText() {
        var lines = []
        for (var i = 0; i < references.length; i++) {
            var item = references[i] || ({})
            lines.push((item.path || currentPath || "") + ":" + (item.line || 1) + ":" + ((item.col || 0) + 1))
        }
        return lines.join("\n")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelLogHeader {
            theme: root.theme
            title: "References"
            iconName: "link"
            count: root.references.length
            onCopyRequested: root.copyRequested(root.allText())
            onClearRequested: root.clearRequested()
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.references
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property int index
                required property var modelData

                width: list.width
                height: 48
                color: refMouse.containsMouse ? (root.theme.hover || "#2A2D34") : (index % 2 === 0 ? "transparent" : (root.theme.inputBg || "#242424"))

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Icon {
                        icon: IconRegistry.fileIcon(modelData.path || root.currentPath, false)
                        size: 17
                        color: root.theme.accent || "#61AFEF"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: root.basename(modelData.path || root.currentPath || "Current file")
                                color: root.theme.textStrong || "#F3F4F6"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pointSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "L" + (modelData.line || 1) + ":C" + ((modelData.col || 0) + 1)
                                color: root.theme.info || root.theme.accent || "#61AFEF"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pointSize: 8
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.compactPath(modelData.path || root.currentPath)
                            color: root.theme.textDim || "#858585"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 8
                            elide: Text.ElideLeft
                        }
                    }
                }

                MouseArea {
                    id: refMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.locationActivated(modelData)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.references.length === 0
                text: "No references yet. Use Shift+F12 in the editor."
                color: root.theme.textDim || "#858585"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 10
            }
        }
    }
}
