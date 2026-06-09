import QtQuick 2.15
import QtQuick.Controls 2.15
import "../../../../qml/filebrowser"
import "../../../../qml/components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var panel: ({})

    color: theme.sidebar || "#252526"

    function openFile(path) {
        if (!path || !EditorVM)
            return
        EditorVM.addTab(EditorVM.get_filename(path), path)
    }

    function openFolder(path) {
        if (!path || !FileVM)
            return
        if (FileVM.openFolder(path) && EditorVM)
            EditorVM.switchWorkspaceSession(path)
    }

    FileExplorer {
        anchors.fill: parent
        theme: root.theme
        folder: FileVM ? FileVM.currentFolder : ""
        activeFilePath: EditorVM ? EditorVM.currentTabContent() : ""
        onFileSelected: function(path) { root.openFile(path) }
        onFolderOpened: function(path) { root.openFolder(path) }
    }
}
