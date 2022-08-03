import os,venv,platform
from pathlib import Path

def newProject(path,name):
    venv.create(path,with_pip=False,)
    os.makedirs(f'{path}/{name}')
    
def activateEnv(name):
    if 'windows' in platform.system().lower():
        os.system(f'{name}\\Scripts\\activate.bat')
    else:os.system(f'source {name}/bin/activate')

def exitEnv():
    os.system('deactivate')

newProject('/home/einswilli/will','will')