import os,venv,platform,shutil
from pathlib import Path
from rope.base.project import Project
from rope.base import libutils
import simplejson as Json

def newProject(name,path,template='',add_temp=True,license=True,env=False,git=False,project_type='kv'):
    if project_type in ('kv','pykv'):
        if project_type=='kv':return create_kv_project(name,path,template,license,env,git)
        else:return create_pykv_project(name,path,template,license,env,git)
    else:
        return create_py_project(name,path,license,env,git)

    # venv.create(path,with_pip=False,)
    # os.makedirs(f'{path}/{name}')
    
def create_py_project(n,p,l,e,g):
    if not os.path.exists(p+n):
        os.makedirs(p+n)
        os.makedirs(p+n+'/lib/')
        os.makedirs(p+n+'/assets/icons/')
        os.makedirs(p+n+'/assets/images/')
        os.makedirs(p+n+'/assets/fonts/')
        if l:
            shutil.copyfile('assets/LICENSE',p+n+'/LICENSE')
        if g:
            shutil.copyfile('.gitignore',p+n+'/.gitignore')

            #: Will init a git repo in the project
            #os.makedirs(p+n+'/.git/')

        with open(p+n+'/main.py','x') as f:
            f.write('# This class was generated automatically by KivymdStudio')
    proj=Project(p+n,ropefolder='.KvStudio')

    #res=libutils.path_to_resource(proj,p+n)
    #print(proj.ropefolder)
    return p+n

def create_kv_project(n,p,t,l,e,g):
    if not os.path.exists(p+n):
        import utils
        os.makedirs(p+n)
        os.makedirs(p+n+'/kvs/')
        os.makedirs(p+n+'/assets/icons/')
        os.makedirs(p+n+'/assets/images/')
        os.makedirs(p+n+'/assets/fonts/')
        with open(p+n+'/main.kv','x') as f:
            code=f'''# This File was generated automatically by KivymdStudio\n#:import hex kivy.utils.get_color_from_hex\n{utils.TEMPLATES[t]}'''
            f.write(code)
        if l:
            shutil.copyfile('assets/LICENSE',p+n+'/LICENSE')
        if g:
            shutil.copyfile('.gitignore',p+n+'/.gitignore')

        proj=Project(p+n,ropefolder='.KvStudio')
        with open(p+n+'.KvStudio/emulator.json','x') as f:
            conf={
                'App_name':n,
                'primary_color':'blue',
                'theme':'dark',
                'main':p+n+'/main.kv',
                'assets':p+n+'/assets'
            }
            f.write(Json.dumps(conf,indent=4))
        with open(p+n+'.KvStudio/editor.json','x') as f:
            conf={
                'tab_size':8,
                'project_path':p+n,
                'highlight_theme':'monokai' #DEFAULT_THEME
            }
            f.write(Json.dumps(conf,indent=4))
        #os.makedirs(proj)
    return p+n

def create_pykv_project(n,p,t,l,e,g):
    pass

def activateEnv(name):
    if 'windows' in platform.system().lower():
        os.system(f'{name}\\Scripts\\activate.bat')
    else:os.system(f'source {name}/bin/activate')

def exitEnv():
    os.system('deactivate')
