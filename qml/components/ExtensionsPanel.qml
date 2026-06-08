import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: extensionsPanel
    color: theme.sidebar || "#252526"
    clip: true

    property var theme: ({})
    property int activeSection: 0
    property var installStatus: ({ state: "idle", ok: false, message: "", errors: [], manifest: {} })
    property var updateStatus: ({ plugin: "", state: "idle", canUpdate: false, message: "", diff: {} })
    property string pendingUpdatePlugin: ""
    property bool installFormExpanded: false
    property var pluginStore: []
    property var pluginStoreSources: []
    property string pluginStoreApiUrl: ""
    property string pluginStoreSearch: ""

    readonly property var _sections: [
        { label: "Installed", icon: "extensions" },
        { label: "Store", icon: "search" },
        { label: "Commands", icon: "terminal" },
        { label: "Views", icon: "columns" },
        { label: "Permissions", icon: "shield" },
    ]

    Component.onCompleted: {
        if (typeof PluginVM !== "undefined" && PluginVM)
            PluginVM.loadPlugins()
        if (typeof ActionVM !== "undefined" && ActionVM)
            ActionVM.runAction("plugins.refresh_store")
        else if (typeof PluginVM !== "undefined" && PluginVM)
            PluginVM.loadPluginStore()
    }

    Connections {
        target: PluginVM
        function onPluginsChanged() {
            installedList.model = PluginVM.plugins
        }
        function onContributionsChanged() {
            commandsList.model = PluginVM.pluginCommands
            viewsList.model = PluginVM.sidebarViews
        }
        function onPermissionsChanged() {
            permissionsList.model = PluginVM.permissionRequests
        }
        function onInstallStatusChanged(status) {
            extensionsPanel.installStatus = status || ({ state: "idle", ok: false, message: "", errors: [], manifest: {} })
        }
        function onUpdateStatusChanged(status) {
            extensionsPanel.updateStatus = status || ({ plugin: "", state: "idle", canUpdate: false, message: "", diff: {} })
        }
        function onStoreChanged() {
            extensionsPanel.pluginStore = PluginVM.pluginStore
            extensionsPanel.pluginStoreSources = PluginVM.pluginStoreSources
            extensionsPanel.pluginStoreApiUrl = PluginVM.pluginStoreApiUrl || ""
            storeList.model = extensionsPanel._filteredPluginStore()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            color: theme.sidebar || "#252526"

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                anchors.topMargin: 8
                anchors.bottomMargin: 6
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Icon {
                        icon: "extensions"
                        color: theme.accent || "#007ACC"
                        size: 18
                    }

                    Text {
                        text: "Extensions"
                        color: theme.textStrong || "#FFFFFF"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        height: 20
                        width: Math.max(34, countText.implicitWidth + 14)
                        radius: 10
                        color: Qt.rgba(0.2, 0.45, 0.75, 0.26)
                        border.width: 1
                        border.color: Qt.rgba(0.45, 0.65, 0.95, 0.24)

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: PluginVM ? PluginVM.plugins.length : 0
                            color: theme.info || "#61AFEF"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Text {
                    text: "Manage installed plugins and contributed features"
                    color: theme.textDim || "#858585"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: theme.tabbarBg || theme.panelHeader || theme.sidebar || "#252526"
            border.width: 1
            border.color: theme.border || "#3E3E42"
            clip: true

            Flickable {
                id: extensionsSectionScroller
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                contentWidth: sectionTabsRow.implicitWidth
                contentHeight: height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                clip: true

                ScrollBar.horizontal: ScrollBar {
                    policy: extensionsSectionScroller.contentWidth > extensionsSectionScroller.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    height: 4
                    background: Rectangle { color: "transparent" }
                    contentItem: Rectangle {
                        radius: 2
                        color: parent.pressed ? (theme.scrollbarHover || "#4F4F4F") : (theme.scrollbarThumb || "#424242")
                    }
                }

                Row {
                    id: sectionTabsRow
                    height: parent.height
                    spacing: 6
                    leftPadding: 2
                    rightPadding: 2

                    Repeater {
                        model: extensionsPanel._sections
                        delegate: Rectangle {
                            required property int index
                            required property var modelData

                            width: sectionLabel.implicitWidth + 32
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 6
                            color: extensionsPanel.activeSection === index
                                   ? (theme.tabActive || Qt.rgba(0.0, 0.48, 0.8, 0.26))
                                   : (sectionMouse.containsMouse ? (theme.tabHover || theme.hover || "#2A2D2E") : "transparent")
                            border.width: extensionsPanel.activeSection === index ? 1 : 0
                            border.color: theme.accentSoft || Qt.rgba(0.4, 0.65, 0.95, 0.28)

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Icon {
                                    icon: modelData.icon
                                    size: 12
                                    color: extensionsPanel.activeSection === index ? (theme.tabActiveText || theme.textStrong || "#FFFFFF") : (theme.tabInactiveText || theme.textDim || "#858585")
                                }
                                Text {
                                    id: sectionLabel
                                    text: modelData.label
                                    color: extensionsPanel.activeSection === index ? (theme.tabActiveText || theme.textStrong || "#FFFFFF") : (theme.tabInactiveText || theme.textDim || "#858585")
                                    font.pixelSize: 10
                                    font.weight: extensionsPanel.activeSection === index ? Font.DemiBold : Font.Normal
                                }
                            }

                            MouseArea {
                                id: sectionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    extensionsPanel.activeSection = index
                                    extensionsSectionScroller.contentX = Math.max(0, Math.min(parent.x - 8, extensionsSectionScroller.contentWidth - extensionsSectionScroller.width))
                                }
                            }
                        }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: extensionsPanel.activeSection

            Item {
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: extensionsPanel.installFormExpanded
                                                ? (manifestSummaryBox.visible ? 226 : (installStatusBox.visible ? 168 : 136))
                                                : 58
                        color: theme.panel || "#1E1E1E"
                        border.width: 1
                        border.color: theme.border || "#3E3E42"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                    radius: 10
                                    color: Qt.rgba(0.0, 0.48, 0.8, 0.14)
                                    border.width: 1
                                    border.color: Qt.rgba(0.35, 0.65, 1.0, 0.22)

                                    Icon {
                                        anchors.centerIn: parent
                                        icon: "extensions"
                                        color: theme.info || "#61AFEF"
                                        size: 18
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Install local plugin"
                                        color: theme.textStrong || "#FFFFFF"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: extensionsPanel.installFormExpanded
                                              ? "Select a plugin directory containing a valid manifest.json."
                                              : (pluginSourceInput.text.length > 0
                                                 ? pluginSourceInput.text
                                                 : "Collapsed · install plugins from a local folder")
                                        color: theme.textDim || "#858585"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Rectangle {
                                    visible: !extensionsPanel.installFormExpanded && extensionsPanel.installStatus.message && extensionsPanel.installStatus.message.length > 0
                                    Layout.preferredWidth: Math.min(120, Math.max(54, compactInstallStatus.implicitWidth + 16))
                                    Layout.preferredHeight: 22
                                    radius: 11
                                    color: extensionsPanel.installStatus.ok ? Qt.rgba(0.2, 0.55, 0.3, 0.13)
                                                                         : Qt.rgba(0.75, 0.25, 0.25, 0.13)
                                    border.width: 1
                                    border.color: extensionsPanel.installStatus.ok ? Qt.rgba(0.45, 0.9, 0.62, 0.28)
                                                                                   : Qt.rgba(0.95, 0.32, 0.28, 0.32)

                                    Text {
                                        id: compactInstallStatus
                                        anchors.centerIn: parent
                                        width: parent.width - 12
                                        text: extensionsPanel.installStatus.ok ? "Valid" : "Invalid"
                                        color: extensionsPanel.installStatus.ok ? (theme.success || "#98C379") : (theme.error || "#E06C75")
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: extensionsPanel.installFormExpanded ? 72 : 86
                                    Layout.preferredHeight: 28
                                    radius: 7
                                    color: installToggleMouse.containsMouse ? Qt.rgba(0.35, 0.65, 1.0, 0.16) : Qt.rgba(1, 1, 1, 0.045)
                                    border.width: 1
                                    border.color: installToggleMouse.containsMouse ? Qt.rgba(0.35, 0.65, 1.0, 0.24) : Qt.rgba(1, 1, 1, 0.09)

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Icon {
                                            icon: extensionsPanel.installFormExpanded ? "chevron-down" : "chevron-right"
                                            color: theme.textStrong || "#FFFFFF"
                                            size: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: extensionsPanel.installFormExpanded ? "Hide" : "Install"
                                            color: theme.textStrong || "#FFFFFF"
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: installToggleMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: extensionsPanel.installFormExpanded = !extensionsPanel.installFormExpanded
                                    }
                                }
                            }

                            RowLayout {
                                visible: extensionsPanel.installFormExpanded
                                Layout.fillWidth: true
                                spacing: 8

                                TextField {
                                    id: pluginSourceInput
                                    Layout.fillWidth: true
                                    height: 30
                                    placeholderText: "/path/to/plugin-directory"
                                    color: theme.text || "#D4D4D4"
                                    placeholderTextColor: theme.textDim || "#858585"
                                    selectionColor: theme.accent || "#007ACC"
                                    selectedTextColor: theme.textStrong || "#FFFFFF"
                                    font.pixelSize: 11
                                    onEditingFinished: {
                                        if (PluginVM && text.length > 0)
                                            PluginVM.validatePluginSource(text)
                                    }
                                    background: Rectangle {
                                        radius: 6
                                        color: theme.inputBg || theme.bg || "#1E1E1E"
                                        border.width: 1
                                        border.color: pluginSourceInput.activeFocus ? (theme.accent || "#007ACC") : (theme.border || "#3E3E42")
                                    }
                                }

                                PanelButton {
                                    theme: extensionsPanel.theme
                                    text: "Browse…"
                                    onClicked: {
                                        if (!PluginVM)
                                            return
                                        var path = PluginVM.choosePluginDirectory()
                                        if (path && path.length > 0) {
                                            pluginSourceInput.text = path
                                            PluginVM.validatePluginSource(path)
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                visible: extensionsPanel.installFormExpanded
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: pluginSourceInput.text.length > 0 ? pluginSourceInput.text : "No local source selected"
                                    color: pluginSourceInput.text.length > 0 ? (theme.textDim || "#858585") : Qt.rgba(0.8, 0.8, 0.8, 0.38)
                                    font.pixelSize: 9
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }

                                PanelButton {
                                    theme: extensionsPanel.theme
                                    text: "Validate"
                                    onClicked: {
                                        if (PluginVM && pluginSourceInput.text.length > 0)
                                            PluginVM.validatePluginSource(pluginSourceInput.text)
                                    }
                                }

                                PanelButton {
                                    theme: extensionsPanel.theme
                                    text: "Install"
                                    highlighted: extensionsPanel.installStatus.ok
                                    onClicked: extensionsPanel._installValidatedPlugin()
                                }
                            }

                            Rectangle {
                                id: installStatusBox
                                visible: extensionsPanel.installFormExpanded && extensionsPanel.installStatus.message && extensionsPanel.installStatus.message.length > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                radius: 6
                                color: extensionsPanel.installStatus.ok ? Qt.rgba(0.2, 0.55, 0.3, 0.12)
                                                                     : Qt.rgba(0.75, 0.25, 0.25, 0.12)
                                border.width: 1
                                border.color: extensionsPanel.installStatus.ok ? (theme.success || "#98C379")
                                                                               : (theme.error || "#E06C75")

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: Text.AlignVCenter
                                    text: extensionsPanel.installStatus.message || ""
                                    color: extensionsPanel.installStatus.ok ? (theme.success || "#98C379")
                                                                            : (theme.error || "#E06C75")
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                id: manifestSummaryBox
                                visible: extensionsPanel.installFormExpanded && extensionsPanel.installStatus.ok && extensionsPanel.installStatus.manifest && extensionsPanel.installStatus.manifest.name
                                Layout.fillWidth: true
                                Layout.preferredHeight: 82
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.035)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.075)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: 8
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        Layout.alignment: Qt.AlignTop
                                        radius: 9
                                        color: Qt.rgba(1, 1, 1, 0.055)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.10)

                                        Icon {
                                            anchors.centerIn: parent
                                            icon: "extensions"
                                            color: extensionsPanel._hasSensitivePermissions(extensionsPanel.installStatus.manifest) ? (theme.warning || "#D19A66") : (theme.success || "#98C379")
                                            size: 16
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: extensionsPanel._manifestSummary(extensionsPanel.installStatus.manifest)
                                            color: theme.textStrong || "#FFFFFF"
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: extensionsPanel.installStatus.manifest.description || "No description"
                                            color: theme.text || "#CCCCCC"
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: extensionsPanel._manifestContributions(extensionsPanel.installStatus.manifest)
                                            color: theme.textDim || "#858585"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: extensionsPanel._manifestPermissions(extensionsPanel.installStatus.manifest)
                                                  + (extensionsPanel._hasSensitivePermissions(extensionsPanel.installStatus.manifest) ? " · sensitive access" : "")
                                            color: (extensionsPanel.installStatus.manifest.permissions && extensionsPanel.installStatus.manifest.permissions.length > 0)
                                                   ? (theme.warning || "#D19A66")
                                                   : (theme.textDim || "#858585")
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: installedList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        boundsBehavior: Flickable.StopAtBounds
                        model: PluginVM ? PluginVM.plugins : []
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 8
                            background: Rectangle { color: "transparent" }
                            contentItem: Rectangle { radius: 4; color: parent.pressed ? (theme.scrollbarHover || "#4F4F4F") : (theme.scrollbarThumb || "#424242") }
                        }
                        topMargin: 10
                        bottomMargin: 12
                        leftMargin: 10
                        rightMargin: 10

                        delegate: ExtensionCard {
                            width: installedList.width - 20
                            theme: extensionsPanel.theme
                            pluginId: modelData.id || ""
                            title: modelData.name || "Unnamed extension"
                            subtitle: modelData.description || "No description"
                            meta: (modelData.version || "0.0.0") + " · " + (modelData.author || "unknown")
                            iconName: modelData.icon ? "" : "extensions"
                            iconSource: modelData.icon || ""
                            accentColor: extensionsPanel._accentFor(modelData.name || "")
                            active: modelData.active || false
                            proprietary: modelData.proprietary || false
                            canUninstall: modelData.canUninstall || false
                            installedFrom: modelData.installedFrom || ""
                            manifestHash: modelData.manifestHash || ""
                            currentManifestHash: modelData.currentManifestHash || ""
                            trusted: modelData.trusted || false
                            modified: modelData.modified || false
                            errorText: modelData.error || ""
                            updateState: extensionsPanel.updateStatus.plugin === pluginId ? (extensionsPanel.updateStatus.state || "") : ""
                            updateMessage: extensionsPanel.updateStatus.plugin === pluginId ? (extensionsPanel.updateStatus.message || "") : ""
                            canUpdate: extensionsPanel.updateStatus.plugin === pluginId ? (extensionsPanel.updateStatus.canUpdate || false) : false
                            onToggleRequested: {
                                if (!PluginVM || !pluginId)
                                    return
                                if (typeof ActionVM !== "undefined" && ActionVM)
                                    ActionVM.runAction(active ? "plugins.deactivate" : "plugins.activate", {"plugin": pluginId})
                                else if (active)
                                    PluginVM.deactivatePlugin(pluginId)
                                else
                                    PluginVM.activatePlugin(pluginId)
                            }
                            onUninstallRequested: {
                                if (PluginVM && pluginId && canUninstall) {
                                    if (typeof ActionVM !== "undefined" && ActionVM)
                                        ActionVM.runAction("plugins.uninstall", {"plugin": pluginId})
                                    else
                                        PluginVM.uninstallPlugin(pluginId)
                                }
                            }
                            onTrustRequested: {
                                if (PluginVM && pluginId)
                                    PluginVM.trustPluginCurrentManifest(pluginId)
                            }
                            onCheckUpdateRequested: {
                                if (PluginVM && pluginId) {
                                    if (typeof ActionVM !== "undefined" && ActionVM)
                                        ActionVM.runAction("plugins.check_update", {"plugin": pluginId})
                                    else
                                        PluginVM.checkPluginUpdate(pluginId)
                                }
                            }
                            onUpdateRequested: {
                                extensionsPanel._confirmPluginUpdate(pluginId)
                            }
                        }

                        EmptyState {
                            anchors.centerIn: parent
                            visible: installedList.count === 0
                            theme: extensionsPanel.theme
                            iconName: "extensions"
                            title: "No extensions installed"
                            subtitle: "Install plugins to add commands, views and editor features."
                        }
                    }
                }
            }

            Item {
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        color: theme.panel || "#1E1E1E"
                        border.width: 1
                        border.color: theme.border || "#3E3E42"

                        ColumnLayout {
                            id: storeSourcesColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Icon {
                                    icon: "search"
                                    color: theme.info || "#61AFEF"
                                    size: 18
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Plugin marketplace"
                                        color: theme.textStrong || "#FFFFFF"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "Configured in Settings · " + (extensionsPanel.pluginStoreApiUrl.length > 0 ? extensionsPanel.pluginStoreApiUrl : "No API configured")
                                        color: theme.textDim || "#858585"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: Math.max(64, storeModeLabel.implicitWidth + 16)
                                    Layout.preferredHeight: 24
                                    radius: 12
                                    color: Qt.rgba(0.35, 0.65, 1.0, 0.12)
                                    border.width: 1
                                    border.color: Qt.rgba(0.35, 0.65, 1.0, 0.22)

                                    Text {
                                        id: storeModeLabel
                                        anchors.centerIn: parent
                                        text: extensionsPanel.pluginStoreSources.length > 0 ? "Online + local" : "Online"
                                        color: theme.info || "#61AFEF"
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                }

                                UiIconButton {
                                    theme: extensionsPanel.theme
                                    iconName: "sync"
                                    iconSize: 14
                                    tooltip: "Refresh marketplace"
                                    actionId: "plugins.refresh_store"
                                    onClicked: {
                                        if ((typeof ActionVM === "undefined" || !ActionVM) && PluginVM)
                                            PluginVM.loadPluginStore()
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 7
                                    color: theme.inputBg || theme.bg || "#1E1E1E"
                                    border.width: 1
                                    border.color: storeSearchInput.activeFocus ? (theme.accent || "#007ACC") : (theme.border || "#3E3E42")

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 9
                                        anchors.rightMargin: 6
                                        spacing: 7

                                        Icon {
                                            icon: "search"
                                            color: theme.textDim || "#858585"
                                            size: 13
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Search plugins by name, author, capability…"
                                                visible: storeSearchInput.text.length === 0
                                                color: theme.textDim || "#858585"
                                                opacity: 0.72
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            TextInput {
                                                id: storeSearchInput
                                                anchors.fill: parent
                                                text: extensionsPanel.pluginStoreSearch
                                                color: theme.text || "#D4D4D4"
                                                selectionColor: theme.accent || "#007ACC"
                                                selectedTextColor: theme.textStrong || "#FFFFFF"
                                                font.pixelSize: 11
                                                clip: true
                                                verticalAlignment: TextInput.AlignVCenter
                                                selectByMouse: true
                                                onTextChanged: {
                                                    extensionsPanel.pluginStoreSearch = text
                                                    storeList.model = extensionsPanel._filteredPluginStore()
                                                }
                                            }
                                        }

                                        UiIconButton {
                                            visible: extensionsPanel.pluginStoreSearch.length > 0
                                            theme: extensionsPanel.theme
                                            iconName: "close"
                                            iconSize: 10
                                            tooltip: "Clear search"
                                            onClicked: {
                                                storeSearchInput.text = ""
                                                extensionsPanel.pluginStoreSearch = ""
                                                storeList.model = extensionsPanel._filteredPluginStore()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: storeList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        boundsBehavior: Flickable.StopAtBounds
                        model: extensionsPanel._filteredPluginStore()
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 8
                            background: Rectangle { color: "transparent" }
                            contentItem: Rectangle { radius: 4; color: parent.pressed ? (theme.scrollbarHover || "#4F4F4F") : (theme.scrollbarThumb || "#424242") }
                        }
                        topMargin: 10
                        bottomMargin: 12
                        leftMargin: 10
                        rightMargin: 10

                        delegate: StorePluginCard {
                            width: storeList.width - 20
                            theme: extensionsPanel.theme
                            pluginId: modelData.id || ""
                            title: modelData.name || modelData.id || "Plugin"
                            subtitle: modelData.description || "No description"
                            meta: (modelData.version || "0.0.0") + " · " + (modelData.author || "unknown") + " · " + (modelData.sourceKind || "directory")
                            iconSource: modelData.icon || ""
                            source: modelData.source || ""
                            installed: modelData.installed || false
                            active: modelData.active || false
                            updateAvailable: modelData.updateAvailable || false
                            archiveHash: modelData.archiveHash || ""
                            signatureStatus: modelData.signatureStatus || "unsigned"
                            publisherName: modelData.publisherName || modelData.author || "Unknown Publisher"
                            publisherVerified: modelData.publisherVerified || false
                            licenseName: modelData.license || ""
                            pricing: modelData.pricing || "free"
                            contributions: extensionsPanel._storeContributionSummary(modelData.contributions || ({}))
                            permissions: (modelData.permissions || []).join(", ")
                            onInstallRequested: extensionsPanel._installStorePluginSource(source, archiveHash)
                        }

                        EmptyState {
                            anchors.centerIn: parent
                            visible: storeList.count === 0
                            theme: extensionsPanel.theme
                            iconName: "search"
                            title: extensionsPanel.pluginStoreSearch.length > 0 ? "No plugins match" : "No plugins found"
                            subtitle: extensionsPanel.pluginStoreSearch.length > 0 ? "Adjust the search query." : "Refresh the marketplace API or configure sources in Settings."
                        }
                    }
                }
            }

            ListView {
                id: commandsList
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                model: PluginVM ? PluginVM.pluginCommands : []
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 8
                    background: Rectangle { color: "transparent" }
                    contentItem: Rectangle { radius: 4; color: parent.pressed ? (theme.scrollbarHover || "#4F4F4F") : (theme.scrollbarThumb || "#424242") }
                }
                topMargin: 10
                bottomMargin: 12
                leftMargin: 10
                rightMargin: 10

                delegate: CommandCard {
                    width: commandsList.width - 20
                    theme: extensionsPanel.theme
                    title: modelData.title || modelData.id
                    subtitle: modelData.id || ""
                    meta: (modelData.plugin || "plugin") + (modelData.keybinding ? " · " + modelData.keybinding : "")
                    onRunRequested: {
                        if (CommandVM)
                            CommandVM.executeCommand(modelData.id)
                    }
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: commandsList.count === 0
                    theme: extensionsPanel.theme
                    iconName: "terminal"
                    title: "No contributed commands"
                    subtitle: "Activated plugins can contribute commands to the palette."
                }
            }

            ListView {
                id: viewsList
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                model: PluginVM ? PluginVM.sidebarViews : []
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 8
                    background: Rectangle { color: "transparent" }
                    contentItem: Rectangle { radius: 4; color: parent.pressed ? (theme.scrollbarHover || "#4F4F4F") : (theme.scrollbarThumb || "#424242") }
                }
                topMargin: 10
                bottomMargin: 12
                leftMargin: 10
                rightMargin: 10

                delegate: ViewCard {
                    width: viewsList.width - 20
                    theme: extensionsPanel.theme
                    title: modelData.title || modelData.id
                    subtitle: modelData.component || "No QML component"
                    meta: modelData.plugin || "plugin"
                    onOpenRequested: extensionsPanel._openContributedView(modelData)
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: viewsList.count === 0
                    theme: extensionsPanel.theme
                    iconName: "columns"
                    title: "No contributed views"
                    subtitle: "Plugins can mount custom QML views in this area."
                }
            }

            ListView {
                id: permissionsList
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                model: PluginVM ? PluginVM.permissionRequests : []
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 8
                    background: Rectangle { color: "transparent" }
                    contentItem: Rectangle { radius: 4; color: parent.pressed ? (theme.scrollbarHover || "#4F4F4F") : (theme.scrollbarThumb || "#424242") }
                }
                topMargin: 10
                bottomMargin: 12
                leftMargin: 10
                rightMargin: 10

                delegate: PermissionCard {
                    width: permissionsList.width - 20
                    theme: extensionsPanel.theme
                    pluginName: modelData.name || modelData.plugin || ""
                    title: modelData.displayName || modelData.name || "Plugin"
                    approved: modelData.approved || false
                    requiresApproval: modelData.requiresApproval || false
                    scopes: modelData.descriptions || []
                    onApproveRequested: {
                        if (PluginVM)
                            PluginVM.approvePluginPermissions(pluginName)
                    }
                    onRevokeRequested: {
                        if (PluginVM)
                            PluginVM.revokePluginPermissions(pluginName)
                    }
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: permissionsList.count === 0
                    theme: extensionsPanel.theme
                    iconName: "shield"
                    title: "No permissions to review"
                    subtitle: "Plugins that request access will appear here before activation."
                }
            }
        }
    }

    function _openContributedView(view) {
        if (!view || !view.component)
            return
        contributedViewPopup.viewTitle = view.title || view.id
        contributedViewPopup.viewSource = view.component
        contributedViewPopup.open()
    }

    function _accentFor(seed) {
        var palette = [theme.accent || "#007ACC", theme.info || "#61AFEF", theme.success || "#98C379", theme.warning || "#D19A66", "#C678DD"]
        var total = 0
        for (var i = 0; i < seed.length; i++)
            total += seed.charCodeAt(i)
        return palette[total % palette.length]
    }

    function _manifestSummary(manifest) {
        if (!manifest || !manifest.name)
            return "No manifest selected"
        return (manifest.display_name || manifest.name) + " · " + (manifest.version || "0.0.0") + " · " + (manifest.author || "unknown")
    }

    function _manifestContributions(manifest) {
        var c = manifest && manifest.contributes ? manifest.contributes : ({})
        var parts = []
        var keys = [
            ["commands", "commands"],
            ["views", "views"],
            ["disabledViews", "disabled views"],
            ["panels", "panels"],
            ["keybindings", "keys"],
            ["themes", "themes"],
            ["icons", "icons"],
            ["fileIcons", "file icons"],
            ["fileIconOverrides", "file icon overrides"],
            ["fonts", "fonts"],
            ["editorDecorations", "decorations"],
            ["aiProviders", "AI providers"],
            ["lspProviders", "LSP providers"],
            ["searchProviders", "search providers"],
            ["fileFormatters", "file formatters"],
            ["fileActions", "file actions"],
            ["fileDecorations", "file decorations"],
            ["searchResultActions", "search result actions"]
        ]
        for (var i = 0; i < keys.length; i++) {
            var value = c[keys[i][0]]
            if (value && value.length > 0)
                parts.push(value.length + " " + keys[i][1])
        }
        return parts.length > 0 ? parts.join(" · ") : "No contributions"
    }

    function _manifestPermissions(manifest) {
        var permissions = manifest && manifest.permissions ? manifest.permissions : []
        return permissions.length > 0 ? permissions.join(", ") : "No permissions"
    }

    function _filteredPluginStore() {
        var items = extensionsPanel.pluginStore || []
        var query = (extensionsPanel.pluginStoreSearch || "").toLowerCase().trim()
        if (query.length === 0)
            return items
        var filtered = []
        for (var i = 0; i < items.length; i++) {
            var item = items[i] || ({})
            var haystack = [
                item.id || "",
                item.name || "",
                item.description || "",
                item.author || "",
                item.version || "",
                item.sourceKind || "",
                (item.permissions || []).join(" ")
            ].join(" ").toLowerCase()
            if (haystack.indexOf(query) >= 0)
                filtered.push(item)
        }
        return filtered
    }

    function _storeContributionSummary(contributions) {
        contributions = contributions || ({})
        var labels = {
            commands: "commands",
            views: "views",
            disabledViews: "disabled views",
            panels: "panels",
            keybindings: "keys",
            themes: "themes",
            icons: "icons",
            fileIcons: "file icons",
            fileIconOverrides: "file icon overrides",
            fonts: "fonts",
            editorDecorations: "decorations",
            aiProviders: "AI providers",
            lspProviders: "LSP providers",
            searchProviders: "search providers",
            fileFormatters: "file formatters",
            fileActions: "file actions",
            fileDecorations: "file decorations",
            searchResultActions: "search result actions"
        }
        var parts = []
        for (var key in labels) {
            var count = contributions[key] || 0
            if (count > 0)
                parts.push(count + " " + labels[key])
        }
        return parts.length > 0 ? parts.join(" · ") : "No contributions"
    }

    function _sensitivePermissions(manifest) {
        var permissions = manifest && manifest.permissions ? manifest.permissions : []
        var sensitive = []
        var riskMap = {
            "file:write": "Can modify files",
            "file:delete": "Can delete files or folders",
            "file:actions": "Can register file browser actions",
            "project:write": "Can modify project state",
            "terminal:exec": "Can execute terminal commands",
            "network": "Can access network",
            "settings:write": "Can modify settings",
            "editor:write": "Can edit opened documents"
        }
        for (var i = 0; i < permissions.length; i++) {
            var permission = permissions[i]
            if (riskMap[permission])
                sensitive.push({ scope: permission, label: riskMap[permission] })
        }
        return sensitive
    }

    function _hasSensitivePermissions(manifest) {
        return _sensitivePermissions(manifest).length > 0
    }

    function _sensitivePermissionItems(permissions) {
        var manifest = ({ permissions: permissions || [] })
        return _sensitivePermissions(manifest)
    }

    function _permissionTone(scope) {
        var high = ["file:write", "project:write", "terminal:exec", "network", "settings:write", "editor:write"]
        var medium = ["file:read", "project:read", "settings:read", "diagnostics:read", "editor:read"]
        if (high.indexOf(scope) >= 0)
            return theme.warning || "#D19A66"
        if (medium.indexOf(scope) >= 0)
            return theme.info || "#61AFEF"
        return theme.textDim || "#858585"
    }

    function _updateDiffRows(diff) {
        diff = diff || ({})
        var rows = []
        if (diff.versionChanged)
            rows.push({ label: "Version", value: (diff.fromVersion || "unknown") + " → " + (diff.toVersion || "unknown"), tone: "info" })
        if (diff.authorChanged)
            rows.push({ label: "Author", value: (diff.fromAuthor || "unknown") + " → " + (diff.toAuthor || "unknown"), tone: "warning" })
        if (diff.permissionsAdded && diff.permissionsAdded.length > 0)
            rows.push({ label: "Permissions added", value: diff.permissionsAdded.join(", "), tone: "warning" })
        if (diff.permissionsRemoved && diff.permissionsRemoved.length > 0)
            rows.push({ label: "Permissions removed", value: diff.permissionsRemoved.join(", "), tone: "success" })

        var contributions = diff.contributions || ({})
        var labels = {
            commands: "commands",
            views: "views",
            keybindings: "keybindings",
            themes: "themes",
            icons: "icons",
            fileIcons: "file icons",
            fileIconOverrides: "file icon overrides",
            fonts: "fonts",
            editorDecorations: "decorations",
            aiProviders: "AI providers",
            lspProviders: "LSP providers",
            fileFormatters: "file formatters",
            fileActions: "file actions",
            fileDecorations: "file decorations"
        }
        var parts = []
        for (var key in contributions) {
            var item = contributions[key] || ({})
            if (item.changed)
                parts.push((labels[key] || key) + " " + (item.from || 0) + " → " + (item.to || 0))
        }
        if (parts.length > 0)
            rows.push({ label: "Contributions", value: parts.join(" · "), tone: "info" })
        if (rows.length === 0)
            rows.push({ label: "Manifest", value: "No structural manifest changes detected.", tone: "neutral" })
        return rows
    }

    function _updateDiffToneColor(tone) {
        if (tone === "warning")
            return theme.warning || "#D19A66"
        if (tone === "success")
            return theme.success || "#98C379"
        if (tone === "info")
            return theme.info || "#61AFEF"
        return theme.textDim || "#858585"
    }

    function _pluginTitle(pluginId) {
        var plugins = PluginVM ? PluginVM.plugins : []
        for (var i = 0; i < plugins.length; i++) {
            if (plugins[i].id === pluginId)
                return plugins[i].name || pluginId
        }
        return pluginId || "Plugin"
    }

    function _confirmPluginUpdate(pluginId) {
        if (!PluginVM || !pluginId)
            return
        extensionsPanel.pendingUpdatePlugin = pluginId
        if (extensionsPanel.updateStatus.plugin === pluginId && extensionsPanel.updateStatus.canUpdate) {
            updateConfirmPopup.open()
            return
        }
        if (typeof ActionVM !== "undefined" && ActionVM)
            ActionVM.runAction("plugins.check_update", {"plugin": pluginId})
        else
            PluginVM.checkPluginUpdate(pluginId)
    }

    function _installValidatedPlugin() {
        if (!PluginVM || !pluginSourceInput.text || pluginSourceInput.text.length === 0)
            return
        if (!extensionsPanel.installStatus.ok) {
            PluginVM.validatePluginSource(pluginSourceInput.text)
            return
        }
        var manifest = extensionsPanel.installStatus.manifest || ({})
        if (_hasSensitivePermissions(manifest)) {
            installConfirmPopup.open()
            return
        }
        if (typeof ActionVM !== "undefined" && ActionVM)
            ActionVM.runAction("plugins.install_local", {"source": pluginSourceInput.text})
        else
            PluginVM.installPlugin(pluginSourceInput.text)
    }

    function _installPluginSource(source) {
        if (!PluginVM || !source)
            return
        extensionsPanel.installFormExpanded = true
        pluginSourceInput.text = source
        var status = PluginVM.validatePluginSource(source)
        extensionsPanel.installStatus = status || extensionsPanel.installStatus
        _installValidatedPlugin()
    }

    function _installStorePluginSource(source, archiveHash) {
        if (!PluginVM || !source)
            return
        var value = String(source)
        if (value.indexOf("http://") === 0 || value.indexOf("https://") === 0) {
            if (typeof ActionVM !== "undefined" && ActionVM)
                ActionVM.runAction("plugins.install_store", {"source": value, "archiveHash": archiveHash || ""})
            else
                PluginVM.installStorePlugin(value, archiveHash || "")
            return
        }
        _installPluginSource(value)
    }

    Popup {
        id: updateConfirmPopup

        width: Math.min(620, Math.max(360, extensionsPanel.width - 32))
        height: Math.min(500, Math.max(340, extensionsPanel.height - 48))
        x: parent ? (parent.width - width) / 2 : 40
        y: parent ? (parent.height - height) / 2 : 40
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        background: Rectangle {
            color: theme.panel || "#1E1E1E"
            radius: 12
            border.width: 1
            border.color: theme.border || "#3E3E42"
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: theme.panelHeader || "#252526"
                radius: 12

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 10

                    Icon {
                        icon: "sync"
                        color: theme.warning || "#D19A66"
                        size: 18
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Review plugin update"
                            color: theme.textStrong || "#FFFFFF"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        Text {
                            text: extensionsPanel._pluginTitle(extensionsPanel.pendingUpdatePlugin)
                            color: theme.textDim || "#858585"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    UiIconButton {
                        theme: extensionsPanel.theme
                        iconName: "close"
                        iconSize: 12
                        tooltip: "Close"
                        onClicked: updateConfirmPopup.close()
                    }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: Math.max(320, updateConfirmPopup.width - 32)
                    spacing: 12
                    anchors.margins: 16

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: updateStateColumn.implicitHeight + 18
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.035)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.075)

                        ColumnLayout {
                            id: updateStateColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 9
                            spacing: 5

                            Text {
                                text: extensionsPanel.updateStatus.message || "Update available."
                                color: theme.textStrong || "#FFFFFF"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "Stored hash "
                                      + ((extensionsPanel.updateStatus.storedHash || "").length > 0 ? extensionsPanel.updateStatus.storedHash.slice(0, 12) : "unknown")
                                      + " → candidate "
                                      + ((extensionsPanel.updateStatus.candidateHash || "").length > 0 ? extensionsPanel.updateStatus.candidateHash.slice(0, 12) : "unknown")
                                color: theme.textDim || "#858585"
                                font.pixelSize: 10
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Repeater {
                        model: extensionsPanel._updateDiffRows(extensionsPanel.updateStatus.diff)
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 6
                                Layout.preferredHeight: 28
                                radius: 3
                                color: extensionsPanel._updateDiffToneColor(modelData.tone || "neutral")
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.label || ""
                                    color: theme.textStrong || "#FFFFFF"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.value || ""
                                    color: theme.text || "#CCCCCC"
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: extensionsPanel._sensitivePermissionItems((extensionsPanel.updateStatus.diff || ({})).permissionsAdded || []).length > 0
                        Layout.fillWidth: true
                        implicitHeight: updateRiskColumn.implicitHeight + 18
                        radius: 9
                        color: Qt.rgba(0.95, 0.62, 0.18, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(0.95, 0.62, 0.18, 0.36)

                        ColumnLayout {
                            id: updateRiskColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 9
                            spacing: 6

                            Text {
                                text: "New sensitive permissions"
                                color: theme.warning || "#D19A66"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: extensionsPanel._sensitivePermissionItems((extensionsPanel.updateStatus.diff || ({})).permissionsAdded || [])
                                delegate: Text {
                                    required property var modelData
                                    text: "• " + modelData.scope + " — " + modelData.label
                                    color: theme.text || "#CCCCCC"
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Text {
                        text: "Updating will replace the installed plugin from its recorded source and may reactivate it if it was active."
                        color: theme.textDim || "#858585"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                color: theme.panelHeader || "#252526"
                border.width: 1
                border.color: theme.border || "#3E3E42"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    PanelButton {
                        theme: extensionsPanel.theme
                        text: "Cancel"
                        onClicked: updateConfirmPopup.close()
                    }

                    PanelButton {
                        theme: extensionsPanel.theme
                        text: "Apply update"
                        highlighted: true
                        actionId: "plugins.update"
                        actionPayload: {"plugin": extensionsPanel.pendingUpdatePlugin}
                        onClicked: {
                            updateConfirmPopup.close()
                            if (PluginVM && extensionsPanel.pendingUpdatePlugin.length > 0) {
                                if (typeof ActionVM === "undefined" || !ActionVM)
                                    PluginVM.updatePluginFromSource(extensionsPanel.pendingUpdatePlugin)
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: installConfirmPopup

        width: Math.min(560, Math.max(340, extensionsPanel.width - 32))
        height: Math.min(440, Math.max(300, extensionsPanel.height - 48))
        x: parent ? (parent.width - width) / 2 : 40
        y: parent ? (parent.height - height) / 2 : 40
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        background: Rectangle {
            color: theme.panel || "#1E1E1E"
            radius: 12
            border.width: 1
            border.color: theme.border || "#3E3E42"
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: theme.panelHeader || "#252526"
                radius: 12

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 10

                    Icon {
                        icon: "shield"
                        color: theme.warning || "#D19A66"
                        size: 18
                    }

                    Text {
                        text: "Confirm plugin install"
                        color: theme.textStrong || "#FFFFFF"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }

                    UiIconButton {
                        theme: extensionsPanel.theme
                        iconName: "close"
                        iconSize: 12
                        tooltip: "Close"
                        onClicked: installConfirmPopup.close()
                    }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: Math.max(300, installConfirmPopup.width - 32)
                    spacing: 14
                    anchors.margins: 16

                    Text {
                        text: extensionsPanel._manifestSummary(extensionsPanel.installStatus.manifest)
                        color: theme.textStrong || "#FFFFFF"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: extensionsPanel.installStatus.manifest.description || "No description"
                        color: theme.text || "#CCCCCC"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: riskColumn.implicitHeight + 20
                        radius: 8
                        color: Qt.rgba(0.95, 0.62, 0.18, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(0.95, 0.62, 0.18, 0.36)

                        ColumnLayout {
                            id: riskColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 7

                            Text {
                                text: "Sensitive permissions"
                                color: theme.warning || "#D19A66"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: extensionsPanel._sensitivePermissions(extensionsPanel.installStatus.manifest)
                                delegate: Text {
                                    required property var modelData
                                    text: "• " + modelData.scope + " — " + modelData.label
                                    color: theme.text || "#CCCCCC"
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Text {
                        text: "Install only plugins from sources you trust. Permissions can be approved or revoked after installation."
                        color: theme.textDim || "#858585"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                color: theme.panelHeader || "#252526"
                border.width: 1
                border.color: theme.border || "#3E3E42"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    PanelButton {
                        theme: extensionsPanel.theme
                        text: "Cancel"
                        onClicked: installConfirmPopup.close()
                    }

                    PanelButton {
                        theme: extensionsPanel.theme
                        text: "Install anyway"
                        highlighted: true
                        actionId: "plugins.install_local"
                        actionPayload: {"source": pluginSourceInput.text}
                        onClicked: {
                            installConfirmPopup.close()
                            if (PluginVM) {
                                if (typeof ActionVM === "undefined" || !ActionVM)
                                    PluginVM.installPlugin(pluginSourceInput.text)
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: contributedViewPopup
        property string viewTitle: ""
        property string viewSource: ""

        width: Math.min(720, Math.max(320, extensionsPanel.width - 24))
        height: Math.min(520, Math.max(320, extensionsPanel.height - 24))
        x: parent ? (parent.width - width) / 2 : 40
        y: parent ? (parent.height - height) / 2 : 40
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        background: Rectangle {
            color: theme.panel || "#1E1E1E"
            radius: 10
            border.width: 1
            border.color: theme.border || "#3E3E42"
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                color: theme.panelHeader || "#252526"
                radius: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 8
                    Text {
                        text: contributedViewPopup.viewTitle
                        color: theme.textStrong || "#FFFFFF"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    UiIconButton {
                        theme: extensionsPanel.theme
                        iconName: "close"
                        iconSize: 12
                        tooltip: "Close"
                        onClicked: contributedViewPopup.close()
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: contributedViewPopup.visible ? contributedViewPopup.viewSource : ""
            }
        }
    }

    component StorePluginCard: Rectangle {
        property var theme: ({})
        property string pluginId: ""
        property string title: ""
        property string subtitle: ""
        property string meta: ""
        property string iconSource: ""
        property string source: ""
        property bool installed: false
        property bool active: false
        property bool updateAvailable: false
        property bool remote: meta.indexOf("remote") >= 0
        property string archiveHash: ""
        property string signatureStatus: "unsigned"
        property string publisherName: "Unknown Publisher"
        property bool publisherVerified: false
        property string licenseName: ""
        property string pricing: "free"
        property string contributions: ""
        property string permissions: ""
        signal installRequested()

        height: permissions.length > 0 ? 154 : 134
        radius: 10
        color: storeCardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.032)
        border.width: 1
        border.color: updateAvailable ? Qt.rgba(0.95, 0.62, 0.18, 0.34)
                                      : (storeCardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.075))

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    Layout.alignment: Qt.AlignTop
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.14)

                    Icon {
                        anchors.centerIn: parent
                        visible: !iconSource
                        icon: "extensions"
                        color: updateAvailable ? (theme.warning || "#D19A66") : (theme.info || "#61AFEF")
                        size: 25
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 38
                        height: 38
                        visible: !!iconSource
                        source: iconSource
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: title
                            color: theme.textStrong || "#FFFFFF"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredWidth: Math.max(58, storeStatusLabel.implicitWidth + 16)
                            Layout.preferredHeight: 20
                            radius: 10
                            color: updateAvailable ? Qt.rgba(0.95, 0.62, 0.18, 0.13)
                                                   : installed ? Qt.rgba(0.35, 0.85, 0.55, 0.13)
                                                               : Qt.rgba(0.35, 0.65, 1.0, 0.12)
                            border.width: 1
                            border.color: updateAvailable ? Qt.rgba(0.95, 0.62, 0.18, 0.34)
                                                          : installed ? Qt.rgba(0.45, 0.9, 0.62, 0.26)
                                                                      : Qt.rgba(0.35, 0.65, 1.0, 0.25)

                            Text {
                                id: storeStatusLabel
                                anchors.centerIn: parent
                                text: updateAvailable ? "Update" : installed ? "Installed" : "Available"
                                color: updateAvailable ? (theme.warning || "#D19A66")
                                                       : installed ? (theme.success || "#98C379")
                                                                   : (theme.info || "#61AFEF")
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Text {
                        text: subtitle
                        color: theme.text || "#CCCCCC"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: publisherName + (publisherVerified ? " · verified" : " · unverified")
                              + " · " + (licenseName.length > 0 ? licenseName : "no license")
                              + " · " + pricing
                        color: theme.textDim || "#858585"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: meta + (active ? " · active" : "")
                        color: theme.textDim || "#858585"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            Text {
                text: contributions
                color: theme.textDim || "#858585"
                font.pixelSize: 9
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: (signatureStatus === "signed" ? "Signed" : "Unsigned")
                      + (archiveHash.length > 0 ? " · sha256 " + archiveHash.slice(0, 12) : " · no archive hash")
                color: signatureStatus === "signed" && archiveHash.length > 0
                       ? (theme.success || "#98C379")
                       : (theme.warning || "#D19A66")
                font.pixelSize: 9
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: permissions.length > 0
                text: "Permissions: " + permissions
                color: theme.warning || "#D19A66"
                font.pixelSize: 9
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                        text: source.length > 0 ? source : "No downloadable archive provided by marketplace API"
                        color: theme.textDim || "#858585"
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: source.length === 0 ? 94 : updateAvailable ? 96 : installed ? 82 : 74
                    Layout.preferredHeight: 26
                    radius: 7
                    color: storeInstallMouse.enabled
                           ? (storeInstallMouse.containsMouse ? (theme.accentHover || "#1C97EA") : (theme.accent || "#007ACC"))
                           : Qt.rgba(1, 1, 1, 0.045)
                    border.width: storeInstallMouse.enabled ? 0 : 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)

                    Text {
                        anchors.centerIn: parent
                        text: source.length === 0 ? "Unavailable" : updateAvailable ? "Review update" : installed ? "Installed" : (remote ? "Download" : "Install")
                        color: storeInstallMouse.enabled ? "white" : (theme.textDim || "#858585")
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: storeInstallMouse
                        anchors.fill: parent
                        enabled: source.length > 0 && (!installed || updateAvailable)
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: installRequested()
                    }
                }
            }
        }

        MouseArea {
            id: storeCardMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component ExtensionCard: Rectangle {
        property var theme: ({})
        property string pluginId: ""
        property string title: ""
        property string subtitle: ""
        property string meta: ""
        property string iconName: "extensions"
        property string iconSource: ""
        property color accentColor: "#007ACC"
        property bool active: false
        property bool proprietary: false
        property bool canUninstall: false
        property string installedFrom: ""
        property string manifestHash: ""
        property string currentManifestHash: ""
        property bool trusted: false
        property bool modified: false
        property string errorText: ""
        property string updateState: ""
        property string updateMessage: ""
        property bool canUpdate: false
        readonly property bool checkBusy: typeof ActionVM !== "undefined" && ActionVM ? ActionVM.isRunning("plugins.check_update") : false
        readonly property bool updateBusy: typeof ActionVM !== "undefined" && ActionVM ? ActionVM.isRunning("plugins.update") : false
        readonly property bool toggleBusy: typeof ActionVM !== "undefined" && ActionVM ? ActionVM.isRunning(active ? "plugins.deactivate" : "plugins.activate") : false
        readonly property bool uninstallBusy: typeof ActionVM !== "undefined" && ActionVM ? ActionVM.isRunning("plugins.uninstall") : false
        signal toggleRequested()
        signal uninstallRequested()
        signal trustRequested()
        signal checkUpdateRequested()
        signal updateRequested()

        height: modified || errorText.length > 0 || updateMessage.length > 0 ? 172 : 146
        radius: 10
        color: cardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.032)
        border.width: 1
        border.color: cardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.075)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    Layout.alignment: Qt.AlignTop
                    radius: 18
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.15)

                    Icon {
                        anchors.centerIn: parent
                        visible: !iconSource
                        icon: iconName || "extensions"
                        color: accentColor
                        size: 27
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 42
                        height: 42
                        visible: !!iconSource
                        source: iconSource
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: title
                            color: theme.textStrong || "#FFFFFF"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredWidth: Math.max(56, statusLabel.implicitWidth + 16)
                            Layout.preferredHeight: 20
                            radius: 10
                            color: modified ? Qt.rgba(0.95, 0.32, 0.28, 0.13)
                                           : trusted ? Qt.rgba(0.35, 0.85, 0.55, 0.14)
                                           : Qt.rgba(0.95, 0.62, 0.18, 0.12)
                            border.width: 1
                            border.color: modified ? Qt.rgba(0.95, 0.32, 0.28, 0.42)
                                                  : trusted ? Qt.rgba(0.45, 0.9, 0.62, 0.28)
                                                  : Qt.rgba(0.95, 0.62, 0.18, 0.34)

                            Text {
                                id: statusLabel
                                anchors.centerIn: parent
                                text: modified ? "Modified" : trusted ? "Trusted" : "Untrusted"
                                color: modified ? (theme.error || "#E06C75")
                                                : trusted ? (theme.success || "#98C379")
                                                          : (theme.warning || "#D19A66")
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Text {
                        text: subtitle
                        color: theme.text || "#CCCCCC"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: meta + (proprietary ? " · bundled" : "") + (active ? " · active" : " · inactive")
                        color: theme.textDim || "#858585"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "hash " + (manifestHash.length > 0 ? manifestHash.slice(0, 10) : "unknown")
                              + (modified && currentManifestHash.length > 0 ? " → " + currentManifestHash.slice(0, 10) : "")
                              + (installedFrom.length > 0 ? " · " + installedFrom : "")
                        color: modified ? (theme.error || "#E06C75") : (theme.textDim || "#858585")
                        font.pixelSize: 9
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: errorText.length > 0
                        text: errorText
                        color: theme.error || "#E06C75"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: updateMessage.length > 0
                        text: updateMessage
                        color: canUpdate ? (theme.warning || "#D19A66") : (theme.textDim || "#858585")
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 66
                    Layout.preferredHeight: 26
                    radius: 7
                    color: checkUpdateMouse.containsMouse ? Qt.rgba(0.35, 0.65, 1.0, 0.18) : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0.35, 0.65, 1.0, 0.22)

                    Text {
                        anchors.centerIn: parent
                        text: checkBusy ? "…" : "Check"
                        color: theme.info || "#61AFEF"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: checkUpdateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !checkBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: checkUpdateRequested()
                    }
                }

                Rectangle {
                    visible: canUpdate
                    Layout.preferredWidth: 70
                    Layout.preferredHeight: 26
                    radius: 7
                    color: updateMouse.containsMouse ? Qt.rgba(0.95, 0.62, 0.18, 0.22) : Qt.rgba(0.95, 0.62, 0.18, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(0.95, 0.62, 0.18, 0.34)

                    Text {
                        anchors.centerIn: parent
                        text: updateBusy ? "…" : "Update"
                        color: theme.warning || "#D19A66"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: updateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !updateBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: updateRequested()
                    }
                }

                Rectangle {
                    visible: modified
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 26
                    radius: 7
                    color: trustMouse.containsMouse ? Qt.rgba(0.95, 0.62, 0.18, 0.22) : Qt.rgba(0.95, 0.62, 0.18, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(0.95, 0.62, 0.18, 0.34)

                    Text {
                        anchors.centerIn: parent
                        text: "Trust"
                        color: theme.warning || "#D19A66"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: trustMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: trustRequested()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 86
                    Layout.preferredHeight: 26
                    radius: 7
                    color: toggleMouse.containsMouse
                           ? (active ? Qt.rgba(0.9, 0.35, 0.35, 0.22) : Qt.rgba(0.35, 0.65, 1.0, 0.22))
                           : (active ? Qt.rgba(0.35, 0.85, 0.55, 0.16) : Qt.rgba(1, 1, 1, 0.055))
                    border.width: 1
                    border.color: active ? Qt.rgba(0.45, 0.9, 0.62, 0.34) : Qt.rgba(1, 1, 1, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: toggleBusy ? "…" : (active ? "Deactivate" : "Activate")
                        color: theme.textStrong || "#FFFFFF"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: toggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !toggleBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toggleRequested()
                    }
                }

                Rectangle {
                    visible: !proprietary
                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 26
                    radius: 7
                    color: uninstallMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.18) : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0.9, 0.3, 0.3, 0.20)

                    Text {
                        anchors.centerIn: parent
                        text: uninstallBusy ? "…" : "Remove"
                        color: theme.error || "#E06C75"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: uninstallMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: canUninstall && !uninstallBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: uninstallRequested()
                    }
                }
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component CommandCard: Rectangle {
        property var theme: ({})
        property string title: ""
        property string subtitle: ""
        property string meta: ""
        signal runRequested()

        height: 78
        radius: 10
        color: commandMouse.containsMouse ? Qt.rgba(0, 0.48, 0.8, 0.13) : Qt.rgba(1, 1, 1, 0.032)
        border.width: 1
        border.color: commandMouse.containsMouse ? Qt.rgba(0.35, 0.65, 1, 0.24) : Qt.rgba(1, 1, 1, 0.075)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Icon { icon: "terminal"; color: theme.info || "#61AFEF"; size: 20 }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: title; color: theme.textStrong || "#FFFFFF"; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: subtitle; color: theme.textDim || "#858585"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: meta; color: theme.text || "#CCCCCC"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
            }

            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 24
                radius: 6
                color: runMouse.containsMouse ? (theme.accentHover || "#1C97EA") : (theme.accent || "#007ACC")
                Text { anchors.centerIn: parent; text: "Run"; color: "white"; font.pixelSize: 10; font.weight: Font.DemiBold }
                MouseArea {
                    id: runMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: runRequested()
                }
            }
        }

        MouseArea {
            id: commandMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component ViewCard: Rectangle {
        property var theme: ({})
        property string title: ""
        property string subtitle: ""
        property string meta: ""
        signal openRequested()

        height: 78
        radius: 10
        color: viewMouse.containsMouse ? Qt.rgba(0.45, 0.25, 0.8, 0.13) : Qt.rgba(1, 1, 1, 0.032)
        border.width: 1
        border.color: viewMouse.containsMouse ? Qt.rgba(0.65, 0.45, 1, 0.24) : Qt.rgba(1, 1, 1, 0.075)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Icon { icon: "columns"; color: "#C678DD"; size: 20 }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: title; color: theme.textStrong || "#FFFFFF"; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: subtitle; color: theme.textDim || "#858585"; font.pixelSize: 10; elide: Text.ElideLeft; Layout.fillWidth: true }
                Text { text: meta; color: theme.text || "#CCCCCC"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
            }

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 24
                radius: 6
                color: openMouse.containsMouse ? Qt.rgba(0.8, 0.55, 1, 0.28) : Qt.rgba(0.8, 0.55, 1, 0.16)
                border.width: 1
                border.color: Qt.rgba(0.8, 0.55, 1, 0.25)
                Text { anchors.centerIn: parent; text: "Open"; color: theme.textStrong || "#FFFFFF"; font.pixelSize: 10; font.weight: Font.DemiBold }
                MouseArea {
                    id: openMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: openRequested()
                }
            }
        }

        MouseArea {
            id: viewMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component PermissionCard: Rectangle {
        property var theme: ({})
        property string pluginName: ""
        property string title: ""
        property bool approved: false
        property bool requiresApproval: false
        property var scopes: []

        signal approveRequested()
        signal revokeRequested()

        height: Math.max(124, 94 + scopesRepeater.count * 24)
        radius: 10
        color: permMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.032)
        border.width: 1
        border.color: requiresApproval ? (theme.warning || "#D19A66") : Qt.rgba(1, 1, 1, 0.075)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: approved ? Qt.rgba(0.3, 0.75, 0.45, 0.16) : Qt.rgba(0.9, 0.6, 0.25, 0.16)
                    Icon {
                        anchors.centerIn: parent
                        icon: "shield"
                        color: approved ? (theme.success || "#98C379") : (theme.warning || "#D19A66")
                        size: 18
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: title
                        color: theme.textStrong || "#FFFFFF"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: approved
                              ? "Approved · plugin can access these capabilities"
                              : "Blocked until approved · activation requires consent"
                        color: approved ? (theme.success || "#98C379") : (theme.warning || "#D19A66")
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: approved ? 62 : 72
                    Layout.preferredHeight: 26
                    radius: 7
                    color: actionMouse.containsMouse
                           ? (approved ? Qt.rgba(0.9, 0.3, 0.3, 0.24) : (theme.accentHover || "#1C97EA"))
                           : (approved ? Qt.rgba(0.9, 0.3, 0.3, 0.14) : (theme.accent || "#007ACC"))
                    border.width: approved ? 1 : 0
                    border.color: Qt.rgba(0.9, 0.3, 0.3, 0.28)
                    Text {
                        anchors.centerIn: parent
                        text: approved ? "Revoke" : "Approve"
                        color: "white"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: approved ? revokeRequested() : approveRequested()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    id: scopesRepeater
                    model: scopes
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        radius: 7
                        color: Qt.rgba(1, 1, 1, 0.035)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.07)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 7

                            Icon {
                                icon: "shield"
                                color: extensionsPanel._permissionTone(modelData.scope || "")
                                size: 12
                            }

                            Text {
                                text: modelData.scope || ""
                                color: extensionsPanel._permissionTone(modelData.scope || "")
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                Layout.preferredWidth: 92
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.description || ""
                                color: theme.textDim || "#858585"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: permMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component PanelButton: Rectangle {
        property var theme: ({})
        property string text: ""
        property bool highlighted: false
        property string actionId: ""
        property var actionPayload: ({})
        readonly property bool busy: actionId.length > 0 && typeof ActionVM !== "undefined" && ActionVM ? ActionVM.isRunning(actionId) : false
        signal clicked()

        Layout.preferredWidth: Math.max(72, buttonLabel.implicitWidth + 22)
        Layout.preferredHeight: 30
        radius: 7
        color: highlighted
               ? (buttonMouse.containsMouse ? (theme.accentHover || "#1C97EA") : (theme.accent || "#007ACC"))
               : (buttonMouse.containsMouse ? (theme.hover || "#2A2D2E") : (theme.inputBg || "#1E1E1E"))
        border.width: highlighted ? 0 : 1
        border.color: theme.border || "#3E3E42"

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: parent.busy ? "…" : parent.text
            color: highlighted ? "white" : (theme.text || "#D4D4D4")
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !parent.busy
            onClicked: {
                parent.clicked()
                if (parent.actionId.length > 0 && typeof ActionVM !== "undefined" && ActionVM)
                    ActionVM.runAction(parent.actionId, parent.actionPayload || ({}))
            }
        }
    }

    component EmptyState: Item {
        property var theme: ({})
        property string iconName: "extensions"
        property string title: ""
        property string subtitle: ""

        width: parent ? parent.width - 32 : 220
        height: 150

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 10

            Rectangle {
                width: 54
                height: 54
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.045)
                anchors.horizontalCenter: parent.horizontalCenter
                Icon { anchors.centerIn: parent; icon: iconName; color: theme.textDim || "#858585"; size: 26 }
            }

            Text {
                text: title
                color: theme.textStrong || "#FFFFFF"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            Text {
                text: subtitle
                color: theme.textDim || "#858585"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }
    }
}
