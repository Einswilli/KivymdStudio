# import os
# import sys

# from PyQt5 import QtCore, QtWidgets, QtNetwork

# import QTermWidget


# class RemoteTerm(QTermWidget.QTermWidget):
#     def __init__(self, ipaddr, port, parent=None):
#         super().__init__(0, parent)

#         self.socket = QtNetwork.QTcpSocket(self)

#         self.socket.error.connect(self.atError)
#         self.socket.readyRead.connect(self.on_readyRead)
#         self.sendData.connect(self.socket.write)

#         self.startTerminalTeletype()
#         self.socket.connectToHost(ipaddr, port)

#     @QtCore.pyqtSlot()
#     def on_readyRead(self):
#         data = self.socket.readAll().data()
#         os.write(self.getPtySlaveFd(), data)

#     @QtCore.pyqtSlot()
#     def atError(self):
#         print(self.socket.errorString())


# if __name__ == "__main__":
#     app = QtWidgets.QApplication(sys.argv)

#     QtCore.QCoreApplication.setApplicationName("QTermWidget Test")
#     QtCore.QCoreApplication.setApplicationVersion("1.0")

#     parser = QtCore.QCommandLineParser()
#     parser.addHelpOption()
#     parser.addVersionOption()
#     parser.setApplicationDescription(
#         "Example(client-side) for remote terminal of QTermWidget"
#     )
#     parser.addPositionalArgument("ipaddr", "adrress of host")
#     parser.addPositionalArgument("port", "port of host")

#     parser.process(QtCore.QCoreApplication.arguments())

#     requiredArguments = parser.positionalArguments()
#     if len(requiredArguments) != 2:
#         parser.showHelp(1)
#         sys.exit(-1)

#     address, port = requiredArguments
#     w = RemoteTerm(QtNetwork.QHostAddress(address), int(port))
#     w.resize(640, 480)
#     w.show()
#     sys.exit(app.exec_())

# import sys
# import os
# import socket
# import pty


# def usage(program):
#     print("Example(server-side) for remote terminal of QTermWidget.")
#     print("Usage: %s ipaddr port" % program)


# def main():
#     if len(sys.argv) != 3:
#         usage(sys.argv[0])
#         sys.exit(1)
#     s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
#     try:
#         s.bind((sys.argv[1], int(sys.argv[2])))
#         s.listen(0)
#         print("[+]Start Server.")
#     except Exception as e:
#         print("[-]Error Happened: %s" % e)#.message)
#         sys.exit(2)

#     while True:
#         c = s.accept()
#         os.dup2(c[0].fileno(), 0)
#         os.dup2(c[0].fileno(), 1)
#         os.dup2(c[0].fileno(), 2)

#         # It's important to use pty to spawn the shell.
#         pty.spawn("/bin/sh")
#         c[0].close()


# if __name__ == "__main__":
#     main()

# import sys
# from threading import Thread
# from PyQt5.QtWidgets import QApplication

# from pyqtconsole.console import PythonConsole

# app = QApplication([])
# console = PythonConsole()
# console.show()
# console.eval_in_thread()

# sys.exit(app.exec_())

# import sys,os
# from PyQt5 import QtCore, QtWidgets

# class EmbTerminal(QtWidgets.QWidget):
#     def __init__(self, parent=None):
#         super(EmbTerminal, self).__init__(parent)
#         self.process = QtCore.QProcess(self)
#         self.terminal = QtWidgets.QWidget(self)
#         layout = QtWidgets.QVBoxLayout(self)
#         layout.addWidget(self.terminal)
#         # Works also with urxvt:
#         self.process.start('urxvt',['-embed', str(int(self.winId()))])
#         self.setFixedSize(640, 480)


# class mainWindow(QtWidgets.QMainWindow):
#     def __init__(self, parent=None):
#         super(mainWindow, self).__init__(parent)

#         central_widget = QtWidgets.QWidget()
#         lay = QtWidgets.QVBoxLayout(central_widget)
#         self.setCentralWidget(central_widget)

#         tab_widget = QtWidgets.QTabWidget()
#         lay.addWidget(tab_widget)

#         tab_widget.addTab(EmbTerminal(), "EmbTerminal")
#         tab_widget.addTab(QtWidgets.QTextEdit(), "QTextEdit")
#         tab_widget.addTab(QtWidgets.QMdiArea(), "QMdiArea")


# if __name__ == "__main__":
#     app = QtWidgets.QApplication(sys.argv)
#     main = mainWindow()
#     main.show()
#     sys.exit(app.exec_())

import time
import re
import subprocess
import sys, os, shutil
from PySide2.QtCore import (Qt, QProcess,)
from PySide2.QtGui import (QWindow,)
from PySide2.QtWidgets import (QApplication, QWidget, QVBoxLayout, QMessageBox,)

class Window(QWidget):
    def __init__(self, program, arguments):
        super().__init__()
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        self.setLayout(layout)
        self.external = QProcess(self)
        self.external.start(program, arguments)
        time.sleep(15)
        p = subprocess.run(['xprop', '-root'], stdout=subprocess.PIPE)
        for line in p.stdout.decode().splitlines():
            m = re.fullmatch(r'^_NET_ACTIVE_WINDOW.*[)].*window id # (0x[0-9a-f]+)', line)
            if m:
                self.embedWindow(int(m.group(1), 16))

                # this is where the magic happens...
                self.external.finished.connect(self.close_maybe)
                break
        else:
            QMessageBox.warning(self, 'Error',  'Could not find WID for curreent Window')

    def close_maybe(self):
        pass

    def closeEvent(self, event):
        self.external.terminate()
        self.external.waitForFinished(1000)

    def embedWindow(self, wid):
        window = QWindow.fromWinId(wid)
        # window.setFlag(Qt.FramelessWindowHint, True)
        widget = QWidget.createWindowContainer(
            window, self, Qt.FramelessWindowHint)
        self.layout().addWidget(widget)


if __name__ == '__main__':

    if len(sys.argv) > 1:
        if shutil.which(sys.argv[1]):
            app = QApplication(sys.argv)
            window = Window(sys.argv[1], sys.argv[2:])
            window.setGeometry(100, 100, 800, 600)
            window.show()
            sys.exit(app.exec_())
        else:
            print('could not find program: %r' % sys.argv[1])
    else:
        print('usage: python %s <external-program-name> [args]' %
              os.path.basename(__file__))