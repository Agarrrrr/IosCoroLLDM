from pathlib import Path
import json,base64,hashlib,uuid,re
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
APP=Path('E:/proyectos/IosCoroLLDM');OUT=APP/'output/remaining_midis/2026-10-12';OUT.mkdir(parents=True,exist_ok=True)
rs=json.loads((APP/'docs/repertorio/2026-10-12/revision_midis.json').read_text(encoding='utf-8'))
cats=json.loads((APP/'assets/catalogo.json').read_text(encoding='utf-8'))
matches=json.loads((APP/'docs/repertorio/2026-10-12/correspondencia_catalogo.json').read_text(encoding='utf-8'))
groups={}
for r in rs:
 if not r['category'].startswith('04'):groups.setdefault(r['title'],[]).append(r)
roots=[APP/'assets',Path('E:/proyectos/CoroLLDM/public'),Path('E:/proyectos/repertorio_bc/assets')]
baseline={'catalogs':{},'assets':{},'roots':[str(x) for x in roots if x.exists()]}
for root in roots:
 for f in [root/'catalogo.json',root/'catalogo_en.json',root/'offline_assets/catalogo.json',root/'offline_assets/catalogo_en.json']:
  if f.exists():baseline['catalogs'][str(f)]={'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'rows':json.loads(f.read_text(encoding='utf-8'))}
 for folder in ['pdfs','midis']:
  for f in (root/'offline_assets'/folder).rglob('*'):
   if f.is_file():baseline['assets'][str(f)]=hashlib.sha256(f.read_bytes()).hexdigest()
if (OUT/'baseline.json').exists():raise RuntimeError('Baseline ya existente; no sobrescribir')
key_text=re.search(r"_rawKey = '([^']+)'",(APP/'lib/core/security/file_crypto.dart').read_text(encoding='utf-8'))[1]
cipher=AESGCM(hashlib.sha256(key_text.encode()).digest())
def clear(b):return b if b.startswith(b'%PDF') else cipher.decrypt(b[:12],b[12:],None)
payload=[]
for title,rr in groups.items():
 if title in ['Coronadle Rey','Remembranza Gloriosa','Perfect (CMG)']:continue
 match=next(x for x in matches if x['title']==title)
 new=not match['exact']
 src=Path(rr[0]['source'])
 if title=='Lluvias Tard\u00edas':src=Path('E:/MIDIS REVISAR TODOS/CORO JALISCO 4TA SECCI\u00d3N/Lluvias Tard\u00edas CJ4S/Lluvias Tard\u00edas MOD by Caleb.mid')
 raw=src.read_bytes()
 if not raw.startswith(b'MThd'):raise ValueError('No MIDI')
 if new:
  pdfs=match['pdfs']
  if title=='Lluvias Tard\u00edas':pdfs=[str(src.parent/'Lluvias Tard\u00edas - Partitura completa.pdf')]
  if len(pdfs)!=1:raise ValueError('PDF ambiguo: '+title)
  pdf=Path(pdfs[0]);b=pdf.read_bytes();h=hashlib.sha256(b).hexdigest()
  row={'id':str(uuid.uuid4()),'nombre':title,'archivo':'global/assets/pdf/'+h+'.enc','temas':[],'es_privado':False,'idioma':'es','_idioma':'es','cifrado_version':1,'version':1}
 else:
  if len(match['exact'])!=1:raise ValueError('ID ambiguo')
  row=next(x for x in cats if x['id']==match['exact'][0]['id'])
  if row.get('midi_archivo'):raise ValueError('MIDI ya existente')
  pdf=APP/'assets/offline_assets/pdfs'/row['archivo'];b=clear(pdf.read_bytes());h=hashlib.sha256(b).hexdigest()
 item={'localId':row['id'],'title':title,'appRow':row,'newWork':new,'sourceMidi':str(src),'sourceMidiHash':hashlib.sha256(raw).hexdigest(),'sourcePdf':str(pdf),'pdfHash':h,'midiHash':hashlib.sha256(raw).hexdigest(),'midiData':'data:audio/midi;base64,'+base64.b64encode(raw).decode(),'sourceTracks':rr[0]['tracks']}
 if new:item['pdfData']='data:application/pdf;base64,'+base64.b64encode(b).decode()
 payload.append(item)
(OUT/'baseline.json').write_text(json.dumps(baseline,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'payload.json').write_text(json.dumps(payload,ensure_ascii=False),encoding='utf-8')
Path('E:/proyectos/CoroLLDM/public/__remaining_midis_payload.json').write_text(json.dumps(payload,ensure_ascii=False),encoding='utf-8')
print(json.dumps({'prepared':len(payload),'newWorks':sum(x['newWork'] for x in payload),'existing':sum(not x['newWork'] for x in payload),'oldFiles':len(baseline['assets']),'titles':[x['title'] for x in payload]},ensure_ascii=False))
