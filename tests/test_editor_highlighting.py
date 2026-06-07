from __future__ import annotations

from app.services.editor_service import build_line_items


def _span_kinds(code: str, language: str) -> tuple[set[str], float]:
    items = build_line_items(code, language)
    spans = [span for item in items for span in item["spans"] if span["text"].strip()]
    kinds = {span["kind"] for span in spans}
    default_chars = sum(len(span["text"]) for span in spans if span["kind"] == "default")
    total_chars = sum(len(span["text"]) for span in spans)
    return kinds, default_chars / max(1, total_chars)


def test_multilanguage_highlight_uses_unified_token_kinds() -> None:
    samples = {
        "python": (
            "from pathlib import Path\n"
            "import os\n"
            "@dataclass\n"
            "class User:\n"
            "    def name(self) -> str:\n"
            '        print(len("x"))\n'
            "        return str(dict(value=Path(os.getcwd())))\n",
            {"class", "function", "keyword", "module", "decorator", "string", "type", "builtin"},
        ),
        "rust": (
            "use std::path::PathBuf;\n"
            "/// docs\n"
            "pub struct User { name: String }\n"
            'impl User { pub fn new() -> Self { Self { name: "x".into() } } }\n',
            {"comment", "keyword", "class", "function", "string"},
        ),
        "tsx": (
            'import React from "react";\n'
            'export function App() { return <div className="x">Hi</div>; }\n',
            {"keyword", "function", "string"},
        ),
        "typescript": (
            "interface User { name: string }\n"
            'export const value: User = { name: "x" };\n',
            {"keyword", "class", "type", "string"},
        ),
        "json": ('{"name": "ember", "count": 3, "ok": true}', {"property", "string", "number", "keyword"}),
        "html": ('<section class="card"><h1>Hello</h1></section>', {"tag", "attribute", "string"}),
        "css": (".card:hover { color: #fff; margin: 1rem; }", {"selector", "property", "string"}),
    }

    for language, (code, expected_kinds) in samples.items():
        kinds, default_ratio = _span_kinds(code, language)
        assert default_ratio < 0.55, (language, kinds, default_ratio)
        assert expected_kinds <= kinds, (language, expected_kinds - kinds, kinds)
