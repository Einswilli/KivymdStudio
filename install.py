import os
from pathlib import Path
import utils
import simplejson as Json
#os.system("pip install -r requirements.txt")
folder_names=['plugins/python','config','logs','logs/studio','logs/emulator']

if not os.path.exists(f'{Path.home}/.kvStudio/'):
    for i in utils.PATHS:
        if utils.PATHS[i].endswith('/'):
            os.makedirs(f'{utils.PATHS[i]}')
else:
    for i in utils.PATHS:
        if not os.path.exists(i):
            if utils.PATHS[i].endswith('/'):
                os.makedirs(f'{i}')
if not os.path.exists(utils.PATHS['THEME_CONFIG']):
    with open(utils.PATHS['THEME_CONFIG'],'x') as f:
        f.write(Json.dumps(utils.THEMES,indent=4))