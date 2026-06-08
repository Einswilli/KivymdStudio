pragma Singleton

import QtQuick 2.15

QtObject {
    id: root

    readonly property var darkTheme: ({
        bg: "#1E1E1E",
        editorBg: "#1E1E1E",
        editorText: "#D4D4D4",
        editorLineHighlight: "#2A2A2A",
        editorSelection: "#264F78",
        findMatch: Qt.rgba(0.95, 0.68, 0.24, 0.18),
        findCurrent: Qt.rgba(0.95, 0.68, 0.24, 0.34),
        minimapFindMatch: "#F2C94C",
        indentGuide: Qt.rgba(1, 1, 1, 0.10),
        activeIndentGuide: Qt.rgba(1, 1, 1, 0.26),
        editorCursor: "#AEAFAD",
        lineNumbers: "#858585",
        activeLineNumber: "#C6C6C6",

        sidebar: "#252526",
        activityBar: "#2C2C2C",
        panel: "#1E1E1E",
        panelHeader: "#252526",
        border: "#3E3E42",
        hover: "#2A2D2E",
        accent: "#007ACC",
        accentHover: "#1C97EA",

        text: "#CCCCCC",
        textStrong: "#FFFFFF",
        textDim: "#858585",
        selection: "#264F78",

        titleBar: "#323233",
        tabBg: "#252526",
        tabActiveBg: "#1E1E1E",
        tabInactiveBg: "#2D2D30",
        tabActiveText: "#FFFFFF",
        tabInactiveText: "#969696",

        inputBg: "#3C3C3C",
        inputBorder: "#555555",
        statusBar: "#007ACC",
        statusBarText: "#FFFFFF",

        terminalBg: "#1E1E1E",
        terminalText: "#D4D4D4",
        terminalCursor: "#AEAFAD",
        terminalAnsiBlack: "#000000",
        terminalAnsiRed: "#CD3131",
        terminalAnsiGreen: "#0DBC79",
        terminalAnsiYellow: "#E5E510",
        terminalAnsiBlue: "#2472C8",
        terminalAnsiMagenta: "#BC3FBC",
        terminalAnsiCyan: "#11A8CD",
        terminalAnsiWhite: "#E5E5E5",
        terminalAnsiBrightBlack: "#666666",
        terminalAnsiBrightRed: "#F14C4C",
        terminalAnsiBrightGreen: "#23D18B",
        terminalAnsiBrightYellow: "#F5F543",
        terminalAnsiBrightBlue: "#3B8EEA",
        terminalAnsiBrightMagenta: "#D670D6",
        terminalAnsiBrightCyan: "#29B8DB",
        terminalAnsiBrightWhite: "#FFFFFF",
        scrollbarBg: "#1E1E1E",
        scrollbarThumb: "#424242",
        scrollbarHover: "#4F4F4F",

        error: "#E06C75",
        warning: "#D19A66",
        info: "#61AFEF",
        success: "#98C379",
    })

    readonly property var tokenColors: ({
        comment: "#6A9955",
        string: "#CE9178",
        number: "#B5CEA8",
        keyword: "#569CD6",
        function: "#DCDCAA",
        class: "#4EC9B0",
        decorator: "#C586C0",
        type: "#4EC9B0",
        tag: "#569CD6",
        attribute: "#9CDCFE",
        selector: "#D7BA7D",
        value: "#CE9178",
        operator: "#D4D4D4",
        identifier: "#9CDCFE",
        module: "#C586C0",
        variable: "#9CDCFE",
        parameter: "#9CDCFE",
        property: "#9CDCFE",
        builtin: "#DCDCAA",
        default: "#D4D4D4",
    })

    readonly property var metrics: ({
        radiusXs: 3,
        radiusSm: 4,
        radiusMd: 6,
        radiusLg: 8,
        activityBarWidth: 48,
        tabHeight: 36,
        statusBarHeight: 24,
        panelHeaderHeight: 28,
        gutterWidth: 56,
        minimapWidth: 96,
        editorContentPadding: 8,
    })

    function mergeTheme(colors) {
        var theme = {}
        for (var key in darkTheme)
            theme[key] = darkTheme[key]
        if (!colors)
            return theme

        var map = {
            "editor.background": "editorBg",
            "editor.foreground": "editorText",
            "editor.lineHighlight": "editorLineHighlight",
            "editor.selection": "editorSelection",
            "editor.selectionBackground": "editorSelection",
            "editor.findMatch": "findMatch",
            "editor.findMatchBackground": "findMatch",
            "editor.findCurrent": "findCurrent",
            "editor.findCurrentBackground": "findCurrent",
            "editor.minimapFindMatch": "minimapFindMatch",
            "editor.indentGuide": "indentGuide",
            "editor.activeIndentGuide": "activeIndentGuide",
            "editor.cursor": "editorCursor",
            "editor.cursorColor": "editorCursor",
            "editor.lineNumbers": "lineNumbers",
            "editor.activeLineNumber": "activeLineNumber",

            "sidebar.background": "sidebar",
            "sidebar.foreground": "text",
            "sidebar.selection": "hover",
            "sidebar.selectionBackground": "hover",
            "activityBar.background": "activityBar",
            "activityBar.foreground": "textDim",

            "tab.activeBackground": "tabActiveBg",
            "tab.activeForeground": "tabActiveText",
            "tab.inactiveBackground": "tabInactiveBg",
            "tab.inactiveForeground": "tabInactiveText",
            "tab.border": "border",

            "titleBar.background": "titleBar",
            "titleBar.foreground": "text",
            "panel.background": "panel",
            "panel.headerBackground": "panelHeader",
            "panel.border": "border",
            "statusBar.background": "statusBar",
            "statusBar.foreground": "statusBarText",
            "terminal.background": "terminalBg",
            "terminal.foreground": "terminalText",
            "terminal.cursor": "terminalCursor",
            "terminal.ansiBlack": "terminalAnsiBlack",
            "terminal.ansiRed": "terminalAnsiRed",
            "terminal.ansiGreen": "terminalAnsiGreen",
            "terminal.ansiYellow": "terminalAnsiYellow",
            "terminal.ansiBlue": "terminalAnsiBlue",
            "terminal.ansiMagenta": "terminalAnsiMagenta",
            "terminal.ansiCyan": "terminalAnsiCyan",
            "terminal.ansiWhite": "terminalAnsiWhite",
            "terminal.ansiBrightBlack": "terminalAnsiBrightBlack",
            "terminal.ansiBrightRed": "terminalAnsiBrightRed",
            "terminal.ansiBrightGreen": "terminalAnsiBrightGreen",
            "terminal.ansiBrightYellow": "terminalAnsiBrightYellow",
            "terminal.ansiBrightBlue": "terminalAnsiBrightBlue",
            "terminal.ansiBrightMagenta": "terminalAnsiBrightMagenta",
            "terminal.ansiBrightCyan": "terminalAnsiBrightCyan",
            "terminal.ansiBrightWhite": "terminalAnsiBrightWhite",
            "button.primary": "accent",
            "button.hover": "accentHover",
            "input.background": "inputBg",
            "input.border": "inputBorder",
            "scrollbar.background": "scrollbarBg",
            "scrollbar.thumb": "scrollbarThumb",
            "scrollbar.hover": "scrollbarHover",
            "diagnostics.error": "error",
            "diagnostics.warning": "warning",
            "diagnostics.info": "info",
            "diagnostics.success": "success",
        }

        for (var sourceKey in colors) {
            var targetKey = map[sourceKey]
            if (targetKey)
                theme[targetKey] = colors[sourceKey]
        }
        theme.bg = theme.editorBg
        theme.panelHeader = theme.panelHeader || theme.sidebar
        theme.textDim = theme.textDim || theme.tabInactiveText
        theme.selection = theme.editorSelection
        return theme
    }

    function mergeTokenColors(colors) {
        var merged = {}
        for (var key in tokenColors)
            merged[key] = tokenColors[key]
        if (!colors)
            return merged
        for (var sourceKey in colors)
            merged[sourceKey] = colors[sourceKey]
        return merged
    }
}
