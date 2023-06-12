import subprocess
from PySide2.QtCore import QObject, Signal, Slot, QProcess

class CommandManager(QObject):
    command_output = Signal(str,name='commandOutput')

    @Slot(str)
    def execute_command(self, command):
        process = QProcess()
        process.finished.connect(self.process_finished)
        process.readyReadStandardOutput.connect(self.process_output)
        process.start(command)
        process.waitForFinished()

    def process_output(self):
        process = self.sender()
        output = process.readAllStandardOutput().data().decode('utf-8')
        self.command_output.emit(output.replace('\n','<br>'))

    def process_finished(self):
        process = self.sender()
        process.deleteLater()