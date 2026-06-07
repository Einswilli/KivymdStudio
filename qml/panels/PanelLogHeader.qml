import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property string title: "Panel"
    property string iconName: "syntax"
    property int count: 0

    signal copyRequested()
    signal clearRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: 34
    color: theme.panelHeader || theme.panel || "#252526"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 8

        Icon {
            icon: root.iconName
            color: root.count > 0 ? (theme.accent || "#007ACC") : (theme.textDim || "#858585")
            size: 15
        }

        Text {
            text: root.title + " · " + root.count
            color: theme.text || "#CCCCCC"
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 11
            font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }

        UiIconButton {
            theme: root.theme
            iconName: "copy"
            iconSize: 13
            tooltip: "Copy All"
            enabled: root.count > 0
            iconColor: enabled ? (theme.textDim || "#858585") : (theme.disabled || "#555555")
            onClicked: root.copyRequested()
        }

        UiIconButton {
            theme: root.theme
            iconName: "delete"
            iconSize: 13
            tooltip: "Clear"
            enabled: root.count > 0
            iconColor: enabled ? (theme.textDim || "#858585") : (theme.disabled || "#555555")
            onClicked: root.clearRequested()
        }
    }
}
