from pathlib import Path
import json, subprocess
from PIL import Image, ImageDraw, ImageFont
OUT=Path('output/priority_midis/2026-10-11')
rows=json.loads((OUT/'inspection.json').read_text(encoding='utf-8'))
exe='C:/Users/Huri_/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/bin/pdftoppm.exe'
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
def vlq(b,p):
 v=0
 while True:
  x=b[p];p+=1;v=(v<<7)|(x&127)
  if x<128:return v,p
def read_midi(path):
 b=Path(path).read_bytes();ppq=int.from_bytes(b[12:14],'big');pos=8+int.from_bytes(b[4:8],'big');tracks=[];signatures=[]
 for i in range(int.from_bytes(b[10:12],'big')):
  n=int.from_bytes(b[pos+4:pos+8],'big');d=b[pos+8:pos+8+n];pos+=8+n;p=0;tick=0;running=None;notes=[];name=''
  while p<len(d):
   dt,p=vlq(d,p);tick+=dt;s=d[p]
   if s<128:s=running
   else:p+=1
   if s==255:
    t=d[p];p+=1;l,p=vlq(d,p);v=d[p:p+l];p+=l
    if t==3:name=v.decode('utf-8','replace')
    if t in [81,88,89]:signatures.append([tick,t,v.hex()])
   elif s in [240,247]:l,p=vlq(d,p);p+=l;running=None
   else:
    running=s;l=1 if s>>4 in [12,13] else 2;v=d[p:p+l];p+=l
    if s>>4==9 and v[1]>0:notes.append([tick,v[0],v[1]])
  if notes:tracks.append({'name':name,'first':notes[:16],'lastTick':tick,'notes':len(notes)})
 return {'ppq':ppq,'signatures':signatures,'tracks':tracks}
def render(path,prefix):
 subprocess.run([exe,'-f','1','-singlefile','-scale-to','1250','-png',str(path),str(prefix)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 return Image.open(str(prefix)+'.png').convert('RGB')
for idx,row in enumerate(rows,1):
 row['midiInfo']=read_midi(row['sourceMidi'])
 app=render(OUT/(row['id']+'.pdf'),OUT/f'{idx:02}_app')
 srcs=[]
 for j,s in enumerate(row['sourcePdfs']):
  src=render(Path(s['path']),OUT/f'{idx:02}_source{j}')
  s['firstPagePixelsIdentical']=app.size==src.size and app.tobytes()==src.tobytes()
  srcs.append(src)
 other=srcs[0] if srcs else None
 width=app.width+(other.width if other else 460)
 canvas=Image.new('RGB',(width,app.height+210),'white');draw=ImageDraw.Draw(canvas)
 draw.text((15,8),f'{idx:02} '+row['title']+' | APP izquierda / fuente derecha',font=font,fill='black')
 draw.text((15,30),'PPQ '+str(row['midiInfo']['ppq'])+' | firmas '+str(row['midiInfo']['signatures'][:8]),font=font,fill='black')
 for j,t in enumerate(row['midiInfo']['tracks']):
  ns=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
  label=t['name']+': '+' '.join(ns[n[1]%12]+str(n[1]//12-1) for n in t['first'][:12])
  draw.text((15,52+21*j),label,font=font,fill='black')
 canvas.paste(app,(0,190))
 if other:canvas.paste(other,(app.width,190))
 else:draw.text((app.width+15,220),'Sin PDF de la fuente',font=font,fill='black')
 canvas.save(OUT/f'{idx:02}_compare.jpg',quality=90)
(OUT/'inspection.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
for idx,row in enumerate(rows,1):
 print(json.dumps({'index':idx,'title':row['title'],'pixelSame':[s['firstPagePixelsIdentical'] for s in row['sourcePdfs']]},ensure_ascii=False))
