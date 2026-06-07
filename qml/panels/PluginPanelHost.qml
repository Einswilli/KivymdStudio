import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var panel: ({})

    color: theme.panel || "#1E1E1E"

    Loader {
        id: pluginLoader
        anchors.fill: parent
        source: root.panel && root.panel.component ? root.panel.component : ""
        asynchronous: true
        onLoaded: {
            if (item && "theme" in item)
                item.theme = root.theme
            if (item && "panel" in item)
                item.panel = root.panel
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 460)
        spacing: 10
        visible: pluginLoader.status === Loader.Error || !root.panel.component

        Icon {
            icon: root.panel.icon || "extensions"
            color: theme.textDim || "#858585"
            size: 36
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            text: root.panel.title || root.panel.label || "Plugin Panel"
            color: theme.text || "#CCCCCC"
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 13
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        Text {
            text: pluginLoader.status === Loader.Error
                ? "Unable to load plugin panel component."
                : "This plugin panel has no component."
            color: theme.textDim || "#858585"
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
    }
}
