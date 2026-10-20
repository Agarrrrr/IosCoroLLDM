from pathlib import Path
import os,subprocess,json,shutil
from PIL import Image,ImageDraw
from inspect_sources import NODE
from extract_dios_poderoso import OUT
def render():
    out=OUT.resolve();work=out/'render';work.mkdir(exist_ok=True)
    for f in work.glob('preview-*.png'):f.unlink()
    binary='C:/Program Files/MuseScore 4/bin/MuseScore4.exe'
    env=os.environ.copy();env.pop('QT_QPA_PLATFORM',None);env['QT_QUICK_BACKEND']='software'
    source=out/'Dios Poderoso - SATB con letra.musicxml'
    style=out/'choral-spacing.mss';shutil.copy2(Path('output/verovio_pilot_support/alabad/choral-spacing.mss'),style)
    jobs=[([binary,'-S',str(style),'-o',str(work/'score.mscz'),str(source)],'styled'),
          ([binary,'-o',str(work/'exported.musicxml'),str(work/'score.mscz')],'export'),
          ([binary,'-o',str(work/'reimport.musicxml'),str(work/'exported.musicxml')],'reimport'),
          ([binary,'-o',str(work/'playback.mid'),str(work/'score.mscz')],'playback'),
          ([binary,'-o',str(work/'playback-reimport.mid'),str(work/'exported.musicxml')],'playback-reimport'),
          ([binary,'-r','110','-o',str(work/'preview.png'),str(work/'score.mscz')],'preview')]
    for command,name in jobs:
        p=subprocess.run(command,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
        (work/(name+'.log')).write_text(p.stdout+'\n'+p.stderr,encoding='utf-8');print(name,p.returncode,flush=True);assert p.returncode==0
    midi=json.loads(subprocess.run(['node','-e',NODE,str(work/'playback.mid')],check=True,capture_output=True,text=True,encoding='utf-8').stdout)
    (work/'playback.json').write_text(json.dumps(midi,indent=2),encoding='utf-8');print('EXPORTED TEMPOS',midi['tempos'])
    again=json.loads(subprocess.run(['node','-e',NODE,str(work/'playback-reimport.mid')],check=True,capture_output=True,text=True,encoding='utf-8').stdout)
    (work/'playback-reimport.json').write_text(json.dumps(again,indent=2),encoding='utf-8');print('REIMPORTED TEMPOS',again['tempos'])
    files=sorted(work.glob('preview-*.png'),key=lambda p:int(p.stem.split('-')[-1]));sheet=Image.new('RGB',(1050,510*((len(files)+2)//3)),'#cccccc');draw=ImageDraw.Draw(sheet)
    for i,f in enumerate(files):
        im=Image.open(f).convert('RGB');im.thumbnail((350,490));x=i%3*350;y=i//3*510;sheet.paste(im,(x,y+20));draw.text((x+8,y+3),f.stem,fill='black')
    sheet.save(work/'contact.png');print('PAGES',len(files))
if __name__=='__main__':render()
