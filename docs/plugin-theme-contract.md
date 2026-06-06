# Plugin Theme & Icon Contract

Plugins can contribute workbench themes, editor token colors, custom icons and file-icon associations through `manifest.json`.

## Manifest Fields

```json
{
  "contributes": {
    "themes": [
      {
        "id": "my-theme",
        "label": "My Theme",
        "path": "themes/my-theme.json"
      }
    ],
    "icons": [
      {
        "id": "file-python",
        "path": "assets/icons/python.svg"
      }
    ],
    "fileIcons": [
      {
        "pattern": ".py",
        "icon": "file-python"
      }
    ],
    "fonts": [
      {
        "id": "jetbrains-mono",
        "label": "JetBrains Mono",
        "family": "JetBrains Mono",
        "fallbacks": ["Menlo", "Monaco", "monospace"],
        "path": "assets/fonts/JetBrainsMono-Regular.ttf",
        "downloadUrl": "https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip",
        "license": "OFL-1.1"
      }
    ]
  }
}
```

## Theme File

```json
{
  "name": "My Theme",
  "type": "dark",
  "colors": {
    "editor.background": "#1E1E1E",
    "editor.foreground": "#D4D4D4",
    "sidebar.background": "#252526",
    "tab.activeBackground": "#1E1E1E",
    "statusBar.background": "#007ACC",
    "button.primary": "#007ACC",
    "input.background": "#3C3C3C"
  },
  "tokenColors": {
    "keyword": "#569CD6",
    "function": "#DCDCAA",
    "class": "#4EC9B0",
    "string": "#CE9178",
    "comment": "#6A9955",
    "default": "#D4D4D4"
  }
}
```

## Override Priority

Effective theme resolution:

1. Project config: `.ember/config.json`
2. Global config: `config.json`
3. Plugin theme contribution
4. Built-in fallback tokens

Supported override keys:

```json
{
  "appearance": {
    "theme": "My Theme",
    "themeOverrides": {
      "editor.background": "#101010"
    },
    "tokenColorOverrides": {
      "keyword": "#C678DD"
    }
  }
}
```
