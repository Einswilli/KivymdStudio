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
    busy=Signal(bool,name='busy')
    exception=Signal(str,name='exception')
    answered=Signal(str,name='answered')

    try:
        stackOverflow=StackAPI('stackoverflow')
    except Exception as e:
        print(e)
        exception.emit(str(e))
        stackOverflow=None

    @Slot(str,result='QVariant')
    def search(self,text):

        self.busy.emit(True)
        worker=Worker(self.process_search,text)
        QThreadPool.globalInstance().start(worker)

    def format_question(self,question:dict):
        # print(question['question_id'])
        return{
            'id':question['question_id'],
            'title':question['title'],
            'link':question['link'],
            'user_id':question['owner']['user_id'] if question['owner']['user_type']!='does_not_exist' else 0,
            'user_name':question['owner']['display_name'] if 'display_name' in question['owner'].keys() else '--',
            'user_image':question['owner']['profile_image'] if 'profile_image' in question['owner'].keys() else '--',
            'user_link':question['owner']['link'] if 'link' in question['owner'].keys() else '--',
            'tags':' ,'.join(question['tags']),
            'view_count':question['view_count'],
            'answer_count':question['answer_count'],
            'score':question['score'],
            'is_answered':question['is_answered']
        }

    def format_answer(self,ans:dict):
        return {
            'id':ans['answer_id'],
            'question_id':ans['question_id'],
            'content':ans['body'],
            'is_accepted':ans['is_accepted'],
            'score':ans['score']
        }

    def process_search(self,text):

        try:
            questions=self.stackOverflow.fetch(
                'search/advanced',tagged='python',
                q=text
            )
            
            # with open('st.json','w')as f:
            #     f.write(Json.dumps(questions,indent=4))

            qs=[self.format_question(q) for q in questions['items']]
            self.busy.emit(False)
            self.result.emit(Json.dumps(qs,indent=4))
        except Exception as e:
            print(e)
            self.busy.emit(False)
            self.exception.emit(str(e))

    @Slot(int)
    def get_answers(self,question_id):
        self.busy.emit(True)
        worker=Worker(self.process_post_answers,question_id)
        QThreadPool.globalInstance().start(worker)

    def process_post_answers(self,post_id):

        try:
            answers=self.stackOverflow.fetch(
                f'questions/{post_id}/answers',filter='withbody'
            )

            with open('st.json','w')as f:
                f.write(Json.dumps(answers,indent=4))
            qs=[self.format_answer(q) for q in answers['items']]
            self.busy.emit(False)
            self.answered.emit(Json.dumps(qs,indent=4))
        except Exception as e:
            print(e)
            self.busy.emit(False)
            self.exception.emit(str(e))

# /questions/{ids}/answers
# StackManager().process_post_answers(74923685)#.process_search('How to declare variables in python')
