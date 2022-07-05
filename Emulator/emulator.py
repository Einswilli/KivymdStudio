from pathlib import Path
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
from kivymd.uix.list import IconLeftWidget, IconRightWidget, OneLineListItem,ThreeLineListItem,OneLineAvatarIconListItem
from kivymd.uix.list import MDList
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.dialog import MDDialog
#from kivy.lang import Builder
from kivy.properties import ObjectProperty, StringProperty
from kivy.clock import Clock
import os
from plyer import filechooser,battery
from datetime import datetime
from time import *
from kivy.config import Config
import simplejson as Json
import shutil

Window.size=(310,640)
Window.resizable=False
Config.set('graphics','resizable',False)

kv="""
#:import HotReloadViewer kivymd.utils.hot_reload_viewer.HotReloadViewer
#:import hex kivy.utils.get_color_from_hex

Screen:
    name:'home'
    padding:'3dp'
    FitImage:
        source:'../assets/images/iph6.png'

    MDBoxLayout:
        id:hbox
        orientation:'vertical'
        size_hint:.895,0.792
        md_bg_color:0,0,0,0
        #padding:'8dp'
        pos_hint:{'center_x':.5,'center_y':.51}

        MDBoxLayout:
            orientation:'vertical'
            size_hint:1,.04
            md_bg_color:hex('#000000')
            MDGridLayout:
                rows:1
                MDGridLayout:
                    rows:1
                    MDGridLayout:
                        cols:1
                        Widget:
                        Lab:
                            id:lab2
                            font_size:11
                            halign:'center'
                            text:'13h : 19min'
                            pos_hint:{'center_x':.5,'center_y':.5}
                        Widget:
                    MDGridLayout:
                        rows:1
                        Image:
                            source:'icons/envelope.png'
                        Image:
                            source:'icons/wifi.png'
                        Widget:
                    #Widget:
                Widget:
                MDBoxLayout:
                    orientation:'vertical'
                    md_bg_color:hex('#000000')
                    MDGridLayout:
                        rows:1
                        size:self.size
                        md_bg_color:hex('#000000')
                        MDBoxLayout:
                            orientation:'vertical'
                            MDGridLayout:
                                rows:1
                                Image:
                                    source:'icons/transfer.png'
                                Image:
                                    source:'icons/reseau.png'
                        Image:
                            id:batimg
                            source:''
                            pos_hint:{'center_x':.5,'center_y':.5}
                        MDGridLayout:
                            cols:1
                            Widget:
                            Lab:
                                id:battext
                                text:'0%'
                                font_size:11
                                halign:'center'
                                pos_hint:{'center_x':.5,'center_y':.5}
                            Widget:
                        

        Carousel:
            id:car
            size:self.size
            MDFloatLayout:
                size:self.size
                ScreenManager:
                    id:scm1
                    Screen:
                        name:"boot"
                        # FitImage:
                        #     source:'../assets/images/emh.png'
                        MDBoxLayout:
                            orientation:'vertical'
                            size:self.size
                            md_bg_color:hex('#00000')
                            Image:
                                source:'../assets/images/anim7.gif'
                                size:self.size
                                allow_strech:True
                                anim_delay:1
                                anim_reset:1
                    Screen:
                        name:"page"
                        size:self.size
                        FitImage:
                            source:'../assets/images/anim4.gif'
                            allow_strech:True
                            anim_delay:1
                            anim_reset:1
                        
                        Lab:
                            id:lab
                            halign:'center'
                            text:'13h : 19min'
                            pos_hint:{'center_x':.5,'center_y':.8}

                        Custcard:
                            text:'Apps'
                            md_bg_color:hex('#00000000')
                            size_hint:.25,.2
                            pos_hint:{'center_x':.5,'center_y':.1}
                            image:'../assets/icons/menu(1).png'
                            on_press:app.home()

            MDFloatLayout:
                size:self.size
                FitImage:
                    source:'../assets/images/anim4.gif'
                MDBoxLayout:
                    orientation:'vertical'
                    size_hint:.85,.80
                    #size_hint_y:None
                    pos_hint:{'center_x':0.5,'center_y':.5}
                    canvas:
                        Color: 
                            rgba:hex('#373F3F49')
                        RoundedRectangle:
                            size:self.size
                            pos:self.pos
                            radius:[15,]
                    MDGridLayout:
                        pos:self.pos
                        cols:3
                        spacing:'5dp'
                        padding:'5dp'
                        Custcard:
                            text:'run file'
                            image:'../assets/icons/run.png'
                            on_press:app.choose_file()
                        Custcard:
                            text:'history'
                            image:'../assets/icons/list.png'
                        Custcard:
                            text:'Github'
                            image:'../assets/icons/git.png'
                        Custcard:
                            text:'Settings'
                            image:'../assets/icons/param.png'
                            on_press:app.settings()
                        Custcard:
                            text:'About'
                            image:'../assets/icons/py.png'
                        Custcard:
                            text:'About'
                            image:'../assets/icons/py.png'
                        Custcard:
                            text:'About'
                            image:'../assets/icons/py.png'
                        Custcard:
                            text:'Instagram'
                            image:'../assets/icons/instagram'
                        Custcard:
                            text:'youtube'
                            image:'../assets/icons/youtube.png'
                        Custcard:
                            text:'support'
                            image:'../assets/icons/coffee4.png'
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
                    orientation:'vertical'
                    Screen:
                        name:'capbox'
                        id:emusc
                        size:self.size
                        MDBoxLayout:
                            orientation:'vertical'
                            size:self.size
                            md_bg_color:hex('#000000')
                            HotReloadViewer:
                                id:reloader
                                size:hbox.size
                                #path:app.path_to_file
                                errors:True
                                errors_text_color:1,.2,.3,1
                                errors_background_color: 0,0,0,1

<Lab@MDLabel>:
    size_hint_y:None
    height:self.texture_size[1]
    font_size:34
    #theme_text_color:"white"
    #font_color:'#ffffff'
    text_color:'#ffffff'

<Custcard@MDCard>
    orientation:'vertical'
    md_bg_color:hex('#363D3F2D')
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
            font_size:14

"""

class Emulator(MDApp):

    path_to_file='calculatrice.kv'

    def build(self):
        self.theme_cls.theme_style='Dark'
        return Builder.load_string(kv)

    def on_start(self):
        Clock.schedule_once(self.next,18)
        Clock.schedule_interval(self.mytime,1)
        #self.loadbattery()
        Clock.schedule_interval(self.loadbattery,5)

    def loadbattery(self,*args):
        from random import randint
        bat=battery.status['percentage'] or randint(0,100)#
        #print(battery.status['isCharging'])
        self.root.ids.battext.text=f'{bat}%'
        if battery.status['isCharging']:
            self.root.ids.batimg.source='icons/battery-charging.png'
        elif int(bat)<10:
            self.root.ids.batimg.source='icons/battery-low.png'
        elif int(bat)in range(20,95):
            self.root.ids.batimg.source='icons/battery-mid.png'
        elif int(bat)>95:
            self.root.ids.batimg.source='icons/battery.png'
        

    def mytime(self,*args):
        heure=strftime("%H : %M : %S")
        self.root.ids.lab.text=str(heure)
        self.root.ids.lab2.text=heure[:-4]

    def next(self,dt):
        self.root.ids.scm1.current="page"

    def home(self):
        self.root.ids.car.load_next(mode='next')

    def settings(self, *largs):
        set_box=MDBoxLayout(
            orientation= "vertical",
            spacing= "12dp",
            size_hint_x= .78,
            size_hint_y=None,
            height= "126dp"
        )
        c=MDList()
        i1=OneLineListItem(text="use android screen",)
        #i1.on_press=self.pla
        i2=OneLineListItem(text="use iphone screen",)
        i3=OneLineListItem(text="Set Project assets dir")
        i3.on_press=self.set_asset
        #i2.on_press=self.plg
        c.add_widget(i1)
        c.add_widget(i2)
        c.add_widget(i3)
        set_box.add_widget(c)
        
        self.setting=MDDialog(
            title="Settings",
            type="custom",
            content_cls=set_box,
            size_hint_x=0.7,
            size_hint_y=None
            # buttons=[
            #     button,
            #     # MDFlatButton(
            #     # text="Réssayer", text_color=self.theme_cls.primary_color,
            #         ],
        )
        self.setting.open()
        
    def set_asset(self):
        filechooser.choose_dir(on_selection=self.handle_folder_selection)
        
    def handle_folder_selection(self,folder):
        print(folder)
        if os.path.exists(os.fspath(Path(__file__).resolve().parent / f"assets/{folder[0].split('/')[-1]}")):
            shutil.rmtree(os.fspath(Path(__file__).resolve().parent / f"assets/{folder[0].split('/')[-1]}"))
        shutil.copytree(folder[0],os.fspath(Path(__file__).resolve().parent / f"assets/{folder[0].split('/')[-1]}"))
        
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
        if path.endswith('.kv') or path.endswith('.py') :
            self.root.ids.reloader.path=path

            # elif  path.endswith('.py'):
            #     self.emulate_file(path)

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
            print(filename)
            try:  # cahching error with kivy files
                Builder.unload_file(filename)
                root = Builder.load_file(filename)
            except:
                traceback.print_exc()
                print("Your kivy file has a problem")

        elif os.path.splitext(filename)[1] == '.py':
            #self.load_defualt_kv(filename)
            print(filename)

            try:  # cahching error with python files
                root = self.load_py_file(filename)
            except:
                traceback.print_exc()
                msg=MDLabel(text="Your python file has a problem",halign='center')
                self.root.ids.emusc.add_widget(msg)
                print("Your python file has a problem")

        if root:
            self.root.app=self.get_app_cls_name(filename)
            b=MDBoxLayout()
            b.add_widget(root)
            if threaded:
                #####################################################------01
                #self.emulation_done(root, filename)
                self.root.ids.emusc.add_widget(b)
                pass
            else:
                pass
                ############# c'est ici ############################# -----02
                self.root.ids.emusc.add_widget(b)

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
            kv_filename=str(filename).replace('.py','.kv')
            if os.path.exists(kv_filename):
                root = Builder.load_file(kv_filename)
                return root
            else:return None

        kv_name = app_cls_name.lower()
        if app_cls_name.endswith('App'):
            kv_name = app_cls_name[:len(app_cls_name) - 3].lower()
            #print(kv_name)

        if app_cls_name:
            file_dir = os.path.dirname(filename)
            kv_filename = os.path.join(file_dir, kv_name + '.kv')

            if os.path.exists(kv_filename):
                try:  # cahching error with kivy files
                    Builder.unload_file(kv_filename)
                    root = Builder.load_file(kv_filename)
                    
                    kv_filename=str(filename).replace('.py','.kv')
                    root = Builder.load_file(kv_filename)
                    return root
                except:
                    
                    traceback.print_exc()
                    msg=MDLabel(text="Your kivy file has a problem",halign='center')
                    self.root.ids.emusc.add_widget(msg)
                    print("Your kivy file has a problem")

                    return None
                

    def get_app_cls_name(self,filename):
        with open(filename) as fn:
            text = fn.read()

        lines = text.splitlines()
        if 'from kivy.app import App' in lines:
            app_cls = self.get_import_as('from kivy.app import App', lines)
        else:
            app_cls= self.get_import_as('from kivymd.app import MDApp', lines)

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
            print('in')
            root_file = self.import_from_dir(filename)
            app_cls = getattr(reload(root_file), app_cls_name)
            root = app_cls().build()
            print(app_cls)
            return root
        print('out')
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
Emulator().run()
