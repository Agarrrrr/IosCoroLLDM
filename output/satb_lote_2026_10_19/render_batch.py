from pathlib import Path
import subprocess,os,json,sys
from PIL import Image,ImageDraw
from inventory import OUT
def run():
    rows=json.loads((OUT/'prepared-index.json').read_text(encoding='utf8'));final=OUT/'final';final.mkdir(exist_ok=True)
    env=os.environ.copy();env['QT_QUICK_BACKEND']='software';binary='C:/Program Files/MuseScore 4/bin/MuseScore4.exe'
    indexes={int(x) for x in sys.argv[1:]} if len(sys.argv)>1 else None
    for r in rows:
        i=r['index']
        if indexes is not None and i not in indexes:continue
        w=OUT/f'{i:02d}';dest=final/(r['finalName']+'.mscz');jobs=[(['-S',str(OUT/'choral.mss'),'-o',str(dest),str(w/'prepared.musicxml')],'create'),(['-o',str(w/'reopened.musicxml'),str(dest)],'reopen'),(['-o',str(w/'playback.mid'),str(dest)],'midi'),(['-r','90','-o',str(w/'preview.png'),str(dest)],'preview')]
        for args,name in jobs:
            p=subprocess.run([binary,*args],env=env,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=240)
            (w/(name+'.log')).write_text(p.stdout+'\n'+p.stderr,encoding='utf8')
            assert p.returncode==0,(i,name,p.returncode,p.stdout,p.stderr)
        images=sorted(w.glob('preview-*.png'),key=lambda p:int(p.stem.split('-')[-1]));cols=3;tw=360;th=520;sheet=Image.new('RGB',(tw*cols,th*((len(images)+cols-1)//cols)),'#ddd');d=ImageDraw.Draw(sheet)
        for j,f in enumerate(images):
            im=Image.open(f).convert('RGB');im.thumbnail((tw,th-25));x=j%cols*tw;y=j//cols*th;sheet.paste(im,(x,y+25));d.text((x+8,y+5),f'{i:02d} / {j+1}',fill='black')
        sheet.save(w/'contact.png');print(i,r['finalName'],'PAGES',len(images),flush=True)
if __name__=='__main__':run()
