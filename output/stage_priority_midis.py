from pathlib import Path
import json,hashlib,base64
APP=Path('E:/proyectos/IosCoroLLDM')
OUT=APP/'output/priority_midis/2026-10-11'
rows=json.loads((OUT/'inspection.json').read_text(encoding='utf-8'))
cat=json.loads((APP/'assets/catalogo.json').read_text(encoding='utf-8'))
selected={2,3,4,5,6,7,8,9,10,11,13,14,15,17,18,19,22,23}
payload=[]
for i,r in enumerate(rows,1):
 if i not in selected:continue
 b=Path(r['sourceMidi']).read_bytes()
 payload.append({'localId':r['id'],'title':r['title'],'appRow':next(x for x in cat if x['id']==r['id']),'pdfHash':r['pdfHash'],'midiHash':hashlib.sha256(b).hexdigest(),'midiData':'data:audio/midi;base64,'+base64.b64encode(b).decode(),'tracks':r['tracks']})
roots=[APP/'assets',Path('E:/proyectos/CoroLLDM/public'),Path('E:/proyectos/repertorio_bc/assets')]
baseline={'catalogs':{},'assets':{},'roots':[]}
for root in roots:
 if not root.exists():continue
 baseline['roots'].append(str(root))
 for file in [root/'catalogo.json',root/'catalogo_en.json',root/'offline_assets/catalogo.json',root/'offline_assets/catalogo_en.json']:
  if file.exists():
   baseline['catalogs'][str(file)]={'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'rows':json.loads(file.read_text(encoding='utf-8'))}
 for folder in ['pdfs','midis']:
  directory=root/'offline_assets'/folder
  if directory.exists():
   for file in directory.rglob('*'):
    if file.is_file():baseline['assets'][str(file)]=hashlib.sha256(file.read_bytes()).hexdigest()
target=OUT/'baseline.json'
if target.exists():raise RuntimeError('Ya existe baseline: no sobrescribir')
target.write_text(json.dumps(baseline,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'payload.json').write_text(json.dumps(payload,ensure_ascii=False),encoding='utf-8')
Path('E:/proyectos/CoroLLDM/public/__midi_import_20261011.json').write_text(json.dumps(payload,ensure_ascii=False),encoding='utf-8')
print(json.dumps({'selected':len(payload),'baselineAssets':len(baseline['assets']),'catalogs':len(baseline['catalogs'])}))
