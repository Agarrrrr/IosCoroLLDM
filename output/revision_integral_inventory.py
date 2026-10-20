from pathlib import Path
import json,zipfile,xml.etree.ElementTree as E,shutil,hashlib,os,subprocess,unicodedata
OUT=Path('output/catalogo_revision_integral_2026_10_19');OUT.mkdir(exist_ok=True)
batch=Path('output/satb_lote_2026_10_19');mapping={}
for r in json.loads((batch/'prepared-index.json').read_text(encoding='utf-8')):
 p=batch/f"{r['index']:02d}/partitura.pdf"
 if r['index']==10:p=batch/'12/partitura.pdf'
 if r['index']==20:p=Path('E:/Respaldo/musescoreactual/06_PDF/La Vida Se Va Como El Viento (reducción).pdf')
 mapping[r['finalName']]=dict(pdf=str(p),batch=r['index'])
for p in Path('output/verovio_pilot_support').glob('*/*.musicxml'):
 if (p.parent/'original.pdf').exists():mapping.setdefault(p.stem,dict(pdf=str(p.parent/'original.pdf')))
mapping['No Hay Amigo Mejor - SATB desarrollado - Cantai']=mapping['No Hay Amigo Mejor - SATB desarrollado']
mapping['Valle de los Huesos Secos - SATB con letra']=dict(pdf='output/verovio_pilot_support/valle/original-2.pdf')
mapping['Valle de los Huesos Secos']=mapping['Valle de los Huesos Secos - SATB con letra']
mapping['El Cántico de los 144 Mil - SATB desarrollado - Cantai']=dict(pdf='output/cantico_144_mil/fuente.pdf')
mapping['Salmo 135 - SATB - Cantai']=dict(pdf='output/salmo_135/original.pdf')
env=os.environ.copy();env.pop('QT_QPA_PLATFORM',None);env['QT_QUICK_BACKEND']='software';rows=[]
for i,p in enumerate(sorted(Path('E:/MusescoreCantai').glob('*.mscz')),1):
 w=OUT/f'{i:02d}';w.mkdir(exist_ok=True);copy=w/'original.mscz'
 if not copy.exists():shutil.copy2(p,copy)
 assert hashlib.sha256(copy.read_bytes()).digest()==hashlib.sha256(p.read_bytes()).digest(),'Saved file changed after inventory'
 with zipfile.ZipFile(copy) as z:
  name=next(n for n in z.namelist() if n.endswith('.mscx') and '/' not in n);root=E.fromstring(z.read(name));staff=root.findall('Score/Staff');style=w/'original.mss';style.write_bytes(z.read('score_style.mss'))
 if not (w/'source.musicxml').exists():
  proc=subprocess.run(['C:/Program Files/MuseScore 4/bin/MuseScore4.exe','-o',str(w/'source.musicxml'),str(copy)],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240);assert proc.returncode==0,proc.stderr
 row=dict(index=i,name=p.stem,destination=str(p),originalHash=hashlib.sha256(copy.read_bytes()).hexdigest(),work=str(w),staves=len(staff),bars=[len(s.findall('Measure')) for s in staff],notes=len(root.findall('.//Note')),lyrics=len(root.findall('.//Lyrics')),**mapping[p.stem]);rows.append(row);print(i,p.stem,row['staves'],row['bars'][0],flush=True)
(OUT/'inventory.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
