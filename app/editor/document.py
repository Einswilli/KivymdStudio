from __future__ import annotations

import json
from dataclasses import dataclass
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtGui import QGuiApplication
from app.services.editor_service import build_line_items, detect_language


@dataclass(slots=True)
class _Snapshot:
    text: str
    cursor: int
    selection_start: int


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
        self._sel_start = -1
        self._undo_stack: list[_Snapshot] = []
        self._redo_stack: list[_Snapshot] = []
        self._history_limit = 200
        self._preferred_col: int | None = None

    @Slot(str)
    def loadText(self, text: str) -> None:
        self._text = text
        self._cursor = 0
        self._sel_start = -1
        self._is_dirty = False
        self._undo_stack = []
        self._redo_stack = []
        self._re_tokenize()
        self.textChanged.emit()
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot(str)
    def typeText(self, text: str) -> None:
        if not text:
            return
        self._push_undo()
        if self.hasSelection():
            self._replace_selection(text)
            return
        before = self._text[:self._cursor]
        after = self._text[self._cursor:]
        self._text = before + text + after
        self._cursor += len(text)
        self._on_change()

    @Slot(str, str)
    def wrapSelection(self, prefix: str, suffix: str) -> None:
        if not self.hasSelection():
            return
        self._push_undo()
        start = min(self._sel_start, self._cursor)
        end = max(self._sel_start, self._cursor)
        selected = self._text[start:end]
        self._text = self._text[:start] + prefix + selected + suffix + self._text[end:]
        self._sel_start = start + len(prefix)
        self._cursor = self._sel_start + len(selected)
        self._on_change()

    @Slot(str, str)
    def insertPair(self, prefix: str, suffix: str) -> None:
        if self.hasSelection():
            self.wrapSelection(prefix, suffix)
            return
        self._push_undo()
        self._text = self._text[:self._cursor] + prefix + suffix + self._text[self._cursor:]
        self._cursor += len(prefix)
        self._sel_start = -1
        self._on_change()

    @Slot(str, result=bool)
    def skipNextIf(self, text: str) -> bool:
        if self.hasSelection() or not text:
            return False
        if self._text[self._cursor:self._cursor + len(text)] != text:
            return False
        self._cursor += len(text)
        self._sel_start = -1
        self._emit_cursor()
        self.selectionChanged.emit()
        return True

    @Slot()
    def doBackspace(self) -> None:
        if self._cursor <= 0 and not self.hasSelection():
            return
        self._push_undo()
        if self.hasSelection():
            self._delete_selection(notify=False)
            self._on_change()
            return
        if self._cursor < len(self._text):
            previous_char = self._text[self._cursor - 1]
            next_char = self._text[self._cursor]
            if self._matching_closer(previous_char) == next_char:
                self._text = self._text[:self._cursor - 1] + self._text[self._cursor + 1:]
                self._cursor -= 1
                self._on_change()
                return
        self._text = self._text[:self._cursor - 1] + self._text[self._cursor:]
        self._cursor -= 1
        self._on_change()

    @Slot()
    def doDelete(self) -> None:
        if self._cursor >= len(self._text) and not self.hasSelection():
            return
        self._push_undo()
        if self.hasSelection():
            self._delete_selection(notify=False)
            self._on_change()
            return
        self._text = self._text[:self._cursor] + self._text[self._cursor + 1:]
        self._on_change()

    @Slot()
    def doNewline(self) -> None:
        if self.hasSelection():
            self.typeText("\n" + self._calc_auto_indent())
            return
        if 0 < self._cursor < len(self._text):
            previous_char = self._text[self._cursor - 1]
            next_char = self._text[self._cursor]
            if self._matching_closer(previous_char) == next_char and previous_char in {"(", "[", "{"}:
                base_indent = self._current_line_indent()
                inner_indent = base_indent + " " * 4
                self._push_undo()
                self._text = (
                    self._text[:self._cursor]
                    + "\n"
                    + inner_indent
                    + "\n"
                    + base_indent
                    + self._text[self._cursor:]
                )
                self._cursor += 1 + len(inner_indent)
                self._sel_start = -1
                self._on_change()
                return
        indent = self._calc_auto_indent()
        self.typeText("\n" + indent)

    @Slot()
    def doTab(self) -> None:
        self.typeText("    ")

    @Slot()
    def indentSelectionOrLine(self) -> None:
        self._edit_selected_lines(lambda line: " " * 4 + line, keep_selection=self.hasSelection())

    @Slot()
    def outdentSelectionOrLine(self) -> None:
        def outdent(line: str) -> str:
            if line.startswith("    "):
                return line[4:]
            if line.startswith("\t"):
                return line[1:]
            stripped = len(line) - len(line.lstrip(" "))
            return line[min(stripped, 4):]

        self._edit_selected_lines(outdent, keep_selection=self.hasSelection())

    @Slot()
    def toggleLineComment(self) -> None:
        comment = self._line_comment_prefix()

        def toggle(line: str) -> str:
            stripped = line.lstrip(" \t")
            indent = line[: len(line) - len(stripped)]
            if stripped.startswith(comment):
                rest = stripped[len(comment):]
                if rest.startswith(" "):
                    rest = rest[1:]
                return indent + rest
            if not stripped:
                return line
            return indent + comment + " " + stripped

        self._edit_selected_lines(toggle, keep_selection=self.hasSelection())

    @Slot()
    def duplicateLineOrSelection(self) -> None:
        self._push_undo()
        if self.hasSelection():
            start = self.selectionStart
            end = self.selectionEnd
            text = self._text[start:end]
            self._text = self._text[:end] + text + self._text[end:]
            self._cursor = end + len(text)
            self._sel_start = end
            self._on_change()
            return
        line_start, line_end = self._current_line_range(include_newline=True)
        text = self._text[line_start:line_end]
        insert = text if text.endswith("\n") else text + "\n"
        self._text = self._text[:line_end] + insert + self._text[line_end:]
        self._cursor = line_end + min(self._cursor - line_start, len(insert.rstrip("\n")))
        self._on_change()

    @Slot()
    def moveLineOrSelectionUp(self) -> None:
        self._move_selected_lines(-1)

    @Slot()
    def moveLineOrSelectionDown(self) -> None:
        self._move_selected_lines(1)

    @Slot()
    def deleteLineOrSelection(self) -> None:
        self._push_undo()
        if self.hasSelection():
            self._delete_selection(notify=False)
            self._on_change()
            return
        start, end = self._current_line_range(include_newline=True)
        if end == start and start > 0:
            start = self._text.rfind("\n", 0, start - 1) + 1
        self._text = self._text[:start] + self._text[end:]
        self._cursor = max(0, min(start, len(self._text)))
        self._sel_start = -1
        self._on_change()

    @Slot()
    def joinLines(self) -> None:
        if not self._text:
            return
        self._push_undo()
        if self.hasSelection():
            start, end = self._line_bounds_for_span(self.selectionStart, self.selectionEnd)
        else:
            start, end = self._current_line_range(include_newline=True)
        block = self._text[start:end]
        joined = " ".join(part.strip() for part in block.splitlines() if part.strip())
        if not joined:
            return
        self._text = self._text[:start] + joined + self._text[end:]
        self._cursor = start + len(joined)
        self._sel_start = -1
        self._on_change()

    @Slot()
    def trimTrailingWhitespace(self) -> None:
        lines = self._text.split("\n")
        trimmed = [line.rstrip(" \t") for line in lines]
        next_text = "\n".join(trimmed)
        if next_text == self._text:
            return
        self._push_undo()
        self._text = next_text
        self._cursor = min(self._cursor, len(self._text))
        self._sel_start = -1
        self._on_change()

    @Slot()
    def toggleSelectionCase(self) -> None:
        start, end = self._target_text_range()
        if start >= end:
            return
        original = self._text[start:end]
        changed = original.upper() if original != original.upper() else original.lower()
        self._replace_range_keep_selection(start, end, changed)

    @Slot()
    def sortSelectedLines(self) -> None:
        start, end = self._selected_or_current_line_bounds()
        block = self._text[start:end]
        lines = block.splitlines()
        if len(lines) < 2:
            return
        sorted_lines = sorted(lines, key=lambda value: value.casefold())
        replacement = "\n".join(sorted_lines)
        if block.endswith("\n"):
            replacement += "\n"
        self._replace_range_keep_selection(start, end, replacement)

    @Slot()
    def reverseSelectedLines(self) -> None:
        start, end = self._selected_or_current_line_bounds()
        block = self._text[start:end]
        lines = block.splitlines()
        if len(lines) < 2:
            return
        replacement = "\n".join(reversed(lines))
        if block.endswith("\n"):
            replacement += "\n"
        self._replace_range_keep_selection(start, end, replacement)

    def _calc_auto_indent(self) -> str:
        prev = self._text[:self._cursor].split("\n")[-1]
        stripped = prev.lstrip(" \t")
        indent_len = len(prev) - len(stripped)
        if stripped.rstrip().endswith(":"):
            indent_len += 4
        return " " * indent_len

    def _current_line_indent(self) -> str:
        line = self._text[:self._cursor].split("\n")[-1]
        return line[: len(line) - len(line.lstrip(" \t"))]

    def _line_comment_prefix(self) -> str:
        return {
            "python": "#",
            "ruby": "#",
            "shell": "#",
            "toml": "#",
            "yaml": "#",
            "rust": "//",
            "javascript": "//",
            "typescript": "//",
            "java": "//",
            "kotlin": "//",
            "go": "//",
            "swift": "//",
            "c": "//",
            "cpp": "//",
            "css": "//",
            "json": "//",
            "qml": "//",
        }.get(self._language, "//")

    @Slot(int)
    def moveCursor(self, pos: int) -> None:
        pos = max(0, min(pos, len(self._text)))
        self._cursor = pos
        self._sel_start = -1
        self._preferred_col = None
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot(int)
    def moveCursorSelect(self, pos: int) -> None:
        pos = max(0, min(pos, len(self._text)))
        if self._sel_start < 0:
            self._sel_start = self._cursor
        self._cursor = pos
        self._preferred_col = None
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot(int, bool)
    def moveLine(self, delta: int, select: bool = False) -> None:
        line, col = self._line_col_from_pos(self._cursor)
        if self._preferred_col is None:
            self._preferred_col = col
        target_line = max(0, min(line + int(delta), max(0, len(self._line_cache) - 1)))
        target_pos = self._pos_from_line_col(target_line, self._preferred_col)
        if select:
            if self._sel_start < 0:
                self._sel_start = self._cursor
            self._cursor = target_pos
        else:
            self._cursor = target_pos
            self._sel_start = -1
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot(bool)
    def moveSmartHome(self, select: bool = False) -> None:
        line, col = self._line_col_from_pos(self._cursor)
        start, end = self._line_range_by_index(line, include_newline=False)
        text = self._text[start:end]
        first_non_space = len(text) - len(text.lstrip(" \t"))
        target_col = 0 if col == first_non_space else first_non_space
        target = self._pos_from_line_col(line, target_col)
        if select:
            self.moveCursorSelect(target)
        else:
            self.moveCursor(target)

    @Slot(bool)
    def moveDocumentStart(self, select: bool = False) -> None:
        if select:
            self.moveCursorSelect(0)
        else:
            self.moveCursor(0)

    @Slot(bool)
    def moveDocumentEnd(self, select: bool = False) -> None:
        if select:
            self.moveCursorSelect(len(self._text))
        else:
            self.moveCursor(len(self._text))

    @Slot(bool)
    def moveWordLeft(self, select: bool = False) -> None:
        pos = self._word_left(self._cursor)
        if select:
            self.moveCursorSelect(pos)
        else:
            self.moveCursor(pos)

    @Slot(bool)
    def moveWordRight(self, select: bool = False) -> None:
        pos = self._word_right(self._cursor)
        if select:
            self.moveCursorSelect(pos)
        else:
            self.moveCursor(pos)

    @Slot()
    def deleteWordLeft(self) -> None:
        if self.hasSelection():
            self.doBackspace()
            return
        target = self._word_left(self._cursor)
        if target == self._cursor:
            return
        self._push_undo()
        self._text = self._text[:target] + self._text[self._cursor:]
        self._cursor = target
        self._sel_start = -1
        self._on_change()

    @Slot()
    def deleteWordRight(self) -> None:
        if self.hasSelection():
            self.doDelete()
            return
        target = self._word_right(self._cursor)
        if target == self._cursor:
            return
        self._push_undo()
        self._text = self._text[:self._cursor] + self._text[target:]
        self._sel_start = -1
        self._on_change()

    # ── Selection ─────────────────────────────────────

    @Slot()
    def selectAll(self) -> None:
        self._sel_start = 0
        self._cursor = len(self._text)
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot(int)
    def selectWordAt(self, pos: int) -> None:
        if not self._text:
            return
        pos = max(0, min(pos, len(self._text) - 1))
        if not self._is_word_char(self._text[pos]) and pos > 0 and self._is_word_char(self._text[pos - 1]):
            pos -= 1
        if not self._is_word_char(self._text[pos]):
            self.moveCursor(pos)
            return
        start = pos
        end = pos + 1
        while start > 0 and self._is_word_char(self._text[start - 1]):
            start -= 1
        while end < len(self._text) and self._is_word_char(self._text[end]):
            end += 1
        self._sel_start = start
        self._cursor = end
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot(int)
    def selectLineAt(self, line: int) -> None:
        start, end = self._line_range_by_index(line, include_newline=True)
        self._sel_start = start
        self._cursor = end
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot(int, int)
    def selectLineRange(self, start_line: int, end_line: int) -> None:
        first = max(0, min(start_line, end_line))
        last = max(0, max(start_line, end_line))
        start, _ = self._line_range_by_index(first, include_newline=False)
        _, end = self._line_range_by_index(last, include_newline=True)
        self._sel_start = start
        self._cursor = end
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot()
    def expandSelection(self) -> None:
        if not self._text:
            return
        if not self.hasSelection():
            self.selectWordAt(self._cursor)
            return
        start = self.selectionStart
        end = self.selectionEnd
        line_start, line_end = self._line_bounds_for_span(start, end)
        if start != line_start or end != line_end:
            self._sel_start = line_start
            self._cursor = line_end
        else:
            self._sel_start = 0
            self._cursor = len(self._text)
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot()
    def shrinkSelection(self) -> None:
        if not self.hasSelection():
            return
        start = self.selectionStart
        end = self.selectionEnd
        if start == 0 and end == len(self._text):
            line_start, line_end = self._line_bounds_for_span(start, start)
            self._sel_start = line_start
            self._cursor = line_end
        else:
            self.selectWordAt(start)
            return
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot()
    def goToMatchingBracket(self) -> None:
        bracket_pos = self._bracket_position_near_cursor()
        if bracket_pos < 0:
            return
        pair_pos = self._matching_bracket_position(bracket_pos)
        if pair_pos < 0:
            return
        self.moveCursor(pair_pos)

    @Slot()
    def selectInsideBrackets(self) -> None:
        pair = self._enclosing_bracket_pair()
        if not pair:
            return
        start, end = pair
        if start + 1 > end:
            return
        self._sel_start = start + 1
        self._cursor = end
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot()
    def selectAroundBrackets(self) -> None:
        pair = self._enclosing_bracket_pair()
        if not pair:
            return
        start, end = pair
        self._sel_start = start
        self._cursor = end + 1
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

    def _delete_selection(self, notify: bool = True) -> None:
        if not self.hasSelection():
            return
        start = min(self._sel_start, self._cursor)
        end = max(self._sel_start, self._cursor)
        self._text = self._text[:start] + self._text[end:]
        self._cursor = start
        self._sel_start = -1
        if notify:
            self._on_change()

    def _line_bounds_for_span(self, start: int, end: int) -> tuple[int, int]:
        start = max(0, min(start, len(self._text)))
        end = max(start, min(end, len(self._text)))
        line_start = self._text.rfind("\n", 0, start) + 1
        if end > start and end <= len(self._text) and self._text[end - 1:end] == "\n":
            line_end = end - 1
        else:
            line_end = self._text.find("\n", end)
        if line_end < 0:
            line_end = len(self._text)
        return line_start, line_end

    def _current_line_range(self, include_newline: bool = False) -> tuple[int, int]:
        start = self._text.rfind("\n", 0, self._cursor) + 1
        end = self._text.find("\n", self._cursor)
        if end < 0:
            end = len(self._text)
        elif include_newline:
            end += 1
        return start, end

    def _line_range_by_index(self, line: int, include_newline: bool = False) -> tuple[int, int]:
        line = max(0, min(line, max(0, len(self._line_cache) - 1)))
        start = 0
        for _ in range(line):
            next_newline = self._text.find("\n", start)
            if next_newline < 0:
                return len(self._text), len(self._text)
            start = next_newline + 1
        end = self._text.find("\n", start)
        if end < 0:
            end = len(self._text)
        elif include_newline:
            end += 1
        return start, end

    def _line_col_from_pos(self, position: int) -> tuple[int, int]:
        position = max(0, min(position, len(self._text)))
        line = self._text[:position].count("\n")
        col = position
        if line > 0:
            col -= self._text[:position].rfind("\n") + 1
        return line, col

    def _pos_from_line_col(self, line: int, col: int) -> int:
        line = max(0, min(line, max(0, len(self._line_cache) - 1)))
        start, end = self._line_range_by_index(line, include_newline=False)
        return start + max(0, min(col, end - start))

    def _target_text_range(self) -> tuple[int, int]:
        if self.hasSelection():
            return self.selectionStart, self.selectionEnd
        return self._current_line_range(include_newline=False)

    def _selected_or_current_line_bounds(self) -> tuple[int, int]:
        if self.hasSelection():
            return self._line_bounds_for_span(self.selectionStart, self.selectionEnd)
        return self._current_line_range(include_newline=False)

    def _replace_range_keep_selection(self, start: int, end: int, replacement: str) -> None:
        if self._text[start:end] == replacement:
            return
        self._push_undo()
        self._text = self._text[:start] + replacement + self._text[end:]
        self._sel_start = start
        self._cursor = start + len(replacement)
        self._on_change()

    def _bracket_position_near_cursor(self) -> int:
        for pos in (self._cursor, self._cursor - 1):
            if 0 <= pos < len(self._text) and self._text[pos] in "()[]{}":
                return pos
        return -1

    def _matching_bracket_position(self, pos: int) -> int:
        if not (0 <= pos < len(self._text)):
            return -1
        char = self._text[pos]
        openers = "([{"
        closers = ")]}"
        if char in openers:
            target = closers[openers.index(char)]
            direction = 1
        elif char in closers:
            target = openers[closers.index(char)]
            direction = -1
        else:
            return -1
        depth = 0
        index = pos
        while True:
            index += direction
            if index < 0 or index >= len(self._text):
                return -1
            current = self._text[index]
            if current == char:
                depth += 1
            elif current == target:
                if depth == 0:
                    return index
                depth -= 1

    def _enclosing_bracket_pair(self) -> tuple[int, int] | None:
        stack: list[tuple[str, int]] = []
        pairs = {"(": ")", "[": "]", "{": "}"}
        reverse_pairs = {value: key for key, value in pairs.items()}
        cursor = max(0, min(self._cursor, len(self._text)))
        for index, char in enumerate(self._text[:cursor]):
            if char in pairs:
                stack.append((char, index))
            elif char in reverse_pairs and stack and stack[-1][0] == reverse_pairs[char]:
                stack.pop()
        while stack:
            opener, start = stack.pop()
            end = self._matching_bracket_position(start)
            if end >= cursor:
                return start, end
        return None

    @staticmethod
    def _is_word_char(char: str) -> bool:
        return bool(char) and (char.isalnum() or char == "_")

    @staticmethod
    def _matching_closer(char: str) -> str:
        return {
            "(": ")",
            "[": "]",
            "{": "}",
            '"': '"',
            "'": "'",
            "`": "`",
        }.get(char, "")

    def _word_left(self, pos: int) -> int:
        pos = max(0, min(pos, len(self._text)))
        while pos > 0 and self._text[pos - 1].isspace():
            pos -= 1
        if pos > 0 and self._is_word_char(self._text[pos - 1]):
            while pos > 0 and self._is_word_char(self._text[pos - 1]):
                pos -= 1
            return pos
        while pos > 0 and not self._text[pos - 1].isspace() and not self._is_word_char(self._text[pos - 1]):
            pos -= 1
        return pos

    def _word_right(self, pos: int) -> int:
        pos = max(0, min(pos, len(self._text)))
        while pos < len(self._text) and self._text[pos].isspace():
            pos += 1
        if pos < len(self._text) and self._is_word_char(self._text[pos]):
            while pos < len(self._text) and self._is_word_char(self._text[pos]):
                pos += 1
            return pos
        while pos < len(self._text) and not self._text[pos].isspace() and not self._is_word_char(self._text[pos]):
            pos += 1
        return pos

    def _edit_selected_lines(self, transform, keep_selection: bool = False) -> None:
        self._push_undo()
        selection_start = self.selectionStart if self.hasSelection() else self._cursor
        selection_end = self.selectionEnd if self.hasSelection() else self._cursor
        line_start, line_end = self._line_bounds_for_span(selection_start, selection_end)
        block = self._text[line_start:line_end]
        lines = block.split("\n")
        changed_lines = [transform(line) for line in lines]
        replacement = "\n".join(changed_lines)
        self._text = self._text[:line_start] + replacement + self._text[line_end:]
        delta_start = len(changed_lines[0]) - len(lines[0]) if lines else 0
        if keep_selection or self.hasSelection():
            self._sel_start = line_start
            self._cursor = line_start + len(replacement)
        else:
            self._cursor = max(line_start, min(line_start + len(replacement), self._cursor + delta_start))
            self._sel_start = -1
        self._on_change()

    def _selected_line_block(self) -> tuple[int, int, str]:
        if self.hasSelection():
            line_start, line_end = self._line_bounds_for_span(self.selectionStart, self.selectionEnd)
        else:
            line_start, line_end = self._current_line_range(include_newline=False)
        return line_start, line_end, self._text[line_start:line_end]

    def _move_selected_lines(self, direction: int) -> None:
        had_selection = self.hasSelection()
        line_start, line_end, block = self._selected_line_block()
        if direction < 0:
            if line_start <= 0:
                return
            prev_start = self._text.rfind("\n", 0, line_start - 1) + 1
            prev_block = self._text[prev_start:line_start]
            selected_with_newline = self._text[line_start:line_end]
            separator = "\n" if line_end < len(self._text) else ""
            self._push_undo()
            self._text = (
                self._text[:prev_start]
                + selected_with_newline
                + separator
                + prev_block.rstrip("\n")
                + self._text[line_end:]
            )
            new_start = prev_start
        else:
            next_start = line_end + (1 if line_end < len(self._text) and self._text[line_end] == "\n" else 0)
            if next_start >= len(self._text):
                return
            next_end = self._text.find("\n", next_start)
            if next_end < 0:
                next_end = len(self._text)
            next_block = self._text[next_start:next_end]
            self._push_undo()
            before = self._text[:line_start]
            selected = self._text[line_start:line_end]
            between_newline = "\n" if line_end < len(self._text) and self._text[line_end] == "\n" else ""
            after_newline = "\n" if next_end < len(self._text) and self._text[next_end] == "\n" else ""
            self._text = before + next_block + between_newline + selected + after_newline + self._text[next_end + len(after_newline):]
            new_start = line_start + len(next_block) + len(between_newline)

        if had_selection:
            self._sel_start = new_start
            self._cursor = new_start + len(block)
        else:
            self._sel_start = -1
            self._cursor = new_start + min(self._cursor - line_start, len(block))
        self._on_change()

    def _replace_selection(self, text: str) -> None:
        start = min(self._sel_start, self._cursor)
        end = max(self._sel_start, self._cursor)
        self._text = self._text[:start] + text + self._text[end:]
        self._cursor = start + len(text)
        self._sel_start = -1
        self._on_change()

    @Slot(int, int, str)
    def replaceRange(self, start: int, end: int, replacement: str) -> None:
        start = max(0, min(int(start), len(self._text)))
        end = max(start, min(int(end), len(self._text)))
        self._push_undo()
        self._text = self._text[:start] + replacement + self._text[end:]
        self._cursor = start + len(replacement)
        self._sel_start = -1
        self._on_change()

    @Slot(str, str, bool, result=int)
    def replaceAllLiteral(self, needle: str, replacement: str, case_sensitive: bool = False) -> int:
        if not needle:
            return 0
        source = self._text if case_sensitive else self._text.lower()
        target = needle if case_sensitive else needle.lower()
        pieces: list[str] = []
        cursor = 0
        count = 0
        while True:
            index = source.find(target, cursor)
            if index < 0:
                break
            pieces.append(self._text[cursor:index])
            pieces.append(replacement)
            cursor = index + len(needle)
            count += 1
        if count == 0:
            return 0
        pieces.append(self._text[cursor:])
        self._push_undo()
        self._text = "".join(pieces)
        self._cursor = 0
        self._sel_start = -1
        self._on_change()
        return count

    @Slot(result=str)
    def selectedText(self) -> str:
        if not self.hasSelection():
            return ""
        start = min(self._sel_start, self._cursor)
        end = max(self._sel_start, self._cursor)
        return self._text[start:end]

    @Slot()
    def selectNextOccurrence(self) -> None:
        needle = self.selectedText()
        if not needle:
            original_cursor = self._cursor
            self.selectWordAt(self._cursor)
            needle = self.selectedText()
            if not needle:
                self.moveCursor(original_cursor)
            return
        search_from = self.selectionEnd if self.hasSelection() else self._cursor
        haystack = self._text.lower()
        target = needle.lower()
        index = haystack.find(target, search_from)
        if index < 0 and search_from > 0:
            index = haystack.find(target, 0)
        if index < 0:
            return
        self._sel_start = index
        self._cursor = index + len(needle)
        self._emit_cursor()
        self.selectionChanged.emit()

    @Slot()
    def copySelection(self) -> None:
        text = self.selectedText()
        if text:
            clipboard = QGuiApplication.clipboard()
            if clipboard:
                clipboard.setText(text)

    @Slot()
    def cutSelection(self) -> None:
        if not self.hasSelection():
            return
        self.copySelection()
        self._push_undo()
        self._delete_selection(notify=False)
        self._on_change()

    @Slot()
    def pasteClipboard(self) -> None:
        clipboard = QGuiApplication.clipboard()
        if clipboard:
            self.typeText(clipboard.text() or "")

    # ── Undo / Redo ───────────────────────────────────

    def _snapshot(self) -> _Snapshot:
        return _Snapshot(self._text, self._cursor, self._sel_start)

    def _restore_snapshot(self, snapshot: _Snapshot) -> None:
        self._text = snapshot.text
        self._cursor = max(0, min(snapshot.cursor, len(self._text)))
        self._sel_start = snapshot.selection_start
        if self._sel_start >= 0:
            self._sel_start = max(0, min(self._sel_start, len(self._text)))
        self._is_dirty = True
        self._re_tokenize()
        self.textChanged.emit()
        self._emit_cursor()
        self.selectionChanged.emit()

    def _push_undo(self) -> None:
        current = self._snapshot()
        if self._undo_stack and self._undo_stack[-1] == current:
            return
        self._undo_stack.append(current)
        self._undo_stack = self._undo_stack[-self._history_limit :]
        self._redo_stack = []

    @Slot()
    def undo(self) -> None:
        if not self._undo_stack:
            return
        self._redo_stack.append(self._snapshot())
        self._restore_snapshot(self._undo_stack.pop())

    @Slot()
    def redo(self) -> None:
        if not self._redo_stack:
            return
        self._undo_stack.append(self._snapshot())
        self._restore_snapshot(self._redo_stack.pop())

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
        self._emit_cursor()
        self.selectionChanged.emit()
        self._re_tokenize()
        self.textChanged.emit()

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
