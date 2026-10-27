from pathlib import Path
import hashlib,sys,json,time,collections
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import pdfplumber
from PIL import Image,ImageDraw
from common import REPO,WORK,read_json,save_json,sha256
from pdf_cache import open_geometry
sys.path.insert(0,str(REPO/'output/cantico_144_mil'))
from midi_reader import read as read_midi

def prepare(ids=None):
 queue=read_json(WORK/'queue.json',[])
 for job in queue:
  if ids and job['id'] not in ids:continue
  if not job['source']:print(job['requested'],'REVIEW catalog match');continue
  folder=WORK/'scores'/job['id'];folder.mkdir(parents=True,exist_ok=True);source=job['source'];inputs={}
  for key,typ,name,signature in [('pdf','pdfs','original.pdf',b'%PDF'),('midi','midis','reference.mid',b'MThd')]:
   if not source.get(key):continue
   src=REPO/'assets/offline_assets'/typ/source[key];target=folder/name;digest=sha256(src);inputs[key]=digest
   if job.get('input_hashes',{}).get(key)==digest and target.exists():continue
   raw=src.read_bytes()
   if raw[:4]!=signature:raw=AESGCM(hashlib.sha256(b'repertorio-coral-lldm-key-2026').digest()).decrypt(raw[:12],raw[12:],None)
   assert raw[:4]==signature;target.write_bytes(raw)
  old=read_json(folder/'source-summary.json')
  if old and inputs==job.get('input_hashes'):
   print(job['requested'],'CACHED',old['pages'],'pages');continue
  midi=read_midi(folder/'reference.mid') if (folder/'reference.mid').exists() else None
  if midi:save_json(folder/'midi.json',midi)
  texts=[];fonts=collections.Counter()
  with pdfplumber.open(folder/'original.pdf') as pdf:
   for i,p in enumerate(pdf.pages,1):
    texts.append(f'PAGE {i}\n'+(p.extract_text() or ''));fonts.update(c['fontname'] for c in p.chars)
    p.to_image(resolution=130).save(folder/f'pdf-{i}.png')
   pages=len(pdf.pages)
  (folder/'pdf-text.txt').write_text('\n\n'.join(texts),encoding='utf-8')
  summary=dict(title=source['title'],pages=pages,fonts=fonts,tracks=[dict(name=t['name'],notes=len(t['notes']),end=t['end']) for t in midi['tracks'] if t['notes']] if midi else [],tempos=midi['tempos'] if midi else [])
  save_json(folder/'source-summary.json',summary);open_geometry(folder/'original.pdf')
  contact=Image.new('RGB',(1600,570*((pages+3)//4)),'#ddd');d=ImageDraw.Draw(contact)
  for i in range(pages):
   im=Image.open(folder/f'pdf-{i+1}.png').convert('RGB');im.thumbnail((390,540));x=i%4*400;y=i//4*570;contact.paste(im,(x,y+25));d.text((x+5,y+5),str(i+1),fill='black')
  contact.save(folder/'pdf-contact.png');job.update(input_hashes=inputs,workspace=str(folder),status='sources_ready');save_json(WORK/'queue.json',queue)
  print(job['requested'],'READY',pages,'pages',len(summary['tracks']),'MIDI tracks',flush=True)
