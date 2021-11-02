from kivymd.app import MDApp
from kivy.core.window import Window
from kivy.lang.builder import Builder

import os, sys
import traceback
from threading import Thread
from functools import partial
try:
    from importlib import reload
except:
    pass
from kivy.lang import Builder
from kivy.clock import mainthread
from kivy.resources import resource_add_path, resource_remove_path
# from kivystudio.components.emulator_area import emulator_area
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.behaviors import ToggleButtonBehavior
from kivy.uix.screenmanager import ScreenManager, Screen
from kivymd.uix.label import MDLabel
#from kivy.lang import Builder
from kivy.properties import ObjectProperty, StringProperty
from kivy.clock import Clock
import os
from plyer import filechooser

Window.size=(330,660)

kv="""
#:import HotReloadViewer kivymd.utils.hot_reload_viewer.HotReloadViewer
#:import hex kivy.utils.get_color_from_hex

Screen:
    name:'home'
    padding:'3pd'
    FitImage:
        source:'../assets/images/iph6.png'
    MDBoxLayout:
        id:hbox
        orientation:'vertical'
        size_hint:.88,0.75
        md_bg_color:0,0,0,0
        #padding:'8dp'
        pos_hint:{'center_x':.5,'center_y':.51}

        Carousel:
            id:car
            size:self.size
            MDFloatLayout:
                size:self.size
                FitImage:
                    source:'../assets/images/emh.png'
                    size:self.size
            MDFloatLayout:
                size:self.size
                MDBoxLayout:
                    orientation:'vertical'
                    size_hint:.8,.7
                    pos_hint:{'center_x':0.5,'center_y':.5}
                    canvas:
                        Color: 
                            rgba:hex('#373F3F')
                        RoundedRectangle:
                            size:self.size
                            pos:self.pos
                            radius:[25,]
                    MDGridLayout:
                        pos:self.pos
                        cols:2
                        spacing:'5dp'
                        padding:'5dp'
                        Custcard:
                            text:'history'
                            image:'../assets/icons/list.png'
                        Custcard:
                            text:'run file'
                            image:'../assets/icons/run.png'
                            on_press:app.choose_file()
                        Custcard:
                            text:'Settings'
                            image:'../assets/icons/param.png'
                        Custcard:
                            text:'Github'
                            image:'../assets/icons/git.png'
                        Custcard:
                            text:'About'
                            image:'../assets/icons/py.png'
                        Custcard:
                            text:'Quit'
                            image:'../assets/icons/deco.png'
                            on_press:app.previous()
            MDFloatLayout:
                size:self.size
                MDBoxLayout:
                    id:emusc
                    orientation:'vertical'
                    # HotReloadViewer:
                    #     id:reloader
                    #     size:hbox.size
                    #     path:''#'/root/Bureau/code/emutest.kv'
                    #     errors:True
                    #     errors_text_color:1,.2,.3,1
                    #     errors_background_color: 0,0,0,1



<Custcard@MDCard>
    orientation:'vertical'
    md_bg_color:hex('#363D3F')
    padding:'5dp'
    spacing:'5dp'
    radius:dp(10)
    ripple_behavior:True
    image:''
    text:''

    Image:
        source:root.image

    MDBoxLayout:
        orientation:'vertical'

        MDLabel:
            halign:'center'
            text:root.text

"""

class Emulator(MDApp):

    def build(self):
        self.theme_cls.theme_style='Dark'
        return Builder.load_string(kv)

    def choose_file(self):
        filechooser.open_file(on_selection=self.handle_selection)

    def previous(self):
        self.root.ids.car.load_previous()

    def handle_selection(self,selection):
        print(selection)
        self.root.ids.car.load_next(mode="next")
        #Window.borderless=True
        #self.root.ids.reloader.
        path=str(selection[0])
        if path.endswith('.py') or path.endswith('.kv'):
            self.emulate_file(path)
        else:
            print(f'Unknown file format:{str(path.split("/")[-1]).split(".")[-1]}')

    def emulate_file(self,filename, threaded=False):
        root = None
        if not os.path.exists(filename):
            return

        dirname = os.path.dirname(filename)
        sys.path.append(dirname)
        os.chdir(dirname)
        resource_add_path(dirname)
        
        ############## il supprime les widgets ##################--------00
        self.root.ids.emusc.clear_widgets()

        if threaded:
            Thread(target=partial(self.start_emulation, filename, threaded=threaded)).start()
        else:
            self.start_emulation(filename, threaded=threaded)

    def start_emulation(self,filename, threaded=False):
        root = None
        if os.path.splitext(filename)[1] == '.kv':  # load the kivy file directly
            try:  # cahching error with kivy files
                Builder.unload_file(filename)
                root = Builder.load_file(filename)
            except:
                traceback.print_exc()
                print("Your kivy file has a problem")

        elif os.path.splitext(filename)[1] == '.py':
            self.load_defualt_kv(filename)
            print(filename)

            try:  # cahching error with python files
                root = self.load_py_file(filename)
            except:
                traceback.print_exc()
                print("Your python file has a problem")

        if root:
            if threaded:
                #####################################################------01
                self.emulation_done(root, filename)
                pass
            else:
                pass
                ############# c'est ici ############################# -----02
                self.root.ids.emusc.add_widget(root)

        dirname = os.path.dirname(filename)
        sys.path.pop()
        resource_remove_path(dirname)

    @mainthread
    def emulation_done(self,root, filename):
        if root:
            ########################################################-------03
            self.root.ids.emusc.add_widget(root)
            pass


    def load_defualt_kv(self,filename):
        app_cls_name = self.get_app_cls_name(filename)
        if app_cls_name is None:
            return 

        kv_name = app_cls_name.lower()
        if app_cls_name.endswith('App'):
            kv_name = app_cls_name[:len(app_cls_name) - 3].lower()
            #print(kv_name)

        if app_cls_name:
            file_dir = os.path.dirname(filename)
            kv_filename = os.path.join(file_dir, kv_name + '.kv')
            print(kv_filename,file_dir)

            if os.path.exists(kv_filename):
                try:  # cahching error with kivy files
                    Builder.unload_file(kv_filename)
                    root = Builder.load_file(kv_filename)
                    if not root:
                        kv_filename=str(filename).replace('.py','.kv')
                        root = Builder.load_file(kv_filename)
                        return root
                except:
                    traceback.print_exc()
                    msg=MDLabel(text="Your kivy file has a problem",halign='center')
                    self.root.ids.emusc.add_widget(msg)
                    print("Your kivy file has a problem")

                    return 'root'
                

    def get_app_cls_name(self,filename):
        with open(filename) as fn:
            text = fn.read()

        lines = text.splitlines()
        app_cls = self.get_import_as('from kivy.app import App' or 'from kivymd.app import MDApp', lines)

        def check_app_cls(line):
            line = line.strip()
            return line.startswith('class') and line.endswith('(%s):' % app_cls)

        found = list(filter(check_app_cls, lines))

        if found:
            line = found[0]
            cls_name = line.split('(')[0].split(' ')[1]
            return cls_name

    def get_root_from_runTouch(self,filename):
        with open(filename) as fn:
            text = fn.read()

        lines = text.splitlines()
        run_touch = self.get_import_as('from kivy.base import runTouchApp', lines)

        def check_run_touch(line):
            line = line.strip()
            return line.startswith('%s(' % run_touch)

        found = list(filter(check_run_touch, lines))

        if found:
            line = found[0]
            root_name = line.strip().split('(')[1].split(')')[0]

            root_file = self.import_from_dir(filename)
            root = getattr(reload(root_file), root_name)

            return root

    def load_py_file(self,filename):
        app_cls_name = self.get_app_cls_name(filename)
        if app_cls_name:
            root_file = self.import_from_dir(filename)
            app_cls = getattr(reload(root_file), app_cls_name)
            root = app_cls().build()

            return root

        run_root = self.get_root_from_runTouch(filename)
        if run_root:
            return run_root


    def import_from_dir(self,filename):
        ''' force python to import this file
        from the project_ dir'''

        dirname, file = os.path.split(filename)
        sys.path = [dirname] + sys.path

        import_word = os.path.splitext(file)[0]
        imported = __import__(import_word)
        return imported

    def get_import_as(self,start, lines):
        line = list(filter(lambda line: line.strip().startswith(start), lines))
        if line:
            words = line[0].split(' ')
            import_word = words[len(words) - 1]
            return import_word
        else:
            return

emu=Emulator()
emu.run()