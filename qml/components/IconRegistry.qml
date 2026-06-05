pragma Singleton
import QtQuick 2.15

Item {
    id: root

    readonly property string fontFamily: mdiFont.name
    property var pluginIcons: ({})
    property var pluginFileIcons: ({})

    FontLoader {
        id: mdiFont
        source: "../../assets/fonts/mdicons.ttf"
    }

    function registerIcon(name, source) {
        if (!name || !source) return
        var next = {}
        for (var key in root.pluginIcons)
            next[key] = root.pluginIcons[key]
        next[name] = source
        root.pluginIcons = next
    }

    function registerIcons(icons) {
        if (!icons) return
        var next = {}
        for (var oldKey in root.pluginIcons)
            next[oldKey] = root.pluginIcons[oldKey]
        for (var key in icons)
            next[key] = icons[key]
        root.pluginIcons = next
    }

    function setIcons(icons) {
        var next = {}
        if (icons) {
            for (var key in icons)
                next[key] = icons[key]
        }
        root.pluginIcons = next
    }

    function registerFileIcons(fileIcons) {
        if (!fileIcons) return
        var next = {}
        for (var oldKey in root.pluginFileIcons)
            next[oldKey] = root.pluginFileIcons[oldKey]
        for (var key in fileIcons)
            next[key] = fileIcons[key]
        root.pluginFileIcons = next
    }

    function setFileIcons(fileIcons) {
        var next = {}
        if (fileIcons) {
            for (var key in fileIcons)
                next[key] = fileIcons[key]
        }
        root.pluginFileIcons = next
    }

    function _baseName(path) {
        var name = String(path || "").toLowerCase()
        var slash = Math.max(name.lastIndexOf("/"), name.lastIndexOf("\\"))
        return slash >= 0 ? name.substring(slash + 1) : name
    }

    function fileIcon(path, isDirectory) {
        var name = String(path || "").toLowerCase()
        var baseName = _baseName(name)
        if (isDirectory) {
            for (var folderPattern in root.pluginFileIcons) {
                var normalizedFolderPattern = String(folderPattern).toLowerCase()
                if (!normalizedFolderPattern.startsWith("folder:"))
                    continue
                var folderName = normalizedFolderPattern.substring(7)
                if (baseName === folderName)
                    return root.pluginFileIcons[folderPattern]
            }
            return "folder"
        }
        for (var pattern in root.pluginFileIcons) {
            var normalizedPattern = String(pattern).toLowerCase()
            if (normalizedPattern.startsWith("folder:"))
                continue
            if (name.endsWith(normalizedPattern))
                return root.pluginFileIcons[pattern]
        }
        var ext = name.split(".").pop()
        return defaultFileIcons[ext] || "file"
    }

    function customSource(name, customPaths) {
        if (customPaths && customPaths[name]) return customPaths[name]
        if (root.pluginIcons && root.pluginIcons[name]) return root.pluginIcons[name]
        if (typeof name === "string" && (
            name.indexOf("/") >= 0 ||
            name.indexOf(".svg") > 0 ||
            name.indexOf(".png") > 0 ||
            name.indexOf("file:") === 0 ||
            name.indexOf("qrc:") === 0
        )) return name
        return ""
    }

    function glyph(name) {
        var code = codepoints[name] || codepoints[aliases[name]] || 0
        return code > 0 ? _fromCodePoint(code) : ""
    }

    function hasGlyph(name) {
        return glyph(name).length > 0
    }

    function _fromCodePoint(code) {
        if (code <= 0xFFFF)
            return String.fromCharCode(code)
        code -= 0x10000
        return String.fromCharCode(0xD800 + (code >> 10), 0xDC00 + (code & 0x3FF))
    }

    readonly property var defaultFileIcons: ({
        py: "file-python",
        pyi: "file-python",
        rs: "file-rust",
        json: "file-json",
        qml: "file-qml",
        md: "file-markdown",
        markdown: "file-markdown",
        txt: "file-text",
        js: "file-text",
        ts: "file-text",
        css: "file-text",
        html: "file-text",
        toml: "syntax",
        yaml: "syntax",
        yml: "syntax",
    })

    readonly property var aliases: ({
        "alert-circle": "alert-circle-outline",
        "bell": "bell-outline",
        "bolt": "lightning-bolt-outline",
        "check-circle": "check-circle-outline",
        "close": "close",
        "code": "code-tags",
        "columns": "view-column-outline",
        "copy": "content-copy",
        "cut": "content-cut",
        "debug": "bug-outline",
        "delete": "trash-can-outline",
        "error": "alert-circle-outline",
        "extensions": "puzzle-outline",
        "file": "file-outline",
        "file-python": "language-python",
        "file-rust": "language-rust",
        "file-json": "code-json",
        "file-qml": "file-document-outline",
        "file-markdown": "language-markdown-outline",
        "file-text": "file-document-outline",
        "folder": "folder-outline",
        "folder-open": "folder-open-outline",
        "format": "format-paint",
        "git": "git",
        "git-branch": "source-branch",
        "history": "refresh",
        "keyboard": "keyboard-outline",
        "layout-sidebar-left": "view-column-outline",
        "new-file": "file-plus-outline",
        "new-folder": "folder-plus-outline",
        "panel-bottom": "view-dashboard-outline",
        "panel-right": "view-split-vertical",
        "link": "link-variant",
        "move": "folder-move-outline",
        "paste": "content-paste",
        "play": "play",
        "plus": "plus",
        "rename": "pencil-outline",
        "search": "magnify",
        "settings": "cog-outline",
        "shield": "shield-outline",
        "split-horizontal": "view-split-vertical",
        "sync": "sync",
        "syntax": "code-json",
        "terminal": "console",
        "trash": "trash-can-outline",
        "warning": "alert-outline"
    })

    readonly property var codepoints: ({
        "account-circle-outline": 0xF0B55,
        "alert-circle-outline": 0xF05D6,
        "alert-outline": 0xF002A,
        "bell-outline": 0xF009C,
        "book-open-outline": 0xF0B63,
        "bug-outline": 0xF0A30,
        "check": 0xF012C,
        "check-circle-outline": 0xF05E1,
        "chevron-down": 0xF0140,
        "chevron-right": 0xF0142,
        "close": 0xF0156,
        "code-braces": 0xF016A,
        "code-json": 0xF0626,
        "code-tags": 0xF0174,
        "cog-outline": 0xF08BB,
        "console": 0xF018D,
        "content-cut": 0xF0190,
        "content-copy": 0xF018F,
        "content-paste": 0xF0192,
        "cookie-check-outline": 0xF16D2,
        "crown-circle-outline": 0xF17DC,
        "dock-bottom": 0xF10A3,
        "dock-left": 0xF10A4,
        "dock-right": 0xF10A5,
        "file-document-outline": 0xF09EE,
        "file-outline": 0xF0224,
        "file-plus-outline": 0xF0EED,
        "folder-outline": 0xF0256,
        "folder-open-outline": 0xF0770,
        "folder-move-outline": 0xF0252,
        "folder-plus-outline": 0xF0B9D,
        "format-paint": 0xF027C,
        "git": 0xF02A2,
        "github": 0xF02A4,
        "language-markdown-outline": 0xF0354,
        "language-python": 0xF0320,
        "language-rust": 0xF1617,
        "keyboard-outline": 0xF030C,
        "link-variant": 0xF0339,
        "lightning-bolt-outline": 0xF140C,
        "magnify": 0xF0349,
        "numeric-1": 0xF0B3A,
        "numeric-2": 0xF0B3B,
        "pencil-outline": 0xF0CB6,
        "play": 0xF040A,
        "plus": 0xF0415,
        "puzzle-outline": 0xF0A66,
        "refresh": 0xF0450,
        "shield-outline": 0xF0499,
        "source-branch": 0xF062C,
        "stack-overflow": 0xF04B7,
        "sync": 0xF04E6,
        "trash-can-outline": 0xF0A7A,
        "view-column-outline": 0xF08C8,
        "view-dashboard-outline": 0xF0A1D,
        "view-split-vertical": 0xF0BCB
    })
}
