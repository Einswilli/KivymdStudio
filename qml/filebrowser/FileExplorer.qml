import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root
    color: "transparent"
    clip: true

    property var theme: ({})
    property string folder: ""
    property string activeFilePath: ""
    property string revealedFilePath: ""
    property int itemHeight: 28
    property var pluginIcons: ({})
    property var _children: ({})
    property var _expanded: ({})
    property string _contextPath: ""
    property string _contextName: ""
    property bool _contextIsDir: false
    property string _promptMode: ""
    property string _promptParent: ""
    property var _pluginActions: []
    property bool _busy: false
    property string _busyLabel: ""
    property bool _pendingOpenCreatedFile: false
    readonly property var _actionBusy: _fileActionBusyInfo()
    readonly property bool _effectiveBusy: _busy || _actionBusy.busy
    readonly property string _effectiveBusyLabel: _busy ? _busyLabel : (_actionBusy.label || "Working…")

    signal fileSelected(string filePath)
    signal folderOpened(string folderPath)

    onFolderChanged: {
        if (root.folder) Qt.callLater(function() { _loadFolder(root.folder) })
        else fileModel.clear()
    }

    Component.onCompleted: {
        if (root.folder) Qt.callLater(function() { _loadFolder(root.folder) })
    }

    ListModel { id: fileModel }

    function _toggleFolder(index, path, name) {
        var entry = fileModel.get(index)
        if (!entry) return
        if (entry.isExpanded) _collapseFolder(index)
        else _expandFolder(index, path)
    }

    function _indexOfPath(path) {
        for (var i = 0; i < fileModel.count; i++) {
            if (fileModel.get(i).path === path)
                return i
        }
        return -1
    }

    function revealFile(path) {
        if (!path || !root.folder || (path !== root.folder && !path.startsWith(root.folder + "/")))
            return false
        root.revealedFilePath = path
        if (fileModel.count === 0)
            _loadFolder(root.folder)
        var relative = path.substring(root.folder.length)
        if (relative.charAt(0) === "/")
            relative = relative.substring(1)
        var parts = relative.split("/")
        var current = root.folder
        for (var i = 0; i < parts.length - 1; i++) {
            current = current + "/" + parts[i]
            var folderIndex = _indexOfPath(current)
            if (folderIndex < 0) {
                _loadFolder(root.folder)
                folderIndex = _indexOfPath(current)
            }
            if (folderIndex >= 0 && !fileModel.get(folderIndex).isExpanded)
                _expandFolder(folderIndex, current)
        }
        var fileIndex = _indexOfPath(path)
        if (fileIndex >= 0) {
            fileList.positionViewAtIndex(fileIndex, ListView.Contain)
            return true
        }
        return false
    }

    function _expandFolder(index, path) {
        if (typeof FileVM === 'undefined') return
        var items = FileVM.list_folder(path)
        var depth = fileModel.get(index).depth + 1
        var children = []
        for (var i = 0; items && i < items.length; i++) {
            if (items[i].name === ".DS_Store") continue
            children.push({
                name: items[i].name, path: items[i].path,
                isDir: items[i].isDir, depth: depth, isExpanded: false,
            })
        }
        _children[path] = children
        fileModel.setProperty(index, "isExpanded", true)
        var insertPos = index + 1
        for (var j = 0; j < children.length; j++)
            fileModel.insert(insertPos + j, children[j])
        _expanded[path] = true
    }

    function _collapseFolder(index) {
        var entry = fileModel.get(index)
        if (!entry) return
        fileModel.setProperty(index, "isExpanded", false)
        _expanded[entry.path] = false
        var removeCount = 0
        var i = index + 1
        while (i < fileModel.count && fileModel.get(i).depth > entry.depth) {
            removeCount++; i++
        }
        if (removeCount > 0) fileModel.remove(index + 1, removeCount)
    }

    function refresh() {
        if (root.folder) _loadFolder(root.folder)
    }

    function _parentFolder(path, isDir) {
        if (isDir)
            return path
        var index = path.lastIndexOf("/")
        return index > 0 ? path.substring(0, index) : root.folder
    }

    function _openContextMenu(path, name, isDir) {
        _contextPath = path
        _contextName = name
        _contextIsDir = isDir
        _pluginActions = (typeof PluginVM !== "undefined" && PluginVM)
            ? PluginVM.getFileBrowserActions(_contextPayload())
            : []
        fileContextMenu.popup()
    }

    function _contextPayload() {
        return _payloadFor(_contextPath, _contextName, _contextIsDir)
    }

    function _payloadFor(path, name, isDir) {
        var extension = ""
        if (!isDir && name && name.indexOf(".") >= 0)
            extension = "." + name.split(".").pop().toLowerCase()
        return {
            path: path,
            name: name,
            isDir: isDir,
            type: isDir ? "folder" : "file",
            extension: extension,
            workspace: root.folder,
            parent: _parentFolder(path, false)
        }
    }

    function _decorationsFor(path, name, isDir) {
        if (typeof PluginVM === "undefined" || !PluginVM)
            return []
        return PluginVM.getFileBrowserDecorations(_payloadFor(path, name, isDir))
    }

    function _applyResult(result, openPath) {
        if (!result || !result.ok) {
            console.warn("[FileExplorer]", result ? result.message : "Action failed")
            return
        }
        refresh()
        if (openPath && result.path && !FileVM.is_dir(result.path))
            root.fileSelected(result.path)
    }

    function _runOperation(label, operation, openPath) {
        if (!operation || root._busy)
            return
        root._busy = true
        root._busyLabel = label || "Working…"
        if (typeof NotificationVM !== "undefined" && NotificationVM)
            NotificationVM.startBusy("file-browser", root._busyLabel)
        Qt.callLater(function() {
            try {
                root._applyResult(operation(), !!openPath)
            } catch (error) {
                console.warn("[FileExplorer]", error)
                if (typeof NotificationVM !== "undefined" && NotificationVM)
                    NotificationVM.error("File operation failed", String(error), 6500)
            } finally {
                root._busy = false
                root._busyLabel = ""
                if (typeof NotificationVM !== "undefined" && NotificationVM)
                    NotificationVM.endBusy("file-browser")
            }
        })
    }

    function _runFileAction(actionId, payload, openPath, fallback) {
        if (!actionId || root._effectiveBusy)
            return
        if (typeof ActionVM !== "undefined" && ActionVM) {
            root._pendingOpenCreatedFile = !!openPath
            ActionVM.runAction(actionId, payload || ({}))
            return
        }
        _runOperation(actionId, fallback, openPath)
    }

    function _fileActionBusyInfo() {
        var operations = (typeof ActionVM !== "undefined" && ActionVM) ? ActionVM.runningActions : []
        for (var i = 0; operations && i < operations.length; i++) {
            var item = operations[i] || ({})
            var actionId = String(item.id || "")
            if (actionId.indexOf("file_browser.") === 0)
                return {"busy": true, "label": item.label || item.title || "Working…"}
        }
        return {"busy": false, "label": ""}
    }

    function _prompt(mode, title, label, parentPath, initialValue) {
        _promptMode = mode
        _promptParent = parentPath || root.folder
        promptDialog.title = title
        promptLabel.text = label
        promptInput.text = initialValue || ""
        promptDialog.open()
        Qt.callLater(function() {
            promptInput.forceActiveFocus()
            promptInput.selectAll()
        })
    }

    function _submitPrompt() {
        if (typeof FileVM === "undefined")
            return
        var value = promptInput.text.trim()
        if (_promptMode === "newFile")
            _runFileAction("file_browser.create_file", {"parent": _promptParent, "name": value}, true, function() { return FileVM.createFileAt(_promptParent, value) })
        else if (_promptMode === "newFolder")
            _runFileAction("file_browser.create_folder", {"parent": _promptParent, "name": value}, false, function() { return FileVM.createFolderAt(_promptParent, value) })
        else if (_promptMode === "rename")
            _runFileAction("file_browser.rename", {"path": _contextPath, "name": value}, false, function() { return FileVM.renamePath(_contextPath, value) })
    }

    function _deleteContext() {
        if (typeof FileVM === "undefined")
            return
        _runFileAction("file_browser.delete", {"path": _contextPath}, false, function() { return FileVM.deletePath(_contextPath) })
    }

    function _moveContext() {
        if (typeof FileVM === "undefined")
            return
        var target = FileVM.openFolderDialog()
        if (target)
            _runFileAction("file_browser.move", {"path": _contextPath, "folder": target}, false, function() { return FileVM.movePath(_contextPath, target) })
    }

    Connections {
        target: (typeof ActionVM !== "undefined") ? ActionVM : null
        function onActionCompleted(result) {
            var actionId = result && result.id ? String(result.id) : ""
            if (actionId.indexOf("file_browser.") !== 0)
                return
            var operation = result.value && result.value.result ? result.value.result : ({})
            root.refresh()
            if (root._pendingOpenCreatedFile && operation.path && typeof FileVM !== "undefined" && !FileVM.is_dir(operation.path))
                root.fileSelected(operation.path)
            root._pendingOpenCreatedFile = false
        }
        function onActionFailed(result) {
            var actionId = result && result.id ? String(result.id) : ""
            if (actionId.indexOf("file_browser.") === 0)
                root._pendingOpenCreatedFile = false
        }
    }

    Connections {
        target: (typeof PluginVM !== "undefined") ? PluginVM : null
        function onFileActionCompleted(result) {
            if (result && result.ok)
                root.refresh()
        }
    }

    function _loadFolder(path) {
        if (typeof FileVM === 'undefined' || !path) return
        var items = FileVM.list_folder(path)
        fileModel.clear()
        _children = ({})
        _expanded = ({})
        for (var i = 0; i < items.length; i++) {
            if (items[i].name === ".DS_Store") continue
            fileModel.append({
                name: items[i].name, path: items[i].path,
                isDir: items[i].isDir, depth: 0, isExpanded: false,
            })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.folder ? 36 : parent.height
            color: Qt.darker(root.color, 1.1)

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: !root.folder

                Icon { icon: "folder-open"; color: theme.textDim || "#858585"; size: 48; Layout.alignment: Qt.AlignHCenter }

                Text {
                    text: "No folder opened"
                    color: theme.textDim || "#858585"
                    font.pointSize: 13; Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 140; height: 32; radius: 4
                    color: openBtn.containsMouse ? Qt.rgba(0.5,0.5,0.5,0.2) : "transparent"
                    border.width: 1; border.color: theme.border || "#3E3E42"
                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Icon { icon: "folder-open"; color: theme.text || "#CCCCCC"; size: 16 }
                        Text { text: "Open Folder"; color: theme.text || "#CCCCCC"; font.pointSize: 11 }
                    }
                    MouseArea {
                        id: openBtn; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof FileVM !== 'undefined') {
                                var p = FileVM.openFolderDialog()
                                if (p)
                                    root.folderOpened(p)
                            }
                        }
                    }
                }
            }

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                visible: !!root.folder

                Icon { icon: "folder-open"; color: theme.textDim || "#858585"; size: 16 }

                Text {
                    text: root.folder ? root.folder.split("/").pop() || "/" : ""
                    color: theme.text || "#CCCCCC"
                    font.pointSize: 11; font.weight: Font.DemiBold
                    elide: Text.ElideLeft; Layout.fillWidth: true
                }

                Row {
                    spacing: 4
                    ToolBtn { icon: "new-file"; tooltip: "New File"; onClicked: _prompt("newFile", "New file", "File name", root.folder, "") }
                    ToolBtn { icon: "new-folder"; tooltip: "New Folder"; onClicked: _prompt("newFolder", "New folder", "Folder name", root.folder, "") }
                    ToolBtn { icon: "paste"; tooltip: "Paste"; onClicked: { if (typeof FileVM !== "undefined") _runFileAction("file_browser.paste", {"folder": root.folder}, false, function() { return FileVM.pasteInto(root.folder) }) } }
                    ToolBtn { icon: "history"; tooltip: "Refresh"; onClicked: refresh() }
                }
            }
        }

        ListView {
            id: fileList
            visible: !!root.folder && fileModel.count > 0
            Layout.fillWidth: true; Layout.fillHeight: true
            model: fileModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded; width: 8
                background: Rectangle { color: "transparent" }
                contentItem: Rectangle { color: Qt.rgba(0.5,0.5,0.5,0.3); radius: 4 }
            }

            delegate: Rectangle {
                id: itemRoot
                width: fileList.width
                height: root.itemHeight
                readonly property bool activeFile: !model.isDir && (model.path === root.activeFilePath || model.path === root.revealedFilePath)
                readonly property var decorations: root._decorationsFor(model.path, model.name, model.isDir)
                color: activeFile ? Qt.rgba(0.23, 0.51, 0.96, 0.18) :
                       (mArea.containsMouse ? Qt.rgba(0.5,0.5,0.5,0.15) : "transparent")

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: itemRoot.activeFile ? (theme.accent || "#3B82F6") : "transparent"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8 + model.depth * 16
                    anchors.rightMargin: 8
                    spacing: 6

	                    Item {
	                        implicitWidth: 16; implicitHeight: 16
	                        Icon {
	                            anchors.centerIn: parent
	                            visible: model.isDir
	                            icon: model.isExpanded ? "chevron-down" : "chevron-right"
	                            color: mArea.containsMouse ? theme.text : theme.textDim
	                            size: 12
                        }
                    }

                    Icon {
                        icon: model.isDir
                              ? _folderIcon(model.path, model.name, model.isExpanded)
                              : _fileIcon(model.name, model.path)
                        color: model.isDir ? (theme.textDim || "#858585") : (theme.text || "#CCCCCC")
                        size: 16
                    }

                    Text {
                        text: model.name
                        color: itemRoot.activeFile ? (theme.textStrong || "#FFFFFF") : (theme.text || "#CCCCCC")
                        font.pointSize: 11
                        font.weight: itemRoot.activeFile ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: itemRoot.decorations
                        delegate: Rectangle {
                            required property var modelData
                            width: Math.max(16, decorationRow.implicitWidth + 8)
                            height: 18
                            radius: 5
                            color: Qt.rgba(0.5, 0.5, 0.5, mArea.containsMouse ? 0.16 : 0.08)
                            border.width: 1
                            border.color: Qt.rgba(0.5, 0.5, 0.5, 0.18)

                            RowLayout {
                                id: decorationRow
                                anchors.centerIn: parent
                                spacing: 3
                                Icon {
                                    visible: !!modelData.icon
                                    icon: modelData.icon || "info"
                                    color: modelData.color || theme.textDim || "#858585"
                                    size: 12
                                }
                                Text {
                                    visible: !!modelData.badge
                                    text: modelData.badge || ""
                                    color: modelData.color || theme.textDim || "#858585"
                                    font.pointSize: 9
                                    font.weight: Font.DemiBold
                                }
                            }

                            ToolTip.visible: decorationMouse.containsMouse && !!modelData.tooltip
                            ToolTip.text: modelData.tooltip || modelData.title || ""
                            MouseArea {
                                id: decorationMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }
                }

                MouseArea {
                    id: mArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            root._openContextMenu(model.path, model.name, model.isDir)
                            return
                        }
                        if (model.isDir) root._toggleFolder(index, model.path, model.name)
                        else root.fileSelected(model.path)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: !!root.folder && fileModel.count === 0
            Text {
                anchors.centerIn: parent
                text: "Empty folder"
                color: theme.textDim || "#858585"
                font.pointSize: 11
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root._effectiveBusy
        color: Qt.rgba(0, 0, 0, 0.22)
        z: 20

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(220, parent.width - 32)
            height: 58
            radius: 10
            color: theme.popup || theme.panel || "#252526"
            border.color: theme.border || "#3E3E42"

            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                BusyIndicator {
                    running: root._effectiveBusy
                    implicitWidth: 22
                    implicitHeight: 22
                }
                Text {
                    text: root._effectiveBusyLabel
                    color: theme.text || "#CCCCCC"
                    font.pointSize: 11
                    elide: Text.ElideRight
                    Layout.maximumWidth: 160
                }
            }
        }
    }

    function _fileIcon(name, path) {
        if (typeof PluginVM !== "undefined" && PluginVM) {
            var override = PluginVM.getFileBrowserIconOverride(_payloadFor(path || name, name, false))
            if (override)
                return override
        }
        if (pluginIcons && pluginIcons[name]) return pluginIcons[name]
        return IconRegistry.fileIcon(name, false)
    }

    function _folderIcon(path, name, isExpanded) {
        var icon = ""
        if (typeof PluginVM !== "undefined" && PluginVM)
            icon = PluginVM.getFileBrowserIconOverride(_payloadFor(path, name || path, true))
        if (!icon)
            icon = IconRegistry.fileIcon(path, true)
        if (isExpanded) {
            var openIcon = icon + "-open"
            if (IconRegistry.customSource(openIcon, null).length > 0)
                return openIcon
        }
        return icon
    }

    function _doNewFile() {
        _prompt("newFile", "New file", "File name", root.folder, "")
    }

    function _doNewFolder() {
        _prompt("newFolder", "New folder", "Folder name", root.folder, "")
    }

    Menu {
        id: fileContextMenu

        MenuItem {
            text: root._contextIsDir ? "New File…" : "New File Here…"
            icon.name: "new-file"
            onTriggered: root._prompt("newFile", "New file", "File name", root._parentFolder(root._contextPath, root._contextIsDir), "")
        }
        MenuItem {
            text: root._contextIsDir ? "New Folder…" : "New Folder Here…"
            icon.name: "new-folder"
            onTriggered: root._prompt("newFolder", "New folder", "Folder name", root._parentFolder(root._contextPath, root._contextIsDir), "")
        }
        MenuSeparator {}
        MenuItem {
            text: "Rename…"
            icon.name: "rename"
            onTriggered: root._prompt("rename", "Rename", "New name", root._parentFolder(root._contextPath, false), root._contextName)
        }
        MenuItem {
            text: "Delete"
            icon.name: "delete"
            onTriggered: {
                if ((typeof SettingsVM !== "undefined" && SettingsVM) && !SettingsVM.filesConfirmDelete)
                    root._deleteContext()
                else
                    deleteDialog.open()
            }
        }
        MenuSeparator {}
        MenuItem {
            text: "Copy"
            icon.name: "copy"
            onTriggered: if (typeof FileVM !== "undefined") root._runFileAction("file_browser.copy", {"path": root._contextPath}, false, function() { return FileVM.copyPath(root._contextPath) })
        }
        MenuItem {
            text: "Cut / Move"
            icon.name: "cut"
            onTriggered: if (typeof FileVM !== "undefined") root._runFileAction("file_browser.cut", {"path": root._contextPath}, false, function() { return FileVM.cutPath(root._contextPath) })
        }
        MenuItem {
            text: "Paste Into"
            icon.name: "paste"
            enabled: root._contextIsDir
            onTriggered: if (typeof FileVM !== "undefined") root._runFileAction("file_browser.paste", {"folder": root._contextPath}, false, function() { return FileVM.pasteInto(root._contextPath) })
        }
        MenuItem {
            text: "Move To…"
            icon.name: "move"
            onTriggered: root._moveContext()
        }
        MenuSeparator {}
        MenuItem {
            text: "Copy Path"
            icon.name: "link"
            onTriggered: if (typeof FileVM !== "undefined") root._runFileAction("file_browser.copy_link", {"path": root._contextPath}, false, function() { return FileVM.copyLink(root._contextPath) })
        }
        MenuItem {
            text: "Format"
            icon.name: "format"
            enabled: !root._contextIsDir
            onTriggered: if (typeof FileVM !== "undefined") root._runFileAction("file_browser.format", {"path": root._contextPath}, false, function() { return FileVM.formatPath(root._contextPath) })
        }
        MenuSeparator {
            visible: root._pluginActions.length > 0
        }
        Menu {
            id: filePluginActionsMenu
            title: "Plugin Actions"
            enabled: root._pluginActions.length > 0
            visible: root._pluginActions.length > 0

            Instantiator {
                model: root._pluginActions
                delegate: MenuItem {
                    required property var modelData
                    text: (modelData.plugin ? modelData.plugin + " · " : "") + (modelData.title || modelData.id)
                    icon.name: modelData.icon || "extensions"
                    onTriggered: {
                        if (typeof ActionVM !== "undefined" && ActionVM)
                            ActionVM.runAction("file_browser.plugin_action", {"actionId": modelData.id, "context": root._contextPayload()})
                        else if (typeof PluginVM !== "undefined" && PluginVM)
                            PluginVM.executeFileBrowserAction(modelData.id, root._contextPayload())
                    }
                }
                onObjectAdded: function(index, object) { filePluginActionsMenu.insertItem(index, object) }
                onObjectRemoved: function(index, object) { filePluginActionsMenu.removeItem(object) }
            }
        }
    }

    Dialog {
        id: promptDialog
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(420, root.width - 32)
        height: 166
        x: Math.max(12, (root.width - width) / 2)
        y: 72
        background: Rectangle {
            color: theme.panel || theme.inputBg || "#252526"
            border.color: theme.border || "#3E3E42"
            radius: 8
        }
        contentItem: ColumnLayout {
            spacing: 10
            Text {
                id: promptLabel
                color: theme.textDim || "#858585"
                font.pointSize: 11
                Layout.fillWidth: true
            }
            TextField {
                id: promptInput
                Layout.fillWidth: true
                color: theme.text || "#CCCCCC"
                selectedTextColor: theme.textStrong || "#FFFFFF"
                selectionColor: theme.selection || theme.accent || "#007ACC"
                background: Rectangle {
                    color: theme.inputBg || "#1E1E1E"
                    border.color: promptInput.activeFocus ? (theme.accent || "#007ACC") : (theme.inputBorder || theme.border || "#3E3E42")
                    radius: 5
                }
                Keys.onReturnPressed: promptDialog.accept()
                Keys.onEnterPressed: promptDialog.accept()
            }
        }
        onAccepted: root._submitPrompt()
    }

    Dialog {
        id: deleteDialog
        title: "Delete"
        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(420, root.width - 32)
        height: 136
        x: Math.max(12, (root.width - width) / 2)
        y: 72
        background: Rectangle {
            color: theme.panel || theme.inputBg || "#252526"
            border.color: theme.border || "#3E3E42"
            radius: 8
        }
        contentItem: Text {
            text: "Delete “" + root._contextName + "” permanently?"
            color: theme.text || "#CCCCCC"
            wrapMode: Text.Wrap
        }
        onAccepted: root._deleteContext()
    }

    component ToolBtn: Item {
        property string icon: ""
        property string tooltip: ""
        signal clicked()

        implicitWidth: 24; implicitHeight: 24

        Icon {
            anchors.centerIn: parent
            icon: parent.icon
            color: mArea.containsMouse ? theme.text : theme.textDim
            size: 14
        }

        MouseArea {
            id: mArea; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }

        ToolTip {
            visible: mArea.containsMouse; text: tooltip; delay: 500
            font.pointSize: 10
            background: Rectangle { color: theme.inputBg || "#3C3C3C"; border.color: theme.inputBorder || theme.border || "#555"; border.width: 1; radius: 2 }
            contentItem: Text { text: tooltip; color: theme.text || "#CCC"; font.pointSize: 10 }
        }
    }
}
