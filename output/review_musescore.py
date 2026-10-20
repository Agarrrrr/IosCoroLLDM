from pathlib import Path
import json,zipfile,xml.etree.ElementTree as ET,re,unicodedata,hashlib,subprocess
ROOT=Path('E:/proyectos/IosCoroLLDM')
OUT=ROOT/'output/musescore_review/2026-10-12'
OUT.mkdir(parents=True,exist_ok=True)
SRC=Path(r'C:\Users\Huri_\Downloads\musescore')
def norm(t):
 t=unicodedata.normalize('NFKD',t).encode('ascii','ignore').decode().lower()
 t=re.sub(r'\([^)]*\)|\[[^]]*\]',' ',t)
 t=re.sub(r'\b(satb|voces|closed|reduccion|ensamble)\b',' ',t)
 return re.sub('[^a-z0-9]+',' ',t).strip()
catalog=[]
for p in ['assets/catalogo.json','assets/catalogo_en.json']:
 catalog+=json.loads((ROOT/p).read_text(encoding='utf-8'))
confirmed=json.loads((ROOT/'docs/repertorio/2026-10-11/midis_confirmados.json').read_text(encoding='utf-8'))
print('confirmed keys',list(confirmed) if isinstance(confirmed,dict) else 'list')
rows=[];jobs=[]
for i,f in enumerate(sorted(SRC.rglob('*.mscz'))):
 row={'index':i,'source':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
 try:
  z=zipfile.ZipFile(f);names=[n for n in z.namelist() if n.endswith('.mscx') and '/' not in n]
  if not names: names=[n for n in z.namelist() if n.endswith('.mscx')]
  sc=ET.fromstring(z.read(names[0])).find('Score')
  title=sc.findtext("metaTag[@name='workTitle']") or f.stem
  labels=[p.findtext('trackName') or p.findtext('Instrument/longName') or '' for p in sc.findall('Part')]
  texts=[x.findtext('text','') for x in sc.findall("./Staff/VBox/Text") if x.findtext('style')=='title']
  title=texts[0] if texts else title
  keys={norm(title),norm(f.stem)}
  matches=[{'id':c['id'],'name':c['nombre'],'midi':c.get('midi_archivo')} for c in catalog if norm(c['nombre']) in keys]
  row.update(title=title,parts=len(labels),labels=labels,staffCount=len(sc.findall('Staff')),matches=matches,nearbyMidi=[str(x) for x in f.parent.glob('*.mid') if norm(x.stem) in keys])
  row['needsReview']=not matches or any(not x['midi'] for x in matches)
  if row['needsReview']:
   target=OUT/f'{i:03}.mid';row['temporaryMidi']=str(target);jobs.append({'in':str(f),'out':str(target)})
 except Exception as e: row['error']=str(e)
 rows.append(row)
(OUT/'scores.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'jobs.json').write_text(json.dumps(jobs,ensure_ascii=False),encoding='utf-8')
print('total',len(rows),'exportJobs',len(jobs))
for r in rows:
 if r.get('needsReview'): print(json.dumps({k:r[k] for k in ['index','title','parts','labels','matches']},ensure_ascii=False))
with (OUT/'export.log').open('w',encoding='utf-8') as log:
 p=subprocess.run([r'C:\Program Files\MuseScore 4\bin\MuseScore4.exe','-j',str(OUT/'jobs.json')],stdout=log,stderr=log,timeout=480,creationflags=0x08000000)
print('exportExit',p.returncode)
