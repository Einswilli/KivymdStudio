import subprocess
from PySide2.QtCore import QObject, Signal, Slot,QRunnable,QThreadPool

from pygments import highlight
from pygments.lexers.python import PythonLexer
from pygments.lexers import load_lexer_from_file
from pygments.lexers.special import TextLexer
from pygments.formatters.html import HtmlFormatter
from pygments.styles import get_style_by_name

from rich.console import Console
from rich.syntax import Syntax
import pyperclip
from flake8.api import legacy
from flake8 import *
from autopep8 import fix_code
import simplejson as Json

import locale, sys,utils

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

class EditorManager(QObject):

    def detect_lang(self,code):
        import re
        defs=code.count('def ')
        classes=code.count('class ')
        if defs>1 or classes>1:
            return PythonLexer()
        return load_lexer_from_file('kivyLexer.py','KivyLexer')

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

    #@Slot(str,result='QString')
    def colorify(self,text):

        """This is used to highlight the given text and returns a html format text

        Args:
            text str: the text which will be highlighted (it could be a code)

        Returns:
            srt: the highlighted text (in html format)
        """
        # directives=[l for l in text.split('\n') if str(l).startswith('import') and len(l.split(' '))>=2 or str(l).startswith('from')and len(l.split(' '))>3]
        
        # mods=[' '.join(d.split(' ',1)[-1].split(',')).split(' ') if d.startswith('import') else ' '.join(d[d.index('import')+6:].split(',',1)).split(' ') for d in directives ]
        # mods.extend([d.split(' ')[1] for d in directives if d.startswith('from')])
        # utils.add_directives(mods)
        #QSyntaxHighlighter()
        style = get_style_by_name(utils.get_active_theme())
        #print(highlight(text,PythonLexer(),HtmlFormatter(full=True,style=style)))
        h_text=highlight(self.clean(text),self.detect_lang(text),HtmlFormatter(full=True,style=style,noclasses=True,nobackground=True))
        # self.highlighting.emit(h_text)
        return h_text

    def clean(self,text):
        return text.replace('\u2029','\n')\
        .replace('\u21E5','\t').replace('â€©','\n')\
        .replace('    ','\t').replace('⇥','\t')

    @Slot(str,result='QString')
    def get_prev_indent_lvl(self,text):
        l=self.clean(str(text)).split('\n')
        prev_line=l[-2]
        tmp=prev_line.lstrip(' \t')
        p=len(prev_line.lstrip(' '))
        c=len(prev_line[:len(prev_line)-len(tmp)])+1 if prev_line.strip().endswith(':') else len(prev_line[:len(prev_line)-len(tmp)])
        
        return str(c)

    @Slot(str,result='QVariant')
    def check_code(self,path):
        style_g=legacy.get_style_guide(
            ignore=['E24','W5'],
            select=['E','W','F'],
            format='pylint'
        )
        stats=style_g.check_files(paths=path)
        if stats.get_statistics('E')==[]:                                         #'No ERROR FOUND'
            return [{'msgs':stats.get_statistics('W'),'t':0}]                     # Must return WARNNINGS
        if stats.get_statistics('W')==[]:                                         #'No WARNNING FOUND'
            return [{'msgs':stats.get_statistics('E'),'t':stats.total_errors}]    # Must return ERRORS


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
        # text=fix_code(text)
        #return self.colorify()#self.richcolor(text)#

        try:
            print(self.clean(str(text)))
            worker=Worker(self.colorify,self.clean(str(text)))
            QThreadPool.globalInstance().start(worker)
        except Exception as e:
            print(e)

        # return self.colorify(str(text).replace('\u2029','\n').replace('\u21E5','\t').replace('â€©','\n').replace('    ','\t'))

    @Slot(str,str,str,int,int,result='QVariant')
    def filter(self,name,mode,code,line,pos):
        return Json.dumps(utils.filter(name,mode,code,line,pos),indent=4)