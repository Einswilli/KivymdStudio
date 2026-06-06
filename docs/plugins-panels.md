# Plugin Workbench Contributions

Plugins can contribute workbench UI through `contributes.panels` and
`contributes.views`.

## Panel Manifest Contract

```json
{
  "name": "my-panel-plugin",
  "display_name": "My Panel Plugin",
  "version": "1.0.0",
  "author": "You",
  "permissions": ["project:read"],
  "contributes": {
    "panels": [
      {
        "id": "myPlugin.projectInspector",
        "location": "right",
        "component": "ui/ProjectInspector.qml",
        "title": "Project Inspector",
        "label": "INSPECTOR",
        "icon": "layout",
        "order": 500,
        "permissions": ["project:read"]
      }
    ]
  }
}
```

## Locations

- `bottom`: contributes a tab to the bottom DockPanel beside Terminal,
  Problems, Output and Console.
- `right`: contributes a tab/component to the optional right DockPanel.

## Sidebar View Manifest Contract

```json
{
  "name": "my-sidebar-plugin",
  "display_name": "My Sidebar Plugin",
  "version": "1.0.0",
  "author": "You",
  "permissions": ["project:read"],
  "contributes": {
    "views": [
      {
        "id": "myPlugin.customExplorer",
        "location": "sidebar",
        "component": "ui/CustomExplorer.qml",
        "title": "Custom Explorer",
        "label": "CUSTOM",
        "icon": "folder",
        "order": 650
      }
    ]
  }
}
```

`location: "sidebar"` adds an item to the left ActivityBar and loads the QML
component inside the sidebar DockPanel.

## Replacing Core Sidebar Views

Plugins can replace a core sidebar view while preserving the stable command/id
used by Ember:

```json
{
  "contributes": {
    "views": [
      {
        "id": "myPlugin.explorer",
        "replaces": "core.explorer",
        "location": "sidebar",
        "component": "ui/MyExplorer.qml",
        "title": "Explorer",
        "label": "EXPLORER",
        "icon": "folder",
        "order": 100
      }
    ]
  }
}
```

When `replaces` is set, Ember keeps the replaced id (`core.explorer`) in the
activity registry. Existing shortcuts and commands continue to work.

## Disabling Core Sidebar Views

```json
{
  "contributes": {
    "disabledViews": ["core.debug", "core.scm"]
  }
}
```

Core view ids:

- `core.explorer`
- `core.search`
- `core.scm`
- `core.debug`
- `core.extensions`

## QML Component Contract

Plugin panels and sidebar views are loaded through `PluginPanelHost`. If the
component exposes these properties, Ember injects them automatically:

```qml
property var theme
property var panel
```

`panel` contains the resolved manifest contribution:

- `id`, `label`, `title`, `icon`, `location`, `order`
- `plugin`: plugin id
- `component`: absolute/resolved component URL
- `source`: plugin root path
- `permissions`: permissions requested by the panel

## Permissions

Panel-level permissions must be declared in the plugin-level `permissions`.
Ember rejects a panel contribution if it asks for undeclared permissions.

## Minimal Panel

```qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    property var theme
    property var panel

    color: theme.panel

    Text {
        anchors.centerIn: parent
        text: panel.title
        color: theme.text
    }
}
```
