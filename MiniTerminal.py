"""Primitive terminal emulator example made from a PyQt QTextEdit widget."""

import fcntl, locale, os, pty, struct, sys, termios
import subprocess
from PySide2 import QtWidgets

from PySide2.QtCore import QObject  # nosec

# Quick hack to limit the scope of the PyLint warning disabler
try:
    # pylint: disable=no-name-in-module
    from PyQt5.QtCore import Qt, QSocketNotifier                 # type: ignore
    from PyQt5.QtGui import QFont, QPalette, QTextCursor         # type: ignore
    from PyQt5.QtWidgets import QApplication, QStyle, QTextEdit  # type: ignore
    from PySide2.QtGui import QGuiApplication
    from PySide2.QtCore import *
except ImportError:
    raise

# It's good practice to put these sorts of things in constants at the top
# rather than embedding them in your code
DEFAULT_TTY_CMD = ['/bin/bash']
DEFAULT_COLS = 80
DEFAULT_ROWS = 25

# NOTE: You can use any QColor instance, not just the predefined ones.
DEFAULT_TTY_FONT = QFont('Noto', 16)
DEFAULT_TTY_FG = Qt.lightGray
DEFAULT_TTY_BG = Qt.black

# The character to use as a reference point when converting between pixel and
# character cell dimensions in the presence of a non-fixed-width font
REFERENCE_CHAR = 'W'


class Terminal(QObject):
    """Simple TERM=tty terminal emulator widget
    (Uses QTextEdit rather than QPlainTextEdit to leave the capability open to
    support colors.)
    """

    # Used to block the user from backspacing more characters than they
    # typed since last pressing Enter
    backspace_budget = 0

    # Persistent handle for the master side of the PTY and its QSocketNotifier
    pty_m = None
    subproc = None
    notifier = None
    te=QTextEdit(parent=None)

    def __init__(self):
        QObject().__init__(self)

        # Do due diligence to figure out what character coding child
        # applications will expect to speak
        self.codec = locale.getpreferredencoding()


        # Customize the look and feel
        pal = self.te.palette()
        pal.setColor(QPalette.Base, DEFAULT_TTY_BG)
        pal.setColor(QPalette.Text, DEFAULT_TTY_FG)
        self.te.setPalette(pal)
        self.te.setFont(DEFAULT_TTY_FONT)

        # Disable the widget's built-in editing support rather than looking
        # into how to constrain it. (Quick hack which means we have to provide
        # our own visible cursor if we want one)
        self.te.setReadOnly(True)

    def cb_echo(self, pty_m):
        """Display output that arrives from the PTY"""
        # Read pending data or assume the child exited if we can't
        # (Not technically the proper way to detect child exit, but it works)
        try:
            # Use 'replace' as a not-ideal-but-better-than-nothing way to deal
            # with bytes that aren't valid in the chosen encoding.
            child_output = os.read(self.pty_m, 1024).decode(
                self.codec, 'replace')
        except OSError:
            # Ask the event loop to exit and then return to it
            QApplication.instance().quit()
            return

        # Insert the output at the end and scroll to the bottom
        self.te.moveCursor(QTextCursor.End)
        self.te.insertPlainText(child_output)
        scroller = self.te.verticalScrollBar()
        scroller.setValue(scroller.maximum())

    def keyPressEvent(self, event):
        """Handler for all key presses delivered while the widget has focus"""
        char = event.text()

        # Move the cursor to the end
        self.te.moveCursor(QTextCursor.End)
        cursor = self.te.textCursor()

        # If the character isn't a control code of some sort,
        # then echo it to the terminal screen.
        #
        # (The length check is necessary to ignore empty strings which
        #  count as printable but break backspace_budget)
        #
        #  FIXME: I'm almost certain backspace_budget will break here if you
        #         feed in multi-codepoint grapheme clusters.
        if char and (char.isprintable() or char == '\r'):
            cursor.insertText(char)
            self.backspace_budget += len(char)

        # Implement backspacing characters we typed
        if char == '\x08' and self.backspace_budget > 0:  # Backspace
            cursor.deletePreviousChar()
            self.backspace_budget -= 1
        elif char == '\r':                                # Enter
            self.backspace_budget = 0

        # Regardless of what we do, send the character to the PTY
        # (Let the kernel's PTY implementation do most of the heavy lifting)
        os.write(self.pty_m, char.encode(self.codec))

        # Scroll to the bottom on keypress, but only after modifying the
        # contents to make sure we don't scroll to where the bottom was before
        # word-wrap potentially added more lines
        scroller = self.te.verticalScrollBar()
        scroller.setValue(scroller.maximum())

    def resizeEvent(self, event):
        """Handler to announce terminal size changes to child processes"""
        # Call Qt's built-in resize event handler
        super(Terminal, self).resizeEvent(event)

        fontMetrics = self.te.fontMetrics()
        win_size_px = self.te.size()
        char_width = fontMetrics.boundingRect(REFERENCE_CHAR).width()

        # Subtract the space a scrollbar will take from the usable width
        usable_width = (win_size_px.width() - QApplication.instance().style()
            .pixelMetric(QStyle.PM_ScrollBarExtent))

        # Use integer division (rounding down in this case) to find dimensions
        cols = usable_width // char_width
        rows = win_size_px.height() // fontMetrics.height()

        # Announce the change to the PTY
        fcntl.ioctl(self.pty_m, termios.TIOCSWINSZ,
            struct.pack("HHHH", rows, cols, 0, 0))

        # As a quick hack, scroll to the bottom on resize
        # (The proper solution would be to preserve scroll position no matter
        # what it is)
        scroller = self.te.verticalScrollBar()
        scroller.setValue(scroller.maximum())

    def spawn(self, argv):
        """Launch a child process in the terminal"""
        # Clean up after any previous spawn() runs
        # TODO: Need to reap zombie children
        # XXX: Kill existing children if spawn is called a second time?
        if self.pty_m:
            self.pty_m.close()
        if self.notifier:
            self.notifier.disconnect()

        # Create a new PTY with both ends open
        self.pty_m, pty_s = pty.openpty()

        # Reset this, since it's PTY-specific
        self.backspace_budget = 0

        # Stop the PTY from echoing back what we type on this end
        term_attrs = termios.tcgetattr(pty_s)
        term_attrs[3] &= ~termios.ECHO
        termios.tcsetattr(pty_s, termios.TCSANOW, term_attrs)

        # Tell child processes that we're a dumb terminal that doesn't
        # understand colour or cursor movement escape sequences
        #
        # (This will prevent well-behaved processes from emitting colour codes
        # and will cause things which *require* cursor control like mutt and
        # ncdu to error out on startup with "Error opening terminal: tty")
        child_env = os.environ.copy()
        child_env['TERM'] = 'tty'

        # Launch the subprocess
        # FIXME: Keep a reference so we can reap zombie processes
        subprocess.Popen(argv,  # nosec
            stdin=pty_s, stdout=pty_s, stderr=pty_s,
            env=child_env,
            preexec_fn=os.setsid)

        # Close the child side of the PTY so that we can detect when to exit
        os.close(pty_s)

        # Hook up an event handler for data waiting on the PTY
        # (Because I didn't feel like looking into whether QProcess can be
        #  integrated with PTYs as a subprocess.Popen alternative)
        self.notifier = QSocketNotifier(
            self.pty_m, QSocketNotifier.Read, self)
        self.notifier.activated.connect(self.cb_echo)

# Run this code if the file is launched from the command line but not if
# it is `import`ed as a dependency.
if __name__ == '__main__':
    app = QGuiApplication(sys.argv)
    #engine = QQmlApplicationEngine()
    mainwin = Terminal()

    # Cheap hack to estimate what 80x25 should be in pixels and resize to it
    fontMetrics = mainwin.fontMetrics()
    target_width = (fontMetrics.boundingRect(
        REFERENCE_CHAR * DEFAULT_COLS
    ).width() + app.style().pixelMetric(QStyle.PM_ScrollBarExtent))
    mainwin.resize(target_width, fontMetrics.height() * DEFAULT_ROWS)

    # Launch DEFAULT_TTY_CMD in the terminal
    mainwin.spawn(DEFAULT_TTY_CMD)

    # Take advantage of how Qt lets any widget be a top-level window
    mainwin.show()
    app.exec_()