import ast
import hashlib
import io
import json
import re
import unicodedata
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from pypdf import PdfReader

ROOT = Path('E:/proyectos/IosCoroLLDM')
MANAGER = Path('E:/proyectos/CoroLLDM')
OUT = ROOT / 'output/priority_midis/2026-10-11'
OUT.mkdir(parents=True, exist_ok=True)
entries = json.loads(Path('E:/Audios Octubre/Candidatos revisados - 2026-10-10/registro.json').read_text(encoding='utf-8'))['records']
catalog = json.loads((ROOT/'assets/catalogo.json').read_text(encoding='utf-8'))
manager_catalog = json.loads((MANAGER/'public/offline_assets/catalogo.json').read_text(encoding='utf-8'))
manager_ids = {row['id']: row for row in manager_catalog}
key_text = re.search(r"_rawKey = '([^']+)'", (ROOT/'lib/core/security/file_crypto.dart').read_text(encoding='utf-8'))[1]
cipher = AESGCM(hashlib.sha256(key_text.encode()).digest())
tree = ast.parse((ROOT/'output/repertoire_import/2026-10-10/prepare_import.py').read_text(encoding='utf-8'))
scope = {}
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in ('vlq','track_info')], type_ignores=[]), '<reader>', 'exec'),scope)

def norm(s):
    return re.sub('[^a-z0-9]+',' ',unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().lower()).strip()

def clear(b):
    return b if b.startswith(b'%PDF-') or b.startswith(b'MThd') else cipher.decrypt(b[:12],b[12:],None)

result=[]
for entry in entries:
    if not entry['category'].startswith('01'): continue
    matches=[row for row in catalog if norm(row['nombre'])==norm(entry['title'])]
    item={'title':entry['title'],'sourceMidi':entry['destination'],'catalogMatches':len(matches)}
    if len(matches)!=1:
        result.append(item);continue
    row=matches[0]; item.update(id=row['id'],pdfKey=row['archivo'],appMidi=row.get('midi_archivo'),appVersion=row.get('version'),managerRow=manager_ids.get(row['id']))
    midi=Path(entry['destination']).read_bytes();assert hashlib.sha256(midi).hexdigest()==entry['sha256']
    position=8+int.from_bytes(midi[4:8],'big');tracks=[]
    for _ in range(int.from_bytes(midi[10:12],'big')):
        size=int.from_bytes(midi[position+4:position+8],'big');data=midi[position+8:position+8+size];position+=8+size
        count, spans=scope['track_info'](data)
        if count:
            labels=[]
            for start,end in spans:
                _,offset=scope['vlq'](data,start)
                labels.append(data[offset:end].decode('utf-8',errors='replace'))
            tracks.append({'labels':labels,'notes':count})
    item['tracks']=tracks
    pdf=clear((ROOT/'assets/offline_assets/pdfs'/row['archivo']).read_bytes())
    (OUT/(row['id']+'.pdf')).write_bytes(pdf)
    item['pdfHash']=hashlib.sha256(pdf).hexdigest()
    reader=PdfReader(io.BytesIO(pdf));item['pages']=len(reader.pages);item['firstPageText']=reader.pages[0].extract_text()[:2200]
    folder=Path(entry['source']).parent
    source_pdfs=[]
    for path in folder.rglob('*.pdf'):
        digest=hashlib.sha256(path.read_bytes()).hexdigest()
        source_pdfs.append({'path':str(path),'hash':digest,'sameAsApp':digest==item['pdfHash']})
    item['sourcePdfs']=source_pdfs
    result.append(item)
(OUT/'inspection.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
for item in result:
    print(json.dumps({'title':item['title'],'matches':item['catalogMatches'],'tracks':item.get('tracks'),'samePdf':any(p['sameAsApp'] for p in item.get('sourcePdfs',[])),'sourcePdfs':[Path(p['path']).name for p in item.get('sourcePdfs',[])],'appMidi':item.get('appMidi'),'managerMidi':(item.get('managerRow') or {}).get('midi_archivo'),'text':item.get('firstPageText','')[:160]},ensure_ascii=False))
