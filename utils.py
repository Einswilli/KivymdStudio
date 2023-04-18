import shutil,os,glob,sys,pathlib
from numpy import False_
import simplejson as Json

PATHS={
    'BASE_PATH':f'{pathlib.Path.home()}/.KvStudio/',
    'PLUGINS_PATH':f'{pathlib.Path.home()}/.KvStudio/plugins/',
    'LOGS_PATH':f'{pathlib.Path.home()}/.KvStudio/logs/',
    'CONFIG_PATH':f'{pathlib.Path.home()}/.KvStudio/configs/',
    'CONFIG_FILE':f'{pathlib.Path.home()}/.KvStudio/configs/studio.conf',
    'THEME_CONFIG':f'{pathlib.Path.home()}/.KvStudio/configs/theme.json',
    'STUDIO_PROJECTS_PATH':f'{pathlib.Path.home()}/KvStudio_Projects/'
}

TEMPLATES={
    'Empty':'',
    'Backdrop':"""
ScreenManager:
    id:screen_manager
    Screen:
        MDBackdrop:
            title: "Backdrop Activity"
            header_text: "Menu:"

            MDBackdropBackLayer:

                MDBoxLayout:
                    orientation:'vertical'
                    md_bg_color:hex('#f3f4f6')

            MDBackdropFrontLayer:

                MDBoxLayout:
                    orientation:'vertical'
                    md_bg_color:hex('#2e2b2b')
""",
    'Tabs':"""
<Tab@MDFloatLayout+MDTabsBase>:
	text:''																															
	MDLabel:
		text: "TabTwo Content"
		halign: "center"

ScreenManager:
    id:screen_manager
    Screen:
        MDBoxLayout:
            orientation: "vertical"

            MDToolbar:
                title: "Bottom-Nav"
                right_action_items: [["dots-vertical", lambda x: x]]

            MDBottomNavigation:

                Tab:
					text: "TabOne"
					content_text:'TabOne'
				Tab:
					text: "TabTwo"
					content_text:'TabTwo'
				Tab:
					text: "TabTree"
					content_text:'TabTree'
""",
    'NavigationDrawer':"""
ScreenManager:
	id:screen_manager
	Screen:
		MDBoxLayout:
			orientation: "vertical"

			MDToolbar:
				title: "Nav-Drawer"
				left_action_items: [["menu", lambda x: nav_drawer.set_state()]]
				right_action_items: [["dots-vertical", lambda x: x]]

			Widget:

		MDNavigationDrawer:
			id:nav_drawer
			MDBoxLayout:
				orientation:'vertical'
				md_bg_color:hex('#f3f4f6')
""",
    'BottomNavigation':"""
ScreenManager:
    id:scree_manager
    Screen:
        MDBoxLayout:
            orientation: "vertical"

            MDToolbar:
                title: "Bottom-Navigation"
                right_action_items: [["dots-vertical", lambda x: x]]

            MDBottomNavigation:

                MDBottomNavigationItem:
                    name: "one"
                    text: "One"
                    icon: "numeric-1"

                MDBottomNavigationItem:
                    name: "two"
                    text: "Two"
                    icon: "numeric-2"

                MDBottomNavigationItem:
                    name: "three"
                    text: "Three"
                    icon: "numeric-3"
"""

}

THEMES=[
    {
        'name':"monokai",
        'active':True
    },
    {
        'name':"manni",
        'active':False
    },
    {
        'name':"rrt",
        'active':False
    },
    {
        'name':"perldoc",
        'active':False
    },
    {
        'name':"borland",
        'active':False
    },
    {
        'name':"colorful",
        'active':False
    },
    {
        'name':"default",
        'active':False
    },
    {
        'name':"murphy",
        'active':False
    },
    {
        'name':"vs",
        'active':False
    },
    {
        'name':"trac",
        'active':False
    },
    {
        'name':"tango",
        'active':False
    },
    {
        'name':"fruity",
        'active':False
    },
    {
        'name':"autumn",
        'active':False
    },
    {
        'name':"bw",
        'active':False
    },
    {
        'name':"emacs",
        'active':False
    },
    {
        'name':"vim",
        'active':False
    },
    {
        'name':"pastie",
        'active':False
    },
    {
        'name':"friendly",
        'active':False
    },
    {
        'name':"native",
        'active':False
    }
]

words=[
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
    'splitlines', 'startswith', 'strip', 'swapcase', 'title', 'translate', 'upper', 'zfill',
    'dict', 'str', 'int', 'float', 'bool', 'list', 'type', 'bytearray', 'bytes', 'complex',
    'set', 'tuple', 'function', 'frozenset', 'range', 'fichier-bin', 'fichier-txt',
    'def', 'class', 'in', 'is', 'self', 'not', 'and', 'True', 'False', 'None','nonlocal', 'del', 
    'global', 'globals', 'locals',"import", 'as', "try", "except", 'for', "while", 'if', 'return',
    'raise', 'break', 'pass', 'continue', 'with', 'from', 'assert', 'elif','Finally', 'yield', 'lambda',
    '__init__','__str__','__repr__','__dict__','__hash__','__annotations__','__delatrtr__','__class__',
    '__dir__','__doc__','__eq__','__format__','__getattribute__','__init_subclass__','__module__','__reduce__',
    '__ne__','__new__','__reduce_ex__','__sizeof__','setattr__','__slots__'
]

def filter(name,mode,code,line,pos):
    if mode in (' ',',','@','\t','\u21E5','\u2029'):
        return[{'name':w.replace(name,f'<span style="color:aqua;"><b>{name}</b></span>'),'text':w,'doc':''}for w in sorted(words) if w.startswith(name)] if name!='' else []
    elif mode =='.':
        from jedi.api import Script
        import inspect

        try:
            s=Script(source=code.replace('\u2029','\n').replace('\u21E5','\t').replace('â€©','\n'))
            results = []
            col=len(str(code)[:pos].splitlines()[-1])
            line=len(str(code)[:pos].splitlines())
            # s.
            for c in s.complete(line,col):
                d={}
                doc=''
                d['name']=c.name.replace(name,f'<span style="color:aqua;"><b>{name}</b></span>')
                d['text']=c.name
                if c.type in ['function', 'class', 'instance']:
                    doc = c.docstring().replace("(self,", "(")
                d['doc']=doc
                # if doc.startswith("{}(".format(c.name)):
                #     continue
                results.append(d)
            if results==[]:
                prev_name=code[:pos].splitlines()[-1].split('.')[-2].split(' ')[-1]
                results=[{'name':e[0].replace(name,f'<span style="color:aqua;"><b>{name}</b></span>'),'text':e[0],'doc':''} for e in inspect.getmembers(prev_name) if e[0].startswith(name) if name!='']
                #print(prev_name,results)
            return results
        except Exception as e:
            print(e)
            return []


def add_directives(d):
    for i in d:
        if isinstance(i,list):
            for n in i:
                if n!='':
                    if n not in words:
                        words.append(n)
        elif isinstance(i,str):
            if i!='':
                if not n in words:
                    words.append(i)

def get_active_theme():
    with open(PATHS['THEME_CONFIG'],'r') as f:
        conf=Json.loads(f.read())

        for theme in conf:
            if theme['active']==True:
                return theme['name']

def activate_theme(name):
    with open(PATHS['THEME_CONFIG'],'r') as f:
        conf=Json.loads(f.read())
        t=[]
        for theme in conf:
            if theme['name']==name:
                theme['active']=True
            else:
                theme['active']=False
            t.append(theme)

def get_studio_projects():
    return PATHS['STUDIO_PROJECTS_PATH']