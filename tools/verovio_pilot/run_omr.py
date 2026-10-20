from pathlib import Path
import subprocess

out=Path('output/verovio_pilot_support/complete').resolve()
with (out/'audiveris.log').open('w',encoding='utf-8') as log:
    result=subprocess.run(['C:/Program Files/Audiveris/Audiveris.exe','-batch','-transcribe','-export','-output',str(out/'omr'),'--',str(out/'app-sample.pdf'),str(out/'acercame.pdf'),str(out/'al-gran-senor.pdf')],stdout=log,stderr=subprocess.STDOUT)
print('Audiveris exit',result.returncode)
print([str(p) for p in (out/'omr').rglob('*.mxl')])
