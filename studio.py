# This Python file uses the following encoding: utf-8
import os
from pathlib import Path
import sys
#import tree

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
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

from PyQt5.QtWidgets import QApplication, QMainWindow, QTreeView
from PyQt5.Qt import QStandardItemModel, QStandardItem,QAbstractItemModel
from PyQt5.QtGui import QFont, QColor
from functools import partial

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


class FolderTree(QObject):
    def __init__(self,parent=None):
        super().__init__()
        tree=QTreeView()
        tree.setHeaderHidden(True)
        self.elements=[]
        self.rootName=''

        self.root=StandardItem(self.rootname,16)


class Studio(QObject):

    def __init__(self):
        QObject.__init__(self)
    folderOpen=Signal(dict)
    fileOpen=Signal(dict)
    colorhighlight=Signal(str)
    

    @Slot(str,result='QRichtext')
    def colorify(self,text):
        #QSyntaxHighlighter()
        self.colorhighlight.emit(highlight(text,PythonLexer(),HtmlFormatter(full=True)))
        return highlight(text,PythonLexer(),HtmlFormatter(full=True,style='monokai'))

    @Slot(str,str,result='QVariant')
    def newfile(self,filename,path):
        pass

    @Slot(str,result='QString')
    def openfile(self,path):
        path=path[5:]
        print(path)
        code=''
        cod=''
        try:
            with open(path,'r') as f:
                code=f.readlines()
            for l in code:cod+=l+'\n'
            self.fileOpen.emit(cod)
            print(cod)
            return cod
        except FileNotFoundError:
            return f'Error when trying to open the file: {path}'

    @Slot(str,result='QString')
    def get_filename(self,path):
        filename=str(path).split('/')[-1]
        return filename

    @Slot(str,result='QVariant')
    def newfolder(self,foldername):
        os.makedirs(foldername)
        pass

    @Slot(result='QVariant')
    def recents(self):
        pass
    
    @Slot(str,result='QVariant')
    def openfolder(self,path_):
        print(path_)
        file_token = ''
        for root, dirs, files in os.walk(path_):
            tree = {d: self.tree_to_dict(os.path.join(root, d)) for d in dirs}
            tree.update({f: file_token for f in files})
            lst=[f for f in tree]
            self.folderOpen.emit(Json.dumps(lst , indent=4))
            print(Json.dumps(lst , indent=4))
            return Json.dumps(lst , indent=4)


    def connect_To_Db(self):
        connection=sqlite3.connect('studio.sqlite')
        curs=connection.cursor()
        return curs,connection

    def run(self):
        
        app = QGuiApplication(sys.argv)
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
