import os,venv,platform
from pathlib import Path

def newProject(name,path,template='',add_temp=True,license=True,env=False,git=False,project_type='kv'):
    if project_type in ('kv','pykv'):
        if project_type=='kv':create_kv_project(name,path,license,env,git)
        else:create_pykv_project(name,path,license,env,git)
    else:
        create_py_project(name,path,license,env,git)

    venv.create(path,with_pip=False,)
    os.makedirs(f'{path}/{name}')
    
def create_py_project(n,p,l,e,g):
    pass

def create_kv_project(n,p,l,e,g):
    pass

def create_pykv_project(n,p,l,e,g):
    pass

def activateEnv(name):
    if 'windows' in platform.system().lower():
        os.system(f'{name}\\Scripts\\activate.bat')
    else:os.system(f'source {name}/bin/activate')

def exitEnv():
    os.system('deactivate')

newProject('/home/einswilli/will','will')