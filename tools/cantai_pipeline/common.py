"""Small, local, resumable helpers for preparing and checking choral scores."""
from pathlib import Path
import hashlib,json,unicodedata,re

REPO=Path(__file__).resolve().parents[2]
WORK=REPO/'output/cantai_pipeline'
WORK.mkdir(exist_ok=True)

def normalized(s):
 return ''.join(c.lower() for c in unicodedata.normalize('NFKD',s) if c.isalnum())

def slug(s):
 return re.sub('[^a-z0-9]+','_',unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().lower()).strip('_')

def read_json(p,default=None):
 return json.loads(Path(p).read_text(encoding='utf-8')) if Path(p).exists() else default

def save_json(p,value):
 p=Path(p);p.parent.mkdir(parents=True,exist_ok=True);tmp=p.with_suffix(p.suffix+'.tmp')
 tmp.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8');tmp.replace(p)

def sha256(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
