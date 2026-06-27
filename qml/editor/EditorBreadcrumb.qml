import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property string filePath: ""
    property string workspacePath: ""
    property var theme: DesignTokens.darkTheme
    property int maxVisibleSegments: 8
    readonly property var segments: _segments()

    signal segmentActivated(string path)
    signal copyPathRequested(string path)
    signal copyRelativePathRequested(string path)
    signal openTerminalRequested(string path)

    color: theme.bg || "#1E1E1E"
    border.width: 0
    visible: filePath.length > 0 && filePath !== "welcome" && filePath !== "settings"
    implicitHeight: visible ? 30 : 0

    function _normalize(path) {
        return String(path || "").replace(/\\/g, "/").replace(/\/+$/, "")
    }

    function _basename(path) {
        var normalized = _normalize(path)
        if (!normalized) return ""
        var parts = normalized.split("/")
        return parts[parts.length - 1] || normalized
    }

    function _dirname(path) {
        var normalized = _normalize(path)
        var index = normalized.lastIndexOf("/")
        return index > 0 ? normalized.substring(0, index) : ""
    }

    function _segments() {
        var file = _normalize(filePath)
        if (!file) return []
        var workspace = _normalize(workspacePath)
        var relative = file
        var base = ""
        if (workspace && (file === workspace || file.indexOf(workspace + "/") === 0)) {
            relative = file.substring(workspace.length)
            if (relative.charAt(0) === "/") relative = relative.substring(1)
            base = workspace
        }
        var rawParts = relative.split("/").filter(function(part) { return part.length > 0 })
        var parts = []
        if (base)
            parts.push({ label: _basename(base) || base, path: base, kind: "workspace" })
        for (var i = 0; i < rawParts.length; i++) {
            var prefix = base ? base : ""
            var partial = rawParts.slice(0, i + 1).join("/")
            var fullPath = prefix ? prefix + "/" + partial : partial
            parts.push({
                label: rawParts[i],
                path: fullPath,
                kind: i === rawParts.length - 1 ? "file" : "folder"
            })
        }
        if (parts.length > maxVisibleSegments) {
            var tail = parts.slice(parts.length - maxVisibleSegments + 1)
            tail.unshift({ label: "…", path: _dirname(tail[0].path), kind: "overflow" })
            return tail
        }
        return parts
    }

    function relativePath(path) {
        var file = _normalize(path)
        var workspace = _normalize(workspacePath)
        if (workspace && (file === workspace || file.indexOf(workspace + "/") === 0)) {
            var relative = file.substring(workspace.length)
            return relative.charAt(0) === "/" ? relative.substring(1) : relative
        }
        return file
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.theme.border || "#30363D"
        opacity: 0.65
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        contentWidth: breadcrumbRow.implicitWidth
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        clip: true

        RowLayout {
            id: breadcrumbRow
            height: flick.height
            spacing: 4

            Repeater {
                model: root.segments

                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        radius: 5
                        color: crumbMouse.containsMouse && modelData.kind !== "file"
                               ? (root.theme.hover || "#30363D")
                               : "transparent"
                        implicitHeight: 22
                        implicitWidth: crumbText.implicitWidth + 12

                        Text {
                            id: crumbText
                            anchors.centerIn: parent
                            text: modelData.label
                            color: modelData.kind === "file"
                                   ? (root.theme.text || "#CCCCCC")
                                   : (root.theme.textDim || "#858585")
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 10
                            font.weight: modelData.kind === "file" ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: crumbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: modelData.kind === "file" ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    crumbMenu.popup()
                                    return
                                }
                                if (modelData.kind !== "file")
                                    root.segmentActivated(modelData.path)
                            }
                        }

                        Menu {
                            id: crumbMenu

                            MenuItem {
                                text: "Reveal in Explorer"
                                enabled: modelData.path && modelData.path.length > 0
                                onTriggered: root.segmentActivated(modelData.path)
                            }

                            MenuItem {
                                text: "Copy Path"
                                enabled: modelData.path && modelData.path.length > 0
                                onTriggered: root.copyPathRequested(modelData.path)
                            }

                            MenuItem {
                                text: "Copy Relative Path"
                                enabled: root.workspacePath.length > 0 && modelData.path && modelData.path.length > 0
                                onTriggered: root.copyRelativePathRequested(root.relativePath(modelData.path))
                            }

                            MenuSeparator {}

                            MenuItem {
                                text: "Open Terminal Here"
                                enabled: modelData.path && modelData.path.length > 0
                                onTriggered: root.openTerminalRequested(modelData.path)
                            }
                        }
                    }

                    Icon {
                        visible: index < root.segments.length - 1
                        icon: "chevron-right"
                        size: 13
                        color: root.theme.textMuted || root.theme.textDim || "#858585"
                        Layout.alignment: Qt.AlignVCenter
                        opacity: 0.75
                    }
                }
            }
        }
    }
}
