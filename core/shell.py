import os,sys,getpass,socket,re
import selectors
import subprocess
import threading
from ansi2html import Ansi2HTMLConverter
from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import BashLexer
from pygments.styles import get_style_by_name
from colorama import init, Fore, Style
from PySide2.QtCore import QObject, Signal, Slot, QProcess

# Init Colorama
init()
class CommandManager(QObject):
    command_output = Signal(str,name='commandOutput')
    end_output = Signal(name='outputEnded')
    input_required = Signal(str,name='inputRequired')

    def __init__(self):
        super().__init__()
        self.process = None
        self.command_thread = None
        self.selector = selectors.DefaultSelector()
        self.pending_input_prompt = None

    @Slot(str)
    def execute_command(self, command):
        '''Runs shell commands.'''

        if self.command_thread and self.command_thread.is_alive():
            self.command_output.emit(
                'A command is already running\n'
            )
            return 

        # Run the command in a separatedt hread
        self.command_thread = threading.Thread(
            target = self.run_command,
            args = (command,)
        )
        self.command_thread.start()

    def run_command(self,command):
        ''' '''

        try:
            self.process = subprocess.Popen(
                command,shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                stdin=subprocess.PIPE,
                text=True
            )

            if self.process.stdout:
                self.selector.register(self.process.stdout,selectors.EVENT_READ)
            if self.process.stderr:
                self.selector.register(self.process.stderr,selectors.EVENT_READ)
            if self.process.stdin:
                self.selector.register(self.process.stdin,selectors.EVENT_WRITE)

            while True:
                for key,events in self.selector.select():

                    # STDOUT
                    if key.fileobj == self.process.stdout:
                        output = self.process.stdout.readline()
                        if output:
                            self.pending_input_prompt = output.strip()
                            self.command_output.emit(
                                self.colorize_output(output.strip())
                            )

                    # STDERR
                    elif key.fileobj == self.process.stderr:
                        err_output = self.process.stderr.read()
                        if err_output:
                            self.pending_input_prompt = err_output.strip()
                            self.command_output.emit(
                                self.colorize_output(err_output.strip())
                            )

                    # STDIN requires inupt
                    elif key.fileobj == self.process.stdin and self.process.stdin.writable():
                        # self.pending_input_prompt = self.process.stdout.readline().strip()
                        # if self.pending_input_prompt:
                        self.input_required.emit(
                            self.pending_input_prompt
                        )
                        print(self.pending_input_prompt)
                        self.pending_input_prompt = None
                        self.selector.unregister(self.process.stdin)
                        # return 

                if self.process.poll() is not None:
                    break

        except Exception as e:
            self.command_output.emit(
                self.colorize_output(str(e))
            )

        finally: self.end_output.emit()

    def colorize_output(self, text):
        # Use regex to detect ANSI codes and apply corresponding HTML tags
        conv = Ansi2HTMLConverter()
        html_output = conv.convert(text)
        
        return html_output

    @Slot(result='QString')
    def get_prompt(self):
        ''' Return the prompt. '''

        # Get user, host, and current directory
        user = getpass.getuser()
        host = socket.gethostname()
        home_dir = os.path.expanduser('~')
        cwd = os.getcwd()

        # Abreviate the directory path
        if cwd.startswith(home_dir):
            cwd = cwd.replace(home_dir,'~',1)
        # The prompt
        prompt = f"{user}@{host}-[{cwd}]$ "
        return self.colorize_output(prompt)

    @Slot(str)
    def sentInput(self,input_text):
        ''' Send input to the command thread. '''
        if self.process and self.process.stdin:
            self.process.stdin.write(input_text + '\n')
            self.process.stdin.flush()