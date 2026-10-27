"""Lossless cache of deduplicated vector geometry, not an OMR prediction."""
import gzip,json,time
from pathlib import Path
import pdfplumber
from common import WORK,sha256

class GeometryPage:
 def __init__(self,data):self.__dict__.update(data)
 def dedupe_chars(self,tolerance=.12):
  if tolerance!=.12:raise ValueError('Cache uses dedupe tolerance .12')
  return self

class GeometryPDF:
 def __init__(self,rows,hit):self.pages=[GeometryPage(p) for p in rows];self.cache_hit=hit
 def __enter__(self):return self
 def __exit__(self,*args):return False

def open_geometry(path):
 path=Path(path);key=sha256(path)+'-pdfplumber-'+pdfplumber.__version__+'-dedupe012';cache=WORK/'geometry-cache'/(key+'.json.gz')
 if cache.exists():
  with gzip.open(cache,'rt',encoding='utf-8') as f:rows=json.load(f)
  return GeometryPDF(rows,True)
 rows=[]
 with pdfplumber.open(path) as pdf:
  for p in pdf.pages:
   p=p.dedupe_chars(tolerance=.12)
   rows.append({k:getattr(p,k) for k in ['width','height','chars','lines','curves','rects']})
 cache.parent.mkdir(parents=True,exist_ok=True);tmp=cache.with_suffix('.tmp')
 with gzip.open(tmp,'wt',encoding='utf-8') as f:json.dump(rows,f,ensure_ascii=False,separators=(',',':'))
 tmp.replace(cache);return GeometryPDF(rows,False)
