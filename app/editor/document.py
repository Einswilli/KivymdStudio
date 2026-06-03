from __future__ import annotations

import json
from PySide6.QtCore import QObject, Signal, Slot, Property
from app.services.editor_service import build_line_items, detect_language


class EditorDocument(QObject):
    textChanged = Signal()
    cursorChanged = Signal(int, int)  # line, col
    selectionChanged = Signal()
    languageChanged = Signal(str)
    suggestionChanged = Signal(str)
    tokensChanged = Signal(str)  # JSON: [[start,end,kind],...] per line
    linesChanged = Signal()

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)
        self._text = ""
        self._cursor = 0
        self._file_path = ""
        self._language = "python"
        self._suggestion = ""
        self._is_dirty = False
        self._line_tokens: dict[int, list] = {}
        self._line_cache: list[str] = []
        self._line_items: list[dict] = []

    @Slot(str)
    def loadText(self, text: str) -> None:
        self._text = text
        self._cursor = 0
        self._is_dirty = False
        self._re_tokenize()
        self.textChanged.emit()

    @Slot(str)
    def typeText(self, text: str) -> None:
        before = self._text[:self._cursor]
        after = self._text[self._cursor:]
        self._text = before + text + after
        self._cursor += len(text)
        self._on_change()

    @Slot()
    def doBackspace(self) -> None:
        if self._cursor <= 0:
            return
        if self._sel_start >= 0:
            self._delete_selection()
            return
        self._text = self._text[:self._cursor - 1] + self._text[self._cursor:]
        self._cursor -= 1
        self._on_change()

    @Slot()
    def doDelete(self) -> None:
        if self._sel_start >= 0:
            self._delete_selection()
            return
        if self._cursor >= len(self._text):
            return
        self._text = self._text[:self._cursor] + self._text[self._cursor + 1:]
        self._on_change()

    @Slot()
    def doNewline(self) -> None:
        indent = self._calc_auto_indent()
        self.typeText("\n" + indent)

    @Slot()
    def doTab(self) -> None:
        self.typeText("    ")

    def _calc_auto_indent(self) -> str:
        lines = self._text[:self._cursor].split("\n")
        if len(lines) < 2:
            return ""
        prev = lines[-2]
        stripped = prev.lstrip(" \t")
        indent_len = len(prev) - len(stripped)
        if stripped.rstrip().endswith(":"):
            indent_len += 4
        return " " * indent_len

    @Slot(int)
    def moveCursor(self, pos: int) -> None:
        pos = max(0, min(pos, len(self._text)))
        self._cursor = pos
        self._sel_start = -1
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot(int)
    def moveCursorSelect(self, pos: int) -> None:
        pos = max(0, min(pos, len(self._text)))
        if self._sel_start < 0:
            self._sel_start = self._cursor
        self._cursor = pos
        self._emit_cursor()
        self.selectionChanged.emit()

    # ── Selection ─────────────────────────────────────

    _sel_start: int = -1

    @Slot()
    def selectAll(self) -> None:
        self._sel_start = 0
        self._cursor = len(self._text)
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot(result=bool)
    def hasSelection(self) -> bool:
        return self._sel_start >= 0 and self._sel_start != self._cursor

    @Property(int, notify=selectionChanged)
    def selectionStart(self) -> int:
        if self._sel_start < 0:
            return self._cursor
        return min(self._sel_start, self._cursor)

    @Property(int, notify=selectionChanged)
    def selectionEnd(self) -> int:
        if self._sel_start < 0:
            return self._cursor
        return max(self._sel_start, self._cursor)

    def _delete_selection(self) -> None:
        start = min(self._sel_start, self._cursor)
        end = max(self._sel_start, self._cursor)
        self._text = self._text[:start] + self._text[end:]
        self._cursor = start
        self._sel_start = -1
        self._on_change()

    # ── Text access ────────────────────────────────────

    @Slot(result=str)
    def plainText(self) -> str:
        return self._text

    @Slot(int, result=str)
    def charAt(self, pos: int) -> str:
        if 0 <= pos < len(self._text):
            return self._text[pos]
        return ""

    @Slot(int, result=int)
    def lineLength(self, lineNum: int) -> int:
        if 0 <= lineNum < len(self._line_cache):
            return len(self._line_cache[lineNum])
        return 0

    # ── Language & File Path ────────────────────────────

    def _get_filePath(self) -> str:
        return self._file_path

    def _set_filePath(self, path: str) -> None:
        self._file_path = path
        self._language = detect_language(path)
        self.languageChanged.emit(self._language)

    filePath = Property(str, _get_filePath, _set_filePath, notify=languageChanged)

    @Slot(str)
    def setFilePath(self, path: str) -> None:
        self._set_filePath(path)

    @Property(str, notify=languageChanged)
    def language(self) -> str:
        return self._language

    # ── Suggestion ─────────────────────────────────────

    @Property(str, notify=suggestionChanged)
    def aiSuggestion(self) -> str:
        return self._suggestion

    @Slot(str)
    def setAiSuggestion(self, text: str) -> None:
        if self._suggestion != text:
            self._suggestion = text
            self.suggestionChanged.emit(text)

    @Slot()
    def acceptSuggestion(self) -> None:
        if self._suggestion:
            self.typeText(self._suggestion)
            self._suggestion = ""
            self.suggestionChanged.emit("")

    @Slot()
    def rejectSuggestion(self) -> None:
        self._suggestion = ""
        self.suggestionChanged.emit("")

    # ── Dirty state ────────────────────────────────────

    @Property(bool, notify=textChanged)
    def isDirty(self) -> bool:
        return self._is_dirty

    @Slot()
    def markClean(self) -> None:
        self._is_dirty = False
        self.textChanged.emit()

    # ── Token query ─────────────────────────────────────

    def _re_tokenize(self) -> None:
        self._line_items = build_line_items(self._text, self._language)
        self._line_cache = [item["text"] for item in self._line_items]
        self._line_tokens = {
            index: [
                [token["start"], token["end"], token["kind"], token.get("rawKind", "")]
                for token in item["tokens"]
            ]
            for index, item in enumerate(self._line_items)
        }
        self.linesChanged.emit()

    def _on_change(self) -> None:
        self._is_dirty = True
        self._re_tokenize()
        self.textChanged.emit()
        self._emit_cursor()

    def _emit_cursor(self) -> None:
        line = self._text[:self._cursor].count("\n")
        col = self._cursor
        if line > 0:
            col -= self._text[:self._cursor].rfind("\n") + 1
        self.cursorChanged.emit(line, col)

    @Slot(int, result="QString")
    def getTokenAt(self, position: int) -> str:
        if position < 0 or position >= len(self._text):
            return ""
        line = self._text[:position].count("\n")
        col = position
        if line > 0:
            col -= self._text[:position].rfind("\n") + 1
        tokens = self._line_tokens.get(line, [])
        for token in tokens:
            start, end, kind = token[:3]
            raw_kind = token[3] if len(token) > 3 else ""
            if start <= col < end:
                return json.dumps({
                    "start": start,
                    "end": end,
                    "kind": kind,
                    "rawKind": raw_kind,
                    "line": line,
                })
        return ""

    @Slot(int, result="QString")
    def getTokensForLine(self, lineNum: int) -> str:
        tokens = self._line_tokens.get(lineNum, [])
        return json.dumps(tokens)

    @Slot(result=str)
    def allTokensJson(self) -> str:
        lines = self._text.split("\n")
        all_tokens = [self._line_tokens.get(i, []) for i in range(len(lines))]
        return json.dumps(all_tokens)

    # ── Cursor position (QML accessible) ──────────────

    @Property(int, notify=cursorChanged)
    def cursorLine(self) -> int:
        return self._text[:self._cursor].count("\n")

    @Property(int, notify=cursorChanged)
    def cursorColumn(self) -> int:
        line = self._text[:self._cursor].count("\n")
        col = self._cursor
        if line > 0:
            col -= self._text[:self._cursor].rfind("\n") + 1
        return col

    @Property(int, notify=cursorChanged)
    def cursorPosition(self) -> int:
        return self._cursor

    @Property(int, notify=textChanged)
    def lineCount(self) -> int:
        return len(self._line_cache)

    @Property("QVariantList", notify=linesChanged)
    def lines(self) -> list[dict]:
        return self._line_items

    # ── Helpers ────────────────────────────────────────

    @staticmethod
    def _detect_language(path: str) -> str:
        return detect_language(path)
