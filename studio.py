# This Python file uses the following encoding: utf-8
import os
from pathlib import Path
import sys
import subprocess
#import tree

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine,QmlElement
from PySide2.QtGui import QGuiApplication
from PySide2.QtQml import QQmlApplicationEngine,QQmlContext
from PySide2.QtCore import *
from PySide2.QtGui import *
from PySide2.QtWidgets import *
from PyQt5 import QtCore, QtGui, QtWidgets
from PySide2.QtQml import qmlRegisterType

import simplejson as Json
from plyer import notification
import datetime
import sys,os,requests,tempfile
import sqlite3
from pygments import highlight
from pygments.lexers.python import PythonLexer
from pygments.formatters.html import HtmlFormatter
from pygments.styles import get_style_by_name
from rich.console import Console
from rich.syntax import Syntax
import pyperclip


from PyQt5.QtWidgets import QApplication, QMainWindow, QTreeView
from PyQt5.Qt import QStandardItemModel, QStandardItem,QAbstractItemModel
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


class StandardItem(QStandardItem):
    def __init__(self, txt='', font_size=12, set_bold=False, color=QColor(0, 0, 0)):
        super().__init__()

        fnt = QFont('Open Sans', font_size)
        fnt.setBold(set_bold)

        self.setEditable(False)
        self.setForeground(color)
        self.setFont(fnt)
        self.setText(txt)

class ItemModel(QStandardItemModel):
    def __init__(self, parent=None):
        super().__init__(parent)

        self.setColumnCount(1)

        root = self.invisibleRootItem()
        group1 = QStandardItem("group1")
        group1.setText("group1")
        value1 = QStandardItem("value1")
        value1.setText("value1")
        group1.appendRow(value1)
        root.appendRow(group1)

#@QmlElement
class FolderTree(QObject):
    pass
    # def __init__(self,parent=None):
    #     super().__init__(self)
    #     tree=QTreeView()
    #     tree.setHeaderHidden(True)
    #     self.elements=[]
    #     self.rootName=''

    #     self.root=StandardItem(self.rootname,16)


class Studio(QObject):

    def __init__(self):
        QObject.__init__(self)
    folderOpen=Signal(dict)
    fileOpen=Signal(dict)
    colorhighlight=Signal(str)
    screeninfo=Signal(dict)
    
    @Slot(result='QString')
    def getScreen(self):
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
        #QSyntaxHighlighter()
        style = get_style_by_name('native')
        #print(highlight(text,PythonLexer(),HtmlFormatter(full=True,style=style)))
        return highlight(text,PythonLexer(),HtmlFormatter(full=True,style=style))

    def richcolor(self,text):
        #pyperclip.set_clipboard("xclip")
        console = Console(record=True)
        syntax = Syntax(text, "python",background_color="#1F1F20",indent_guides=True,tab_size=8,theme='native')
        console.print(syntax)
        r=console.export_html(code_format="<pre>{code}</pre>",inline_styles=True)

        return r

    @Slot(str,str)
    def newfile(self,filename,fpath):
        link=os.path.join(str(fpath)[7:],str(filename))
        print(fpath)
        os.system(f'touch {link}')
        #print('cool!')

    @Slot(str,result='QString')
    def highlight(self,text):
        #print(text)
        if text=='':return ''
        return self.richcolor(text)

    @Slot(str,result='QString')
    def openfile(self,path):
        path=path[7:]
        print(path)
        code=''
        cod=''
        try:
            with open(path,'r') as f:
                code=f.read()
        # for l in code.split('\n'):cod+=l+'\n\r'
        # self.fileOpen.emit(cod)
        # print(cod)
            return self.colorify(code)#self.colorify(code)# cod
        except :
            return f'Error when trying to open the file: {path}\n\r may be the file extention is not supported '

    @Slot(str,result='QString')
    def get_filename(self,path):
        filename=str(path).split('/')[-1]
        return filename

    @Slot(str,str,result='QVariant')
    def newfolder(self,foldername,path_):
        os.system(f'mkdir {os.path.join(str(path_)[7:],foldername)}')
        #os.makedirs(foldername)
        #pass

    @Slot(str,str,str)
    def savefile(self,p,fname,contenu):
        print(p[7:],fname,contenu)
        with open(os.path.join(str(p)[7:],str(fname)),'w') as f:
            f.write(contenu)
            f.close()

    @Slot(result='QVariant')
    def recents(self):
        pass
    
    @Slot(str,result='QVariant')
    def openfolder(self,path_):
        print(path_)
        paths = DisplayablePath.make_tree(Path(path_[6:]))
        ls=[{'filename':str(path.displayable())} for path in paths]
        
        # tree,lst=self.tree_to_dict(path_)
        # #lst=[{'itemName':f} for f in lst]
        # ls=[]
        # for i in tree:
        #     d=[{'itemName':e.name}for e in os.scandir(os.path.join(path_[6:],i))]
        #     ls.append({'categoryName':i,'subitems':d})
        #     #d={'categoryName':self.tree_to_dict(os.path.join(path_,i))}
        # for i in lst:ls.append(i)
        # self.folderOpen.emit(Json.dumps(ls , indent=4))
        # #print(Json.dumps(ls , indent=4))
        return Json.dumps(ls , indent=4)

    @Slot()
    def emulator(self):
        executeur=subprocess.Popen('python3 /root/KivyLiteEmulator/main.py',shell=True, stdout=subprocess.PIPE,stdin=subprocess.PIPE,stderr=subprocess.PIPE)
        sortie=executeur.stdout.read()+executeur.stderr.read()
        #strsortie=str(sortie)
        print(sortie)
        #os.system('python3 /root/KivyLiteEmulator/main.py')

    def tree_to_dict(self,path_):
        file_token = ''
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
        qmlRegisterType(FolderTree,'DotPy.FolderTreeView' , 1, 0, 'FolderTree')
        studio=Studio()
        model=ItemModel()
        item=StandardItem()
        # ft=FolderTree()
        # ft.addchildren(data)
        engine.rootContext().setContextProperty('backend',studio)
        engine.rootContext().setContextProperty('treeModel',model)
        engine.rootContext().setContextProperty('StItem',item)
        #engine.rootContext().setContextProperty('FolderTree',ft)
        # engine.load(os.path.join(os.path.dirname(__file__), "studio.qml"))
        engine.load(os.fspath(Path(__file__).resolve().parent / "qml/studio.qml"))
        if not engine.rootObjects():
            sys.exit(-1)
        
        sys.exit(app.exec_())

Studio().run()