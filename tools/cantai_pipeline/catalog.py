from pathlib import Path
from difflib import SequenceMatcher
import json
from common import REPO,WORK,normalized,slug,read_json,save_json,sha256

CATALOG=REPO/'assets/catalogo.json'
BACKUP=Path('E:/Respaldo/musescoreactual')

def candidates(title):
 query=normalized(title);records=read_json(CATALOG)
 ranked=sorted(((1 if query==normalized(r['nombre']) else SequenceMatcher(None,query,normalized(r['nombre'])).ratio(),r) for r in records),key=lambda x:-x[0])
 return [dict(match=round(score,3),title=r['nombre'],pdf=r.get('archivo'),midi=r.get('midi_archivo')) for score,r in ranked[:4]]

def editable_index(refresh=False):
 p=WORK/'editable-index.json';old=read_json(p)
 if old is not None and not refresh:return old
 rows=[]
 if BACKUP.exists():
  for f in BACKUP.rglob('*'):
   if f.suffix.lower() in ['.mscz','.mscx','.mxl','.musicxml','.xml'] and f.is_file():
    rows.append(dict(path=str(f),name=f.name,normalized=normalized(f.name.split('.')[0])))
 save_json(p,rows);return rows

def enqueue(titles):
 queue=read_json(WORK/'queue.json',[]);index=editable_index()
 for title in titles:
  existing=next((q for q in queue if normalized(q['requested'])==normalized(title)),None)
  if existing:print(title,existing['status']);continue
  matches=candidates(title);exact=matches[0]['match']==1
  edits=[x['path'] for x in index if normalized(title)==x['normalized']]
  record=dict(id=slug(title),requested=title,status='queued' if exact else 'needs_catalog_match',source=matches[0] if exact else None,candidates=matches,editable=edits,versions=['original','synthesizer'])
  queue.append(record);print(title,'=>',matches[0]['title'],matches[0]['match'],'editable',len(edits),'MIDI',bool(matches[0]['midi']))
 save_json(WORK/'queue.json',queue)
