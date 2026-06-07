import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Item {
    id: root

    property var theme: ({})
    property var currentProject: ({})
    property var recentProjects: []
    property var recentFiles: []
    property string searchText: ""

    signal projectSelected(string path)
    signal fileSelected(string path)
    signal openFolderRequested()
    signal copyPathRequested(string path)
    signal revealPathRequested(string path)

    implicitWidth: 156
    implicitHeight: 28
    readonly property real popupMargin: 8
    readonly property real preferredPopupWidth: 360

    function displayProjects() {
        var output = []
        var seen = ({})
        if (root.currentProject && root.currentProject.path) {
            output.push(root.currentProject)
            seen[root.currentProject.path] = true
        }
        for (var i = 0; root.recentProjects && i < root.recentProjects.length; i++) {
            var project = root.recentProjects[i]
            if (!project || !project.path || seen[project.path])
                continue
            output.push(project)
            seen[project.path] = true
        }
        return output
    }

    function projectMatches(project) {
        var query = root.searchText.toLowerCase().trim()
        if (query.length === 0)
            return true
        return String((project || {}).name || "").toLowerCase().indexOf(query) >= 0
            || String((project || {}).path || "").toLowerCase().indexOf(query) >= 0
    }

    function fileMatches(file) {
        var query = root.searchText.toLowerCase().trim()
        if (query.length === 0)
            return true
        return String((file || {}).name || "").toLowerCase().indexOf(query) >= 0
            || String((file || {}).path || "").toLowerCase().indexOf(query) >= 0
    }

    function filteredProjects() {
        var projects = root.displayProjects()
        var output = []
        for (var i = 0; i < projects.length; i++) {
            if (root.projectMatches(projects[i]))
                output.push(projects[i])
        }
        return output
    }

    function filteredFiles() {
        var output = []
        for (var i = 0; root.recentFiles && i < root.recentFiles.length; i++) {
            var file = root.recentFiles[i]
            if (file && file.path && root.fileMatches(file))
                output.push(file)
        }
        return output.slice(0, 12)
    }

    function shortPath(path) {
        var value = String(path || "")
        if (value.length <= 46)
            return value
        var parts = value.split("/")
        if (parts.length >= 3)
            return "…/" + parts.slice(Math.max(0, parts.length - 3)).join("/")
        return "…" + value.slice(Math.max(0, value.length - 43))
    }

    function popupX() {
        var desired = 0
        var window = root.Window.window
        if (!window || !window.contentItem)
            return desired
        var global = root.mapToItem(window.contentItem, desired, 0)
        var rightOverflow = global.x + popup.width - window.width + root.popupMargin
        if (rightOverflow > 0)
            desired -= rightOverflow
        var leftOverflow = root.popupMargin - (global.x + desired)
        if (leftOverflow > 0)
            desired += leftOverflow
        return desired
    }

    function popupHeight() {
        var desired = Math.max(260, projectList.contentHeight + fileList.contentHeight + 148)
        var window = root.Window.window
        if (!window || !window.contentItem)
            return Math.min(420, desired)
        var global = root.mapToItem(window.contentItem, 0, root.height + 6)
        var available = Math.max(160, window.height - global.y - root.popupMargin)
        return Math.min(420, available, desired)
    }

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: switchMouse.containsMouse || popup.visible
               ? (theme.hover || Qt.rgba(1, 1, 1, 0.10))
               : (theme.inputBg || Qt.rgba(1, 1, 1, 0.045))
        border.width: 1
        border.color: popup.visible ? (theme.accent || "#3B82F6") : (theme.border || "#3E3E42")

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 7
                color: root.currentProject.color || "#3B82F6"
                Text {
                    anchors.centerIn: parent
                    text: root.currentProject.avatar || "EM"
                    color: "white"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.currentProject.name || "No project"
                color: theme.textStrong || "#FFFFFF"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Icon {
                icon: popup.visible ? "chevron-right" : "chevron-down"
                color: theme.textDim || "#858585"
                size: 12
            }
        }

        MouseArea {
            id: switchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.open()
        }
    }

    Popup {
        id: popup
        x: root.popupX()
        y: root.height + 6
        width: Math.min(root.preferredPopupWidth, root.Window.window ? root.Window.window.width - root.popupMargin * 2 : root.preferredPopupWidth)
        height: root.popupHeight()
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        background: Rectangle {
            color: theme.panel || "#1E1E1E"
            border.color: theme.border || "#3E3E42"
            border.width: 1
            radius: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Projects"
                        color: theme.textStrong || "#FFFFFF"
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root.displayProjects().length + " workspace" + (root.displayProjects().length === 1 ? "" : "s")
                              + " · " + root.recentFiles.length + " file" + (root.recentFiles.length === 1 ? "" : "s")
                        color: theme.textDim || "#858585"
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    Layout.preferredWidth: openLabel.implicitWidth + 20
                    Layout.preferredHeight: 28
                    radius: 8
                    color: openMouse.containsMouse ? (theme.accentSoft || Qt.rgba(0.23, 0.51, 0.96, 0.18)) : (theme.inputBg || "transparent")
                    border.width: 1
                    border.color: openMouse.containsMouse ? (theme.accent || "#3B82F6") : (theme.border || "#3E3E42")

                    Text {
                        id: openLabel
                        anchors.centerIn: parent
                        text: "Open Folder"
                        color: theme.text || "#CCCCCC"
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: openMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.close()
                            root.openFolderRequested()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 9
                color: theme.inputBg || Qt.rgba(1, 1, 1, 0.045)
                border.width: 1
                border.color: searchInput.activeFocus ? (theme.accent || "#3B82F6") : (theme.border || "#3E3E42")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 6
                    spacing: 7

                    Icon {
                        icon: "search"
                        color: theme.textDim || "#858585"
                        size: 14
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        text: root.searchText
                        placeholderText: "Search projects and recent files..."
                        color: theme.text || "#CCCCCC"
                        placeholderTextColor: theme.textDim || "#858585"
                        font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                        font.pixelSize: 11
                        selectByMouse: true
                        onTextChanged: root.searchText = text
                        background: Rectangle { color: "transparent" }
                        Keys.onEscapePressed: {
                            root.searchText = ""
                            popup.close()
                        }
                    }

                    Icon {
                        visible: root.searchText.length > 0
                        icon: "close"
                        color: clearMouse.containsMouse ? (theme.text || "#CCCCCC") : (theme.textDim || "#858585")
                        size: 12
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.searchText = ""
                        }
                    }
                }
            }

            RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                Text {
                    text: "Recent Projects"
                    color: theme.textStrong || "#FFFFFF"
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: theme.border || "#3E3E42"
            }

            ListView {
                id: projectList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.filteredProjects()
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    required property var modelData
                    width: projectList.width
                    height: 56
                    radius: 8
                    color: rowMouse.containsMouse || modelData.path === root.currentProject.path
                           ? (theme.hover || Qt.rgba(1, 1, 1, 0.09)) : "transparent"
                    border.width: modelData.path === root.currentProject.path ? 1 : 0
                    border.color: theme.accent || "#3B82F6"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 9
                            color: modelData.color || "#3B82F6"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.avatar || "PR"
                                color: "white"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: modelData.name || "Project"
                                color: theme.textStrong || "#FFFFFF"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.shortPath(modelData.path)
                                color: theme.textDim || "#858585"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pixelSize: 10
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }

                        Icon {
                            visible: modelData.path === root.currentProject.path
                            icon: "check"
                            color: theme.accent || "#3B82F6"
                            size: 15
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.close()
                            root.projectSelected(modelData.path || "")
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Recent Files"
                    color: theme.textStrong || "#FFFFFF"
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Text {
                    text: root.filteredFiles().length
                    color: theme.textDim || "#858585"
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pixelSize: 10
                }
            }

            ListView {
                id: fileList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(168, Math.max(0, contentHeight))
                visible: root.filteredFiles().length > 0
                clip: true
                model: root.filteredFiles()
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    required property var modelData
                    width: fileList.width
                    height: 48
                    radius: 8
                    color: fileMouse.containsMouse ? (theme.hover || Qt.rgba(1, 1, 1, 0.09)) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 8
                            color: theme.inputBg || Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: theme.border || "#3E3E42"

                            Icon {
                                anchors.centerIn: parent
                                icon: IconRegistry.fileIcon(modelData.path || "", false)
                                color: theme.accent || "#3B82F6"
                                size: 15
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: modelData.name || "File"
                                color: theme.textStrong || "#FFFFFF"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.shortPath(modelData.path)
                                color: theme.textDim || "#858585"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pixelSize: 9
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }

                        RowLayout {
                            spacing: 2
                            visible: fileMouse.containsMouse

                            MiniAction {
                                theme: root.theme
                                iconName: "copy"
                                tooltip: "Copy path"
                                onClicked: root.copyPathRequested(modelData.path || "")
                            }
                            MiniAction {
                                theme: root.theme
                                iconName: "folder-open"
                                tooltip: "Reveal"
                                onClicked: root.revealPathRequested(modelData.path || "")
                            }
                        }
                    }

                    MouseArea {
                        id: fileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            popup.close()
                            root.fileSelected(modelData.path || "")
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.filteredProjects().length === 0 && root.filteredFiles().length === 0
                text: "No project or recent file matches your search."
                color: theme.textDim || "#858585"
                horizontalAlignment: Text.AlignHCenter
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
    }

    component MiniAction: Rectangle {
        id: action
        property var theme: root.theme
        property string iconName: "copy"
        property string tooltip: ""
        signal clicked()

        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 7
        color: actionMouse.containsMouse ? (theme.accentSoft || Qt.rgba(0.23, 0.51, 0.96, 0.18)) : "transparent"
        border.width: actionMouse.containsMouse ? 1 : 0
        border.color: theme.accent || "#3B82F6"

        Icon {
            anchors.centerIn: parent
            icon: action.iconName
            color: actionMouse.containsMouse ? (theme.accent || "#3B82F6") : (theme.textDim || "#858585")
            size: 13
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                mouse.accepted = true
                action.clicked()
            }
        }

        ToolTip {
            visible: actionMouse.containsMouse
            text: action.tooltip
            delay: 500
        }
    }
}
