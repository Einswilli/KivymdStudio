# This Python file uses the following encoding: utf-8
import os
from pathlib import Path
import sys

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
#from PySide2.QtGui import QGuiApplication
from PySide2.QtQml import QQmlApplicationEngine
from PySide2.QtCore import *
from PySide2.QtGui import *
from PySide2.QtWidgets import *
from PyQt5 import QtCore, QtGui, QtWidgets

import simplejson as Json
from plyer import notification
import datetime
import sys,os,requests,tempfile
import sqlite3
from pygments import highlight
from pygments.lexers.python import PythonLexer
from pygments.formatters.html import HtmlFormatter


class SyntaxCOlor():
    #qmlRegisterType(CamFeed, 'CFeed', 1, 0, 'CamFeed')
    pass

class Studio(QObject):

    def __init__(self):
        QObject.__init__(self)
    folderOpen=Signal(dict)
    fileOpen=Signal(dict)
    colorhighlight=Signal(str)

    @Slot(str,result='QTextCharFormat')
    def colorify(self,text):
        #QSyntaxHighlighter()
        self.colorhighlight.emit(highlight(text,PythonLexer(),HtmlFormatter(full=True)))
        return highlight(text,PythonLexer(),HtmlFormatter(full=True,style='monokai'))

    @Slot(str,str,result='QVariant')
    def newfile(self,filename,path):
        pass

    @Slot(str,result='QString')
    def openfile(self,path):
        pass

    @Slot(str,result='QVariant')
    def newfolder(self,foldername):
        os.makedirs(foldername)
        pass

    @Slot(str,result='QVariant')
    def openfolder(self,path):
        pass

    @Slot(result='QVariant')
    def recents(self):
        pass

    def connect_To_Db(self):
        connection=sqlite3.connect('studio.sqlite')
        curs=connection.cursor()
        return curs,connection

    def run(self):
        app = QGuiApplication(sys.argv)
        engine = QQmlApplicationEngine()
        studio=Studio()
        engine.rootContext().setContextProperty('backend',studio)
        # engine.load(os.path.join(os.path.dirname(__file__), "studio.qml"))
        engine.load(os.fspath(Path(__file__).resolve().parent / "qml/studio.qml"))
        if not engine.rootObjects():
            sys.exit(-1)
        sys.exit(app.exec_())

Studio().run()
