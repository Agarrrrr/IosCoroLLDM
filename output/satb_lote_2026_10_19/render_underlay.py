from pathlib import Path
import json,subprocess,os,sys
from PIL import Image,ImageDraw
OUT=Path('output/underlay_revision_2026_10_19');jobs=json.loads((OUT/'corrections.json').read_text(encoding='utf-8'))
env=os.environ.copy();env.pop('QT_QPA_PLATFORM',None);env['QT_QUICK_BACKEND']='software';binary='C:/Program Files/MuseScore 4/bin/MuseScore4.exe'
selected={int(a) for a in sys.argv[1:]} if len(sys.argv)>1 else None
for i,r in enumerate(jobs,1):
 if selected is not None and i not in selected:continue
 if r.get('skip'):continue
 w=Path(r['work']);final=w/(r['name']+'.mscz')
 commands=[(['-S',r['style'],'-o',str(final),r['correctedXml']],'create'),(['-o',str(w/'reopened.musicxml'),str(final)],'reopen'),(['-o',str(w/'playback.mid'),str(final)],'playback'),(['-r','90','-o',str(w/'preview.png'),str(final)],'preview')]
 if r.get('nativePatch'):commands=commands[1:]
 for old in w.glob('preview-*.png'):old.unlink()
 for args,label in commands:
  p=subprocess.run([binary,*args],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240)
  (w/(label+'.log')).write_text(p.stdout+'\n'+p.stderr,encoding='utf-8');assert p.returncode==0,(i,label,p.stderr)
 images=sorted(w.glob('preview-*.png'),key=lambda p:int(p.stem.split('-')[-1]));sheet=Image.new('RGB',(1080,520*((len(images)+2)//3)),'#ddd');draw=ImageDraw.Draw(sheet)
 for j,p in enumerate(images):
  im=Image.open(p).convert('RGB');im.thumbnail((360,495));x=j%3*360;y=j//3*520;sheet.paste(im,(x,y+25));draw.text((x+8,y+5),str(j+1),fill='black')
 sheet.save(w/'contact.png');print(i,r['name'],len(images),'pages',flush=True)
