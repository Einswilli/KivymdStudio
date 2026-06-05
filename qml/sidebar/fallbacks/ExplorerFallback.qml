import QtQuick 2.15
import "../../filebrowser"
import "../../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var panel: ({})
    property string currentFolder: ""
    property string activeFilePath: ""

    signal fileSelected(string path)
    signal folderOpened(string path)

    color: theme.sidebar || "#252526"

    FileExplorer {
        anchors.fill: parent
        theme: root.theme
        folder: root.currentFolder
        activeFilePath: root.activeFilePath
        onFileSelected: function(path) { root.fileSelected(path) }
        onFolderOpened: function(path) { root.folderOpened(path) }
    }
}
