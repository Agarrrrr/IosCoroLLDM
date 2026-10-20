from pathlib import Path
import json,collections,math,re,unicodedata
import pdfplumber
OUT=Path(__file__).resolve().parent
RAW=json.loads((OUT/'midi.json').read_text(encoding='utf8'))
LENGTH={m:3 if m in [19,20,33,35,42,44] else 2 if m==0 else 4 for m in range(60)}
START={};pos=0
for m in range(60):START[m]=pos;pos+=LENGTH[m]
FORM=list(range(52))+[48,49,52,53]+list(range(29,50))+list(range(52,60))
assert sum(LENGTH[m] for m in FORM)==328
NATURAL=[0,2,4,5,7,9,11]
def dia(p):
 pc=p%12;return (p//12-1)*7+min(range(7),key=lambda k:abs(NATURAL[k]-pc))
def duration(n,role):
 return round((n['duration']+.00208333333333)/(.95 if role in [0,2] else 1)*4)/4
def reference_start(m):return START[m] if m<52 else START[m]+8 if m<54 else START[m]+96
events=[]
for role,t in enumerate(RAW['tracks']):
 for m in range(60):
  rs=reference_start(m)
  for n in t['notes']:
   if rs<=n['onset']<rs+LENGTH[m]-.001:
    events.append(dict(role=role,measure=m,onset=n['onset']-rs,duration=duration(n,role),pitch=n['pitch'],velocity=n['velocity'],absolute=START[m]+n['onset']-rs))
(OUT/'source-notes.json').write_text(json.dumps(dict(events=events,lengths=LENGTH,starts=START,form=FORM),ensure_ascii=False,indent=2),encoding='utf8')

def staff_groups(page):
 hh=sorted({round(e['top'],2) for e in page.edges if abs(e['top']-e['bottom'])<.2 and e['x1']-e['x0']>150});ys=[]
 for y in hh:
  if not ys or y-ys[-1]>.7:ys.append(y)
 result=[]
 for y in ys:
  if result and y<=result[-1][-1]+1:continue
  row=[min(ys,key=lambda v:abs(v-(y+4.62*i))) for i in range(5)]
  if all(abs(v-(y+4.62*i))<.16 for i,v in enumerate(row)):result.append(row)
 return result

def align(groups,notes,left,right):
 onset=sorted({e['onset'] for e in notes});n=len(groups);k=len(onset)
 states={(0,0):(0,[])}
 for i in range(n+1):
  for j in range(k+1):
   if (i,j) not in states:continue
   cost,path=states[i,j]
   def put(key,c,p):
    if key not in states or c<states[key][0]:states[key]=(c,p)
   if i<n:put((i+1,j),cost+2,path+[(i,None)])
   if i<n and j<k:
    g=groups[i];expected={dia(e['pitch']) for e in notes if e['onset']==onset[j]};seen={h['diatonic'] for h in g['heads']}
    missing=len(expected-seen);match=len(expected&seen)
    normalized=(g['x']-left)/(right-left)
    timing=onset[j]/max(1,max(onset)+.5)
    put((i+1,j+1),cost+missing*25-match*.2+abs(normalized-timing)*2,path+[(i,onset[j])])
 if (n,k) not in states:return []
 return states[n,k][1]

systems=[];allgroups=[];tokens=[];diagnostics=[]
with pdfplumber.open(OUT/'original.pdf') as doc:
 for pi,page in enumerate(doc.pages,1):
  staves=staff_groups(page);expected=12 if pi==1 else 10;assert len(staves)==expected,(pi,staves)
  firsts=[0,6,11,16,23,29] if pi==1 else [34,40,45,49,53]
  for sy,first in enumerate(firsts):
   top=staves[sy*2][0];bottom=staves[sy*2+1][-1]
   bars=sorted({round(r['x0'],2) for r in page.rects if .65<r['width']<.8 and r['height']>17 and abs(r['top']-top)<.8})
   nextbar=firsts[sy+1] if sy+1<len(firsts) else 34 if pi==1 else 60
   assert len(bars)-1==nextbar-first,(pi,first,bars,nextbar)
   systems.append(dict(page=pi,system=sy,first=first,last=nextbar-1,bars=bars,staves=staves[sy*2:sy*2+2]))
   heads=[];seen=set()
   for c in page.curves:
    color=c.get('non_stroking_color',0)
    black=color==0 or color==[0] or color==(0,) or color==[0,0,0] or color==(0,0,0)
    if not black or not c['fill'] or not 5.8<c['width']<10.5 or not 4.1<c['height']<5.8 or sum(p[0]=='c' for p in c['path'])!=4:continue
    x=(c['x0']+c['x1'])/2;y=(c['top']+c['bottom'])/2
    if not top-30<y<bottom+22 or not bars[0]<x<bars[-1]:continue
    staff=min(range(2),key=lambda si:abs(y-sum(staves[sy*2+si])/5));lines=staves[sy*2+staff]
    key=(round(x,1),round(y,1))
    if key in seen:continue
    seen.add(key);m=nextbar-1
    for b in range(len(bars)-1):
     if bars[b]<=x<bars[b+1]:m=first+b;break
    base=18 if staff==1 or 20<=m<=28 else 30
    d=base+round((lines[-1]+.24-y)/2.31)
    heads.append(dict(x=x,y=y,staff=staff,diatonic=d,measure=m,page=pi,system=sy))
   for m in range(first,nextbar):
    row=sorted([h for h in heads if h['measure']==m],key=lambda h:h['x']);groups=[]
    for h in row:
     if groups and h['x']-groups[-1]['x']<5.5:groups[-1]['heads'].append(h)
     else:groups.append(dict(x=h['x'],heads=[h],measure=m,page=pi,system=sy))
    notes=[e for e in events if e['measure']==m];mapping=align(groups,notes,bars[m-first],bars[m-first+1])
    for j,on in mapping:
     groups[j]['onset']=on
     if on is not None:
      want={dia(e['pitch']) for e in notes if e['onset']==on};got={h['diatonic'] for h in groups[j]['heads']}
      if want-got:diagnostics.append(dict(bar=m,onset=on,wanted=sorted(want),found=sorted(got),x=groups[j]['x']))
    allgroups.extend(groups)
   # One common lyric line, between the closed SA and TB staves.
   line=[c for c in page.chars if c['fontname'] in ['CIDFont+F2','CIDFont+F4'] and staves[sy*2][-1]+5<c['top']<staves[sy*2+1][0]-3]
   line=[c for c in line if c['text'] not in ['q']];line.sort(key=lambda c:c['x0']);chunks=[];chunk=[]
   def flush():
    if chunk:chunks.append(dict(text=unicodedata.normalize('NFKC',''.join(c['text'] for c in chunk)),x=(chunk[0]['x0']+chunk[-1]['x1'])/2));chunk.clear()
   for c in line:
    if c['text'].isspace():flush();continue
    if chunk and c['x0']-chunk[-1]['x1']>2.1:flush()
    chunk.append(c)
   flush()
   for chunk in chunks:
    candidates=[g for g in allgroups if g['page']==pi and g['system']==sy and g.get('onset') is not None]
    if not candidates:continue
    g=min(candidates,key=lambda g:abs(g['x']-chunk['x']))
    tokens.append(dict(**chunk,measure=g['measure'],onset=g['onset'],distance=abs(g['x']-chunk['x']),page=pi,system=sy))
result=dict(systems=systems,groups=allgroups,tokens=tokens,diagnostics=diagnostics)
(OUT/'pdf-alignment.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print('MIDI source notes',len(events),'performance bars',len(FORM),'PDF note groups',len(allgroups),'alignment warnings',len(diagnostics))
for d in diagnostics:print('PITCH',d)
for m in range(60):
 print(m,[(t['onset'],t['text'],round(t['distance'],1)) for t in tokens if t['measure']==m])
