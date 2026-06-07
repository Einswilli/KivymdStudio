import QtQuick 2.15
import QtQuick.Controls.Basic 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root
    anchors.fill: parent

    property int activePage: 0
    property bool ready: false
    property var theme: DesignTokens.darkTheme
    readonly property bool hasSettings: typeof SettingsVM !== "undefined" && SettingsVM
    readonly property color bg: theme.bg || DesignTokens.darkTheme.bg
    readonly property color panel: theme.sidebar || DesignTokens.darkTheme.sidebar
    readonly property color card: theme.panel || DesignTokens.darkTheme.panel
    readonly property color cardHover: theme.hover || DesignTokens.darkTheme.hover
    readonly property color border: theme.border || DesignTokens.darkTheme.border
    readonly property color text: theme.text || DesignTokens.darkTheme.text
    readonly property color strongText: theme.textStrong || DesignTokens.darkTheme.textStrong
    readonly property color muted: theme.textDim || DesignTokens.darkTheme.textDim
    readonly property color dim: theme.tabInactiveText || theme.textDim || DesignTokens.darkTheme.textDim
    readonly property color accent: theme.accent || DesignTokens.darkTheme.accent
    readonly property color accentHover: theme.accentHover || DesignTokens.darkTheme.accentHover
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.10)
    readonly property color inputBg: theme.inputBg || card
    readonly property color error: theme.error || DesignTokens.darkTheme.error
    readonly property color warning: theme.warning || DesignTokens.darkTheme.warning
    readonly property color success: theme.success || DesignTokens.darkTheme.success
    readonly property color info: theme.info || DesignTokens.darkTheme.info
    readonly property var settingsPages: [
        { icon: "code", title: "Editor", component: editorPage },
        { icon: "panel-bottom", title: "Workbench", component: workbenchPage },
        { icon: "search", title: "Search", component: searchPage },
        { icon: "format", title: "Appearance", component: appearancePage },
        { icon: "keyboard", title: "Keyboard", component: shortcutsPage },
        { icon: "syntax", title: "Language & LSP", component: languagePage },
        { icon: "bolt", title: "AI", component: aiPage },
        { icon: "extensions", title: "Plugins", component: pluginsPage },
        { icon: "bolt", title: "Actions", component: actionsPage },
        { icon: "settings", title: "Config", component: configPage }
    ]
    property var formatterTargets: [
        { language: "python", extension: ".py", extensions: [".py", ".pyi"], label: "Python formatter", description: "Default formatter for Python and stub files." },
        { language: "rust", extension: ".rs", extensions: [".rs"], label: "Rust formatter", description: "Default formatter for Rust files." },
        { language: "javascript", extension: ".js", extensions: [".js", ".jsx", ".mjs", ".cjs"], label: "JavaScript formatter", description: "Default formatter for JavaScript files." },
        { language: "typescript", extension: ".ts", extensions: [".ts", ".tsx"], label: "TypeScript formatter", description: "Default formatter for TypeScript files." },
        { language: "json", extension: ".json", extensions: [".json"], label: "JSON formatter", description: "Default formatter for JSON files." },
        { language: "toml", extension: ".toml", extensions: [".toml"], label: "TOML formatter", description: "Default formatter for TOML files." }
    ]

    Component.onCompleted: {
        ready = true
        if (root.hasSettings)
            SettingsVM.refreshToolInstallAudits()
    }

    function settingValue(key, fallback) {
        if (!hasSettings)
            return fallback
        var value = SettingsVM.value(key)
        return value === undefined || value === null ? fallback : value
    }

    function saveJson(key, value, project) {
        if (!hasSettings)
            return
        SettingsVM.setValueJson(key, JSON.stringify(value), project || false)
    }

    function applyPluginPolicies() {
        if (typeof PluginVM !== "undefined" && PluginVM)
            PluginVM.applyPluginPolicies()
    }

    function appearanceProvider(aspect) {
        if (!hasSettings)
            return "ember-default-theme"
        var providers = SettingsVM.getAppearanceProviders()
        return providers[aspect] || "ember-default-theme"
    }

    function appearanceProviderOptions(aspect) {
        if (typeof PluginVM === "undefined" || !PluginVM)
            return aspect === "fonts" ? ["core"] : ["ember-default-theme"]
        var options = PluginVM.getAppearanceProviderOptions(aspect)
        var names = []
        for (var i = 0; i < options.length; i++)
            names.push(options[i].name)
        if (names.length === 0)
            names.push(aspect === "fonts" ? "core" : "ember-default-theme")
        return names
    }

    function appearanceProviderOptionObjects(aspect) {
        if (typeof PluginVM === "undefined" || !PluginVM)
            return [{ name: aspect === "fonts" ? "core" : "ember-default-theme", displayName: aspect === "fonts" ? "Core" : "Ember Default Theme" }]
        var options = PluginVM.getAppearanceProviderOptions(aspect)
        if (!options || options.length === 0)
            return [{ name: aspect === "fonts" ? "core" : "ember-default-theme", displayName: aspect === "fonts" ? "Core" : "Ember Default Theme" }]
        return options
    }

    function appearanceProviderIndex(aspect) {
        var current = appearanceProvider(aspect)
        var options = appearanceProviderOptionObjects(aspect)
        for (var i = 0; i < options.length; i++) {
            if (options[i].name === current)
                return i
        }
        return 0
    }

    function fontFamilyOptions() {
        var provider = appearanceProvider("fonts")
        if (typeof PluginVM !== "undefined" && PluginVM)
            PluginVM.loadFontsFor(provider)
        var fonts = (typeof PluginVM !== "undefined" && PluginVM) ? PluginVM.getFontsFor(provider) : []
        var families = []
        for (var i = 0; i < fonts.length; i++) {
            if ((fonts[i].target || "editor") === "editor" || (fonts[i].target || "") === "all")
                families.push(fonts[i].family || fonts[i].label || fonts[i].id)
        }
        if (families.length === 0)
            families = ["Menlo", "Monaco", "Fira Code", "JetBrains Mono", "Courier New"]
        if (root.hasSettings && families.indexOf(SettingsVM.fontFamily) < 0)
            families.unshift(SettingsVM.fontFamily)
        return families
    }

    function uiFontFamilyOptions() {
        var provider = appearanceProvider("fonts")
        if (typeof PluginVM !== "undefined" && PluginVM)
            PluginVM.loadFontsFor(provider)
        var fonts = (typeof PluginVM !== "undefined" && PluginVM) ? PluginVM.getFontsFor(provider) : []
        var families = []
        for (var i = 0; i < fonts.length; i++) {
            if ((fonts[i].target || "editor") === "ui" || (fonts[i].target || "") === "all")
                families.push(fonts[i].family || fonts[i].label || fonts[i].id)
        }
        if (families.length === 0)
            families = ["Arial", "Helvetica Neue", "Helvetica"]
        if (root.hasSettings && families.indexOf(SettingsVM.uiFontFamily) < 0)
            families.unshift(SettingsVM.uiFontFamily)
        return families
    }

    function shortcutBindings() {
        var bindings = (typeof PluginVM !== "undefined" && PluginVM) ? PluginVM.getResolvedKeybindings() : []
        var query = shortcutSearchText.length > 0 ? shortcutSearchText.toLowerCase() : ""
        if (query.length === 0)
            return bindings
        var filtered = []
        for (var i = 0; i < bindings.length; i++) {
            var item = bindings[i]
            var haystack = [
                item.key || "",
                item.command || "",
                item.plugin || "",
                item.source || "",
                root.commandTitle(item.command || ""),
                root.commandCategory(item.command || "")
            ].join(" ").toLowerCase()
            if (haystack.indexOf(query) >= 0)
                filtered.push(item)
        }
        return filtered
    }

    function shortcutConflictsFor(sequence, whenClause) {
        var bindings = (typeof PluginVM !== "undefined" && PluginVM) ? PluginVM.getResolvedKeybindings() : []
        var conflicts = []
        var key = sequence || ""
        var scope = whenClause || "global"
        for (var i = 0; i < bindings.length; i++) {
            var item = bindings[i]
            if ((item.key || "") === key && (item.when || "global") === scope) {
                conflicts.push({
                    command: item.command || "",
                    source: item.source || "",
                    plugin: item.plugin || "",
                    active: item.active || false
                })
            }
        }
        return conflicts
    }

    function commandTitle(commandId) {
        var commands = (typeof CommandVM !== "undefined" && CommandVM) ? CommandVM.commands : []
        for (var i = 0; i < commands.length; i++) {
            if (commands[i].id === commandId)
                return commands[i].title || commandId
        }
        return commandId
    }

    function commandCategory(commandId) {
        var commands = (typeof CommandVM !== "undefined" && CommandVM) ? CommandVM.commands : []
        for (var i = 0; i < commands.length; i++) {
            if (commands[i].id === commandId)
                return commands[i].category || "Plugin"
        }
        return "Plugin"
    }

    function commandIds() {
        var commands = (typeof CommandVM !== "undefined" && CommandVM) ? CommandVM.commands : []
        var ids = []
        for (var i = 0; i < commands.length; i++)
            ids.push(commands[i].id || "")
        return ids
    }

    property string actionSearchText: ""

    function actionRows() {
        var actions = (typeof ActionVM !== "undefined" && ActionVM) ? ActionVM.actions : []
        var query = actionSearchText.length > 0 ? actionSearchText.toLowerCase() : ""
        var rows = []
        for (var i = 0; i < actions.length; i++) {
            var item = actions[i] || ({})
            var haystack = [
                item.id || "",
                item.title || "",
                item.category || "",
                item.source || "",
                item.description || ""
            ].join(" ").toLowerCase()
            if (query.length === 0 || haystack.indexOf(query) >= 0)
                rows.push(item)
        }
        return rows
    }

    function actionShortcut(actionId) {
        var binding = root.actionBinding(actionId)
        return binding.key || ""
    }

    function actionBinding(actionId) {
        var bindings = (typeof PluginVM !== "undefined" && PluginVM) ? PluginVM.getResolvedKeybindings() : []
        var inactiveMatch = null
        for (var i = 0; i < bindings.length; i++) {
            if ((bindings[i].command || "") === actionId) {
                if (bindings[i].active === undefined || bindings[i].active)
                    return bindings[i]
                if (inactiveMatch === null)
                    inactiveMatch = bindings[i]
            }
        }
        if (inactiveMatch !== null)
            return inactiveMatch
        return ({ key: "", conflict: false, conflicts: [] })
    }

    function notify(level, title, message) {
        if (typeof NotificationVM === "undefined" || !NotificationVM)
            return
        NotificationVM.push(level || "info", title || "Settings", message || "", 3600)
    }

    function runSettingAction(key, label, successMessage, callback) {
        if (typeof NotificationVM !== "undefined" && NotificationVM)
            NotificationVM.startBusy(key, label)
        try {
            callback()
            root.notify("success", "Settings updated", successMessage || label)
        } catch (error) {
            root.notify("error", "Settings action failed", String(error))
        } finally {
            if (typeof NotificationVM !== "undefined" && NotificationVM)
                NotificationVM.endBusy(key)
        }
    }

    function notifyResult(message) {
        var text = message || "Done."
        var failed = text.indexOf("Invalid") === 0
                || text.indexOf("Could not") === 0
                || text.indexOf("No active") === 0
        root.notify(failed ? "error" : "success", failed ? "Settings error" : "Settings updated", text)
        return text
    }

    function operationsSummary() {
        var operations = (typeof NotificationVM !== "undefined" && NotificationVM) ? NotificationVM.operations : []
        if (!operations || operations.length === 0)
            return "No active operation"
        var labels = []
        for (var i = 0; i < operations.length; i++)
            labels.push(operations[i].label || operations[i].key || "Working")
        return labels.join(" · ")
    }

    function aiProviderOptions() {
        var options = (typeof PluginVM !== "undefined" && PluginVM) ? PluginVM.getAiProviderOptions() : []
        if (!options || options.length === 0)
            options = [{ id: "ollama", name: "ollama", label: "Ollama", displayName: "Ollama", endpoint: "http://localhost:11434", defaultModel: "codellama:7b", models: ["codellama:7b"], plugin: "core" }]
        var current = root.hasSettings ? SettingsVM.aiProvider : "ollama"
        var found = false
        for (var i = 0; i < options.length; i++) {
            if ((options[i].name || options[i].id) === current)
                found = true
        }
        if (!found)
            options.unshift({ id: current, name: current, label: current, displayName: current, endpoint: root.hasSettings ? SettingsVM.aiEndpoint : "", defaultModel: root.hasSettings ? SettingsVM.aiModel : "", models: [], plugin: "custom" })
        return options
    }

    function aiProviderIndex() {
        var options = root.aiProviderOptions()
        var current = root.hasSettings ? SettingsVM.aiProvider : "ollama"
        for (var i = 0; i < options.length; i++) {
            if ((options[i].name || options[i].id) === current)
                return i
        }
        return 0
    }

    function aiProviderAt(index) {
        var options = root.aiProviderOptions()
        if (index < 0 || index >= options.length)
            return options.length > 0 ? options[0] : ({ id: "ollama", name: "ollama" })
        return options[index]
    }

    function aiModelOptions(providerIndex) {
        var revision = root.hasSettings ? SettingsVM.aiModelsRevision : 0
        var provider = root.aiProviderAt(providerIndex)
        var providerId = provider.name || provider.id || (root.hasSettings ? SettingsVM.aiProvider : "ollama")
        var config = root.hasSettings ? SettingsVM.getAiProviderConfig(providerId) : ({})
        var runtimeModels = root.hasSettings ? SettingsVM.getAiRuntimeModels(providerId) : []
        var values = []

        function add(value) {
            var text = String(value || "").trim()
            if (text.length > 0 && values.indexOf(text) < 0)
                values.push(text)
        }

        add(config.model)
        add(provider.defaultModel)
        if (provider.models) {
            for (var i = 0; i < provider.models.length; i++)
                add(provider.models[i])
        }
        if (runtimeModels) {
            for (var j = 0; j < runtimeModels.length; j++)
                add(runtimeModels[j])
        }
        if (root.hasSettings && providerId === SettingsVM.aiProvider)
            add(SettingsVM.aiModel)
        if (values.length === 0)
            values.push("custom-model")
        return values
    }

    function aiModelIndex(providerIndex) {
        var provider = root.aiProviderAt(providerIndex)
        var providerId = provider.name || provider.id || (root.hasSettings ? SettingsVM.aiProvider : "ollama")
        var config = root.hasSettings ? SettingsVM.getAiProviderConfig(providerId) : ({})
        var selected = String(config.model || (providerId === SettingsVM.aiProvider ? SettingsVM.aiModel : provider.defaultModel) || "")
        var models = root.aiModelOptions(providerIndex)
        var index = models.indexOf(selected)
        return index >= 0 ? index : 0
    }

    function applyAiProviderDefaults(provider) {
        if (!provider || !root.hasSettings)
            return
        if (typeof aiEndpointInput === "undefined"
                || typeof aiModelCombo === "undefined"
                || typeof providerCombo === "undefined"
                || typeof aiTemperatureInput === "undefined"
                || typeof aiMaxTokensSpin === "undefined"
                || typeof aiProviderConfigEditor === "undefined")
            return
        var providerId = provider.name || provider.id || "ollama"
        var config = SettingsVM.getAiProviderConfig(providerId)
        aiEndpointInput.text = config.endpoint || provider.endpoint || ""
        aiModelCombo.model = root.aiModelOptions(providerCombo.currentIndex)
        aiModelCombo.currentIndex = root.aiModelIndex(providerCombo.currentIndex)
        aiModelCombo.editText = config.model || provider.defaultModel || ((provider.models && provider.models.length > 0) ? provider.models[0] : aiModelCombo.currentText)
        aiTemperatureInput.text = String(config.temperature !== undefined ? config.temperature : SettingsVM.aiTemperature)
        aiMaxTokensSpin.value = Number(config.maxTokens !== undefined ? config.maxTokens : SettingsVM.aiMaxTokens)
        aiProviderConfigEditor.text = SettingsVM.getAiProviderConfigJson(providerId)
    }

    function aiProviderOwnerText(index) {
        var provider = root.aiProviderAt(index)
        return (provider.plugin || "core") + " · " + (provider.providerType || "custom")
    }

    function aiProviderCapabilitiesText(index) {
        var provider = root.aiProviderAt(index)
        var bits = []
        var runtimeModels = root.hasSettings ? SettingsVM.getAiRuntimeModels(provider.name || provider.id || "") : []
        if (provider.requiresApiKey)
            bits.push("API key")
        if (provider.models && provider.models.length > 0)
            bits.push(String(provider.models.length) + " models")
        if (runtimeModels && runtimeModels.length > 0)
            bits.push(String(runtimeModels.length) + " live")
        if (provider.configSchema && Object.keys(provider.configSchema).length > 0)
            bits.push("schema")
        return bits.length > 0 ? bits.join(" · ") : "No extra capability declared"
    }

    function lspProviderOptions(language) {
        var lang = language || "python"
        var options = (typeof PluginVM !== "undefined" && PluginVM) ? PluginVM.getLspProviderOptions(lang) : []
        if (!options || options.length === 0)
            options = [{ id: "python.ty", name: "python.ty", label: "ty", displayName: "ty", language: "python", plugin: "core", command: "ty", args: ["server"], capabilities: ["hover", "completion", "diagnostics", "symbols"] }]
        return options
    }

    function lspProviderIds(language) {
        var options = root.lspProviderOptions(language)
        var ids = []
        for (var i = 0; i < options.length; i++)
            ids.push(options[i].name || options[i].id)
        return ids
    }

    function lspProviderAt(language, index) {
        var options = root.lspProviderOptions(language)
        if (index < 0 || index >= options.length)
            return options.length > 0 ? options[0] : ({ id: "", name: "" })
        return options[index]
    }

    function lspProviderIndex(language, providerId) {
        var ids = root.lspProviderIds(language)
        var index = ids.indexOf(providerId)
        return index >= 0 ? index : 0
    }

    function formatterOptions(language, extension) {
        var options = (typeof PluginVM !== "undefined" && PluginVM)
                    ? PluginVM.getFileFormatterOptions(language || "", extension || "")
                    : []
        return options && options.length > 0 ? options : []
    }

    function formatterAt(language, extension, index) {
        var options = root.formatterOptions(language, extension)
        if (index < 0 || index >= options.length)
            return options.length > 0 ? options[0] : ({ id: "", name: "", displayName: "No formatter" })
        return options[index]
    }

    function formatterIndex(language, extension, formatterId) {
        var options = root.formatterOptions(language, extension)
        for (var i = 0; i < options.length; i++) {
            var id = options[i].name || options[i].id || ""
            if (id === formatterId)
                return i
        }
        return 0
    }

    function formatterSummary(formatter) {
        formatter = formatter || ({})
        if (!formatter.id && !formatter.name)
            return "No formatter provider available"
        var args = formatter.args && formatter.args.length > 0 ? " " + formatter.args.join(" ") : ""
        return (formatter.plugin || "core") + " · " + (formatter.command || "") + args
    }

    function saveFormatterTarget(target, formatterId) {
        if (!root.hasSettings || !formatterId || !target)
            return
        root.runSettingAction("settings:formatter:" + target.language, "Applying formatter settings…", "Formatter settings applied.", function() {
            SettingsVM.setDefaultFormatterForLanguage(target.language, formatterId)
            var exts = target.extensions || [target.extension]
            for (var i = 0; i < exts.length; i++)
                SettingsVM.setDefaultFormatterForExtension(exts[i], formatterId)
        })
    }

    function lspProviderSummary(provider) {
        if (!provider)
            return "No provider selected"
        var args = provider.args && provider.args.length > 0 ? " " + provider.args.join(" ") : ""
        return (provider.plugin || "core") + " · " + (provider.command || "") + args
    }

    function lspCapabilitiesSummary(provider) {
        if (!provider || !provider.capabilities || provider.capabilities.length === 0)
            return "No capabilities declared"
        return provider.capabilities.join(" · ")
    }

    function lspInstallSummary(provider) {
        if (!provider || !provider.install || !provider.install.command)
            return "No installer declared"
        var args = provider.install.args || []
        return [provider.install.command].concat(args).join(" ")
    }

    function searchProviderOptions() {
        var options = (typeof PluginVM !== "undefined" && PluginVM) ? PluginVM.getSearchProviders() : []
        if (!options || options.length === 0)
            options = [{ id: "core.python", name: "core.python", label: "Core Python Search", plugin: "core", providerType: "python" }]
        return options
    }

    function searchProviderLabels() {
        var options = root.searchProviderOptions()
        var labels = []
        for (var i = 0; i < options.length; i++)
            labels.push(options[i].label || options[i].displayName || options[i].id || options[i].name)
        return labels
    }

    function searchProviderIndex(providerId) {
        var options = root.searchProviderOptions()
        for (var i = 0; i < options.length; i++) {
            if ((options[i].id || options[i].name) === providerId)
                return i
        }
        return 0
    }

    function searchProviderAt(index) {
        var options = root.searchProviderOptions()
        if (index < 0 || index >= options.length)
            return options.length > 0 ? options[0] : ({ id: "core.python", providerType: "python" })
        return options[index]
    }

    function lspProviderHasInstaller(provider) {
        return !!(provider && provider.install && provider.install.command)
    }

    function selectedLspProviderStatus() {
        if (!root.hasSettings || typeof lspProviderCombo === "undefined")
            return ({})
        return SettingsVM.lspProviderPreviewStatus(root.lspProviderAt(root.selectedLspLanguage, lspProviderCombo.currentIndex))
    }

    property string shortcutSearchText: ""
    property string pendingShortcutSequence: ""
    property string pendingShortcutWhen: "global"
    property string selectedLspLanguage: "python"
    property string pendingToolInstallKind: "lsp"
    property var pendingLspInstallProvider: ({})
    property var pendingLspInstallPreview: ({})

    Connections {
        target: root.hasSettings ? SettingsVM : null
        function onAiModelsChanged(provider, models) {
            if (typeof providerCombo === "undefined" || typeof aiModelCombo === "undefined")
                return
            var currentProvider = providerCombo.currentValue || providerCombo.currentText
            if (provider !== currentProvider)
                return
            aiModelCombo.model = root.aiModelOptions(providerCombo.currentIndex)
            aiModelCombo.currentIndex = root.aiModelIndex(providerCombo.currentIndex)
            if (models && models.length > 0)
                aiModelCombo.editText = models[0]
        }

        function onToolInstallAuditsChanged() {
            if (typeof lspToolAuditViewer === "undefined")
                return
            lspToolAuditViewer.text = JSON.stringify(SettingsVM.toolInstallAudits, null, 2)
        }
    }

    Popup {
        id: lspInstallConfirmPopup
        modal: true
        focus: true
        width: Math.min(560, root.width - 48)
        x: Math.max(24, (root.width - width) / 2)
        y: Math.max(24, (root.height - implicitHeight) / 2)
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: root.panel
            radius: DesignTokens.metrics.radiusLg
            border.width: 1
            border.color: root.border
        }

        contentItem: ColumnLayout {
            width: lspInstallConfirmPopup.width
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 18
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Approve Tool Install"
                    color: root.strongText
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: "Ember will execute this command without a shell. Review the command before approving."
                    color: root.muted
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                InfoPill {
                    title: "Provider"
                    value: root.pendingLspInstallPreview.providerId || "Unknown"
                }

                InfoPill {
                    title: "Plugin"
                    value: root.pendingLspInstallPreview.plugin || "core"
                }

                InfoPill {
                    title: "Command"
                    value: root.pendingLspInstallPreview.commandText || "No command"
                }

                Text {
                    Layout.fillWidth: true
                    text: root.pendingLspInstallPreview.description || "No description provided."
                    color: root.text
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    SettingButton {
                        text: "Cancel"
                        onClicked: lspInstallConfirmPopup.close()
                    }

                    SettingButton {
                        text: "Approve & install"
                        onClicked: {
                            if (root.hasSettings) {
                                root.notify("info", "Installer started", root.pendingLspInstallPreview.commandText || "Installing provider tool…")
                                if (root.pendingToolInstallKind === "search")
                                    SettingsVM.installSearchProviderTool(root.pendingLspInstallProvider, true)
                                else
                                    SettingsVM.installLspProviderTool(root.pendingLspInstallProvider, true)
                            }
                            lspInstallConfirmPopup.close()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bg

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 218
                radius: DesignTokens.metrics.radiusLg
                color: root.panel
                border.color: root.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: DesignTokens.metrics.radiusSm
                            color: "transparent"
                            border.color: root.border

                            Text {
                                anchors.centerIn: parent
                                text: "⚙"
                                color: root.strongText
                                font.pixelSize: 14
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "Settings"
                                color: root.text
                                font.pixelSize: 15
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "Editor preferences"
                                color: root.muted
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: root.border
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ColumnLayout {
                            width: Math.max(parent.width - 8, 150)
                            spacing: 6

                            Repeater {
                                model: root.settingsPages

                                delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 46
                            radius: DesignTokens.metrics.radiusMd
                            color: root.activePage === index ? root.cardHover : navMouse.containsMouse ? root.cardHover : "transparent"
                            border.color: "transparent"

                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activePage = index
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 12
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 2
                                    Layout.preferredHeight: 20
                                    radius: 1
                                    color: root.activePage === index ? root.accent : "transparent"
                                }

                                Rectangle {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 26
                                    radius: DesignTokens.metrics.radiusSm
                                    color: "transparent"

                                    Icon {
                                        anchors.centerIn: parent
                                        icon: modelData.icon
                                        color: root.activePage === index ? root.text : root.muted
                                        size: 18
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: modelData.title
                                        color: root.text
                                        font.pixelSize: 13
                                        font.bold: root.activePage === index
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.caption || ""
                                        color: root.muted
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        visible: false
                                    }
                                }
                            }
                        }
                            }

                        }
                    }

                    SettingButton {
                        Layout.fillWidth: true
                        text: "Reload configuration"
                        onClicked: {
                            if (!root.hasSettings) return
                            root.runSettingAction("settings:reload", "Reloading configuration…", "Configuration reloaded.", function() {
                                SettingsVM.reload()
                            })
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: DesignTokens.metrics.radiusLg
                color: root.bg
                border.color: "transparent"
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        color: root.bg
                        border.color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: root.settingsPages[Math.max(0, Math.min(root.activePage, root.settingsPages.length - 1))].title
                                    color: root.text
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                Text {
                                    text: "Project settings override global settings."
                                    color: root.muted
                                    font.pixelSize: 13
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 10
                                Layout.preferredHeight: 10
                                radius: 4
                                color: root.hasSettings ? (root.theme.success || "#98C379") : (root.theme.warning || "#D19A66")
                            }

                            Text {
                                text: root.hasSettings ? "Live" : "Readonly"
                                color: root.muted
                                font.pixelSize: 12
                            }
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            width: Math.max(560, parent.width - 48)
                            spacing: 42
                            anchors.margins: 24

                            Loader {
                                Layout.fillWidth: true
                                sourceComponent: root.settingsPages[Math.max(0, Math.min(root.activePage, root.settingsPages.length - 1))].component
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: editorPage

        ColumnLayout {
            spacing: 42

            SectionCard {
                title: "UI Typography"
                subtitle: "Application interface font. Keep it separate from code editor fonts."

                SettingRow {
                    title: "UI font family"
                    description: "Used by menus, sidebars, panels and settings."
                    SettingComboBox {
                        id: uiFontFamilyCombo
                        Layout.preferredWidth: 220
                        model: root.uiFontFamilyOptions()
                        currentIndex: root.hasSettings ? Math.max(0, model.indexOf(SettingsVM.uiFontFamily)) : 0
                    }
                }

                SettingRow {
                    title: "UI font size"
                    description: "General application text size in points."
                    SettingSpinBox {
                        id: uiFontSizeSpin
                        from: 10
                        to: 22
                        value: root.hasSettings ? SettingsVM.uiFontSize : 12
                        editable: true
                    }
                }

                SettingButton {
                    text: "Apply UI typography"
                    onClicked: {
                        if (!root.hasSettings) return
                        root.runSettingAction("settings:ui-typography", "Applying UI typography…", "UI typography applied.", function() {
                            SettingsVM.setUiFont(uiFontFamilyCombo.currentText, uiFontSizeSpin.value)
                        })
                    }
                }
            }

            SectionCard {
                title: "Editor Typography"
                subtitle: "Font and spacing used by the code editor."

                SettingRow {
                    title: "Font family"
                    description: "Provided by the selected appearance font provider."
                    SettingComboBox {
                        id: fontFamilyCombo
                        Layout.preferredWidth: 220
                        model: root.fontFamilyOptions()
                        currentIndex: root.hasSettings ? Math.max(0, model.indexOf(SettingsVM.fontFamily)) : 0
                    }
                }

                SettingRow {
                    title: "Font size"
                    description: "Editor text size in points."
                    SettingSpinBox {
                        id: fontSizeSpin
                        from: 9
                        to: 28
                        value: root.hasSettings ? SettingsVM.fontSize : 12
                        editable: true
                    }
                }

                SettingRow {
                    title: "Line spacing"
                    description: "Vertical breathing room between code lines."
                    SettingSpinBox {
                        id: lineSpacingSpin
                        from: 2
                        to: 16
                        value: root.hasSettings ? SettingsVM.editorLineSpacing : 6
                        editable: true
                    }
                }

                SettingButton {
                    text: "Apply typography"
                    onClicked: {
                        if (!root.hasSettings) return
                        root.runSettingAction("settings:typography", "Applying editor typography…", "Editor typography applied.", function() {
                            SettingsVM.setFont(fontFamilyCombo.currentText, fontSizeSpin.value)
                            SettingsVM.setEditorLineSpacing(lineSpacingSpin.value)
                        })
                    }
                }
            }

            SectionCard {
                title: "Editing"
                subtitle: "Editing defaults and hover behavior."

                SettingRow {
                    title: "Tab size"
                    description: "Number of columns represented by one tab character."
                    SettingSpinBox {
                        id: tabSizeSpin
                        from: 1
                        to: 12
                        value: root.hasSettings ? SettingsVM.tabSize : 4
                        editable: true
                    }
                }

                SettingRow {
                    title: "Hover delay"
                    description: "Delay before symbol documentation appears. Diagnostics stay instant."
                    SettingSpinBox {
                        id: hoverDelaySpin
                        from: 100
                        to: 3000
                        stepSize: 100
                        value: root.hasSettings ? SettingsVM.hoverDelayMs : 1000
                        editable: true
                    }
                }

                SettingRow {
                    title: "Word wrap"
                    description: "Wrap long lines when the editor renderer supports it."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.wordWrap : false
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setWordWrap(checked)
                            root.notify("success", "Settings updated", "Word wrap " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingRow {
                    title: "Rulers"
                    description: "Comma-separated visual columns, for example 80, 100."
                    SettingTextField {
                        id: rulersInput
                        Layout.preferredWidth: 180
                        text: root.hasSettings ? SettingsVM.rulersCsv : "80, 100"
                        placeholderText: "80, 100"
                    }
                }

                SettingButton {
                    text: "Apply editing"
                    onClicked: {
                        if (!root.hasSettings) return
                        root.runSettingAction("settings:editing", "Applying editing settings…", "Editing settings applied.", function() {
                            SettingsVM.setTabSize(tabSizeSpin.value)
                            SettingsVM.setHoverDelayMs(hoverDelaySpin.value)
                            SettingsVM.setRulersCsv(rulersInput.text)
                        })
                    }
                }
            }

            SectionCard {
                title: "Save Behavior"
                subtitle: "File cleanup and autosave policy."

                SettingRow {
                    title: "Autosave"
                    description: "Persisted setting for the editor autosave flow."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.autoSaveEnabled : false
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setAutoSaveEnabled(checked)
                            root.notify("success", "Settings updated", "Autosave " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingRow {
                    title: "Autosave delay"
                    description: "Delay in milliseconds before autosave runs after edits."
                    SettingSpinBox {
                        id: autoSaveDelaySpin
                        from: 250
                        to: 10000
                        stepSize: 250
                        value: root.hasSettings ? SettingsVM.autoSaveDelayMs : 1200
                        editable: true
                    }
                }

                SettingRow {
                    title: "Trim trailing whitespace"
                    description: "Remove spaces and tabs at line ends when saving."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.trimTrailingWhitespace : true
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setTrimTrailingWhitespace(checked)
                            root.notify("success", "Settings updated", "Trailing whitespace cleanup " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingRow {
                    title: "Insert final newline"
                    description: "Ensure saved text files end with a newline."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.insertFinalNewline : true
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setInsertFinalNewline(checked)
                            root.notify("success", "Settings updated", "Final newline " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingButton {
                    text: "Apply save behavior"
                    onClicked: {
                        if (!root.hasSettings) return
                        root.runSettingAction("settings:save-behavior", "Applying save behavior…", "Save behavior applied.", function() {
                            SettingsVM.setAutoSaveDelayMs(autoSaveDelaySpin.value)
                        })
                    }
                }
            }

            SectionCard {
                title: "Suggestions"
                subtitle: "Completion popup timing and documentation behavior."

                SettingRow {
                    title: "Automatic suggestions"
                    description: "Open completion candidates while typing when language services are available."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.suggestionsAuto : true
                        onToggled: if (root.ready && root.hasSettings) SettingsVM.setSuggestionsAuto(checked)
                    }
                }

                SettingRow {
                    title: "Suggestion delay"
                    description: "Debounce in milliseconds before requesting completion candidates."
                    SettingSpinBox {
                        id: suggestionsDelaySpin
                        from: 0
                        to: 2000
                        stepSize: 20
                        value: root.hasSettings ? SettingsVM.suggestionsDelayMs : 260
                        editable: true
                    }
                }

                SettingRow {
                    title: "Space toggles details"
                    description: "Use Space inside the suggestion popup to show or hide documentation details."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.suggestionsDetailsOnSpace : true
                        onToggled: if (root.ready && root.hasSettings) SettingsVM.setSuggestionsDetailsOnSpace(checked)
                    }
                }

                SettingButton {
                    text: "Apply suggestions"
                    onClicked: {
                        if (!root.hasSettings) return
                        root.runSettingAction("settings:suggestions", "Applying suggestion settings…", "Suggestion settings applied.", function() {
                            SettingsVM.setSuggestionsDelayMs(suggestionsDelaySpin.value)
                        })
                    }
                }
            }

            SectionCard {
                title: "Hover & Diagnostics"
                subtitle: "Editor-side debounce values. Diagnostics decorations remain immediate once received."

                SettingRow {
                    title: "Diagnostics delay"
                    description: "Debounce in milliseconds before publishing diagnostics after edits."
                    SettingSpinBox {
                        id: diagnosticsDelaySpin
                        from: 0
                        to: 5000
                        stepSize: 100
                        value: root.hasSettings ? SettingsVM.diagnosticsDelayMs : 1600
                        editable: true
                    }
                }

                SettingRow {
                    title: "Symbols delay"
                    description: "Debounce before refreshing document symbols for hover/context metadata."
                    SettingSpinBox {
                        id: symbolsDelaySpin
                        from: 100
                        to: 5000
                        stepSize: 100
                        value: root.hasSettings ? SettingsVM.symbolsDelayMs : 1400
                        editable: true
                    }
                }

                SettingButton {
                    text: "Apply diagnostics timing"
                    onClicked: {
                        if (!root.hasSettings) return
                        root.runSettingAction("settings:diagnostics", "Applying diagnostics timing…", "Diagnostics timing applied.", function() {
                            SettingsVM.setDiagnosticsDelayMs(diagnosticsDelaySpin.value)
                            SettingsVM.setSymbolsDelayMs(symbolsDelaySpin.value)
                        })
                    }
                }
            }

            SectionCard {
                title: "Minimap"
                subtitle: "Code overview options."

                SettingRow {
                    title: "Show minimap"
                    description: "Display the code overview at the right edge of the editor."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.minimapEnabled : true
                        onToggled: if (root.ready && root.hasSettings) SettingsVM.setMinimapEnabled(checked)
                    }
                }

                SettingRow {
                    title: "Minimap width"
                    description: "Width in pixels."
                    SettingSpinBox {
                        id: minimapWidthSpin
                        from: 48
                        to: 180
                        stepSize: 4
                        value: root.hasSettings ? SettingsVM.minimapWidth : 96
                        editable: true
                    }
                }

                SettingRow {
                    title: "Diagnostics markers"
                    description: "Show error and warning markers inside the minimap."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.minimapDiagnostics : true
                        onToggled: if (root.ready && root.hasSettings) SettingsVM.setMinimapDiagnostics(checked)
                    }
                }

                SettingButton {
                    text: "Apply minimap"
                    onClicked: {
                        if (!root.hasSettings) return
                        root.runSettingAction("settings:minimap", "Applying minimap settings…", "Minimap settings applied.", function() {
                            SettingsVM.setMinimapWidth(minimapWidthSpin.value)
                        })
                    }
                }
            }
        }
    }

    Component {
        id: workbenchPage

        ColumnLayout {
            spacing: 42

            SectionCard {
                title: "Layout"
                subtitle: "Panels shown by default and their initial sizes."

                SettingRow {
                    title: "Activity bar"
                    description: "Left icon rail for explorer, search, git and extensions."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.activityBarVisible : true
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setActivityBarVisible(checked)
                            root.notify("success", "Settings updated", "Activity bar " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingRow {
                    title: "Left sidebar"
                    description: "Explorer and contextual panel visibility."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.sidebarVisible : true
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setSidebarVisible(checked)
                            root.notify("success", "Settings updated", "Left sidebar " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingRow {
                    title: "Bottom panel"
                    description: "Terminal/output panel visibility."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.panelVisible : false
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setPanelVisible(checked)
                            root.notify("success", "Settings updated", "Bottom panel " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingRow {
                    title: "Right panel"
                    description: "Optional assistant/details panel."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.rightPanelVisible : false
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setRightPanelVisible(checked)
                            root.notify("success", "Settings updated", "Right panel " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingRow {
                    title: "Sidebar width"
                    description: "Default width used when the left panel is opened."
                    SettingSpinBox {
                        id: sidebarWidthSpin
                        from: 180
                        to: 520
                        stepSize: 10
                        value: root.hasSettings ? SettingsVM.sidebarWidth : 280
                        editable: true
                    }
                }

                SettingRow {
                    title: "Bottom panel height"
                    description: "Default terminal/problems panel height."
                    SettingSpinBox {
                        id: panelHeightSpin
                        from: 120
                        to: 500
                        stepSize: 10
                        value: root.hasSettings ? SettingsVM.panelHeight : 240
                        editable: true
                    }
                }

                SettingRow {
                    title: "Right panel width"
                    description: "Default width used by the optional right panel."
                    SettingSpinBox {
                        id: rightPanelWidthSpin
                        from: 180
                        to: 520
                        stepSize: 10
                        value: root.hasSettings ? SettingsVM.rightPanelWidth : 320
                        editable: true
                    }
                }

                SettingButton {
                    text: "Apply layout sizes"
                    onClicked: {
                        if (!root.hasSettings) return
                        root.runSettingAction("settings:layout", "Applying layout sizes…", "Layout sizes applied.", function() {
                            SettingsVM.setSidebarWidth(sidebarWidthSpin.value)
                            SettingsVM.setPanelHeight(panelHeightSpin.value)
                            SettingsVM.setRightPanelWidth(rightPanelWidthSpin.value)
                        })
                    }
                }
            }

            SectionCard {
                title: "Files & Workspace"
                subtitle: "Workspace restore, explorer visibility and shared file exclusions."

                SettingRow {
                    title: "Restore last workspace"
                    description: "Reopen the last active project when Ember starts."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.filesRestoreWorkspace : true
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setFilesRestoreWorkspace(checked)
                            root.notify("success", "Settings updated", "Workspace restore " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingRow {
                    title: "File watcher"
                    description: "Persisted policy for external file change detection."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.filesWatcherEnabled : true
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setFilesWatcherEnabled(checked)
                            root.notify("success", "Settings updated", "File watcher " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingRow {
                    title: "Show hidden files"
                    description: "Show dotfiles in the file explorer and search when enabled."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.filesShowHidden : false
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setFilesShowHidden(checked)
                            root.notify("success", "Settings updated", "Hidden files " + (checked ? "shown." : "hidden."))
                        }
                    }
                }

                SettingRow {
                    title: "Confirm delete"
                    description: "Persisted policy for destructive file actions."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.filesConfirmDelete : true
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setFilesConfirmDelete(checked)
                            root.notify("success", "Settings updated", "Delete confirmation " + (checked ? "enabled." : "disabled."))
                        }
                    }
                }

                SettingRow {
                    title: "Exclude patterns"
                    description: "Comma-separated names ignored by explorer and search."
                    SettingTextField {
                        id: filesExcludeInput
                        Layout.preferredWidth: 360
                        text: root.hasSettings ? SettingsVM.filesExcludeCsv : "node_modules, target, .git"
                        placeholderText: "node_modules, target, .git"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }

                    SettingButton {
                        text: "Apply globally"
                        onClicked: {
                            if (!root.hasSettings) return
                            root.runSettingAction("settings:files", "Applying global file settings…", "Global file settings applied.", function() {
                                SettingsVM.setFilesExcludeCsv(filesExcludeInput.text, false)
                            })
                        }
                    }

                    SettingButton {
                        text: "Apply to project"
                        onClicked: {
                            if (!root.hasSettings) return
                            root.runSettingAction("settings:files-project", "Applying project file settings…", "Project file settings applied.", function() {
                                SettingsVM.setFilesExcludeCsv(filesExcludeInput.text, true)
                            })
                        }
                    }
                }
            }

            SectionCard {
                title: "Runtime State"
                subtitle: "Live UI state exposed by the workbench backend."

                InfoPill {
                    title: "UI font"
                    value: (typeof UiVM !== "undefined" && UiVM) ? UiVM.fontFamily + " · " + UiVM.fontSize + "pt" : "Unavailable"
                }

                InfoPill {
                    title: "Activity"
                    value: root.operationsSummary()
                }

                InfoPill {
                    title: "Notifications"
                    value: (typeof NotificationVM !== "undefined" && NotificationVM) ? String(NotificationVM.notifications.length) + " visible · " + String(NotificationVM.busyCount) + " active" : "Unavailable"
                }
            }
        }
    }

    Component {
        id: languagePage

        ColumnLayout {
            spacing: 42

            SectionCard {
                title: "Language Services"
                subtitle: "Language service behavior."

                SettingRow {
                    title: "Enable LSP"
                    description: "Start external language servers for symbols, hover and diagnostics."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.lspEnabled : true
                        onToggled: if (root.ready && root.hasSettings) SettingsVM.setLspEnabled(checked)
                    }
                }

                SettingRow {
                    title: "Diagnostics on type"
                    description: "Publish diagnostics while editing. Disable for very large files."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.diagnosticsOnType : true
                        onToggled: if (root.ready && root.hasSettings) SettingsVM.setDiagnosticsOnType(checked)
                    }
                }

                InfoPill {
                    title: "Active language"
                    value: root.selectedLspLanguage
                }
            }

            SectionCard {
                title: "LSP Providers"
                subtitle: "Language servers can come from core or active plugins. Ferrite remains the local parser/highlight fallback."

                SettingRow {
                    title: "Language"
                    description: "Select the language whose LSP provider chain you want to configure."
                    SettingComboBox {
                        id: lspLanguageCombo
                        Layout.preferredWidth: 180
                        model: ["python", "rust", "javascript", "typescript", "json", "toml"]
                        currentIndex: Math.max(0, model.indexOf(root.selectedLspLanguage))
                        onActivated: {
                            root.selectedLspLanguage = currentText
                            lspProvidersInput.text = root.hasSettings ? SettingsVM.getLspProvidersCsv(root.selectedLspLanguage) : root.lspProviderIds(root.selectedLspLanguage).join(", ")
                            lspProviderCombo.model = root.lspProviderOptions(root.selectedLspLanguage)
                            lspProviderCombo.currentIndex = 0
                            lspProviderConfigEditor.text = root.hasSettings ? SettingsVM.getLspProviderConfigJson(lspProviderCombo.currentValue || lspProviderCombo.currentText) : "{}"
                        }
                    }
                }

                SettingRow {
                    title: "Provider chain"
                    description: "Comma-separated provider ids. First capable provider wins for each feature."
                    SettingTextField {
                        id: lspProvidersInput
                        Layout.preferredWidth: 320
                        text: root.hasSettings ? SettingsVM.getLspProvidersCsv(root.selectedLspLanguage) : root.lspProviderIds(root.selectedLspLanguage).join(", ")
                        placeholderText: "python.ty, python.ruff"
                    }
                }

                SettingRow {
                    title: "Provider details"
                    description: "Inspect one discovered provider from core or active plugins."
                    SettingProviderComboBox {
                        id: lspProviderCombo
                        Layout.preferredWidth: 240
                        model: root.lspProviderOptions(root.selectedLspLanguage)
                        currentIndex: 0
                        onProviderActivated: lspProviderConfigEditor.text = root.hasSettings ? SettingsVM.getLspProviderConfigJson(currentValue || currentText) : "{}"
                    }
                }

                InfoPill {
                    title: "Command"
                    value: root.lspProviderSummary(root.lspProviderAt(root.selectedLspLanguage, lspProviderCombo.currentIndex))
                }

                InfoPill {
                    title: "Capabilities"
                    value: root.lspCapabilitiesSummary(root.lspProviderAt(root.selectedLspLanguage, lspProviderCombo.currentIndex))
                }

                InfoPill {
                    title: "Installer"
                    value: root.lspInstallSummary(root.lspProviderAt(root.selectedLspLanguage, lspProviderCombo.currentIndex))
                }

                ConfigTextArea {
                    id: lspProviderConfigEditor
                    Layout.preferredHeight: 150
                    text: root.hasSettings ? SettingsVM.getLspProviderConfigJson(lspProviderCombo.currentValue || lspProviderCombo.currentText) : "{}"
                }

                RowLayout {
                    spacing: 10

                    SettingButton {
                        text: "Apply provider chain"
                        onClicked: {
                            if (!root.hasSettings) return
                            root.runSettingAction("settings:lsp", "Applying LSP settings…", "LSP provider chain applied.", function() {
                                SettingsVM.setLspProvidersCsv(root.selectedLspLanguage, lspProvidersInput.text)
                            })
                        }
                    }

                    SettingButton {
                        text: "Save provider config"
                        onClicked: {
                            if (!root.hasSettings) return
                            var providerId = lspProviderCombo.currentValue || lspProviderCombo.currentText
                            var result = SettingsVM.saveLspProviderConfigJson(providerId, lspProviderConfigEditor.text)
                            root.notifyResult(result)
                        }
                    }

                    SettingButton {
                        text: "Install tool"
                        visible: root.lspProviderHasInstaller(root.lspProviderAt(root.selectedLspLanguage, lspProviderCombo.currentIndex))
                        busy: (typeof NotificationVM !== "undefined" && NotificationVM) ? NotificationVM.busy : false
                        onClicked: {
                            if (!root.hasSettings) return
                            var provider = root.lspProviderAt(root.selectedLspLanguage, lspProviderCombo.currentIndex)
                            root.pendingToolInstallKind = "lsp"
                            root.pendingLspInstallProvider = provider
                            root.pendingLspInstallPreview = SettingsVM.previewLspProviderToolInstall(provider)
                            lspInstallConfirmPopup.open()
                        }
                    }

                    SettingButton {
                        text: "Restart LSP"
                        actionId: "lsp.restart"
                        onClicked: {
                            if (typeof EditorVM === "undefined" || !EditorVM) return
                            root.notify("info", "Restarting LSP", "Language servers are restarting.")
                            if (typeof ActionVM === "undefined" || !ActionVM)
                                EditorVM.restartLsp()
                        }
                    }
                }
            }

            SectionCard {
                title: "Runtime Status"
                subtitle: "Live LSP and diagnostics state from the editor backend."

                InfoPill {
                    title: "Language"
                    value: (typeof StatusVM !== "undefined" && StatusVM) ? StatusVM.language : "Unavailable"
                }

                InfoPill {
                    title: "LSP"
                    value: (typeof StatusVM !== "undefined" && StatusVM) ? StatusVM.lspStatus : "Unavailable"
                }

                InfoPill {
                    title: "Servers"
                    value: (typeof StatusVM !== "undefined" && StatusVM) && StatusVM.lspDetails.length > 0 ? StatusVM.lspDetails : "No server details yet"
                }

                InfoPill {
                    title: "Diagnostics"
                    value: (typeof StatusVM !== "undefined" && StatusVM) ? String(StatusVM.errorCount) + " errors · " + String(StatusVM.warningCount) + " warnings" : "Unavailable"
                }

                RowLayout {
                    spacing: 10

                    SettingButton {
                        text: "Start LSP"
                        actionId: "lsp.start"
                        onClicked: {
                            if (typeof EditorVM === "undefined" || !EditorVM) return
                            root.notify("info", "Starting LSP", "Language servers are starting.")
                            if (typeof ActionVM === "undefined" || !ActionVM)
                                EditorVM.startLsp()
                        }
                    }

                    SettingButton {
                        text: "Stop LSP"
                        actionId: "lsp.stop"
                        onClicked: {
                            if (typeof EditorVM === "undefined" || !EditorVM) return
                            root.notify("warning", "Stopping LSP", "Language services will be unavailable until restarted.")
                            if (typeof ActionVM === "undefined" || !ActionVM)
                                EditorVM.stopLsp()
                        }
                    }

                    SettingButton {
                        text: "Refresh status"
                        actionId: "lsp.refresh_status"
                        onClicked: {
                            if (typeof EditorVM === "undefined" || !EditorVM) return
                            if (typeof ActionVM === "undefined" || !ActionVM)
                                EditorVM.refreshLspStatus()
                            root.notify("info", "LSP status refreshed", (typeof StatusVM !== "undefined" && StatusVM) ? StatusVM.lspStatus : "")
                        }
                    }
                }
            }

            SectionCard {
                title: "Provider Logs & Audit"
                subtitle: "Read-only provider status, command errors and approved tool install history."

                ConfigTextArea {
                    id: lspProviderStatusViewer
                    Layout.preferredHeight: 150
                    readOnly: true
                    text: JSON.stringify(root.selectedLspProviderStatus(), null, 2)
                }

                ConfigTextArea {
                    id: lspToolAuditViewer
                    Layout.preferredHeight: 190
                    readOnly: true
                    text: root.hasSettings ? JSON.stringify(SettingsVM.toolInstallAudits, null, 2) : "[]"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingButton {
                        text: "Refresh logs"
                        onClicked: {
                            if (root.hasSettings)
                                SettingsVM.refreshToolInstallAudits()
                            lspProviderStatusViewer.text = JSON.stringify(root.selectedLspProviderStatus(), null, 2)
                            lspToolAuditViewer.text = root.hasSettings ? JSON.stringify(SettingsVM.toolInstallAudits, null, 2) : "[]"
                            root.notify("info", "LSP logs refreshed", "Provider status and install audit refreshed.")
                        }
                    }

                    SettingButton {
                        text: "Refresh status"
                        onClicked: {
                            root.runSettingAction("settings:lsp-status", "Refreshing LSP status…", "LSP status refreshed.", function() {
                            if (typeof EditorVM !== "undefined" && EditorVM)
                                EditorVM.refreshLspStatus()
                            lspProviderStatusViewer.text = JSON.stringify(root.selectedLspProviderStatus(), null, 2)
                            })
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            SectionCard {
                title: "Formatting"
                subtitle: "Formatter behavior. Providers remain plugin/extensible."

                SettingRow {
                    title: "Format on save"
                    description: "Run the selected formatter before saving files."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.formatOnSave : false
                        onToggled: if (root.ready && root.hasSettings) SettingsVM.setFormatOnSave(checked)
                    }
                }

                Repeater {
                    model: root.formatterTargets
                    delegate: ColumnLayout {
                        required property var modelData
                        property var target: modelData
                        property var currentFormatter: root.formatterAt(
                            target.language,
                            target.extension,
                            formatterCombo.currentIndex
                        )
                        spacing: 8
                        Layout.fillWidth: true

                        SettingRow {
                            title: target.label
                            description: target.description
                            SettingProviderComboBox {
                                id: formatterCombo
                                Layout.preferredWidth: 260
                                model: root.formatterOptions(target.language, target.extension)
                                currentIndex: root.hasSettings
                                              ? root.formatterIndex(target.language, target.extension, SettingsVM.getDefaultFormatterForLanguage(target.language))
                                              : 0
                                onProviderActivated: function(providerName) {
                                    root.saveFormatterTarget(target, providerName)
                                }
                            }
                        }

                        InfoPill {
                            title: target.language + " command"
                            value: root.formatterSummary(currentFormatter)
                        }
                    }
                }

                InfoPill {
                    title: "Config priority"
                    value: ".ember/config.json → global config"
                }
            }
        }
    }

    Component {
        id: appearancePage

        ColumnLayout {
            spacing: 42

            SectionCard {
                title: "Appearance Providers"
                subtitle: "Choose which plugin owns each visual aspect of the application."

                SettingRow {
                    title: "Color theme"
                    description: "Theme selected from the active color/editor provider."
                    SettingComboBox {
                        id: themeCombo
                        model: root.hasSettings ? SettingsVM.availableThemes() : ["Ember Dark"]
                        currentIndex: root.hasSettings ? Math.max(0, model.indexOf(SettingsVM.currentTheme)) : 0
                        onActivated: if (root.ready && root.hasSettings) SettingsVM.applyTheme(currentText)
                    }
                }

                Repeater {
                    model: [
                        { aspect: "colors", title: "Colors", description: "Workbench colors and surfaces." },
                        { aspect: "editor", title: "Editor", description: "Syntax token colors and editor decorations." },
                        { aspect: "icons", title: "Icons", description: "Application and contributed icon assets." },
                        { aspect: "fileIcons", title: "File icons", description: "File and folder icon associations." },
                        { aspect: "fonts", title: "Fonts", description: "Application and editor font provider." },
                        { aspect: "borders", title: "Borders", description: "Radii, strokes and separator style." }
                    ]

                    delegate: SettingRow {
                        required property var modelData
                        title: modelData.title
                        description: modelData.description
                        SettingProviderComboBox {
                            aspect: modelData.aspect
                            model: root.appearanceProviderOptionObjects(modelData.aspect)
                            currentIndex: root.appearanceProviderIndex(modelData.aspect)
                            onProviderActivated: function(providerName) {
                                if (typeof PluginVM !== "undefined" && PluginVM)
                                    PluginVM.loadFontsFor(providerName)
                                if (root.ready && root.hasSettings)
                                    SettingsVM.setAppearanceProvider(modelData.aspect, providerName, false)
                            }
                        }
                    }
                }
            }

            SectionCard {
                title: "Override Keys"
                subtitle: "Project and global configs can override provider output."

                InfoPill {
                    title: "UI colors"
                    value: "appearance.themeOverrides"
                }

                InfoPill {
                    title: "Token colors"
                    value: "appearance.tokenColorOverrides"
                }
            }
        }
    }

    Component {
        id: searchPage

        ColumnLayout {
            spacing: 42

            SectionCard {
                title: "Search Provider"
                subtitle: "Choose the default workspace search engine and execution behavior."

                SettingRow {
                    title: "Default provider"
                    description: "Provider used by the Search panel when the workspace opens."
                    SettingComboBox {
                        id: searchProviderCombo
                        implicitWidth: 260
                        model: root.searchProviderLabels()
                        currentIndex: root.hasSettings ? root.searchProviderIndex(SettingsVM.searchProvider) : 0
                    }
                }

                InfoPill {
                    title: "Provider details"
                    value: {
                        var provider = root.searchProviderAt(searchProviderCombo.currentIndex)
                        return (provider.plugin || "core") + " · " + (provider.providerType || "python") + " · " + ((provider.capabilities || []).join(" · ") || "text")
                    }
                }

                InfoPill {
                    title: "Runtime"
                    value: {
                        if (!root.hasSettings)
                            return "Unavailable"
                        var status = SettingsVM.searchProviderPreviewStatus(root.searchProviderAt(searchProviderCombo.currentIndex))
                        if (status.available)
                            return "Ready · " + (status.resolvedCommand || status.command || "embedded")
                        return "Missing · " + (status.commandError || status.command || "No command")
                    }
                }

                InfoPill {
                    title: "Installer"
                    value: {
                        var provider = root.searchProviderAt(searchProviderCombo.currentIndex)
                        if (!provider.install || !provider.install.command)
                            return "No installer declared"
                        return [provider.install.command].concat(provider.install.args || []).join(" ")
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }

                    SettingButton {
                        text: "Install provider tool"
                        visible: root.lspProviderHasInstaller(root.searchProviderAt(searchProviderCombo.currentIndex))
                        busy: (typeof NotificationVM !== "undefined" && NotificationVM) ? NotificationVM.busy : false
                        onClicked: {
                            if (!root.hasSettings)
                                return
                            var provider = root.searchProviderAt(searchProviderCombo.currentIndex)
                            root.pendingToolInstallKind = "search"
                            root.pendingLspInstallProvider = provider
                            root.pendingLspInstallPreview = SettingsVM.previewSearchProviderToolInstall(provider)
                            root.notify("info", "Installer confirmation", "Review the command before installing " + (provider.displayName || provider.name || "provider") + ".")
                            lspInstallConfirmPopup.open()
                        }
                    }
                }
            }

            SectionCard {
                title: "Default Search Options"
                subtitle: "These defaults are persisted globally or in the active project override."

                SettingRow {
                    title: "Match case"
                    description: "Respect uppercase/lowercase while searching."
                    SettingSwitch {
                        id: searchCaseSwitch
                        checked: root.hasSettings ? SettingsVM.searchCaseSensitive : false
                    }
                }

                SettingRow {
                    title: "Regular expressions"
                    description: "Enable regex mode. The Python provider will ask for ripgrep for regex searches."
                    SettingSwitch {
                        id: searchRegexSwitch
                        checked: root.hasSettings ? SettingsVM.searchRegex : false
                    }
                }

                SettingRow {
                    title: "Include hidden files"
                    description: "Allow hidden files and folders when the selected provider supports it."
                    SettingSwitch {
                        id: searchHiddenSwitch
                        checked: root.hasSettings ? SettingsVM.searchIncludeHidden : false
                    }
                }

                SettingRow {
                    title: "Max results"
                    description: "Upper bound to keep the UI responsive on large workspaces."
                    SettingSpinBox {
                        id: searchMaxResultsSpin
                        from: 10
                        to: 10000
                        stepSize: 50
                        value: root.hasSettings ? SettingsVM.searchMaxResults : 500
                    }
                }

                SettingRow {
                    title: "Max file size"
                    description: "Files larger than this many bytes are skipped."
                    SettingSpinBox {
                        id: searchMaxFileSizeSpin
                        from: 1024
                        to: 50000000
                        stepSize: 1024
                        value: root.hasSettings ? SettingsVM.searchMaxFileSize : 512000
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }

                    SettingButton {
                        text: "Apply globally"
                        onClicked: {
                            if (!root.hasSettings)
                                return
                            var provider = root.searchProviderAt(searchProviderCombo.currentIndex)
                            root.runSettingAction("settings:search-global", "Saving search settings…", "Search settings saved globally.", function() {
                                SettingsVM.setSearchConfig(
                                    provider.id || provider.name || "core.python",
                                    searchCaseSwitch.checked,
                                    searchRegexSwitch.checked,
                                    searchHiddenSwitch.checked,
                                    searchMaxResultsSpin.value,
                                    searchMaxFileSizeSpin.value,
                                    false
                                )
                            })
                        }
                    }

                    SettingButton {
                        text: "Apply to project"
                        onClicked: {
                            if (!root.hasSettings)
                                return
                            var provider = root.searchProviderAt(searchProviderCombo.currentIndex)
                            root.runSettingAction("settings:search-project", "Saving project search settings…", "Project search settings saved.", function() {
                                SettingsVM.setSearchConfig(
                                    provider.id || provider.name || "core.python",
                                    searchCaseSwitch.checked,
                                    searchRegexSwitch.checked,
                                    searchHiddenSwitch.checked,
                                    searchMaxResultsSpin.value,
                                    searchMaxFileSizeSpin.value,
                                    true
                                )
                            })
                        }
                    }
                }
            }
        }
    }

    Component {
        id: shortcutsPage

        ColumnLayout {
            spacing: 42

            SectionCard {
                title: "Active Keybindings"
                subtitle: "Project/user overrides win over custom actions, active plugins and core fallback."

                SettingRow {
                    title: "Search"
                    description: "Filter by sequence, command, provider or source."
                    SettingTextField {
                        Layout.preferredWidth: 260
                        placeholderText: "Ctrl+S, save, plugin…"
                        text: root.shortcutSearchText
                        onTextChanged: root.shortcutSearchText = text
                    }
                }

                Repeater {
                    model: root.shortcutBindings()

                    delegate: ShortcutBindingRow {
                        required property var modelData
                        keySequence: modelData.key || ""
                        commandId: modelData.command || ""
                        commandTitle: root.commandTitle(modelData.command || "")
                        commandCategory: root.commandCategory(modelData.command || "")
                        pluginName: modelData.plugin || "core"
                        bindingId: modelData.id || ""
                        whenClause: modelData.when || "global"
                        source: modelData.source || "plugin"
                        active: modelData.active || false
                        disabled: modelData.disabled || false
                        conflict: modelData.conflict || false
                        conflicts: modelData.conflicts || []
                        onResetRequested: {
                            if (root.hasSettings && source === "override")
                                SettingsVM.clearKeybindingOverride(keySequence, false)
                        }
                        onDisableRequested: {
                            if (root.hasSettings && source === "custom")
                                SettingsVM.setCustomKeybindingDisabled(bindingId, true, false)
                        }
                        onEnableRequested: {
                            if (root.hasSettings && source === "custom")
                                SettingsVM.setCustomKeybindingDisabled(bindingId, false, false)
                        }
                        onRemoveRequested: {
                            if (root.hasSettings && source === "custom")
                                SettingsVM.removeCustomKeybinding(bindingId, false)
                        }
                    }
                }

                EmptyState {
                    visible: root.shortcutBindings().length === 0
                    title: "No plugin keybindings active"
                    subtitle: "Fallback core shortcuts remain available, but no active plugin is currently contributing bindings."
                }
            }

            SectionCard {
                title: "Custom Shortcut"
                subtitle: "Create a user binding. If it conflicts, it wins by priority but the conflict stays visible."

                SettingRow {
                    title: "Key sequence"
                    description: "Use Qt-style sequences like Ctrl+Alt+T or Ctrl+Shift+P."
                    SettingTextField {
                        id: customShortcutSequence
                        Layout.preferredWidth: 180
                        placeholderText: "Ctrl+Alt+T"
                        onTextChanged: root.pendingShortcutSequence = text
                    }
                }

                SettingRow {
                    title: "Command"
                    description: "Action executed by this shortcut."
                    SettingComboBox {
                        id: customShortcutCommand
                        Layout.preferredWidth: 260
                        model: root.commandIds()
                    }
                }

                SettingRow {
                    title: "When"
                    description: "Activation scope for conflict detection."
                    SettingComboBox {
                        id: customShortcutWhen
                        Layout.preferredWidth: 160
                        model: ["global", "editorFocus", "terminalFocus", "commandPaletteFocus"]
                        onActivated: root.pendingShortcutWhen = currentText
                    }
                }

                Rectangle {
                    visible: customShortcutSequence.text.length > 0 && root.shortcutConflictsFor(customShortcutSequence.text, customShortcutWhen.currentText).length > 0
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: DesignTokens.metrics.radiusMd
                    color: Qt.rgba(root.warning.r, root.warning.g, root.warning.b, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(root.warning.r, root.warning.g, root.warning.b, 0.42)

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        text: {
                            var conflicts = root.shortcutConflictsFor(customShortcutSequence.text, customShortcutWhen.currentText)
                            var labels = []
                            for (var i = 0; i < conflicts.length; i++)
                                labels.push(conflicts[i].command + " (" + conflicts[i].source + "/" + conflicts[i].plugin + ")")
                            return "Conflict detected: " + labels.join(" · ")
                        }
                        color: root.warning
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    spacing: 10

                    SettingButton {
                        text: "Add custom"
                        onClicked: {
                            if (!root.hasSettings || customShortcutSequence.text.length === 0 || customShortcutCommand.currentText.length === 0)
                                return
                            var sequence = customShortcutSequence.text
                            SettingsVM.addCustomKeybinding(customShortcutSequence.text, customShortcutCommand.currentText, customShortcutWhen.currentText, root.commandTitle(customShortcutCommand.currentText), false)
                            customShortcutSequence.text = ""
                            root.notify("success", "Shortcut added", sequence + " registered.")
                        }
                    }

                    SettingButton {
                        text: "Force override"
                        onClicked: {
                            if (!root.hasSettings || customShortcutSequence.text.length === 0 || customShortcutCommand.currentText.length === 0)
                                return
                            var sequence = customShortcutSequence.text
                            SettingsVM.setKeybindingOverride(customShortcutSequence.text, customShortcutCommand.currentText, customShortcutWhen.currentText, false)
                            customShortcutSequence.text = ""
                            root.notify("success", "Shortcut override applied", sequence + " now overrides conflicts.")
                        }
                    }
                }
            }
        }
    }

    Component {
        id: aiPage

        ColumnLayout {
            spacing: 42

            SectionCard {
                title: "AI Assistance"
                subtitle: "AI completion and provider settings."

                SettingRow {
                    title: "Inline suggestions"
                    description: "Allow ghost-text suggestions in the editor."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.aiInlineSuggestions : true
                        onToggled: if (root.ready && root.hasSettings) SettingsVM.setAiInlineSuggestions(checked)
                    }
                }

                SettingRow {
                    title: "Provider"
                    description: "Core or plugin-contributed AI backend."
                    SettingProviderComboBox {
                        id: providerCombo
                        Layout.preferredWidth: 180
                        model: root.aiProviderOptions()
                        currentIndex: root.aiProviderIndex()
                        onProviderActivated: root.applyAiProviderDefaults(root.aiProviderAt(currentIndex))
                    }
                }

                SettingRow {
                    title: "Model"
                    description: "Available models declared by the selected provider. Custom names remain allowed."
                    SettingEditableComboBox {
                        id: aiModelCombo
                        Layout.preferredWidth: 218
                        model: root.aiModelOptions(providerCombo.currentIndex)
                        currentIndex: root.aiModelIndex(providerCombo.currentIndex)
                        placeholderText: "codellama:7b, gpt-4.1-mini…"
                        Component.onCompleted: editText = root.hasSettings ? SettingsVM.aiModel : currentText
                    }
                }

                SettingRow {
                    title: "Endpoint"
                    description: "Local or remote provider endpoint."
                    SettingTextField {
                        id: aiEndpointInput
                        Layout.preferredWidth: 280
                        text: root.hasSettings ? SettingsVM.aiEndpoint : "http://localhost:11434"
                        placeholderText: "http://localhost:11434"
                    }
                }

                SettingRow {
                    title: "Temperature"
                    description: "Creativity level from 0.0 to 2.0."
                    SettingTextField {
                        id: aiTemperatureInput
                        Layout.preferredWidth: 90
                        text: root.hasSettings ? String(SettingsVM.aiTemperature) : "0.2"
                        placeholderText: "0.2"
                    }
                }

                SettingRow {
                    title: "Max tokens"
                    description: "Upper bound for generated responses."
                    SettingSpinBox {
                        id: aiMaxTokensSpin
                        from: 64
                        to: 32000
                        stepSize: 64
                        value: root.hasSettings ? SettingsVM.aiMaxTokens : 1024
                        editable: true
                    }
                }

                SettingButton {
                    text: "Apply AI provider"
                    onClicked: {
                        if (!root.hasSettings) return
                        var temperature = Number(aiTemperatureInput.text)
                        if (isNaN(temperature)) temperature = 0.2
                        var providerId = providerCombo.currentValue || providerCombo.currentText
                        var selectedModel = aiModelCombo.editText.length > 0 ? aiModelCombo.editText : aiModelCombo.currentText
                        root.runSettingAction("settings:ai-provider", "Applying AI provider…", "AI provider settings applied.", function() {
                            SettingsVM.setAiConfig(providerId, selectedModel, aiEndpointInput.text, temperature, aiMaxTokensSpin.value)
                            if (typeof ChatVM !== "undefined" && ChatVM)
                                ChatVM.saveAiConfig(providerId, selectedModel, aiEndpointInput.text, temperature, aiMaxTokensSpin.value)
                            aiProviderConfigEditor.text = SettingsVM.getAiProviderConfigJson(providerId)
                        })
                    }
                }
            }

            SectionCard {
                title: "Provider Extension Config"
                subtitle: "Provider-specific JSON owned by core or plugin providers. Plugins can read this config via Settings permissions."

                InfoPill {
                    title: "Owner"
                    value: root.aiProviderOwnerText(providerCombo.currentIndex)
                }

                InfoPill {
                    title: "Capabilities"
                    value: root.aiProviderCapabilitiesText(providerCombo.currentIndex)
                }

                ConfigTextArea {
                    id: aiProviderConfigEditor
                    Layout.preferredHeight: 170
                    text: root.hasSettings ? SettingsVM.getAiProviderConfigJson(SettingsVM.aiProvider) : "{}"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingButton {
                        text: "Load selected"
                        onClicked: root.applyAiProviderDefaults(root.aiProviderAt(providerCombo.currentIndex))
                    }

                    SettingButton {
                        text: "Refresh models"
                        actionId: "ai.refresh_models"
                        actionPayload: {
                            var provider = root.aiProviderAt(providerCombo.currentIndex)
                            return {
                                "providerId": providerCombo.currentValue || providerCombo.currentText,
                                "endpoint": aiEndpointInput.text || provider.endpoint || "",
                                "providerType": provider.providerType || ""
                            }
                        }
                        onClicked: {
                            if (!root.hasSettings) return
                            var provider = root.aiProviderAt(providerCombo.currentIndex)
                            var providerId = providerCombo.currentValue || providerCombo.currentText
                            var endpoint = aiEndpointInput.text || provider.endpoint || ""
                            if (typeof ActionVM === "undefined" || !ActionVM)
                                SettingsVM.refreshAiProviderModels(providerId, endpoint, provider.providerType || "")
                            root.notify("info", "Refreshing models", providerId + " model list refresh started.")
                        }
                    }

                    SettingButton {
                        text: "Save provider config"
                        onClicked: {
                            if (!root.hasSettings) return
                            var providerId = providerCombo.currentValue || providerCombo.currentText
                            var result = SettingsVM.saveAiProviderConfigJson(providerId, aiProviderConfigEditor.text)
                            root.notifyResult(result)
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            SectionCard {
                title: "Context & Cache"
                subtitle: "Controls how much context AI actions can use."

                SettingRow {
                    title: "Completion cache"
                    description: "Cache inline completion responses locally when available."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.aiCache : true
                        onToggled: if (root.ready && root.hasSettings) SettingsVM.setAiCache(checked)
                    }
                }

                SettingRow {
                    title: "Context characters"
                    description: "Maximum characters sent as editor context for chat/actions."
                    SettingSpinBox {
                        id: aiContextCharsSpin
                        from: 1000
                        to: 50000
                        stepSize: 1000
                        value: root.hasSettings ? SettingsVM.aiContextChars : 4000
                        editable: true
                    }
                }

                SettingButton {
                    text: "Apply context"
                    onClicked: {
                        if (!root.hasSettings) return
                        root.runSettingAction("settings:ai-context", "Applying AI context…", "AI context settings applied.", function() {
                            SettingsVM.setAiContextChars(aiContextCharsSpin.value)
                        })
                    }
                }
            }

            SectionCard {
                title: "Runtime State"
                subtitle: "Current AI integration state."

                InfoPill {
                    title: "Configured"
                    value: root.hasSettings ? SettingsVM.aiProvider + " · " + SettingsVM.aiModel : "Unavailable"
                }

                InfoPill {
                    title: "Endpoint"
                    value: root.hasSettings ? SettingsVM.aiEndpoint : "Unavailable"
                }

                InfoPill {
                    title: "Inline"
                    value: root.hasSettings && SettingsVM.aiInlineSuggestions ? "Enabled" : "Disabled"
                }
            }

            SectionCard {
                title: "Provider Notes"
                subtitle: "Current integration boundaries."

                InfoPill {
                    title: "Local"
                    value: "Ollama endpoint-compatible"
                }

                InfoPill {
                    title: "Cloud"
                    value: "OpenAI / Anthropic provider contract"
                }
            }
        }
    }

    Component {
        id: pluginsPage

        ColumnLayout {
            spacing: 42

            SectionCard {
                title: "Plugin Runtime"
                subtitle: "Global policy for Ember plugin execution."

                SettingRow {
                    title: "Enable plugins"
                    description: "Allow activated plugins to contribute commands, views, themes and editor features."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.extensionsEnabled : true
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setExtensionsEnabled(checked)
                            root.applyPluginPolicies()
                        }
                    }
                }

                SettingRow {
                    title: "Auto activate"
                    description: "Automatically activate enabled plugins after discovery."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.extensionsAutoActivate : true
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setExtensionsAutoActivate(checked)
                            root.applyPluginPolicies()
                        }
                    }
                }

                SettingRow {
                    title: "User plugins"
                    description: "Allow loading plugins from the user plugin directory."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.extensionsAllowUserPlugins : true
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setExtensionsAllowUserPlugins(checked)
                            root.applyPluginPolicies()
                        }
                    }
                }

                SettingRow {
                    title: "Network installs"
                    description: "Disabled by default. Local plugin directories remain supported."
                    SettingSwitch {
                        checked: root.hasSettings ? SettingsVM.extensionsAllowNetworkInstall : false
                        onToggled: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setExtensionsAllowNetworkInstall(checked)
                            root.applyPluginPolicies()
                        }
                    }
                }
            }

            SectionCard {
                title: "Proprietary Store"
                subtitle: "Marketplace endpoint and local development mirrors used by the Extensions panel."

                SettingRow {
                    title: "Store API"
                    description: "Base URL exposing /plugins and downloadable plugin archives."
                    SettingTextField {
                        id: marketplaceApiInput
                        Layout.preferredWidth: 360
                        text: root.hasSettings ? SettingsVM.extensionsMarketplaceApiUrl : "http://127.0.0.1:9865/api/marketplace"
                        placeholderText: "https://plugins.ember.dev/api/marketplace"
                        onEditingFinished: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setExtensionsMarketplaceApiUrl(text)
                            if (typeof PluginVM !== "undefined" && PluginVM)
                                PluginVM.loadPluginStore()
                        }
                    }
                }

                SettingRow {
                    title: "Local store sources"
                    description: "JSON array of local folders used only for development/offline plugin mirrors."
                    SettingTextField {
                        id: marketplaceLocalSourcesInput
                        Layout.preferredWidth: 360
                        text: root.hasSettings ? SettingsVM.extensionsMarketplaceLocalSourcesJson : "[]"
                        placeholderText: "[\"/path/to/plugins\"]"
                        onEditingFinished: {
                            if (!root.ready || !root.hasSettings) return
                            SettingsVM.setExtensionsMarketplaceLocalSourcesJson(text)
                            if (typeof PluginVM !== "undefined" && PluginVM)
                                PluginVM.loadPluginStore()
                        }
                    }
                }
            }

            SectionCard {
                title: "Installed Plugins"
                subtitle: "Compact overview. Full lifecycle controls remain in the Extensions panel."

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    InfoPill {
                        title: "Installed"
                        value: (typeof PluginVM !== "undefined" && PluginVM) ? String(PluginVM.getPluginStats().installed || 0) : "0"
                    }

                    InfoPill {
                        title: "Active"
                        value: (typeof PluginVM !== "undefined" && PluginVM) ? String(PluginVM.getPluginStats().active || 0) : "0"
                    }

                    InfoPill {
                        title: "Commands"
                        value: (typeof PluginVM !== "undefined" && PluginVM) ? String(PluginVM.getPluginStats().commands || 0) : "0"
                    }
                }

                Repeater {
                    model: (typeof PluginVM !== "undefined" && PluginVM) ? PluginVM.plugins : []

                    delegate: PluginSettingsRow {
                        required property var modelData
                        pluginId: modelData.id || ""
                        title: modelData.name || modelData.id || "Plugin"
                        subtitle: modelData.description || ""
                        version: modelData.version || "0.0.0"
                        active: modelData.active || false
                        pluginEnabled: modelData.enabled !== false
                        proprietary: modelData.proprietary || false
                        onToggleRequested: {
                            if (!PluginVM || pluginId.length === 0) return
                            if (active) PluginVM.deactivatePlugin(pluginId)
                            else PluginVM.activatePlugin(pluginId)
                        }
                    }
                }

                SettingButton {
                    text: "Reload plugins"
                    busy: (typeof NotificationVM !== "undefined" && NotificationVM) ? NotificationVM.busy : false
                    onClicked: {
                        if (typeof PluginVM === "undefined" || !PluginVM) return
                        root.notify("info", "Reloading plugins", "Plugin registry refresh started.")
                        PluginVM.loadPlugins()
                    }
                }
            }
        }
    }

    Component {
        id: actionsPage

        ColumnLayout {
            spacing: 42

            SectionCard {
                title: "Action Registry"
                subtitle: "Central registry used by buttons, command palette, plugins, panels and future automations."

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    InfoPill {
                        title: "Registered"
                        value: (typeof ActionVM !== "undefined" && ActionVM) ? String(ActionVM.actions.length) + " actions" : "Unavailable"
                    }

                    InfoPill {
                        title: "Running"
                        value: (typeof ActionVM !== "undefined" && ActionVM) ? String(ActionVM.runningActions.length) + " active" : "Unavailable"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: DesignTokens.metrics.radiusSm
                    color: root.inputBg
                    border.width: 1
                    border.color: actionSearchInput.activeFocus ? root.accent : root.border

                    TextField {
                        id: actionSearchInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        text: root.actionSearchText
                        placeholderText: "Filter actions by id, source, category..."
                        color: root.text
                        placeholderTextColor: root.dim
                        selectByMouse: true
                        font.pixelSize: 12
                        background: null
                        onTextChanged: root.actionSearchText = text
                    }
                }

                Repeater {
                    model: root.actionRows()

                    delegate: ActionRegistryRow {
                        Layout.fillWidth: true
                        actionId: modelData.id || ""
                        title: modelData.title || modelData.id || ""
                        category: modelData.category || "Action"
                        source: modelData.source || "core"
                        description: modelData.description || ""
                        requiresPayload: modelData.requiresPayload || false
                        permissions: modelData.permissions || []
                        requiresPermission: modelData.requiresPermission || false
                        safeToRun: modelData.safeToRun !== false
                        exposable: modelData.exposable !== false
                        shortcut: root.actionShortcut(modelData.id || "")
                        conflict: root.actionBinding(modelData.id || "").conflict || false
                        conflicts: root.actionBinding(modelData.id || "").conflicts || []
                        running: (typeof ActionVM !== "undefined" && ActionVM) ? ActionVM.isRunning(modelData.id || "") : false
                        onResolveConflictRequested: {
                            if (!root.hasSettings || shortcut.length === 0)
                                return
                            SettingsVM.setKeybindingOverride(shortcut, actionId, "global", false)
                            root.notify("success", "Shortcut conflict resolved", shortcut + " now runs " + actionId + ".")
                        }
                    }
                }
            }
        }
    }

    Component {
        id: configPage

        ColumnLayout {
            spacing: 42

            SectionCard {
                title: "Configuration Sources"
                subtitle: "Ember loads project overrides first, then global settings, then defaults."

                InfoPill {
                    title: "Priority"
                    value: ".ember/config.json → global config → defaults"
                }

                InfoPill {
                    title: "Global"
                    value: root.hasSettings ? SettingsVM.globalConfigPath : "Unavailable"
                }

                InfoPill {
                    title: "Project"
                    value: root.hasSettings && SettingsVM.projectConfigPath.length > 0 ? SettingsVM.projectConfigPath : "No active workspace config"
                }
            }

            SectionCard {
                title: "Global Config"
                subtitle: "User-wide settings stored outside projects."

                ConfigTextArea {
                    id: globalConfigEditor
                    Layout.preferredHeight: 220
                    text: root.hasSettings ? SettingsVM.globalConfigJson() : "{}"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingButton {
                        text: "Validate"
                        onClicked: {
                            configStatus.text = root.hasSettings ? SettingsVM.validateConfigJson(globalConfigEditor.text) : "Settings backend unavailable."
                            root.notifyResult(configStatus.text)
                        }
                    }

                    SettingButton {
                        text: "Save global"
                        onClicked: {
                            configStatus.text = root.hasSettings ? SettingsVM.saveGlobalConfigJson(globalConfigEditor.text) : "Settings backend unavailable."
                            root.notifyResult(configStatus.text)
                        }
                    }

                    SettingButton {
                        text: "Reload"
                        onClicked: {
                            if (!root.hasSettings) return
                            SettingsVM.reload()
                            globalConfigEditor.text = SettingsVM.globalConfigJson()
                            projectConfigEditor.text = SettingsVM.projectConfigJson()
                            mergedConfigViewer.text = JSON.stringify(SettingsVM.getConfig(), null, 2)
                            configStatus.text = "Configuration reloaded."
                            root.notify("info", "Settings reloaded", "Global and project config editors refreshed.")
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            SectionCard {
                title: "Project Overrides"
                subtitle: "Workspace-specific overrides saved in .ember/config.json."

                ConfigTextArea {
                    id: projectConfigEditor
                    Layout.preferredHeight: 220
                    text: root.hasSettings ? SettingsVM.projectConfigJson() : "{}"
                    opacity: root.hasSettings && SettingsVM.projectConfigPath.length > 0 ? 1 : 0.48
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingButton {
                        text: "Validate"
                        onClicked: {
                            configStatus.text = root.hasSettings ? SettingsVM.validateConfigJson(projectConfigEditor.text) : "Settings backend unavailable."
                            root.notifyResult(configStatus.text)
                        }
                    }

                    SettingButton {
                        text: "Save project"
                        onClicked: {
                            configStatus.text = root.hasSettings ? SettingsVM.saveProjectConfigJson(projectConfigEditor.text) : "Settings backend unavailable."
                            root.notifyResult(configStatus.text)
                        }
                    }

                    InfoPill {
                        Layout.fillWidth: true
                        title: "Status"
                        value: root.hasSettings && SettingsVM.projectConfigPath.length > 0 ? "Project overrides enabled" : "Open a project to enable overrides"
                    }
                }
            }

            SectionCard {
                title: "Resolved Config"
                subtitle: "Read-only merged configuration currently used by the editor."

                ConfigTextArea {
                    id: mergedConfigViewer
                    Layout.preferredHeight: 300
                    readOnly: true
                    text: root.hasSettings ? JSON.stringify(SettingsVM.getConfig(), null, 2) : "{}"
                }

                Text {
                    id: configStatus
                    Layout.fillWidth: true
                    text: "Ready."
                    color: text.indexOf("Invalid") === 0 || text.indexOf("Could not") === 0 ? root.error : root.muted
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingButton {
                        text: "Refresh resolved"
                        onClicked: {
                            if (!root.hasSettings) return
                            SettingsVM.reload()
                            mergedConfigViewer.text = JSON.stringify(SettingsVM.getConfig(), null, 2)
                            configStatus.text = "Resolved config refreshed."
                            root.notify("info", "Resolved config refreshed", "Current merged config was reloaded.")
                        }
                    }

                    SettingButton {
                        text: "Show defaults"
                        onClicked: {
                            if (!root.hasSettings) return
                            mergedConfigViewer.text = SettingsVM.defaultConfigJson()
                            configStatus.text = "Showing defaults only."
                            root.notify("info", "Showing defaults", "Resolved viewer now displays default config only.")
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }

    component ConfigTextArea: ScrollView {
        id: configArea
        property alias text: editor.text
        property alias readOnly: editor.readOnly
        property alias placeholderText: editor.placeholderText

        Layout.fillWidth: true
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded

        background: Rectangle {
            radius: DesignTokens.metrics.radiusMd
            color: root.bg
            border.width: 1
            border.color: editor.activeFocus ? root.accent : root.border
        }

        TextArea {
            id: editor
            readOnly: false
            selectByMouse: true
            wrapMode: TextEdit.NoWrap
            color: root.text
            selectedTextColor: root.strongText
            selectionColor: root.accent
            placeholderTextColor: root.dim
            font.family: root.hasSettings ? SettingsVM.fontFamily : "Menlo"
            font.pixelSize: 12
            leftPadding: 12
            rightPadding: 12
            topPadding: 10
            bottomPadding: 10
            background: null
        }

        ScrollBar.vertical.contentItem: Rectangle {
            implicitWidth: 5
            radius: 3
            color: root.muted
            opacity: 0.55
        }

        ScrollBar.horizontal.contentItem: Rectangle {
            implicitHeight: 5
            radius: 3
            color: root.muted
            opacity: 0.55
        }
    }

    component SectionCard: Item {
        id: cardRoot
        property string title: ""
        property string subtitle: ""
        default property alias contentData: body.data
        Layout.fillWidth: true
        implicitHeight: content.implicitHeight

        ColumnLayout {
            id: content
            anchors.fill: parent
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: cardRoot.title
                    color: root.strongText
                    font.pixelSize: 15
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: cardRoot.subtitle
                    color: root.muted
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.border
                opacity: 0.75
            }

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: 10
            }
        }
    }

    component SettingRow: Item {
        id: rowRoot
        property string title: ""
        property string description: ""
        default property alias controlData: controlSlot.data
        Layout.fillWidth: true
        implicitHeight: Math.max(62, content.implicitHeight + 20)

        RowLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 28

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: rowRoot.title
                    color: root.text
                    font.pixelSize: 13
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: rowRoot.description
                    color: root.muted
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Item {
                id: controlSlot
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.border
            opacity: 0.18
        }
    }

    component SettingToggle: SettingRow {
        property string key: ""
        property bool fallback: false
        SettingSwitch {
            checked: root.settingValue(key, fallback)
            onToggled: {
                if (!root.ready) return
                root.saveJson(key, checked, false)
                root.notify("success", "Settings updated", key + " = " + String(checked))
            }
        }
    }

    component SettingTextField: TextField {
        id: fieldRoot
        color: root.text
        selectedTextColor: root.strongText
        selectionColor: root.accent
        placeholderTextColor: root.dim
        font.pixelSize: 12
        leftPadding: 10
        rightPadding: 10
        background: Rectangle {
            implicitWidth: 180
            implicitHeight: 30
            radius: DesignTokens.metrics.radiusSm
            color: root.inputBg
            border.width: 1
            border.color: fieldRoot.activeFocus ? root.accent : root.border
        }
    }

    component SettingSpinBox: SpinBox {
        id: spinRoot
        editable: true
        implicitWidth: 96
        implicitHeight: 30
        contentItem: TextInput {
            z: 2
            text: spinRoot.textFromValue(spinRoot.value, spinRoot.locale)
            font.pixelSize: 12
            color: root.text
            selectionColor: root.accent
            selectedTextColor: root.strongText
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            leftPadding: 8
            rightPadding: 20
            readOnly: !spinRoot.editable
            validator: spinRoot.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
        background: Rectangle {
            radius: DesignTokens.metrics.radiusSm
            color: root.inputBg
            border.width: 1
            border.color: spinRoot.activeFocus ? root.accent : root.border
        }
        up.indicator: Text {
            x: spinRoot.width - width - 8
            y: 3
            text: "⌃"
            color: spinRoot.up.pressed ? root.strongText : root.muted
            font.pixelSize: 10
        }
        down.indicator: Text {
            x: spinRoot.width - width - 8
            y: spinRoot.height - height - 3
            text: "⌄"
            color: spinRoot.down.pressed ? root.strongText : root.muted
            font.pixelSize: 10
        }
    }

    component SettingSwitch: Switch {
        id: switchRoot
        implicitWidth: 34
        implicitHeight: 20
        indicator: Rectangle {
            width: 32
            height: 18
            x: 1
            y: 1
            radius: 10
            color: switchRoot.checked ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.48) : "transparent"
            border.color: switchRoot.checked ? root.accent : root.border

            Rectangle {
                width: 14
                height: 14
                radius: 7
                x: switchRoot.checked ? 16 : 2
                y: 2
                color: switchRoot.checked ? root.strongText : root.muted
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
        }
        contentItem: Item {}
    }

    component SettingComboBox: ComboBox {
        id: comboRoot
        implicitWidth: 180
        implicitHeight: 30
        contentItem: Text {
            leftPadding: 10
            rightPadding: 26
            text: comboRoot.displayText
            color: root.text
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: Text {
            x: comboRoot.width - width - 10
            y: (comboRoot.height - height) / 2
            text: "⌄"
            color: root.muted
            font.pixelSize: 12
        }
        background: Rectangle {
            radius: DesignTokens.metrics.radiusSm
            color: root.inputBg
            border.width: 1
            border.color: comboRoot.activeFocus ? root.accent : root.border
        }
        delegate: ItemDelegate {
            width: comboRoot.width
            height: 30
            text: modelData
            highlighted: comboRoot.highlightedIndex === index
            contentItem: Text {
                text: parent.text
                color: parent.highlighted ? root.strongText : root.text
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: parent.highlighted ? root.cardHover : root.panel
            }
        }
        popup: Popup {
            y: comboRoot.height + 4
            width: comboRoot.width
            implicitHeight: contentItem.implicitHeight
            padding: 1
            background: Rectangle {
                color: root.panel
                border.color: root.border
                radius: DesignTokens.metrics.radiusSm
            }
            contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, 180)
                model: comboRoot.popup.visible ? comboRoot.delegateModel : null
                currentIndex: comboRoot.highlightedIndex
            }
        }
    }

    component SettingEditableComboBox: ComboBox {
        id: editableComboRoot
        editable: true
        implicitWidth: 180
        implicitHeight: 30
        property string placeholderText: ""

        contentItem: TextInput {
            leftPadding: 10
            rightPadding: 26
            text: editableComboRoot.editText
            color: root.text
            selectionColor: root.accent
            selectedTextColor: root.strongText
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            clip: true
            selectByMouse: true
            inputMethodHints: Qt.ImhNoPredictiveText
            onTextEdited: editableComboRoot.editText = text

            Text {
                anchors.left: parent.left
                anchors.leftMargin: parent.leftPadding
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.text.length === 0 && editableComboRoot.placeholderText.length > 0
                text: editableComboRoot.placeholderText
                color: root.dim
                font.pixelSize: 12
            }
        }

        indicator: Text {
            x: editableComboRoot.width - width - 10
            y: (editableComboRoot.height - height) / 2
            text: "⌄"
            color: root.muted
            font.pixelSize: 12
        }

        background: Rectangle {
            radius: DesignTokens.metrics.radiusSm
            color: root.inputBg
            border.width: 1
            border.color: editableComboRoot.activeFocus ? root.accent : root.border
        }

        delegate: ItemDelegate {
            width: editableComboRoot.width
            height: 30
            text: modelData
            highlighted: editableComboRoot.highlightedIndex === index
            contentItem: Text {
                text: parent.text
                color: parent.highlighted ? root.strongText : root.text
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                color: parent.highlighted ? root.cardHover : root.panel
            }
        }

        popup: Popup {
            y: editableComboRoot.height + 4
            width: editableComboRoot.width
            implicitHeight: contentItem.implicitHeight
            padding: 1
            background: Rectangle {
                color: root.panel
                border.color: root.border
                radius: DesignTokens.metrics.radiusSm
            }
            contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, 180)
                model: editableComboRoot.popup.visible ? editableComboRoot.delegateModel : null
                currentIndex: editableComboRoot.highlightedIndex
            }
        }
    }

    component SettingProviderComboBox: ComboBox {
        id: providerCombo
        property string aspect: ""
        signal providerActivated(string providerName)

        textRole: "displayName"
        valueRole: "name"
        implicitWidth: 220
        implicitHeight: 30
        onActivated: providerActivated(currentValue)

        contentItem: Text {
            leftPadding: 10
            rightPadding: 26
            text: providerCombo.displayText
            color: root.text
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            x: providerCombo.width - width - 10
            y: (providerCombo.height - height) / 2
            text: "⌄"
            color: root.muted
            font.pixelSize: 12
        }

        background: Rectangle {
            radius: DesignTokens.metrics.radiusSm
            color: root.inputBg
            border.width: 1
            border.color: providerCombo.activeFocus ? root.accent : root.border
        }

        delegate: ItemDelegate {
            width: providerCombo.width
            height: 38
            highlighted: providerCombo.highlightedIndex === index

            contentItem: Item {
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 1

                    Text {
                        width: parent.width
                        text: modelData.displayName || modelData.name
                        color: providerCombo.highlightedIndex === index ? root.strongText : root.text
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: modelData.name
                        color: root.muted
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            background: Rectangle {
                color: parent.highlighted ? root.cardHover : root.panel
            }
        }

        popup: Popup {
            y: providerCombo.height + 4
            width: providerCombo.width
            implicitHeight: contentItem.implicitHeight
            padding: 1
            background: Rectangle {
                color: root.panel
                border.color: root.border
                radius: DesignTokens.metrics.radiusSm
            }
            contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, 220)
                model: providerCombo.popup.visible ? providerCombo.delegateModel : null
                currentIndex: providerCombo.highlightedIndex
            }
        }
    }

    component ShortcutBindingRow: Rectangle {
        property string bindingId: ""
        property string keySequence: ""
        property string commandId: ""
        property string commandTitle: ""
        property string commandCategory: ""
        property string pluginName: ""
        property string whenClause: ""
        property string source: "plugin"
        property bool active: true
        property bool disabled: false
        property bool conflict: false
        property var conflicts: []
        signal resetRequested()
        signal disableRequested()
        signal enableRequested()
        signal removeRequested()

        Layout.fillWidth: true
        implicitHeight: conflict ? 84 : 62
        radius: DesignTokens.metrics.radiusMd
        opacity: disabled ? 0.48 : (active ? 1 : 0.62)
        color: conflict ? Qt.rgba(root.warning.r, root.warning.g, root.warning.b, 0.08)
                        : (shortcutMouse.containsMouse ? root.cardHover : "transparent")
        border.width: 1
        border.color: conflict ? root.warning
                               : (shortcutMouse.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.26) : Qt.rgba(root.border.r, root.border.g, root.border.b, 0.45))

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 118
                Layout.preferredHeight: 28
                radius: DesignTokens.metrics.radiusSm
                color: root.inputBg
                border.width: 1
                border.color: root.border

                Text {
                    anchors.centerIn: parent
                    text: keySequence
                    color: root.strongText
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: commandTitle
                    color: root.text
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: commandId + " · " + commandCategory
                    color: root.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: conflict
                    text: "Conflict: " + conflicts.join(" | ")
                    color: root.warning
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 214
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: Math.max(54, sourceLabel.implicitWidth + 14)
                        Layout.preferredHeight: 20
                        radius: 10
                        color: source === "override" ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                             : source === "custom" ? Qt.rgba(root.success.r, root.success.g, root.success.b, 0.16)
                             : source === "core" ? Qt.rgba(1, 1, 1, 0.06)
                             : Qt.rgba(root.info.r, root.info.g, root.info.b, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            id: sourceLabel
                            anchors.centerIn: parent
                            text: source
                            color: root.text
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Text {
                    text: pluginName + " · " + whenClause
                    color: root.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    SettingButton {
                        visible: source === "override"
                        text: "Reset"
                        onClicked: {
                            root.notify("info", "Shortcut reset requested", commandId || keySequence)
                            resetRequested()
                        }
                    }

                    SettingButton {
                        visible: source === "custom" && disabled
                        text: "Enable"
                        onClicked: {
                            root.notify("info", "Shortcut enable requested", commandId || keySequence)
                            enableRequested()
                        }
                    }

                    SettingButton {
                        visible: source === "custom" && !disabled
                        text: "Disable"
                        onClicked: {
                            root.notify("info", "Shortcut disable requested", commandId || keySequence)
                            disableRequested()
                        }
                    }

                    SettingButton {
                        visible: source === "custom"
                        text: "Remove"
                        onClicked: {
                            root.notify("info", "Shortcut remove requested", commandId || keySequence)
                            removeRequested()
                        }
                    }
                }
            }
        }

        MouseArea {
            id: shortcutMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component ActionRegistryRow: Rectangle {
        property string actionId: ""
        property string title: ""
        property string category: ""
        property string source: ""
        property string description: ""
        property string shortcut: ""
        property bool conflict: false
        property var conflicts: []
        property bool requiresPayload: false
        property var permissions: []
        property bool requiresPermission: false
        property bool safeToRun: true
        property bool exposable: true
        property bool running: false
        signal resolveConflictRequested()

        Layout.fillWidth: true
        implicitHeight: conflict || requiresPermission || !exposable || !safeToRun ? 104 : 76
        radius: DesignTokens.metrics.radiusMd
        color: actionMouse.containsMouse ? root.cardHover : "transparent"
        border.width: 1
        border.color: conflict ? root.warning
                               : actionMouse.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24)
                                                           : Qt.rgba(root.border.r, root.border.g, root.border.b, 0.42)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 10
                color: running ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                               : Qt.rgba(root.muted.r, root.muted.g, root.muted.b, 0.10)
                border.width: 1
                border.color: running ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.42)
                                      : Qt.rgba(root.border.r, root.border.g, root.border.b, 0.7)

                Icon {
                    anchors.centerIn: parent
                    icon: running ? "sync" : "bolt"
                    color: running ? root.accent : root.muted
                    size: 18
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: title
                    color: root.text
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: actionId
                    color: root.muted
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                }

                Text {
                    Layout.fillWidth: true
                    visible: description.length > 0
                    text: description
                    color: root.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: conflict
                    text: "Shortcut conflict: " + conflicts.join(" | ")
                    color: root.warning
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 246
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: Math.max(60, categoryLabel.implicitWidth + 14)
                        Layout.preferredHeight: 22
                        radius: 11
                        color: Qt.rgba(root.info.r, root.info.g, root.info.b, 0.13)
                        border.width: 1
                        border.color: Qt.rgba(root.info.r, root.info.g, root.info.b, 0.28)

                        Text {
                            id: categoryLabel
                            anchors.centerIn: parent
                            text: category
                            color: root.info
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: Math.max(56, sourceLabel.implicitWidth + 14)
                        Layout.preferredHeight: 22
                        radius: 11
                        color: Qt.rgba(root.muted.r, root.muted.g, root.muted.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(root.border.r, root.border.g, root.border.b, 0.5)

                        Text {
                            id: sourceLabel
                            anchors.centerIn: parent
                            text: source
                            color: root.text
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: (shortcut.length > 0 ? shortcut + " · " : "")
                          + (requiresPayload ? "Context payload required" : "Palette executable")
                          + (requiresPermission ? " · Requires permission" : "")
                          + (!exposable ? " · Not agent-exposable" : "")
                    color: !safeToRun ? root.error : (requiresPayload || requiresPermission || !exposable ? root.warning : root.success)
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: permissions.length > 0
                    text: "Permissions: " + permissions.join(", ")
                    color: root.muted
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Item { Layout.fillWidth: true }

                    SettingButton {
                        visible: conflict && shortcut.length > 0
                        text: "Resolve"
                        onClicked: resolveConflictRequested()
                    }

                    SettingButton {
                        visible: !requiresPayload
                        text: running ? "Running" : "Run"
                        actionId: actionId
                        disabled: running
                    }
                }
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component PluginSettingsRow: Rectangle {
        property string pluginId: ""
        property string title: ""
        property string subtitle: ""
        property string version: ""
        property bool active: false
        property bool pluginEnabled: true
        property bool proprietary: false
        signal toggleRequested()

        Layout.fillWidth: true
        implicitHeight: 64
        radius: DesignTokens.metrics.radiusMd
        color: pluginMouse.containsMouse ? root.cardHover : "transparent"
        border.width: 1
        border.color: pluginMouse.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24)
                                               : Qt.rgba(root.border.r, root.border.g, root.border.b, 0.42)
        opacity: pluginEnabled ? 1 : 0.55

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 8
                color: active ? Qt.rgba(root.success.r, root.success.g, root.success.b, 0.16)
                              : Qt.rgba(root.muted.r, root.muted.g, root.muted.b, 0.10)
                border.width: 1
                border.color: active ? Qt.rgba(root.success.r, root.success.g, root.success.b, 0.38)
                                     : Qt.rgba(root.border.r, root.border.g, root.border.b, 0.7)

                Text {
                    anchors.centerIn: parent
                    text: active ? "●" : "○"
                    color: active ? root.success : root.muted
                    font.pixelSize: 12
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: title
                    color: root.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: subtitle
                    color: root.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Text {
                Layout.preferredWidth: 116
                text: version + (proprietary ? " · built-in" : "")
                color: root.muted
                font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

            SettingButton {
                text: active ? "Deactivate" : "Activate"
                onClicked: {
                    root.notify("info", active ? "Plugin deactivation requested" : "Plugin activation requested", pluginId || title)
                    toggleRequested()
                }
            }
        }

        MouseArea {
            id: pluginMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component EmptyState: Item {
        property string title: ""
        property string subtitle: ""

        Layout.fillWidth: true
        implicitHeight: 78

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width
            spacing: 4

            Text {
                text: title
                color: root.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            Text {
                text: subtitle
                color: root.muted
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
    }

    component SettingButton: Rectangle {
        id: buttonRoot
        property string text: ""
        property string actionId: ""
        property var actionPayload: ({})
        property bool busy: actionId.length > 0 && typeof ActionVM !== "undefined" && ActionVM ? ActionVM.isRunning(actionId) : false
        property bool disabled: false
        signal clicked()

        Layout.preferredHeight: 30
        implicitWidth: Math.max(116, label.implicitWidth + 30)
        implicitHeight: 30
        radius: DesignTokens.metrics.radiusSm
        opacity: disabled ? 0.48 : 1
        color: buttonMouse.containsMouse && !disabled ? root.cardHover : root.inputBg
        border.width: 1
        border.color: busy ? root.accent : root.border

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                id: busyGlyph
                visible: buttonRoot.busy
                text: "◌"
                color: root.accent
                font.pixelSize: 12

                RotationAnimation on rotation {
                    running: buttonRoot.busy
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }

            Text {
                id: label
                text: buttonRoot.text
                color: buttonMouse.containsMouse && !buttonRoot.disabled ? root.strongText : root.text
                font.pixelSize: 12
                font.bold: false
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !buttonRoot.disabled && !buttonRoot.busy
            onClicked: {
                buttonRoot.clicked()
                if (buttonRoot.actionId.length > 0 && typeof ActionVM !== "undefined" && ActionVM)
                    ActionVM.runAction(buttonRoot.actionId, buttonRoot.actionPayload || ({}))
            }
        }
    }

    component InfoPill: Rectangle {
        property string title: ""
        property string value: ""
        Layout.fillWidth: true
        implicitHeight: 54
        radius: DesignTokens.metrics.radiusMd
        color: root.bg
        border.color: root.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Text {
                Layout.preferredWidth: 110
                text: title
                color: root.muted
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: value
                color: root.text
                font.pixelSize: 12
                elide: Text.ElideMiddle
            }
        }
    }
}
