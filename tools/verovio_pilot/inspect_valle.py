"""Read the two bundled scores without changing the repertoire."""
from pathlib import Path
import hashlib,json,re,io,subprocess
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from pypdf import PdfReader

OUT=Path('output/verovio_pilot_support/valle');OUT.mkdir(parents=True,exist_ok=True)
raw=re.search(r"_rawKey = '([^']+)'",Path('lib/core/security/file_crypto.dart').read_text()).group(1)
cipher=AESGCM(hashlib.sha256(raw.encode()).digest())
def asset(kind,name):
    data=(Path('assets/offline_assets')/kind/name).read_bytes()
    return data if data.startswith((b'%PDF',b'MThd')) else cipher.decrypt(data[:12],data[12:],None)
rows=[r for r in json.loads(Path('assets/catalogo.json').read_text(encoding='utf-8')) if 'huesos' in r['nombre'].lower()]
for i,row in enumerate(rows):
    data=asset('pdfs',row['archivo']);pdf=PdfReader(io.BytesIO(data))
    (OUT/f'original-{i+1}.pdf').write_bytes(data)
    (OUT/f'original-{i+1}.mid').write_bytes(asset('midis',row['midi_archivo']))
    lines=[]
    for pi,page in enumerate(pdf.pages):
        lines.append(f'PAGE {pi+1}\n'+page.extract_text())
    subprocess.run(['pdftoppm','-scale-to','1600','-png',str(OUT/f'original-{i+1}.pdf'),str(OUT/f'original-{i+1}')],check=True,capture_output=True)
    (OUT/f'original-{i+1}.txt').write_text('\n'.join(lines),encoding='utf-8')
    print(row['nombre'],len(pdf.pages),'pages',hashlib.sha256(data).hexdigest())
    print('\n'.join(lines)[:1800])
