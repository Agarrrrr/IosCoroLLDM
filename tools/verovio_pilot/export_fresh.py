from pathlib import Path
import os,subprocess
from inspect_sources import SOURCE,OUT,source_files

env=os.environ.copy();env['QT_QPA_PLATFORM']='offscreen'
for key,path in source_files()+[('guerrero-celestial',SOURCE/'Guerrero Celestial.musicxml')]:
    target=OUT/(key+'-fresh.musicxml')
    result=subprocess.run(['C:/Program Files/MuseScore 4/bin/MuseScore4.exe','-o',str(target.resolve()),str(path.with_suffix('.mscz'))],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
    print(key,result.returncode,target.exists(),result.stderr[-600:])
