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

class StackManager(QObject):

    result=Signal(str,name='result')

    try:
        stackOverflow=StackAPI('stackoverflow')
    except Exception as e:
        print(e)
        stackOverflow=None

    @Slot(str,result='QVariant')
    def search(self,text):

        worker=Worker(self.process_search,text)
        QThreadPool.globalInstance().start(worker)

    def format_question(self,question):
        # print(question['question_id'])
        return{
            'id':question['question_id'],
            'title':question['title'],
            'link':question['link'],
            'user_id':question['owner']['user_id'] if question['owner']['user_type']!='does_not_exist' else 0,
            'user_name':question['owner']['display_name'],
            'user_image':question['owner']['profile_image'] if question['owner']['user_type']!='does_not_exist' else '--',
            'user_link':question['owner']['link'] if question['owner']['user_type']!='does_not_exist' else '-',
            'tags':' ,'.join(question['tags']),
            'view_count':question['view_count'],
            'answer_count':question['answer_count'],
            'score':question['score'],
            'is_answered':question['is_answered']
        }

    def process_search(self,text):

        try:
            questions=self.stackOverflow.fetch(
                'search/advanced',tagged='python',
                q=text
            )
            with open('st.json','w')as f:
                f.write(Json.dumps(questions,indent=4))
            qs=[self.format_question(q) for q in questions['items']]
            self.result.emit(Json.dumps(qs,indent=4))
        except Exception as e:
            print(e)
            pass

    def process_post(self,post_id):
        comments=self.stackOverflow.fetch(
            f'questions/{post_id}/answers'
        )

# StackManager().process_search('How to declare variables in python')
