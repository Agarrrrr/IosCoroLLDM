"""Read stacked time-signature digits from the vector PDF, for review."""
from common import WORK,read_json,save_json
from pdf_cache import open_geometry

def detect_meters(job_id):
 p=WORK/'scores'/job_id;systems=read_json(p/'systems.json');found=[]
 with open_geometry(p/'original.pdf') as pdf:
  for sy in systems:
   page=pdf.pages[sy['page']-1];st=sy['staves'][0];spacing=(st[-1]-st[0])/4;S=spacing/4.9603;rows=[]
   for c in sorted(page.chars,key=lambda c:c['x0']):
    if not c['fontname'].endswith(('+Opus','+OpusStd')) or not c['text'].isdigit():continue
    y=page.height-c['matrix'][5]
    if not st[0]-S<y<st[-1]+3*S:continue
    row=next((r for r in rows if abs(r['y']-y)<.4*S and c['x0']-r['right']<3*S),None)
    if row is None:rows.append(dict(text=c['text'],left=c['x0'],right=c['x1'],y=y))
    else:row['text']+=c['text'];row['right']=c['x1']
   for top in rows:
    for bottom in rows:
     if not 1.5*spacing<bottom['y']-top['y']<2.5*spacing:continue
     if abs((top['left']+top['right'])/2-(bottom['left']+bottom['right'])/2)>5*S:continue
     n,d=int(top['text']),int(bottom['text'])
     if not 1<=n<=32 or d not in [2,4,8,16,32]:continue
     x=(top['left']+bottom['left'])/2;b=sy['first']+sum(bb<x+S for bb in sy['bars'])-1;b=max(sy['first'],b)
     item=dict(bar=b,meter=[n,d],page=sy['page'],x=round(x,3))
     if item not in found:found.append(item)
 save_json(p/'meter-review.json',found);print(job_id,found);return found
