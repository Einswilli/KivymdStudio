import os
from .dbManager import *
from stackapi import StackAPI
import simplejson as Json
from PySide2.QtCore import QObject, Signal, Slot,QRunnable,QThreadPool


####
##  WORKER
#####
class Worker(QRunnable):
    '''
    Worker thread

    Inherits from QRunnable to handler worker thread setup, signals and wrap-up.

    :param callback: The function callback to run on this worker thread. Supplied args and
                     kwargs will be passed through to the runner.
    :type callback: function
    :param args: Arguments to pass to the callback function
    :param kwargs: Keywords to pass to the callback function

    '''

    def __init__(self, fn, *args, **kwargs):
        super(Worker, self).__init__()

        # Store constructor arguments (re-used for processing)
        self.fn = fn
        self.args = args
        self.kwargs = kwargs


    @Slot()
    def run(self):
        '''
        Initialise the runner function with passed args, kwargs.
        '''

        # Retrieve args/kwargs here; and fire processing using them
        
        self.fn(*self.args, **self.kwargs)


####
##  FILE MANAGER
#####
class FileManager(QObject):

    @Slot(str,result='QVariant')
    def search(self,text):
        pass

    @Slot(str)
    def save_to_history(self,path):
        db=get_db()
        curs=db.cursor()

        #SET THE CURRENT PROJECT
        self.set_current_project_dir(path)
        try:
            curs.execute(f"SELECT * from history WHERE link ='{path}'")
            if curs.fetchone() is not None:
                pass #file already exists in history!
            else: exec('1+a') # Must get an error and raise exception
        except Exception as e:
            # then Cool save ut to history
            curs.execute("INSERT INTO history VALUES(null,?)",(path,))
        db.commit()
        db.close()

    def set_current_project_dir(self,url):
        db=get_db()
        curs=db.cursor()

        try:
            curs.execute(f'UPDATE currentproject SET url=? where id=1',(url,))
        except:
            curs.execute("INSERT INTO currentproject VALUES(null,?)",(url,))
        db.commit()
        db.close()

    def get_current_project_dir(self):

        db=get_db()
        curs=db.cursor()

        curs.execute(f'SELECT * FROM currentproject  where id=1')
        d=curs.fetchone()
        
        db.commit()
        db.close()

        return {
            'name':os.path.basename(str(d[1])),
            'fname':str(d[1])
        }

    def process_search(self,text):
        pass