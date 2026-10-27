from pathlib import Path
import zipfile,hashlib,os,tempfile
from common import WORK,read_json,save_json,sha256

def deliver(manifest,destination='E:/MusescoreCantai'):
 entries=read_json(manifest);dest=Path(destination).resolve();assert dest.is_dir();receipt=[]
 # Complete preflight before writing any destination file.
 for entry in entries:
  p=Path(entry['file']).resolve();assert entry.get('reviewed') is True and p.suffix.lower()=='.mscz'
  assert Path(entry['validation']).is_file();assert sha256(p)==entry['sha256']
  with zipfile.ZipFile(p) as z:assert z.testzip() is None and any(n.endswith('.mscx') for n in z.namelist())
  target=dest/p.name;assert target.parent==dest
  if target.exists() and sha256(target)!=entry['sha256'] and sha256(target)!=entry.get('expected_existing_sha256'):raise RuntimeError('Existing file differs; preserving it: '+str(target))
 for entry in entries:
  source=Path(entry['file']);target=dest/source.name
  if not target.exists():
   with target.open('xb') as f:f.write(source.read_bytes())
  elif sha256(target)!=entry['sha256']:
   # A correction may replace only our byte-identical prior delivery.
   # User edits fail this check; preserve a recoverable prior copy locally.
   assert sha256(target)==entry['expected_existing_sha256']
   backup=WORK/'delivery_backups'/(entry['expected_existing_sha256']+'.mscz');backup.parent.mkdir(exist_ok=True)
   if not backup.exists():backup.write_bytes(target.read_bytes())
   fd,tmp=tempfile.mkstemp(prefix='.cantai-',suffix='.tmp',dir=dest)
   try:
    with os.fdopen(fd,'wb') as f:f.write(source.read_bytes())
    assert sha256(target)==entry['expected_existing_sha256'];os.replace(tmp,target)
   finally:
    if Path(tmp).exists():Path(tmp).unlink()
  assert sha256(target)==entry['sha256'];receipt.append(dict(path=str(target),sha256=entry['sha256'],bytes=target.stat().st_size))
 receipt_path=WORK/(Path(manifest).stem+'-receipt.json');save_json(receipt_path,receipt)
 print('DELIVERED',len(receipt),'MSCZ; SHA-256 verified')
 for row in receipt:print(row['path'])
