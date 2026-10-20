from pathlib import Path
import os,subprocess,json,xml.etree.ElementTree as E,zipfile
from PIL import Image,ImageDraw
OUT=Path(__file__).resolve().parent;STEM='La Vida Se Va Como El Viento - Israel Gómez Morales - SATB - Cantai'
env=dict(os.environ,QT_QUICK_BACKEND='software');env.pop('QT_QPA_PLATFORM',None)
style=E.parse('output/satb_lote_2026_10_19/choral.mss').getroot();s=style.find('Style')
for key,value in [('lyricsDashForce','1'),('lyricsDashMaxDistance','12'),('hideEmptyStaves','0')]:
 old=s.find(key)
 if old is None:old=E.SubElement(s,key)
 old.text=value
E.ElementTree(style).write(OUT/'choral.mss',encoding='utf-8',xml_declaration=True)
binary='C:/Program Files/MuseScore 4/bin/MuseScore4.exe'
jobs=[(['-S',OUT/'choral.mss','-o',OUT/(STEM+'.mscz'),OUT/'final.musicxml'],'create'),(['-o',OUT/'reopened.musicxml',OUT/(STEM+'.mscz')],'reopen'),(['-o',OUT/'playback.mid',OUT/(STEM+'.mscz')],'playback'),(['-r','100','-o',OUT/'preview.png',OUT/(STEM+'.mscz')],'preview')]
for args,label in jobs:
 result=subprocess.run([binary]+list(map(str,args)),env=env,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=180)
 (OUT/(label+'.log')).write_text(result.stdout+'\n'+result.stderr,encoding='utf8');print(label,result.returncode,flush=True);assert result.returncode==0,result.stderr
 if label=='create':
  path=OUT/(STEM+'.mscz')
  with zipfile.ZipFile(path) as z:items={n:z.read(n) for n in z.namelist()}
  name=next(n for n in items if n.endswith('.mscx'));root=E.fromstring(items[name])
  composer=next(t for t in root.findall('.//VBox/Text') if t.findtext('style')=='composer')
  composer.find('text').text='Letra y música: Jorge Díaz Mora\nArreglo: Israel Gómez Morales'
  items[name]=E.tostring(root,encoding='utf-8',xml_declaration=True)
  with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED) as z:
   for n,data in items.items():z.writestr(n,data)
files=sorted(OUT.glob('preview-*.png'),key=lambda p:int(p.stem.split('-')[-1]));contact=Image.new('RGB',(1200,580*((len(files)+2)//3)),'#ddd');draw=ImageDraw.Draw(contact)
for i,f in enumerate(files):
 im=Image.open(f).convert('RGB');im.thumbnail((390,550));x=i%3*400;y=i//3*580;contact.paste(im,(x,y+25));draw.text((x+8,y+5),str(i+1),fill='black')
contact.save(OUT/'contact.png');print('Pages',len(files))

