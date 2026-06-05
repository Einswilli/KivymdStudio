import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var panel: ({})

    color: theme.sidebar || "#252526"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Text {
            text: "Source Control"
            color: theme.textDim || "#858585"
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 12
            font.weight: Font.DemiBold
        }
        Text {
            text: "No changes yet"
            color: theme.textDim || "#858585"
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 11
        }
    }
}
