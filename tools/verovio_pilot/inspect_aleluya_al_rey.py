from pathlib import Path
import hashlib,json,re,subprocess
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from pypdf import PdfReader
from inspect_sources import NODE
OUT=Path('output/verovio_pilot_support/aleluya_al_rey');OUT.mkdir(parents=True,exist_ok=True)
raw=re.search(r"_rawKey = '([^']+)'",Path('lib/core/security/file_crypto.dart').read_text()).group(1)
cipher=AESGCM(hashlib.sha256(raw.encode()).digest())
row=next(r for r in json.loads(Path('assets/catalogo.json').read_text(encoding='utf-8')) if r['id']=='be1d8013-b5ba-4aed-b8f7-ae754e6e21a9')
for kind,field,ext in [('pdfs','archivo','pdf'),('midis','midi_archivo','mid')]:
    data=(Path('assets/offline_assets')/kind/row[field]).read_bytes()
    if not data.startswith((b'%PDF',b'MThd')):data=cipher.decrypt(data[:12],data[12:],None)
    (OUT/('original.'+ext)).write_bytes(data)
pdf=PdfReader(OUT/'original.pdf')
(OUT/'original.txt').write_text('\n'.join(f'PAGE {i+1}\n'+p.extract_text() for i,p in enumerate(pdf.pages)),encoding='utf-8')
print('PDF pages',len(pdf.pages));print((OUT/'original.txt').read_text(encoding='utf-8')[:12000])
subprocess.run(['pdftoppm','-scale-to','1700','-png',str(OUT/'original.pdf'),str(OUT/'original')],check=True,capture_output=True)
midi=json.loads(subprocess.run(['node','-e',NODE,str(OUT/'original.mid')],check=True,capture_output=True,text=True,encoding='utf-8').stdout)
(OUT/'midi-reading.json').write_text(json.dumps(midi,indent=2),encoding='utf-8')
print('MIDI metadata',{k:v for k,v in midi.items() if k!='tracks'})
print('TRACKS',[(i,t['name'],len(t['notes']),min(n['pitch'] for n in t['notes']) if t['notes'] else 0,max(n['pitch'] for n in t['notes']) if t['notes'] else 0) for i,t in enumerate(midi['tracks'])])
