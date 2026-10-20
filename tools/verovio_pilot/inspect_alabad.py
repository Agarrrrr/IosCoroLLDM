from pathlib import Path
import hashlib,json,re,io,subprocess
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from pypdf import PdfReader
OUT=Path('output/verovio_pilot_support/alabad');OUT.mkdir(parents=True,exist_ok=True)
raw=re.search(r"_rawKey = '([^']+)'",Path('lib/core/security/file_crypto.dart').read_text()).group(1)
cipher=AESGCM(hashlib.sha256(raw.encode()).digest())
row=next(r for r in json.loads(Path('assets/catalogo.json').read_text(encoding='utf-8')) if r['id']=='5426fdf8-3582-4049-81ac-bdef6a3f0414')
for kind,field,ext in [('pdfs','archivo','pdf'),('midis','midi_archivo','mid')]:
    data=(Path('assets/offline_assets')/kind/row[field]).read_bytes()
    if not data.startswith((b'%PDF',b'MThd')):data=cipher.decrypt(data[:12],data[12:],None)
    (OUT/('original.'+ext)).write_bytes(data)
pdf=PdfReader(OUT/'original.pdf')
(OUT/'original.txt').write_text('\n'.join(f'PAGE {i+1}\n'+p.extract_text() for i,p in enumerate(pdf.pages)),encoding='utf-8')
print('PDF pages',len(pdf.pages));print((OUT/'original.txt').read_text(encoding='utf-8')[:4500])
subprocess.run(['pdftoppm','-scale-to','1700','-png',str(OUT/'original.pdf'),str(OUT/'original')],check=True,capture_output=True)
for base in [Path('E:/MIDIS REVISAR TODOS'),Path('E:/Audios Octubre'),Path('C:/Users/Huri_/Downloads')]:
    for p in base.rglob('*'):
        if 'alabad' in p.name.lower() and p.is_file():print(p)
