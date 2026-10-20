from pathlib import Path
import urllib.request,json,hashlib,re,xml.etree.ElementTree as ET
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
out=Path('output/lldm_comunidad/2026-10-15')
catalog=json.loads(Path('assets/catalogo.json').read_text(encoding='utf-8'))
ids={14:'aef84e4f-cdb1-4ab3-8dbe-895b03c8826c',15:'usmc_64b3e9a19631ba687d63072b',16:'usmc_64b52d5521b21cae026054cb',17:'usmc_64b3ebcb9631ba687d630851'}
text=Path('lib/core/security/file_crypto.dart').read_text(encoding='utf-8')
key=re.search(r"_rawKey = '([^']+)'",text)[1];cipher=AESGCM(hashlib.sha256(key.encode()).digest())
def clear(b):return b if b.startswith(b'%PDF') or b.startswith(b'MThd') else cipher.decrypt(b[:12],b[12:],None)
results=[]
for i,sid in ids.items():
 row=next(r for r in catalog if r['id']==sid)
 info=json.loads((out/(str(i)+'-info.json')).read_text(encoding='utf-8'))
 url=(out/'api_url.txt').read_text().strip()+info['item']['pdfUrl']
 remotePath=out/(str(i)+'-remote.pdf')
 if remotePath.exists():remote=remotePath.read_bytes()
 elif i==16:remote=None
 else:
  with urllib.request.urlopen(url,timeout=25) as res:remote=res.read()
 if remote is not None:(out/(str(i)+'-remote.pdf')).write_bytes(remote)
 local=clear((Path('assets/offline_assets/pdfs')/row['archivo']).read_bytes());(out/(str(i)+'-ours.pdf')).write_bytes(local)
 midi=clear((Path('assets/offline_assets/midis')/row['midi_archivo']).read_bytes());(out/(str(i)+'-ours.mid')).write_bytes(midi)
 xml=ET.fromstring((out/(str(i)+'-score.xml')).read_bytes())
 groups=[]
 for part in xml.findall('part'):
  voices={}
  for n in part.findall('measure/note'):
   if n.find('pitch') is not None:
    v=n.findtext('voice','1');voices[v]=voices.get(v,0)+1
  groups.append({'part':part.get('id'),'voices':voices})
 result={'id':i,'title':row['nombre'],'pdfSameBytes':remote==local if remote is not None else None,'theirPdfHash':hashlib.sha256(remote).hexdigest() if remote is not None else None,'ourPdfHash':hashlib.sha256(local).hexdigest(),'ourMidiHash':hashlib.sha256(midi).hexdigest(),'remoteXmlParts':groups}
 results.append(result);print(json.dumps(result,ensure_ascii=False))
(out/'comparison.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
