import re
import os,sys
class Highlighter(object):

    def __init__(self,text=''):
        self.text=text

    def highlight(self,text):
        violets = [
                "import", 'as', "try", "except", 'for', "while", 'if', 'return',
                'raise', 'break', 'pass', 'continue', 'with', 'from', 'assert', 'elif',
                'Finally', 'yield', 'lambda','else'
        ]
        bleus = [
            'def', 'class', 'in', 'is', 'self', 'not', 'and', 'True', 'False', 'None',
            'nonlocal', 'del', 'global', 'globals', 'locals'
        ]
        yellows = [
            'print', 'input', 'abs', 'bin', 'callable', 'delattr', 'all', 'any', 'ascii',
            'chr', 'dir', 'bin', 'classmethod', 'compile', 'copyright', 'credits', 'divmod',
            'enumerate', 'eval', 'exec', 'exit', 'filter', 'format', 'getattr',
            'hasattr', 'hash', 'help', 'hex', 'id', 'isinstance', 'issubclass', 'iter', 'len',
            'license', 'map', 'max', 'memoryview', 'min', 'next', 'object', 'oct', 'open', 'ord',
            'pow', 'property', 'quit', 'repr', 'reversed', 'round', 'setattr', 'slice',
            'sorted', 'staticmethod', 'sum', 'super', 'vars', 'zip', 'capitalize', 'casefold',
            'center', 'count', 'encode', 'endswith', 'expandtabs', 'find', 'format', 'format_map',
            'index', 'isalnum', 'isalpha', 'isdecimal', 'isdigit', 'isidentifier', 'islower', 'isnumeric',
            'isprintable', 'isspace', 'istitle', 'isupper', 'join', 'ljust', 'lower', 'lstrip', 'maketrans',
            'partition', 'replace', 'rfind', 'rindex', 'rjust', 'rpartition', 'rsplit', 'rstrip', 'split',
            'splitlines', 'startswith', 'strip', 'swapcase', 'title', 'translate', 'upper', 'zfill'
        ]
        greens = [
            'dict', 'str', 'int', 'float', 'bool', 'list', 'type', 'bytearray', 'bytes', 'complex',
            'set', 'tuple', 'function', 'frozenset', 'range', 'fichier-bin', 'fichier-txt','Object',
            'Slot'
        ]
        oranges=[
            '__init__','__str__','__repr__','__dict__','__hash__','__annotations__','__delatrtr__','__class__',
            '__dir__','__doc__','__eq__','__format__','__getattribute__','__init_subclass__','__module__','__reduce__',
            '__ne__','__new__','__reduce_ex__','__sizeof__','setattr__','__slots__'
        ]
        kv=[
            'canvas','rgb','rgba','Rectangle','RoundedRectangle','color'
        ]

        for l in str(text).splitlines():
            if l.startswith('#'):
                str(text).replace(l,"<span style='color:#0F572D'>" + l + "</span>")
            elif '#' in l:
                idx=l.index('#')
                str(text).replace(l[idx:],"<span style='color:#0F572D'>" + l[idx] + "</span>")
            
            else:
                for w in l:
                    if w in greens:
                        l.replace(w,"<span style='color:#00C0A6'><b>" + w + "</b></span>")
                    elif w in bleus:
                        l.replace(w,"<span style='color:#19478B'><b>" + w + "</b></span>")
                    elif w in yellows:
                        l.replace(w,"<span style='color:#E2D958'>" + w + "</span>")
                    elif w in violets:
                        l.replace(w,"<span style='color:#9607A3'><b>" + w + "</b></span>")
                    elif w in oranges:
                        l.replace(w,"<span style='color:#EB7200'><b>" + w + "</b></span>")
                    elif w in kv:
                        l.replace(w,"<span style='color:#89D116'><b>" + w + "</b></span>")
                    elif w.startswith(r'MD[A-Z][a-zA-Z0-9]'):
                        l.replace(w,"<span style='color:#00C0A6'><b>" + w + "</b></span>")
                l.replace(r"([A-Z][A-Za-z]*|[a-z][A-Za-z]*|[A-Z][A-Za-z_]*|[a-z][A-Za-z_]*|[0-9]+|[ \t\n]|['][^']*[']|[^A-Za-z0-9\t\n ])",) 