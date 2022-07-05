# This Python file uses the following encoding: utf-8
import os
from pathlib import Path
import shutil
import sys
import subprocess
#from Terminal import*
import getpass
import socket
import glob,schedule
import Synthaxhighlighter
import platform
#import execjs
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
import locale, sys

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

        """this function is used to get the screen geometry like width and the height

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
        except:return'1200,800'
        
    @Slot(str,result='QString')
    def get_prev_indent_lvl(self,text):
        l=str(text).replace('\u2029','\n').split('\n')
        prev_line=l[-2]
        tmp=prev_line.lstrip(' \t')
        c=len(prev_line[:len(prev_line)-len(tmp)])+1 if prev_line.strip().endswith(':') else len(prev_line[:len(prev_line)-len(tmp)])
        #prev_line.count('\t') if not prev_line.endswith(':') else prev_line.count('\t')+1
        return str(c)#prev_line.count('\t') if not prev_line.endswith(':') else prev_line.count('\t')+1

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
        return highlight(text,PythonLexer(),HtmlFormatter(full=True,style=style,noclasses=True,nobackground=True))

    def richcolor(self,text):

        """This is used to highlight the given text and returns a html format text

        Args:
            text str: the text which will be highlighted (it could be a code)

        Returns:
            srt: the highlighted text (in html format)
        """

        #pyperclip.set_clipboard("xclip")
        syntax = Syntax(text, "python",background_color="#1F1F20",tab_size=4,theme='monokai',indent_guides=True)
        console = Console(record=True)
        console.print(syntax)
        r=console.export_html(code_format="<pre>{code}</pre>",inline_styles=True)
        #print(r)

        return r

    @Slot(str,str)
    def newfile(self,filename,fpath):
        """this is used to create a new file in a given path

        Args:
            filename str: the file name
            fpath str: the file path
        """
        link=os.path.join(str(fpath)[7:],str(filename))
        #print(fpath)
        try:
            with open(link,'x')as f:
                f.write('')
        except Exception as e:
            print(e)
        #os.system(f'touch {link}')
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
        #s=Synthaxhighlighter.Highlighter().highlight(text)
        if text=='':return ''
        return self.colorify(str(text).replace('\u2029','\n').replace('\u21E5','\t'))#self.richcolor(text)#

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
            p=path[7:].replace('/','\\') if 'windows' in platform.system().lower() else path[7:] 
            with open(p,'r') as f:
                code=f.read()
                #self.richcolor(code)
            return self.colorify(code)#self.richcolor(code)# cod
        except Exception as e:
            print(e)
            return f'Error when trying to open the file: {path}\r\n may be the file extention is not supported '

    @Slot(str,result='QString')
    def get_filename(self,path):
        """this function is used to get the file name from a given path

        Args:
            path str: the file path

        Returns:
            str: the file name
        """
        if 'windows' in platform.system().lower():
            filename=str(path).split('\\')[-1]
        else:filename=str(path).split('/')[-1]
        return filename

    @Slot(str,str,result='QVariant')
    def newfolder(self,foldername,path_):
        """This function is used to create a new folder in a directory

        Args:
            foldername str  : the new folder name
            path_ str       : the directory path
        """
        os.mkdir(os.path.join(str(path_)[7:],foldername))
        #os.system(f'mkdir {os.path.join(str(path_)[7:],foldername)}')
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
        #print(p,fname,contenu)
        with open(os.path.join(p,fname),'w') as f:
            f.write(contenu.replace('\u2029','\n').replace('\u21E5','\t'))
            f.close()

    @Slot(result='QVariant')
    def recents(self):
        curs,conn=self.connect_To_Db()
        lst=[]
        try:
            curs.execute('SELECT * FROM history')
            lst=[{'fname':i[1]} for i in curs.fetchall()]
        except:pass
        #self.loadPlugins()
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
                #print(path_)
                curs.execute(f"SELECT * from history WHERE link ='{path_}'")
                if curs.fetchone() is not None:
                    pass
            except Exception as e:
                #print(e,'frido')
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
        #print(path_)
        paths = DisplayablePath.make_tree(Path(path_[6:]))
        ls=[{'filename':str(path.displayable())} for path in paths]
        
        
        return Json.dumps(ls , indent=4)

    @Slot()
    def emulator(self):
        """ This function will be used to start the kivy emulator"""
        #Emulator().run()
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

    @Slot(result='QVariant')
    def loadPlugins(self):
        """
        Simple plugin loader.

        Returns:
            list: the plugins list(type,icon,display_view,template_path)
        """
        #program directory
        cd=os.path.dirname(os.path.abspath(__file__))
        #plugins directory
        pd= os.fspath(Path(__file__).resolve().parent / "plugins/python")
        #Getting Plugins list
        pluglist=glob.glob(os.path.join(pd,'*Plugin'))
        l=[]
        
        for plugin in pluglist:
            plug=glob.glob(plugin)[0]#,r'^[a-zA-Z0-9_]+Plugin.py$')
            #print(plug)
            for p in glob.glob(os.path.join(plug,'*Plugin.py')):
                module=p.split("/")[-1].split(".")[0]

                if module=='__init__':
                    continue
                #print(f'importing module {module}')
                #print(p.split("/")[-2].split(".")[0])
                try:
                    import importlib
                    s=importlib.import_module(f'plugins.python.{p.split("/")[-2].split(".")[0]}.{module}')
                    #exec(f'from plugins.python.{p.split("/")[-2].split(".")[0]}.{module} import *')
                    #print(s.CONFIG)
                    # with open(os.path.join(pd,os.path.join(f'{p.split("/")[-2].split(".")[0]}',f"{s.CONFIG['template']}"))) as f:
                    s.CONFIG.update({'template':f'plugins/python/{p.split("/")[-2].split(".")[0]}/{s.CONFIG["template"]}'})
                        #print(s.CONFIG)
                    l.append(s.CONFIG)
                    importlib.import_module(f'plugins.python.{p.split("/")[-2].split(".")[0]}.{s.CONFIG["backend"].split(".")[0]}')
                except Exception as e:
                    print(e)
                #module=os.path.splitext()

        return Json.dumps(l,indent=4)

    @Slot(str,result='QVariant')
    def installPlugin(self,link):

        origin=r''+link[7:]
        target=r''+os.fspath(Path(__file__).resolve().parent / "plugins/python")

        shutil.copytree(origin,os.path.join(target,f'{origin.split("/")[-1]}'))
        
        return Json.dumps({'msg':'SUCCESS:'},indent=4)

    def run(self):
        
        app = QGuiApplication(sys.argv)
        QQuickStyle.setStyle("Material")
        engine = QQmlApplicationEngine()
        #qmlRegisterType(FolderTree,'DotPy.Core' , 1, 0, 'Terminal')
        studio=Studio()
        #ft=FolderTree()
        engine.rootContext().setContextProperty('backend',studio)
        #engine.rootContext().setContextProperty('Terminal',ft)
        # engine.load(os.path.join(os.path.dirname(__file__), "studio.qml"))
        engine.load(os.fspath(Path(__file__).resolve().parent / "qml/studio.qml"))
        if not engine.rootObjects():
            sys.exit(-1)
        sys.exit(app.exec_())

Studio().run()
