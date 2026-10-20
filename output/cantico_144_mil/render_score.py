from pathlib import Path
import os,subprocess,json
from PIL import Image,ImageDraw
from build_score import STEM
from model import OUT

def run():
    binary='C:/Program Files/MuseScore 4/bin/MuseScore4.exe'
    work=OUT/'render';work.mkdir(exist_ok=True)
    env=os.environ.copy();env.pop('QT_QPA_PLATFORM',None);env['QT_QUICK_BACKEND']='software'
    jobs=[(['-S',str(OUT/'choral.mss'),'-o',str(OUT/(STEM+'.mscz')),str(OUT/(STEM+'.musicxml'))],'create'),
          (['-o',str(work/'exported.musicxml'),str(OUT/(STEM+'.mscz'))],'reopen'),
          (['-o',str(work/'playback.mid'),str(OUT/(STEM+'.mscz'))],'playback'),
          (['-r','110','-o',str(work/'preview.png'),str(OUT/(STEM+'.mscz'))],'preview')]
    for args,name in jobs:
        r=subprocess.run([binary,*args],env=env,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=180)
        (work/(name+'.log')).write_text(r.stdout+'\n'+r.stderr,encoding='utf8');print(name,r.returncode,flush=True)
        assert r.returncode==0,(name,r.stdout,r.stderr)
    files=sorted(work.glob('preview-*.png'),key=lambda p:int(p.stem.split('-')[-1]));print('Pages',len(files),flush=True)
    sheet=Image.new('RGB',(1200,580*((len(files)+2)//3)),'#ccc');draw=ImageDraw.Draw(sheet)
    for i,f in enumerate(files):
        im=Image.open(f).convert('RGB');im.thumbnail((400,550));x=i%3*400;y=i//3*580;sheet.paste(im,(x,y+25));draw.text((x+10,y+5),str(i+1),fill='black')
    sheet.save(work/'contact.png')

if __name__=='__main__':run()
