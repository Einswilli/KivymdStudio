import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../../../../../qml/components"

Rectangle {
    id: root

    property var theme: DesignTokens.darkTheme
    property var panel: ({})
    property var results: (typeof SearchVM !== "undefined" && SearchVM) ? SearchVM.results : []
    property bool loading: (typeof SearchVM !== "undefined" && SearchVM) ? SearchVM.loading : false
    property string message: (typeof SearchVM !== "undefined" && SearchVM) ? SearchVM.message : "Open a folder to search"
    property var providers: (typeof SearchVM !== "undefined" && SearchVM) ? SearchVM.providers : []
    property bool caseSensitive: (typeof SearchVM !== "undefined" && SearchVM) ? SearchVM.caseSensitive : false
    property bool regex: (typeof SearchVM !== "undefined" && SearchVM) ? SearchVM.regex : false
    property bool includeHidden: (typeof SearchVM !== "undefined" && SearchVM) ? SearchVM.includeHidden : false

    color: theme.sidebar || "#252526"

    function runSearch() {
        if (typeof SearchVM !== "undefined" && SearchVM)
            SearchVM.search(searchInput.text)
    }

    function escapeHtml(value) {
        return String(value || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    function richPreview(result) {
        var before = root.escapeHtml(result.previewBefore || "")
        var match = root.escapeHtml(result.previewMatch || "")
        var after = root.escapeHtml(result.previewAfter || "")
        if (!match)
            return root.escapeHtml(result.preview || "")
        return before
            + "<span style='color:" + (theme.textStrong || "#FFFFFF") + "; background-color:" + (theme.accentSoft || "rgba(0,122,204,0.24)") + "; font-weight:600;'>"
            + match
            + "</span>"
            + after
    }

    function openResult(result) {
        if (!result || !result.path || !EditorVM)
            return
        if (typeof SearchVM !== "undefined" && SearchVM)
            SearchVM.emitResultAction(result)
        EditorVM.addTab(EditorVM.get_filename(result.path), result.path)
    }

    function copyResultPath(result) {
        if (typeof SearchVM !== "undefined" && SearchVM && result && result.path)
            SearchVM.copyPath(result.path)
    }

    function resultActions(result) {
        if (typeof PluginVM !== "undefined" && PluginVM)
            return PluginVM.getSearchResultActions(result || ({}))
        return []
    }

    function executeResultAction(action, result) {
        if (typeof PluginVM !== "undefined" && PluginVM && action && action.id)
            PluginVM.executeSearchResultAction(action.id, result || ({}))
    }

    Connections {
        target: (typeof SearchVM !== "undefined" && SearchVM) ? SearchVM : null
        function onResultsChanged() { root.results = SearchVM.results }
        function onLoadingChanged() { root.loading = SearchVM.loading }
        function onMessageChanged() { root.message = SearchVM.message }
        function onOptionsChanged() {
            root.caseSensitive = SearchVM.caseSensitive
            root.regex = SearchVM.regex
            root.includeHidden = SearchVM.includeHidden
        }
        function onProvidersChanged() {
            root.providers = SearchVM.providers
            providerCombo.model = root.providers
        }
        function onQueryChanged() {
            if (searchInput.text !== SearchVM.query)
                searchInput.text = SearchVM.query
        }
    }

    Timer {
        id: debounce
        interval: 220
        repeat: false
        onTriggered: root.runSearch()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Search"
                color: theme.text || "#CCCCCC"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 12
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            BusyIndicator {
                visible: root.loading
                running: root.loading
                implicitWidth: 18
                implicitHeight: 18
            }

            UiIconButton {
                theme: root.theme
                iconName: "close"
                tooltip: root.loading ? "Cancel search" : "Clear search"
                iconSize: 12
                onClicked: {
                    if (!SearchVM)
                        return
                    if (root.loading) {
                        SearchVM.cancel()
                    } else {
                        searchInput.text = ""
                        SearchVM.clear()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: DesignTokens.metrics.radiusSm
            color: theme.inputBg || "#2A2A2A"
            border.width: 1
            border.color: searchInput.activeFocus ? (theme.accent || "#007ACC") : (theme.inputBorder || theme.border || "#3E3E42")

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 4
                spacing: 6

                Icon {
                    icon: "search"
                    size: 13
                    color: theme.textDim || "#858585"
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                    placeholderText: "Search in workspace..."
                    color: theme.text || "#CCCCCC"
                    placeholderTextColor: theme.textDim || "#858585"
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 11
                    selectByMouse: true
                    background: Rectangle { color: "transparent" }
                    onTextChanged: debounce.restart()
                    Keys.onReturnPressed: root.runSearch()
                    Keys.onEnterPressed: root.runSearch()
                    Component.onCompleted: forceActiveFocus()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Provider"
                color: theme.textDim || "#858585"
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 9
            }

            ComboBox {
                id: providerCombo
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                model: root.providers
                textRole: "label"
                valueRole: "id"
                currentIndex: {
                    if (!SearchVM)
                        return 0
                    for (var i = 0; i < root.providers.length; i++) {
                        if ((root.providers[i].id || root.providers[i].name) === SearchVM.providerId)
                            return i
                    }
                    return 0
                }
                onActivated: {
                    var provider = root.providers[currentIndex] || ({})
                    if (SearchVM)
                        SearchVM.setProvider(provider.id || provider.name || "core.python")
                    if (searchInput.text.length >= 2)
                        debounce.restart()
                }
                contentItem: Text {
                    text: providerCombo.displayText
                    color: theme.text || "#CCCCCC"
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                    font.pointSize: 10
                }
                background: Rectangle {
                    radius: DesignTokens.metrics.radiusSm
                    color: theme.inputBg || "#2A2A2A"
                    border.width: 1
                    border.color: theme.border || "#3E3E42"
                }
                Component.onCompleted: model = root.providers
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            SearchOptionButton {
                theme: root.theme
                label: "Aa"
                tooltip: "Match case"
                checked: root.caseSensitive
                onClicked: if (SearchVM) SearchVM.setCaseSensitive(!root.caseSensitive)
            }

            SearchOptionButton {
                theme: root.theme
                label: ".*"
                tooltip: "Use regular expression"
                checked: root.regex
                onClicked: if (SearchVM) SearchVM.setRegex(!root.regex)
            }

            SearchOptionButton {
                theme: root.theme
                label: "Hidden"
                tooltip: "Include hidden files"
                checked: root.includeHidden
                onClicked: if (SearchVM) SearchVM.setIncludeHidden(!root.includeHidden)
            }

            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            text: root.message
            color: root.loading ? (theme.accent || "#007ACC") : (theme.textDim || "#858585")
            elide: Text.ElideRight
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 10
        }

        ListView {
            id: resultsView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.results
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Text {
                anchors.centerIn: parent
                width: Math.min(parent.width - 24, 220)
                visible: resultsView.count === 0 && !root.loading
                text: searchInput.text.length < 2 ? "Type at least two characters." : root.message
                color: theme.textDim || "#858585"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                font.pointSize: 10
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                property var pluginActions: root.resultActions(modelData)
                width: resultsView.width
                height: 86
                radius: DesignTokens.metrics.radiusSm
                color: mouse.containsMouse ? (theme.hover || "#2A2D2E") : (theme.panel || theme.sidebar || "#252526")
                border.width: 1
                border.color: mouse.containsMouse ? (theme.accent || "#007ACC") : (theme.border || "#333333")
                opacity: mouse.containsMouse ? 1.0 : 0.96

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openResult(row.modelData)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 9
                    anchors.bottomMargin: 9
                    spacing: 9

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignTop
                        radius: DesignTokens.metrics.radiusSm
                        color: theme.accentSoft || Qt.rgba(0.0, 0.48, 0.8, 0.16)
                        border.width: 1
                        border.color: theme.accent || "#007ACC"

                        Icon {
                            anchors.centerIn: parent
                            icon: "file"
                            size: 14
                            color: theme.accent || "#007ACC"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            Text {
                                text: row.modelData.name || ""
                                color: theme.textStrong || theme.text || "#FFFFFF"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pointSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                text: row.modelData.relativePath || row.modelData.path || ""
                                color: theme.textDim || "#858585"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pointSize: 9
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: languageText.implicitWidth + 12
                                Layout.preferredHeight: 20
                                radius: 10
                                color: theme.inputBg || "#2A2A2A"
                                border.width: 1
                                border.color: theme.border || "#3E3E42"

                                Text {
                                    id: languageText
                                    anchors.centerIn: parent
                                    text: row.modelData.language || "text"
                                    color: theme.textDim || "#858585"
                                    font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                    font.pointSize: 9
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.RichText
                            text: root.richPreview(row.modelData)
                            color: theme.text || "#CCCCCC"
                            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                            font.pointSize: 10
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: (row.modelData.line || 1) + ":" + (row.modelData.column || 1)
                                color: theme.accent || "#007ACC"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pointSize: 9
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: row.modelData.provider || ""
                                color: theme.textDim || "#858585"
                                font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
                                font.pointSize: 9
                            }

                            Item { Layout.fillWidth: true }

                            SearchActionButton {
                                theme: root.theme
                                label: "Open"
                                onClicked: root.openResult(row.modelData)
                            }

                            SearchActionButton {
                                theme: root.theme
                                label: "Copy path"
                                onClicked: root.copyResultPath(row.modelData)
                            }

                            SearchActionButton {
                                theme: root.theme
                                label: "Plugins"
                                visible: row.pluginActions.length > 0
                                onClicked: resultActionMenu.popup()
                            }
                        }
                    }
                }

                Menu {
                    id: resultActionMenu

                    Instantiator {
                        model: row.pluginActions
                        delegate: MenuItem {
                            required property var modelData
                            text: (modelData.plugin ? modelData.plugin + " · " : "") + (modelData.title || modelData.id)
                            icon.name: modelData.icon || "extensions"
                            onTriggered: root.executeResultAction(modelData, row.modelData)
                        }
                        onObjectAdded: function(index, object) { resultActionMenu.insertItem(index, object) }
                        onObjectRemoved: function(index, object) { resultActionMenu.removeItem(object) }
                    }
                }
            }
        }
    }

    component SearchActionButton: Rectangle {
        id: action

        property var theme: root.theme
        property string label: ""

        signal clicked()

        Layout.preferredHeight: 22
        Layout.preferredWidth: actionText.implicitWidth + 16
        radius: 11
        color: actionMouse.containsMouse ? (theme.accentSoft || Qt.rgba(0.0, 0.48, 0.8, 0.22)) : "transparent"
        border.width: 1
        border.color: actionMouse.containsMouse ? (theme.accent || "#007ACC") : (theme.border || "#3E3E42")

        Text {
            id: actionText
            anchors.centerIn: parent
            text: action.label
            color: actionMouse.containsMouse ? (theme.textStrong || "#FFFFFF") : (theme.textDim || "#858585")
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 9
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }

    component SearchOptionButton: Rectangle {
        id: opt

        property var theme: root.theme
        property string label: ""
        property string tooltip: ""
        property bool checked: false

        signal clicked()

        Layout.preferredHeight: 26
        Layout.preferredWidth: Math.max(42, optionLabel.implicitWidth + 18)
        radius: 13
        color: checked
            ? (theme.accentSoft || Qt.rgba(0.0, 0.48, 0.8, 0.22))
            : (optionMouse.containsMouse ? (theme.hover || "#2A2D2E") : (theme.inputBg || "#2A2A2A"))
        border.width: 1
        border.color: checked ? (theme.accent || "#007ACC") : (theme.border || "#3E3E42")

        Text {
            id: optionLabel
            anchors.centerIn: parent
            text: opt.label
            color: opt.checked ? (theme.textStrong || "#FFFFFF") : (theme.textDim || "#858585")
            font.family: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily : "Inter"
            font.pointSize: 9
            font.weight: opt.checked ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: optionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: opt.clicked()
        }

        ToolTip {
            visible: optionMouse.containsMouse
            text: opt.tooltip
            delay: 450
            background: Rectangle {
                color: theme.inputBg || "#3C3C3C"
                border.color: theme.inputBorder || "#555555"
                radius: DesignTokens.metrics.radiusXs
            }
            contentItem: Text {
                text: opt.tooltip
                color: theme.textStrong || "#FFFFFF"
                font.pointSize: 9
            }
        }
    }
}
