# File Formatter Plugin Contract

Ember file formatting is provider-based. Core keeps safe fallbacks, but active plugins can provide preferred formatters.

## Manifest Contribution

```json
{
  "contributes": {
    "fileFormatters": [
      {
        "id": "python.ruff-format",
        "label": "ruff format",
        "description": "Format Python files with ruff.",
        "languages": ["python"],
        "extensions": [".py", ".pyi"],
        "command": "ruff",
        "args": ["format", "{file}"],
        "priority": 900,
        "permissions": [],
        "install": {
          "strategy": "pythonTool",
          "command": "uv",
          "args": ["tool", "install", "ruff"],
          "requiresApproval": true
        }
      }
    ]
  }
}
```

## Selection Rules

Formatter selection order:

1. `files.defaultFormatterByExtension[".py"]`
2. `files.defaultFormatterByLanguage["python"]`
3. Highest `priority` active formatter matching the file
4. Core fallback formatter, when available

## Command Arguments

Use `{file}` where the absolute target file path should be injected.

If no argument contains `{file}`, Ember appends the file path automatically.

## Settings

```json
{
  "files": {
    "formatOnSave": false,
    "defaultFormatterByLanguage": {
      "python": "python.ruff-format",
      "rust": "rust.rustfmt"
    },
    "defaultFormatterByExtension": {
      ".py": "python.ruff-format",
      ".rs": "rust.rustfmt"
    }
  }
}
```

## Events

Formatters still pass through the file operation pipeline:

- `file:willFormat`
- `file:formatted`
- `file:formatFailed`

`file:willFormat` can block formatting by returning:

```python
{"ok": False, "message": "Formatting disabled for generated files"}
```
