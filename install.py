import os
from pathlib import Path
os.system("pip install -r requirements.txt")
folder_naames=['plugins/python','config','logs','logs/studio','logs/emulator']

if not os.path.exists:
    for i in folder_naames:
        os.makedirs(f'{Path.home}/.kvStudio/{i}')