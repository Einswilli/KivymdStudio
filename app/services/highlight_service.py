"""
Syntax highlighting service powered by ferrite (tree-sitter via Rust/PyO3).

This replaces the old Pygments-based approach which re-renders the entire
document on every keystroke. Instead, we use tree-sitter's incremental
parsing to highlight only changed regions.
"""

from __future__ import annotations

import html
from typing import Any

try:
    import ferrite
    HAS_FERRITE = True
except ImportError:
    HAS_FERRITE = False

# tree-sitter node type → CSS class mapping
TOKEN_CLASS_MAP: dict[str, str] = {
    "comment": "tok-comment",
    "string": "tok-string",
    "integer": "tok-number",
    "float": "tok-number",
    "true": "tok-keyword",
    "false": "tok-keyword",
    "none": "tok-keyword",
    "identifier": "tok-variable",
    "function_definition": "tok-function",
    "class_definition": "tok-class",
    "decorator": "tok-decorator",
    "import_statement": "tok-keyword",
    "import_from_statement": "tok-keyword",
    "return_statement": "tok-keyword",
    "def": "tok-keyword",
    "class": "tok-keyword",
    "import": "tok-keyword",
    "from": "tok-keyword",
    "as": "tok-keyword",
    "if": "tok-keyword",
    "elif": "tok-keyword",
    "else": "tok-keyword",
    "for": "tok-keyword",
    "while": "tok-keyword",
    "try": "tok-keyword",
    "except": "tok-keyword",
    "finally": "tok-keyword",
    "with": "tok-keyword",
    "raise": "tok-keyword",
    "pass": "tok-keyword",
    "break": "tok-keyword",
    "continue": "tok-keyword",
    "yield": "tok-keyword",
    "return": "tok-keyword",
    "lambda": "tok-keyword",
    "and": "tok-operator",
    "or": "tok-operator",
    "not": "tok-operator",
    "is": "tok-operator",
    "in": "tok-operator",
    "call": "tok-function",
    "attribute": "tok-property",
    "type": "tok-type",
    "parameters": "tok-param",
    "pattern": "tok-pattern",
}

# Default styling for token types (used with QML RichText)
TOKEN_STYLES: dict[str, str] = {
    "tok-keyword": "#C678DD",
    "tok-string": "#98C379",
    "tok-number": "#D19A66",
    "tok-comment": "#5C6370",
    "tok-function": "#61AFEF",
    "tok-class": "#E5C07B",
    "tok-variable": "#E06C75",
    "tok-type": "#E5C07B",
    "tok-operator": "#C678DD",
    "tok-decorator": "#61AFEF",
    "tok-property": "#ABB2BF",
    "tok-param": "#ABB2BF",
    "tok-pattern": "#56B6C2",
}


def classify_token(kind: str) -> str:
    return TOKEN_CLASS_MAP.get(kind, "tok-variable")


def token_style(kind: str) -> str:
    cls_name = classify_token(kind)
    color = TOKEN_STYLES.get(cls_name, "#ABB2BF")
    return color


def highlight_to_html(code: str, language: str = "python") -> str:
    """
    Highlight code using ferrite (tree-sitter) and return HTML suitable
    for Qt's RichText TextEdit.

    Returns a <pre> block with <span> elements for coloured tokens.
    """
    if not HAS_FERRITE:
        return _fallback_highlight(code)

    try:
        tokens = ferrite.parse_code(code, language)
    except Exception as e:
        print(f"[Highlight] ferrite error: {e}")
        return _fallback_highlight(code)

    if not tokens:
        return f"<pre>{html.escape(code)}</pre>"

    # Sort by start position, assign CSS classes
    sorted_tokens = sorted(tokens, key=lambda t: t[0])
    spans = _build_spans(code, sorted_tokens)
    lines = _wrap_in_pre(spans)
    return lines


def highlight_incremental_to_html(
    code: str,
    changed_start: int | None = None,
    changed_end: int | None = None,
    language: str = "python",
) -> str:
    """
    Incremental highlighting using ferrite. When a changed range is provided,
    we can limit re-parsing (future optimization). For now, falls back to full.
    """
    if not HAS_FERRITE:
        return _fallback_highlight(code)

    try:
        tokens = ferrite.highlight_incremental(
            code,
            (changed_start, changed_end) if changed_start is not None else None,
            language,
        )
    except Exception as e:
        print(f"[Highlight] incremental error: {e}")
        return _fallback_highlight(code)

    if not tokens:
        return f"<pre>{html.escape(code)}</pre>"

    sorted_tokens = sorted(tokens, key=lambda t: t[0])
    spans = _build_spans(code, sorted_tokens)
    return _wrap_in_pre(spans)


def _build_spans(code: str, tokens: list[tuple[int, int, str]]) -> list[str]:
    """
    Build a list of HTML <span> elements from token positions.
    Handles gaps (un-tokenized text) by wrapping them in default spans.
    """
    spans: list[str] = []
    pos = 0

    for start, end, kind in tokens:
        if start > pos:
            escaped = html.escape(code[pos:start])
            spans.append(f'<span style="color: #ABB2BF">{escaped}</span>')
        if end > start:
            color = token_style(kind)
            escaped = html.escape(code[start:end])
            escaped = escaped.replace("\n", "<br>")
            spans.append(f'<span style="color: {color}">{escaped}</span>')
        pos = max(pos, end)

    if pos < len(code):
        escaped = html.escape(code[pos:])
        spans.append(f'<span style="color: #ABB2BF">{escaped}</span>')

    return spans


def _wrap_in_pre(spans: list[str]) -> str:
    body = "".join(spans)
    return (
        '<pre style="font-family: monospace; margin: 0; '
        f'white-space: pre-wrap; line-height: 1.5">{body}</pre>'
    )


def _fallback_highlight(code: str) -> str:
    """
    Fallback highlighting using Pygments when ferrite is not available.
    """
    try:
        from pygments import highlight
        from pygments.lexers.python import PythonLexer
        from pygments.formatters.html import HtmlFormatter
        formatter = HtmlFormatter(
            full=True,
            noclasses=True,
            nobackground=True,
            style="monokai",
        )
        return highlight(code, PythonLexer(), formatter)
    except ImportError:
        escaped = html.escape(code).replace("\n", "<br>")
        return f'<pre style="color: #CCC">{escaped}</pre>'


def get_token_types() -> dict[str, str]:
    return TOKEN_STYLES
