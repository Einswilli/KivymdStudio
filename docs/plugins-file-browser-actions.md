# File Browser Plugin Actions

Plugins can contribute custom actions to the file browser context menu through
`contributes.fileActions`.

## Manifest Contract

```json
{
  "name": "my-formatter",
  "display_name": "My Formatter",
  "version": "1.0.0",
  "author": "You",
  "entry": "backend.py",
  "permissions": ["file:read", "file:write"],
  "contributes": {
    "commands": [
      {
        "id": "myFormatter.format",
        "title": "Format With My Formatter"
      }
    ],
    "fileActions": [
      {
        "id": "myFormatter.formatFile",
        "title": "Format With My Formatter",
        "command": "myFormatter.format",
        "icon": "format",
        "group": "300_format",
        "appliesTo": ["file"],
        "permissions": ["file:read", "file:write"]
      }
    ]
  }
}
```

## Backend Handler

```python
def activate(api):
    async def format_file(context, action):
        path = context["path"]
        text = await api.files.read(path)
        formatted = text.rstrip() + "\n"
        await api.files.write(path, formatted)
        await api.events.emit("file:formatted", path=path, provider=action["id"])
        return {"ok": True, "message": "Formatted", "path": path}

    api.commands.register("myFormatter.format", format_file)
```

## Runtime Context

The command handler receives:

- `context.path`: selected file/folder path
- `context.name`: selected item basename
- `context.isDir`: whether the item is a folder
- `context.type`: `file` or `folder`
- `context.workspace`: current workspace folder
- `context.parent`: parent folder
- `action`: the file action manifest payload

## Events

Plugins can subscribe to:

- `fileBrowser:action:before`
- `fileBrowser:action:after`
- `fileBrowser:action:error`
- Native file events: `file:created`, `folder:created`, `path:renamed`,
  `path:deleted`, `path:copied`, `path:cut`, `path:pasted`, `path:moved`,
  `path:linkCopied`, `file:formatted`
