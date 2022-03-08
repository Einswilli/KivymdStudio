# This Python file uses the following encoding: utf-8
import os
from pathlib import Path
import sys
import subprocess
from Terminal import*
import getpass
import socket
import glob,schedule
#import tree
#from Emulator.emulator import Emulator

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine,QmlElement
from PySide2.QtGui import QGuiApplication
from PySide2.QtQml import QQmlApplicationEngine,QQmlContext
from PySide2.QtCore import *
from PySide2.QtGui import *
from PySide2.QtWidgets import *
from PyQt5 import QtCore, QtGui, QtWidgets
from PySide2.QtQml import qmlRegisterType
import fcntl, locale, pty, struct, sys, termios

import simplejson as Json
from plyer import notification
import datetime
import sys,os,requests,tempfile
import sqlite3
from pygments import highlight
from pygments.lexers.python import PythonLexer
from pygments.formatters.html import HtmlFormatter
from pygments.formatters.other import NullFormatter
from pygments.styles import get_style_by_name
from rich.console import Console
from rich.syntax import Syntax
import pyperclip


from PyQt5.QtWidgets import QApplication, QMainWindow, QTreeView
from PyQt5.Qt import QStandardItemModel, QStandardItem,QAbstractItemModel
from PyQt5.QtWidgets import QApplication, QStyle, QTextEdit
from PyQt5.QtGui import QFont, QColor
from functools import partial
from pathlib import Path
from PySide6.QtQuickControls2 import QQuickStyle

QML_IMPORT_NAME = "io.qt.textproperties"
QML_IMPORT_MAJOR_VERSION = 1


class DisplayablePath(object):
    display_filename_prefix_middle = '├─'
    display_filename_prefix_last = '└─'
    display_parent_prefix_middle = '  '
    display_parent_prefix_last = '│ '

    def __init__(self, path, parent_path, is_last):
        self.path = Path(str(path))
        self.parent = parent_path
        self.is_last = is_last
        if self.parent:
            self.depth = self.parent.depth + 1
        else:
            self.depth = 0

    @property
    def displayname(self):
        if self.path.is_dir():
            return self.path.name + '/'
        return self.path.name

    @classmethod
    def make_tree(cls, root, parent=None, is_last=False, criteria=None):
        root = Path(str(root))
        criteria = criteria or cls._default_criteria

        displayable_root = cls(root, parent, is_last)
        yield displayable_root

        children = sorted(list(path
                               for path in root.iterdir()
                               if criteria(path)),
                          key=lambda s: str(s).lower())
        count = 1
        for path in children:
            is_last = count == len(children)
            if path.is_dir():
                yield from cls.make_tree(path,
                                         parent=displayable_root,
                                         is_last=is_last,
                                         criteria=criteria)
            else:
                yield cls(path, displayable_root, is_last)
            count += 1

    @classmethod
    def _default_criteria(cls, path):
        return True

    @property
    def displayname(self):
        if self.path.is_dir():
            return self.path.name + '/'
        return self.path.name

    def displayable(self):
        if self.parent is None:
            return self.displayname

        _filename_prefix = (self.display_filename_prefix_last
                            if self.is_last
                            else self.display_filename_prefix_middle)

        parts = ['{!s} {!s}'.format(_filename_prefix,
                                    self.displayname)]

        parent = self.parent
        while parent and parent.parent is not None:
            parts.append(self.display_parent_prefix_middle
                         if parent.is_last
                         else self.display_parent_prefix_last)
            parent = parent.parent

        return ''.join(reversed(parts))


#@QmlElement
class FolderTree(QObject):
    #pass
    def __init__(self):
        QObject.__init__(self)
        self.pty_m=None
        self.codec = locale.getpreferredencoding()
        #ter=QTextEdit()
        # ter.run()

    #@Property()
    #def initial(self):

    #@Slot()
    def cb_echo(self, pty_m):
        """Display output that arrives from the PTY"""
        # Read pending data or assume the child exited if we can't
        # (Not technically the proper way to detect child exit, but it works)
        try:
            # Use 'replace' as a not-ideal-but-better-than-nothing way to deal
            # with bytes that aren't valid in the chosen encoding.
            child_output = os.read(pty_m, 1024).decode(
                self.codec, 'replace')
            return child_output
        except OSError:
            # Ask the event loop to exit and then return to it
            #QApplication.instance().quit()
            return ''

    @Slot(str,result='QString')
    def spawn(self, argv):
        """Launch a child process in the terminal"""
        # Clean up after any previous spawn() runs
        # TODO: Need to reap zombie children
        # XXX: Kill existing children if spawn is called a second time?
        # if self.pty_m:
        #     self.pty_m=None

        # Create a new PTY with both ends open
        self.pty_m, pty_s = pty.openpty()

        # Reset this, since it's PTY-specific
        self.backspace_budget = 0

        # Stop the PTY from echoing back what we type on this end
        term_attrs = termios.tcgetattr(pty_s)
        term_attrs[3] &= ~termios.ECHO
        termios.tcsetattr(pty_s, termios.TCSANOW, term_attrs)

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
        # self.notifier = QSocketNotifier(
        #     self.pty_m, QSocketNotifier.Read, self)
        # self.notifier.activated.connect(self.cb_echo)
        return self.cb_echo(self.pty_m)
    

DEFAULT_TTY_CMD = ['/bin/bash']
DEFAULT_COLS = 80
DEFAULT_ROWS = 25

# The character to use as a reference point when converting between pixel and
# character cell dimensions in the presence of a non-fixed-width font
REFERENCE_CHAR = 'W'
class Studio(QObject):

    def __init__(self):
        QObject.__init__(self)
    folderOpen=Signal(dict)
    fileOpen=Signal(dict)
    colorhighlight=Signal(str)
    screeninfo=Signal(dict)
    terminalReady=Signal(str)
    
    @Slot(result='QString')
    def getScreen(self):

        """this function is used to get the screen geometry like with an the height

        Returns:
            str: a str format of the screen geometry
        """
        # screen=QGuiApplication.primaryScreen()
        # x=screen.size.width()
        # y=screen.size.height()
        try:
            import tkinter as tk

            root = tk.Tk()
            width = root.winfo_screenwidth()
            height = root.winfo_screenheight()
            #print(width,height)
            self.screeninfo.emit([width,height])
            return f'{width},{height}'
        except:pass

    #@Slot(str,result='QString')
    def colorify(self,text):

        """This is used to highlight the given text and returns a html format text

        Args:
            text str: the text which will be highlighted (it could be a code)

        Returns:
            srt: the highlighted text (in html format)
        """

        #QSyntaxHighlighter()
        style = get_style_by_name('monokai')
        #print(highlight(text,PythonLexer(),HtmlFormatter(full=True,style=style)))
        return str(highlight(text,PythonLexer(),HtmlFormatter(full=True,style=style)))

    def richcolor(self,text):

        """This is used to highlight the given text and returns a html format text

        Args:
            text str: the text which will be highlighted (it could be a code)

        Returns:
            srt: the highlighted text (in html format)
        """

        #pyperclip.set_clipboard("xclip")
        console = Console(record=True)
        syntax = Syntax(text, "python",background_color="#1F1F20",tab_size=4,theme='native')
        console.print(syntax)
        r=console.export_html(code_format="<pre>{code}</pre>",inline_styles=True)

        return str(r)

    @Slot(str,str)
    def newfile(self,filename,fpath):
        """this is used to create a new file in a given path

        Args:
            filename str: the file name
            fpath str: the file path
        """
        link=os.path.join(str(fpath)[7:],str(filename))
        #print(fpath)
        os.system(f'touch {link}')
        #print('cool!')

    @Slot(str,result='QString')
    def highlight(self,text):
        """This is used to highlight the given text and returns a html format text

        Args:
            text str: the text which will be highlighted (it could be a code)

        Returns:
            srt: the highlighted text (in html format)
        """
        #print(str(text).removeprefix('\r'))
        if text=='':return ''
        return self.richcolor(str(text).removeprefix('\r'))

    @Slot(str,result='QString')
    def openfile(self,path):
        """this fonction is used to open a file from a given path,save it to the history and returns the file content

        Args:
            path str: the file path 

        Returns:
            str: the file content
        """
        code=''
        curs,conn=self.connect_To_Db()
        
        try:
            self.save_to_history(path[7:])
            # curs.execute("INSERT INTO history VALUES(null,?)",(path[7:],))
            # conn.commit()
            # conn.close()
            with open(path[7:],'r') as f:
                code=f.read()
                #self.richcolor(code)
            return self.colorify(code)#self.richcolor(code)# cod
        except :
            return f'Error when trying to open the file: {path}\n\r may be the file extention is not supported '

    @Slot(str,result='QString')
    def get_filename(self,path):
        """this function is used to get the file name from a given path

        Args:
            path str: the file path

        Returns:
            str: the file name
        """
        filename=str(path).split('/')[-1]
        return filename

    @Slot(str,str,result='QVariant')
    def newfolder(self,foldername,path_):
        """This function is used to create a new folder in a directory

        Args:
            foldername str  : the new folder name
            path_ str       : the directory path
        """
        os.system(f'mkdir {os.path.join(str(path_)[7:],foldername)}')
        #os.makedirs(foldername)
        #pass

    @Slot(str,str,str)
    def savefile(self,p,fname,contenu):
        """
        Function for saving file

        Argv:
            p         : the file path
            fname     : the file name
            contenue  : the file content
        """

        if str(p).endswith(fname):
            idx=str(p).index(fname)
            p=p[7:idx]
        print(p,fname,contenu)
        with open(os.path.join(p,fname),'w') as f:
            f.write(contenu)
            f.close()

    @Slot(result='QVariant')
    def recents(self):
        curs,conn=self.connect_To_Db()
        lst=[]
        try:
            curs.execute('SELECT * FROM history')
            lst=[{'fname':i[1]} for i in curs.fetchall()]
        except:pass
        
        return Json.dumps(lst, indent=4)

    #@Slot(str)
    def save_to_history(self,path_):
        """This function is called when we re trying to save a given file path to the history

        Args:
            path_ str: the file path

        """
        curs,conn=self.connect_To_Db()
        try:
            try:
                curs.execute(f"SELECT * from history WHERE fnama ={path_}")
            except:
                curs.execute("INSERT INTO history VALUES(null,?)",(path_,))
                conn.commit()
                conn.close()
        except:pass
    
    @Slot(str,result='QVariant')
    def openfolder(self,path_):
        """
        Open folder fuction

        Returns:
            a JSON encoded list of the folder
        """
        print(path_)
        paths = DisplayablePath.make_tree(Path(path_[6:]))
        ls=[{'filename':str(path.displayable())} for path in paths]
        
        
        return Json.dumps(ls , indent=4)

    @Slot()
    def emulator(self):
        """ This function will be used to start the kivy emulator"""
        #Emulator().run()
        pass
        

    @Slot(result='QString')
    def terminal(self):
        
        # subprocess.Popen(cmd,  # nosec
        #     stdin=pty_s, stdout=pty_s, stderr=pty_s,
        #     env=child_env,
        #     preexec_fn=os.setsid)
        return f'{getpass.getuser()}@{socket.gethostname()}:\n\r'
        
    @Slot(str,result='QString')
    def run_command(self,cmd):
        '''Runs shell commands and returns the output'''

        executeur=subprocess.Popen(str(cmd),shell=True, stdout=subprocess.PIPE,stdin=subprocess.PIPE,stderr=subprocess.PIPE)
        sortie=str(executeur.stdout.read()+executeur.stderr.read())[2:-3]
        srt=sortie.replace('\n','\n\r')
        return f'\n\r{getpass.getuser()}@{socket.gethostname()}:{cmd}\n\r{srt}'

    def tree_to_dict(self,path_):
        '''' transforming the directory tree in dictionnary '''

        for root, dirs, files in os.walk(path_[6:]):
            tree = {d: self.tree_to_dict(os.path.join(root, d)) for d in dirs}
            lst=[{'itemName': str(f)} for f in files]
            return  tree,lst

    def connect_To_Db(self):
        connection=sqlite3.connect('studio.sqlite')
        curs=connection.cursor()
        return curs,connection

    def run(self):
        
        app = QGuiApplication(sys.argv)
        QQuickStyle.setStyle("Material")
        engine = QQmlApplicationEngine()
        #qmlRegisterType(FolderTree,'DotPy.Core' , 1, 0, 'Terminal')
        studio=Studio()
        ft=FolderTree()
        engine.rootContext().setContextProperty('backend',studio)
        engine.rootContext().setContextProperty('Terminal',ft)
        # engine.load(os.path.join(os.path.dirname(__file__), "studio.qml"))
        engine.load(os.fspath(Path(__file__).resolve().parent / "qml/studio.qml"))
        if not engine.rootObjects():
            sys.exit(-1)
        
        sys.exit(app.exec_())

Studio().run()