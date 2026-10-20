import build_score as b
from pathlib import Path
from fractions import Fraction as F
import json,collections,xml.etree.ElementTree as E,pdfplumber
heads=[]
for g in b.PDF['groups']:
 for h in g['heads']:heads.append(dict(h,onset=g.get('onset')))
def dia(p):
 natural=[0,2,4,5,7,9,11];return (p//12-1)*7+min(range(7),key=lambda k:abs(natural[k]-p%12))
def nearest(page,point):
 x,y=point;candidates=[h for h in heads if h['page']==page]
 h=min(candidates,key=lambda h:abs(h['x']-x)*2+abs(h['y']-y)*.7)
 cost=abs(h['x']-x)*2+abs(h['y']-y)*.7
 return h if cost<26 and abs(h['x']-x)<10 else None
def owners(h):
 m=h['measure'];roles=([2] if h['staff']==0 else [3]) if 19<=m<=28 else ([0,1] if h['staff']==0 else [2,3])
 onset=h['onset']
 if onset is None:
  gs=[g for g in b.PDF['groups'] if g['measure']==m and g.get('onset') is not None]
  onset=min(gs,key=lambda g:abs(g['x']-h['x']))['onset']
 time=b.START[m]+onset
 return {role:e for role in roles for e in b.NOTES if e['role']==role and dia(e['pitch'])==h['diatonic'] and e['absolute']<=time<e['absolute']+e['duration']}
arcs=[];review=[]
with pdfplumber.open(b.OUT/'original.pdf') as doc:
 for pi,page in enumerate(doc.pages,1):
  for c in page.curves:
   if len(c['path'])!=4 or c['path'][0][0]!='m' or c['path'][1][0]!='c' or c['path'][2][0]!='c' or c['width']<8 or c['height']<.4:continue
   a=nearest(pi,c['path'][0][1]);z=nearest(pi,c['path'][1][-1])
   if a is None or z is None:continue
   aa=owners(a);zz=owners(z)
   for role in aa.keys()&zz.keys():
    x,y=aa[role],zz[role]
    if x['absolute']>=y['absolute']:continue
    arcs.append((role,x['measure'],x['onset'],y['measure'],y['onset']))
    review.append(dict(page=pi,role=role,sourceStart=[x['measure'],x['onset']],sourceEnd=[y['measure'],y['onset']],pdfStart=c['path'][0][1],pdfEnd=c['path'][1][-1]))
# Small phrase arcs whose outlines are split into multiple PDF paths.
arcs.extend([(0,32,0,32,1),(0,41,0,41,1),(3,19,0,19,1)])
for m in [54,55]:
 for role in range(4):arcs.append((role,m,0,m,1))
arcs=sorted(set(arcs));written=[];active=collections.defaultdict(list)
for role,sm,so,em,eo in arcs:
 for i,m in enumerate(b.FORM):
  end=i+em-sm
  if m!=sm or end>=len(b.FORM) or b.FORM[end]!=em or any(b.FORM[i+j]!=sm+j for j in range(em-sm+1)):continue
  an=b.nodes.get((role,i,F(str(so))));zn=b.nodes.get((role,end,F(str(eo))))
  if not an or not zn:continue
  # Slurs belong to the chord as a whole; one notation on its primary head.
  start=b.measure_starts[i]+F(str(so));stop=b.measure_starts[end]+F(str(eo));active[role]=[(num,t) for num,t in active[role] if t>start];num=next(n for n in range(1,17) if n not in [j for j,t in active[role]])
  active[role].append((num,stop));E.SubElement(b.notation(an[0]),'slur',type='start',number=str(num));E.SubElement(b.notation(zn[0]),'slur',type='stop',number=str(num));written.append(dict(role=role,start=[i+1,so],end=[end+1,eo],source=[sm,so,em,eo]))
# Keep MusicXML child order valid after adding phrase curves.
order=['chord','pitch','rest','duration','tie','voice','type','dot','accidental','notations','lyric']
for n in b.root.findall('.//note'):n[:]=sorted(n,key=lambda x:order.index(x.tag) if x.tag in order else 99)
E.indent(b.root);E.ElementTree(b.root).write(b.OUT/'Oh Señor - SATB desarrollado - Cantai.musicxml',encoding='utf-8',xml_declaration=True)
(b.OUT/'phrasing.json').write_text(json.dumps(dict(sourceSlurs=arcs,expandedSlurs=written,pdfReview=review),ensure_ascii=False,indent=2),encoding='utf8')
print('Source phrase arcs:',len(arcs),'expanded:',len(written))
