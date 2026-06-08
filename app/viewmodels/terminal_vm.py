from __future__ import annotations

import os
import re
import pty
import struct
import termios
import asyncio
import signal
import getpass
import fcntl
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtGui import QGuiApplication
from app.core.events import EventBus
from app.services.settings_service import SettingsService


_ANSI_RE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')


def strip_ansi(text: str) -> str:
    return _ANSI_RE.sub('', text).replace('\r\n', '\n').replace('\r', '\n')


class TerminalScreen:
    """Small VT-style screen model for interactive shell output.

    This is intentionally not a full xterm emulator yet. It handles the shell
    redraw sequences that matter for a usable prompt: SGR colors, carriage
    returns, backspace, clear-line, clear-screen, and scrollback.
    """

    _FG = {
        "30": "black",
        "31": "red",
        "32": "green",
        "33": "yellow",
        "34": "blue",
        "35": "magenta",
        "36": "cyan",
        "37": "white",
        "90": "brightBlack",
        "91": "brightRed",
        "92": "brightGreen",
        "93": "brightYellow",
        "94": "brightBlue",
        "95": "brightMagenta",
        "96": "brightCyan",
        "97": "brightWhite",
    }
    _BG = {
        "40": "black",
        "41": "red",
        "42": "green",
        "43": "yellow",
        "44": "blue",
        "45": "magenta",
        "46": "cyan",
        "47": "white",
        "100": "brightBlack",
        "101": "brightRed",
        "102": "brightGreen",
        "103": "brightYellow",
        "104": "brightBlue",
        "105": "brightMagenta",
        "106": "brightCyan",
        "107": "brightWhite",
    }

    def __init__(self, scrollback: int = 3000):
        self.scrollback = scrollback
        self.lines: list[list[dict]] = [[]]
        self._text_lines: list[str] = [""]
        self._cursor_line = 0
        self._cursor_col = 0
        self._cursor_visible = True
        self._insert_mode = False
        self._state = {
            "fg": "",
            "bg": "",
            "bold": False,
            "italic": False,
            "underline": False,
        }

    def feed(self, data: str) -> tuple[list[dict], str, dict]:
        i = 0
        while i < len(data):
            char = data[i]
            if char == "\x1b" and i + 1 < len(data):
                consumed = self._consume_escape(data, i)
                i = consumed if consumed > i else i + 1
                continue
            if char == "\n":
                self._newline()
            elif char == "\r":
                self._cursor_col = 0
            elif char == "\b" or char == "\x7f":
                self._backspace()
            elif char == "\t":
                self._append_text("    ")
            elif char >= " ":
                self._append_text(char)
            i += 1
        return self.snapshot()

    def snapshot(self) -> tuple[list[dict], str, dict]:
        rendered = []
        plain_lines = []
        visible_lines = self.lines[-self.scrollback :]
        first_visible_line = max(0, len(self.lines) - len(visible_lines))
        for spans in visible_lines:
            text = "".join(span["text"] for span in spans)
            plain_lines.append(text)
            rendered.append({"text": text, "spans": [dict(span) for span in spans]})
        cursor = {
            "line": max(0, self._cursor_line - first_visible_line),
            "col": max(0, self._cursor_col),
            "visible": self._cursor_visible,
        }
        return rendered, "\n".join(plain_lines), cursor

    def _append_text(self, text: str) -> None:
        if not text:
            return
        self._ensure_cursor_line()
        cells = self._line_to_cells(self._cursor_line)
        for char in text:
            cell = {
                "text": char,
                "fg": self._state["fg"],
                "bg": self._state["bg"],
                "bold": self._state["bold"],
                "italic": self._state["italic"],
                "underline": self._state["underline"],
            }
            while self._cursor_col > len(cells):
                cells.append({**cell, "text": " "})
            if self._insert_mode or self._cursor_col >= len(cells):
                cells.insert(self._cursor_col, cell)
            else:
                cells[self._cursor_col] = cell
            self._cursor_col += 1
        self._set_line_from_cells(self._cursor_line, cells)
        self._cursor_visible = True

    def _newline(self) -> None:
        self._cursor_line += 1
        self._ensure_cursor_line()
        self._cursor_col = 0
        if len(self.lines) > self.scrollback:
            self.lines = self.lines[-self.scrollback :]
            self._text_lines = self._text_lines[-self.scrollback :]
            self._cursor_line = min(self._cursor_line, len(self.lines) - 1)

    def _clear_current_line(self) -> None:
        self._ensure_cursor_line()
        self.lines[self._cursor_line] = []
        self._text_lines[self._cursor_line] = ""
        self._cursor_col = 0

    def _truncate_current_line(self, column: int) -> None:
        self._ensure_cursor_line()
        column = max(0, min(column, len(self._text_lines[self._cursor_line])))
        remaining = column
        truncated: list[dict] = []
        for span in self.lines[self._cursor_line]:
            text = span["text"]
            if remaining <= 0:
                break
            if len(text) <= remaining:
                truncated.append(dict(span))
                remaining -= len(text)
            else:
                copy = dict(span)
                copy["text"] = text[:remaining]
                truncated.append(copy)
                remaining = 0
        self.lines[self._cursor_line] = truncated
        self._text_lines[self._cursor_line] = self._text_lines[self._cursor_line][:column]

    def _backspace(self) -> None:
        if self._cursor_col <= 0:
            return
        self._cursor_col -= 1

    def _clear_screen(self) -> None:
        self.lines = [[]]
        self._text_lines = [""]
        self._cursor_line = 0
        self._cursor_col = 0

    def _ensure_cursor_line(self) -> None:
        while self._cursor_line >= len(self.lines):
            self.lines.append([])
            self._text_lines.append("")
        if self._cursor_line < 0:
            self._cursor_line = 0

    def _move_cursor_line(self, delta: int) -> None:
        self._cursor_line = max(0, min(len(self.lines) - 1, self._cursor_line + delta))
        self._cursor_col = min(self._cursor_col, len(self._text_lines[self._cursor_line]))

    def _move_cursor_col(self, delta: int) -> None:
        self._cursor_col = max(0, min(len(self._text_lines[self._cursor_line]), self._cursor_col + delta))

    def _line_to_cells(self, line_index: int) -> list[dict]:
        self._ensure_cursor_line()
        cells: list[dict] = []
        for span in self.lines[line_index]:
            span_text = span.get("text", "")
            style = {key: span.get(key) for key in ("fg", "bg", "bold", "italic", "underline")}
            for char in span_text:
                cells.append({"text": char, **style})
        return cells

    def _set_line_from_cells(self, line_index: int, cells: list[dict]) -> None:
        spans: list[dict] = []
        for cell in cells:
            if not spans or any(
                spans[-1].get(key) != cell.get(key)
                for key in ("fg", "bg", "bold", "italic", "underline")
            ):
                spans.append(dict(cell))
            else:
                spans[-1]["text"] += cell.get("text", "")
        self.lines[line_index] = spans
        self._text_lines[line_index] = "".join(cell.get("text", "") for cell in cells)

    def _erase_chars(self, count: int) -> None:
        self._ensure_cursor_line()
        cells = self._line_to_cells(self._cursor_line)
        end = min(len(cells), self._cursor_col + max(1, count))
        for index in range(self._cursor_col, end):
            cells[index]["text"] = " "
        self._set_line_from_cells(self._cursor_line, cells)

    def _delete_chars(self, count: int) -> None:
        self._ensure_cursor_line()
        cells = self._line_to_cells(self._cursor_line)
        del cells[self._cursor_col : self._cursor_col + max(1, count)]
        self._set_line_from_cells(self._cursor_line, cells)

    def _insert_blank_chars(self, count: int) -> None:
        self._ensure_cursor_line()
        cells = self._line_to_cells(self._cursor_line)
        blank = {
            "text": " ",
            "fg": self._state["fg"],
            "bg": self._state["bg"],
            "bold": self._state["bold"],
            "italic": self._state["italic"],
            "underline": self._state["underline"],
        }
        for _ in range(max(1, count)):
            cells.insert(self._cursor_col, dict(blank))
        self._set_line_from_cells(self._cursor_line, cells)

    def _consume_escape(self, data: str, start: int) -> int:
        if start + 1 >= len(data):
            return start + 1
        if data[start + 1] != "[":
            return start + 2

        index = start + 2
        while index < len(data) and not ("@" <= data[index] <= "~"):
            index += 1
        if index >= len(data):
            return len(data)

        command = data[index]
        params = data[start + 2 : index]
        if command == "m":
            self._apply_sgr(params)
        elif command == "@":
            self._insert_blank_chars(self._first_int(params, 1))
        elif command == "P":
            self._delete_chars(self._first_int(params, 1))
        elif command == "X":
            self._erase_chars(self._first_int(params, 1))
        elif command == "K":
            if params == "2":
                col = self._cursor_col
                self._clear_current_line()
                self._cursor_col = col
            else:
                self._truncate_current_line(self._cursor_col)
        elif command == "J":
            if params in ("2", "3"):
                self._clear_screen()
        elif command == "A":
            self._move_cursor_line(-self._first_int(params, 1))
        elif command == "B":
            self._move_cursor_line(self._first_int(params, 1))
        elif command == "C":
            self._move_cursor_col(self._first_int(params, 1))
        elif command == "D":
            self._move_cursor_col(-self._first_int(params, 1))
        elif command == "G":
            self._cursor_col = max(0, self._first_int(params, 1) - 1)
        elif command in ("H", "f"):
            parts = [part for part in params.split(";") if part]
            if not parts:
                self._cursor_line = 0
                self._cursor_col = 0
            else:
                try:
                    self._cursor_line = max(0, int(parts[0]) - 1)
                    self._cursor_col = max(0, int(parts[1]) - 1) if len(parts) > 1 else 0
                    self._ensure_cursor_line()
                except ValueError:
                    pass
        elif command == "h":
            if params == "4":
                self._insert_mode = True
            elif params == "?25":
                self._cursor_visible = True
        elif command == "l":
            if params == "4":
                self._insert_mode = False
            elif params == "?25":
                self._cursor_visible = False
        return index + 1

    @staticmethod
    def _first_int(params: str, default: int) -> int:
        try:
            return int((params or "").split(";")[0] or default)
        except ValueError:
            return default

    def _apply_sgr(self, params: str) -> None:
        codes = params.split(";") if params else ["0"]
        for code in codes:
            code = code or "0"
            if code == "0":
                self._state = {"fg": "", "bg": "", "bold": False, "italic": False, "underline": False}
            elif code == "1":
                self._state["bold"] = True
            elif code == "3":
                self._state["italic"] = True
            elif code == "4":
                self._state["underline"] = True
            elif code == "22":
                self._state["bold"] = False
            elif code == "23":
                self._state["italic"] = False
            elif code == "24":
                self._state["underline"] = False
            elif code == "39":
                self._state["fg"] = ""
            elif code == "49":
                self._state["bg"] = ""
            elif code in self._FG:
                self._state["fg"] = self._FG[code]
            elif code in self._BG:
                self._state["bg"] = self._BG[code]


class TerminalSession:
    """PTY-based shell session — full terminal emulation via forkpty."""

    def __init__(self, session_id: int, cwd: str = "", shell: str = "", scrollback: int = 3000):
        self.id = session_id
        self.cwd = cwd or os.getcwd()
        self.shell = shell or os.environ.get("SHELL", "/bin/bash")
        self._master_fd: int | None = None
        self._child_pid: int | None = None
        self._running = False
        self.title = os.path.basename(self.shell or "shell") or "shell"
        self.cols = 100
        self.rows = 30
        self.screen = TerminalScreen(scrollback=scrollback)

    async def start(self):
        if self._running:
            return
        pid, master_fd = pty.fork()
        if pid == 0:
            os.chdir(self.cwd)
            os.environ["TERM"] = "xterm-256color"
            shell = self.shell or os.environ.get("SHELL", "/bin/bash")
            os.execve(shell, [shell, "-i"], os.environ)
            os._exit(1)
        self._child_pid = pid
        self._master_fd = master_fd
        fcntl.fcntl(self._master_fd, fcntl.F_SETFL, os.O_NONBLOCK)
        self._running = True
        self.resize(self.cols, self.rows)

    def read_output(self) -> str:
        if not self._running or self._master_fd is None:
            return ""
        try:
            data = os.read(self._master_fd, 65536)
            if not data:
                self._running = False
                return ""
            return data.decode("utf-8", errors="replace")
        except BlockingIOError:
            return ""
        except OSError:
            self._running = False
            return ""

    def write_input(self, data: str):
        if self._running and self._master_fd is not None:
            try:
                os.write(self._master_fd, data.encode("utf-8"))
            except OSError:
                self._running = False

    def resize(self, cols: int, rows: int):
        self.cols = max(20, int(cols or self.cols))
        self.rows = max(4, int(rows or self.rows))
        if self._master_fd is not None:
            try:
                winsize = struct.pack("HHHH", self.rows, self.cols, 0, 0)
                fcntl.ioctl(self._master_fd, termios.TIOCSWINSZ, winsize)
            except Exception:
                pass

    async def stop(self):
        self._running = False
        if self._child_pid:
            try:
                os.kill(self._child_pid, signal.SIGTERM)
                await asyncio.sleep(0.3)
                os.kill(self._child_pid, signal.SIGKILL)
                os.waitpid(self._child_pid, 0)
            except (ProcessLookupError, ChildProcessError):
                pass
            self._child_pid = None
        if self._master_fd is not None:
            try:
                os.close(self._master_fd)
            except OSError:
                pass
            self._master_fd = None

    @property
    def is_running(self) -> bool:
        if not self._running or self._child_pid is None:
            return False
        try:
            pid, status = os.waitpid(self._child_pid, os.WNOHANG)
            if pid == self._child_pid:
                self._running = False
                return False
        except ChildProcessError:
            self._running = False
            return False
        return True


class TerminalViewModel(QObject):
    outputReady = Signal(int, str)
    screenReady = Signal(int, "QVariantList", str, "QVariantMap")
    sessionCreated = Signal(int)
    sessionRemoved = Signal(int)
    sessionsChanged = Signal()
    activeSessionChanged = Signal(int)
    commandFinished = Signal(str, int)

    def __init__(self, events: EventBus, parent: QObject | None = None):
        super().__init__(parent)
        self._events = events
        self._sessions: dict[int, TerminalSession] = {}
        self._next_id = 0
        self._active_id: int | None = None
        self._cwd = os.getcwd()
        self._poll_task: asyncio.Task | None = None
        self._screen_flush_tasks: dict[int, asyncio.Task] = {}
        self._pending_screens: dict[int, tuple[list[dict], str, dict]] = {}
        self._settings: SettingsService | None = None
        self._terminal_config: dict = {}
        self._start_polling()

    def set_settings_service(self, settings: SettingsService) -> None:
        self._settings = settings
        self._refresh_terminal_config()

    def _refresh_terminal_config(self) -> dict:
        if not self._settings:
            self._terminal_config = {}
            return self._terminal_config
        try:
            self._terminal_config = dict((self._settings.load().get("terminal") or {}))
        except Exception:
            self._terminal_config = {}
        return self._terminal_config

    def _configured_shell(self) -> str:
        config = self._refresh_terminal_config()
        shell = str(config.get("shell") or "").strip()
        expanded = os.path.expanduser(shell)
        return expanded if expanded and os.path.exists(expanded) else ""

    def _configured_scrollback(self) -> int:
        config = self._refresh_terminal_config()
        try:
            return max(500, min(50000, int(config.get("scrollback") or 3000)))
        except Exception:
            return 3000

    def _configured_cwd(self) -> str:
        config = self._refresh_terminal_config()
        mode = str(config.get("cwdMode") or "project")
        if mode == "home":
            return os.path.expanduser("~")
        if mode == "process":
            return os.getcwd()
        return self._cwd

    def _loop(self) -> asyncio.AbstractEventLoop | None:
        try:
            return asyncio.get_running_loop()
        except RuntimeError:
            try:
                return asyncio.get_event_loop()
            except RuntimeError:
                return None

    def _schedule(self, coro) -> None:
        loop = self._loop()
        if loop is None:
            coro.close()
            return
        loop.create_task(coro)

    def _start_polling(self):
        loop = self._loop()
        if loop is not None and self._poll_task is None:
            self._poll_task = loop.create_task(self._poll_loop())

    async def _poll_loop(self):
        while True:
            await asyncio.sleep(0.02)
            for sid in list(self._sessions.keys()):
                sess = self._sessions.get(sid)
                if sess and sess.is_running:
                    raw = sess.read_output()
                    if raw:
                        self.outputReady.emit(sid, raw)
                        lines, plain, cursor = sess.screen.feed(raw)
                        self._queue_screen_emit(sid, lines, plain, cursor)
                elif sess and not sess.is_running:
                    await self._remove_session(sid)

    def _queue_screen_emit(self, sid: int, lines: list[dict], plain: str, cursor: dict) -> None:
        self._pending_screens[sid] = (lines, plain, cursor)
        if sid in self._screen_flush_tasks and not self._screen_flush_tasks[sid].done():
            return
        loop = self._loop()
        if loop is None:
            self.screenReady.emit(sid, lines, plain, cursor)
            return
        self._screen_flush_tasks[sid] = loop.create_task(self._flush_screen_later(sid))

    async def _flush_screen_later(self, sid: int) -> None:
        await asyncio.sleep(0.035)
        payload = self._pending_screens.pop(sid, None)
        self._screen_flush_tasks.pop(sid, None)
        if not payload:
            return
        lines, plain, cursor = payload
        self.screenReady.emit(sid, lines, plain, cursor)

    async def _remove_session(self, sid: int, persist: bool = True):
        task = self._screen_flush_tasks.pop(sid, None)
        if task:
            task.cancel()
        self._pending_screens.pop(sid, None)
        sess = self._sessions.pop(sid, None)
        if sess:
            await sess.stop()
            self.sessionRemoved.emit(sid)
            if self._active_id == sid:
                remaining = list(self._sessions.keys())
                self._active_id = remaining[0] if remaining else None
                self.activeSessionChanged.emit(self._active_id if self._active_id is not None else -1)
            self.sessionsChanged.emit()
            if persist:
                self._persist_state()

    @Slot(result=int)
    def createSession(self) -> int:
        sid = self._next_id
        self._next_id += 1
        sess = TerminalSession(
            sid,
            self._configured_cwd(),
            shell=self._configured_shell(),
            scrollback=self._configured_scrollback(),
        )
        self._sessions[sid] = sess
        self._active_id = sid
        self._start_polling()
        self._schedule(sess.start())
        self.sessionCreated.emit(sid)
        self.sessionsChanged.emit()
        self.activeSessionChanged.emit(sid)
        self._persist_state()
        return sid

    @Slot(int)
    def activateSession(self, sid: int):
        if sid in self._sessions:
            self._active_id = sid
            self.activeSessionChanged.emit(sid)
            self._persist_state()

    @Slot(int)
    def closeSession(self, sid: int):
        self._schedule(self._remove_session(sid))

    @Slot(int, str)
    def writeToSession(self, sid: int, data: str):
        sess = self._sessions.get(sid)
        if sess:
            sess.write_input(data)

    @Slot(int, int, int)
    def resizeSession(self, sid: int, cols: int, rows: int) -> None:
        sess = self._sessions.get(sid)
        if sess:
            sess.resize(cols, rows)

    @Slot(int, result="QVariantMap")
    def sessionInfo(self, sid: int) -> dict:
        sess = self._sessions.get(sid)
        if not sess:
            return {}
        return {
            "id": sid,
            "title": sess.title,
            "cwd": sess.cwd,
            "running": sess.is_running,
            "cols": sess.cols,
            "rows": sess.rows,
        }

    @Property("QVariantList", notify=sessionsChanged)
    def sessions(self) -> list[dict]:
        return [self.sessionInfo(sid) for sid in self._sessions.keys()]

    @Property(int, notify=activeSessionChanged)
    def activeSessionId(self) -> int:
        return self._active_id if self._active_id is not None else -1

    @Slot(result="QString")
    def get_prompt(self) -> str:
        pid = self._active_id if self._active_id is not None else 0
        return f"[{pid}] {getpass.getuser()}@host:"

    @Slot(str)
    def set_cwd(self, path: str) -> None:
        if os.path.isdir(path):
            self._cwd = path
            self._persist_state()

    @Slot(str)
    def run_command(self, command: str) -> None:
        if self._active_id is not None:
            self.writeToSession(self._active_id, command + "\n")

    @Slot(result=str)
    def pasteText(self) -> str:
        clipboard = QGuiApplication.clipboard()
        return clipboard.text() if clipboard else ""

    @Slot(str)
    def copyText(self, text: str) -> None:
        clipboard = QGuiApplication.clipboard()
        if clipboard:
            clipboard.setText(text or "")

    def activeSession(self) -> TerminalSession | None:
        return self._sessions.get(self._active_id) if self._active_id is not None else None

    async def shutdown(self):
        if self._poll_task:
            self._poll_task.cancel()
            self._poll_task = None
        for task in self._screen_flush_tasks.values():
            task.cancel()
        self._screen_flush_tasks.clear()
        self._pending_screens.clear()
        self._persist_state()
        for sid in list(self._sessions.keys()):
            await self._remove_session(sid, persist=False)

    @Slot(result=int)
    def restoreSessions(self) -> int:
        if not self._settings:
            return 0
        config = self._settings.load()
        terminal_config = config.get("terminal") or {}
        if not terminal_config.get("restoreSessions", True):
            return 0
        sessions = terminal_config.get("sessions") or []
        restored = 0
        for item in sessions:
            cwd = str(item.get("cwd") or self._cwd)
            if cwd and os.path.isdir(cwd):
                self._cwd = cwd
            self.createSession()
            restored += 1
        active = int(terminal_config.get("activeSession") or 0)
        ids = list(self._sessions.keys())
        if ids:
            self.activateSession(ids[min(active, len(ids) - 1)])
        return restored

    def _persist_state(self) -> None:
        if not self._settings:
            return
        session_items = []
        ids = list(self._sessions.keys())
        for sid in ids:
            sess = self._sessions.get(sid)
            if not sess:
                continue
            session_items.append({
                "cwd": sess.cwd,
                "title": sess.title,
            })
        active_index = ids.index(self._active_id) if self._active_id in ids else 0
        try:
            self._settings.save_project({
                "terminal": {
                    "restoreSessions": True,
                    "sessions": session_items,
                    "activeSession": active_index,
                }
            })
        except Exception as exc:
            print(f"[TerminalVM] persist error: {exc}")
