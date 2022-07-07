from pygments.lexer import RegexLexer,bygroups,using
from pygments.lexers.python import PythonLexer
from pygments.token import *

class KivyLexer(RegexLexer):
    name='KivyLexer'
    aliases=['kivy','kivymd','kv']
    filenames=['*.kv']
    
    tokens = {
        'root': [
            (r'#:.*?$', Comment.Preproc),
            (r'#.*?$', using(PythonLexer)),
            (r'\s+', Text),
            (r'<.+>', Name.Namespace),
            (r'(\[)(\s*)(.*?)(\s*)(@)',
                bygroups(Punctuation, Text, Name.Class, Text, Operator),
                'classList'),
            (r'[A-Za-z][A-Za-z0-9]*$', Name.Attribute),
            (r'(.*?)(\s*)(:)(\s*)$',
                bygroups(Name.Class, Text, Punctuation, Text)),
            (r'(.*?)(\s*)(:)(\s*)(.*?)$',
                bygroups(Name.Attribute, Text, Punctuation, Text,
                using(PythonLexer))),
            (r'[^:]+?$', using(PythonLexer))],
        'classList': [
            (r'(,)(\s*)([A-Z][A-Za-z0-9]*)',
                bygroups(Punctuation, Text, Name.Class)),
            (r'(\+)(\s*)([A-Z][A-Za-z0-9]*)',
                bygroups(Operator, Text, Name.Class)),
            (r'\s+', Text),
            (r'[A-Z][A-Za-z0-9]*', Name.Class),
            (r'\]', Punctuation, '#pop')]}
