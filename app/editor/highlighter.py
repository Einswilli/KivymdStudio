"""
Effortless syntax highlighting using ferrite (tree-sitter via Rust/PyO3)
applied through Qt's QSyntaxHighlighter for incremental, per-block formatting.

No more full-document HTML re-renders. Only changed blocks are reformatted.
"""

from __future__ import annotations

from PySide6.QtGui import (
    QSyntaxHighlighter,
    QTextCharFormat,
    QColor,
    QFont,
)
from PySide6.QtCore import Qt

try:
    import ferrite
    HAS_FERRITE = True
except ImportError:
    HAS_FERRITE = False

# ── CSS-style naming for color customization ────────────────

TOKEN_COLORS: dict[str, QColor] = {
    "keyword":       QColor("#C678DD"),
    "string":        QColor("#98C379"),
    "number":        QColor("#D19A66"),
    "comment":       QColor("#5C6370"),
    "function":      QColor("#61AFEF"),
    "class":         QColor("#E5C07B"),
    "variable":      QColor("#E06C75"),
    "type":          QColor("#E5C07B"),
    "operator":      QColor("#C678DD"),
    "decorator":     QColor("#61AFEF"),
    "property":      QColor("#ABB2BF"),
    "parameter":     QColor("#ABB2BF"),
    "default":       QColor("#ABB2BF"),
}

# tree-sitter node kind → broad category
KIND_TO_CATEGORY: dict[str, str] = {
    "def": "keyword", "class": "keyword", "import": "keyword",
    "from": "keyword", "as": "keyword", "if": "keyword", "elif": "keyword",
    "else": "keyword", "for": "keyword", "while": "keyword", "try": "keyword",
    "except": "keyword", "finally": "keyword", "with": "keyword", "raise": "keyword",
    "pass": "keyword", "break": "keyword", "continue": "keyword", "yield": "keyword",
    "return": "keyword", "lambda": "keyword", "and": "operator", "or": "operator",
    "not": "operator", "is": "operator", "in": "operator", "global": "keyword",
    "nonlocal": "keyword", "del": "keyword", "assert": "keyword",
    "true": "keyword", "false": "keyword", "none": "keyword",
    "comment": "comment",
    "string": "string", "string_content": "string",
    "integer": "number", "float": "number",
    "identifier": "variable",
    "function_definition": "function",
    "class_definition": "class",
    "decorator": "decorator",
    "call": "function",
    "attribute": "property",
    "type": "type",
    "parameters": "parameter",
}


def _node_category(kind: str) -> str:
    return KIND_TO_CATEGORY.get(kind, "default")


def _node_color(kind: str) -> QColor:
    return TOKEN_COLORS.get(_node_category(kind), TOKEN_COLORS["default"])


class SyntaxHighlighter(QSyntaxHighlighter):
    """
    Syntax highlighter powered by ferrite (tree-sitter).

    Parses the full document with tree-sitter into token spans,
    then highlights each block from the cached spans.
    Re-parses only when the document text changes.
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self._tokens: list[tuple[int, int, str]] = []
        self._code: str = ""
        self._language: str = "python"

    def set_language(self, language: str) -> None:
        self._language = language or "python"

    def set_code(self, code: str) -> None:
        if code == self._code:
            return
        self._code = code
        if HAS_FERRITE and code.strip():
            try:
                self._tokens = ferrite.parse_code(code, self._language)
                self._tokens.sort(key=lambda t: t[0])
            except Exception:
                self._tokens = []
        else:
            self._tokens = []

    def highlightBlock(self, text: str) -> None:
        block = self.currentBlock()
        block_start = block.position()
        block_end = block_start + len(text)

        if not self._tokens:
            fmt = QTextCharFormat()
            fmt.setForeground(TOKEN_COLORS["default"])
            self.setFormat(0, len(text), fmt)
            return

        # Find tokens overlapping this block
        relevant = [
            (s, e, k) for s, e, k in self._tokens
            if s < block_end and e > block_start
        ]

        if not relevant:
            fmt = QTextCharFormat()
            fmt.setForeground(TOKEN_COLORS["default"])
            self.setFormat(0, len(text), fmt)
            return

        sorted_tokens = sorted(relevant, key=lambda t: t[0])

        pos = block_start
        for start, end, kind in sorted_tokens:
            if start > pos:
                gap_start = pos - block_start
                gap_len = min(start - pos, block_end - pos)
                if gap_len > 0:
                    fmt = QTextCharFormat()
                    fmt.setForeground(TOKEN_COLORS["default"])
                    self.setFormat(gap_start, gap_len, fmt)
                pos = start

            if end > pos:
                rel_start = pos - block_start
                rel_len = min(end - pos, block_end - pos)
                if rel_len > 0:
                    color = _node_color(kind)
                    fmt = QTextCharFormat()
                    fmt.setForeground(color)
                    if kind == "comment":
                        fmt.setFontItalic(True)
                    self.setFormat(rel_start, rel_len, fmt)
                pos = end

        if pos < block_end:
            rel_start = pos - block_start
            rel_len = block_end - pos
            fmt = QTextCharFormat()
            fmt.setForeground(TOKEN_COLORS["default"])
            self.setFormat(rel_start, rel_len, fmt)

    def get_token_at(self, position: int) -> tuple[int, int, str] | None:
        for start, end, kind in self._tokens:
            if start <= position < end:
                return (start, end, kind)
        return None

    @classmethod
    def get_token_colors(cls) -> dict[str, QColor]:
        return dict(TOKEN_COLORS)
