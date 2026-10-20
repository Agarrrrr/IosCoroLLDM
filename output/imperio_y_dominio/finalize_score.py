from pathlib import Path
from fractions import Fraction as F
import json,sys,collections,xml.etree.ElementTree as E,pdfplumber
sys.path.insert(0,'output/satb_lote_2026_10_19');from score_model import parse
OUT=Path(__file__).resolve().parent
root=E.parse(OUT/'underlaid.musicxml').getroot();parts=parse(root);layout=json.loads((OUT/'layout.json').read_text(encoding='utf-8'));mapped=json.loads((OUT/'mapped.json').read_text(encoding='utf-8'))['events'];nodes={}
def text(p,k,v,**attrs):e=E.SubElement(p,k,attrs);e.text=str(v);return e
def notation(n):
 e=n.find('notations')
 return e if e is not None else E.SubElement(n,'notations')
for r,part in enumerate(root.findall('part')):
 for b,m in enumerate(part.findall('measure'),1):
  for i,(n,e) in enumerate(zip(m.findall('note'),parts[r][b-1]['events'])):nodes[r,b,i]=n
primary={(e['role'],e['measure'],e['onset']):nodes[e['role'],e['measure'],e['index']] for e in mapped if not e['chord']}

curves=[]
for c in layout['curves']:
 if len(c['path'])!=2:continue
 start=c['path'][0][1];end=c['path'][1][-1];pi=c['page'];pool=[e for e in mapped if e['page']==pi]
 def cost(e,x,y):return abs(e['x']+3.3-x)*3+abs(e['y']-y)*.5
 a=min(pool,key=lambda e:cost(e,*start));b=min(pool,key=lambda e:cost(e,*end))
 sa=next(s for s in layout['systems'] if s['page']==pi and s['system']==a['system']);sb=next(s for s in layout['systems'] if s['page']==pi and s['system']==b['system'])
 if end[0]>sa['bars'][-1]-6:kind='open'
 elif start[0]<min(e['x'] for e in pool if e['system']==b['system'] and e['role']==b['role'])+.5:kind='close'
 else:kind='arc'
 curves.append(dict(a=a,b=b,kind=kind,start=start,end=end,page=pi))
opens=[c for c in curves if c['kind']=='open'];closes=[c for c in curves if c['kind']=='close'];pairs=[(c['a'],c['b']) for c in curves if c['kind']=='arc'];unpaired=[]
for c in opens:
 choices=[d for d in closes if d['b']['role']==c['a']['role'] and d['b']['absolute']>c['a']['absolute']]
 if not choices:unpaired.append(c);continue
 d=min(choices,key=lambda d:(d['b']['absolute'],abs(d['b']['pitch']-c['a']['pitch'])));closes.remove(d);pairs.append((c['a'],d['b']))
unpaired+=closes
positions={(r,m['index']+1,float(e['onset']),e['pitch']):i for r,p in enumerate(parts) for i,(m,e) in enumerate((m,e) for m in p for e in m['events'])}
connections=[];seen=set();active=collections.defaultdict(dict)
for a,b in sorted(pairs,key=lambda ab:ab[0]['absolute']):
 if a['role']!=b['role'] or a['absolute']>=b['absolute']:continue
 ka=(a['role'],a['measure'],a['onset'],a['pitch']);kb=(b['role'],b['measure'],b['onset'],b['pitch'])
 if (ka,kb) in seen:continue
 seen.add((ka,kb));na=nodes[a['role'],a['measure'],a['index']];nb=nodes[b['role'],b['measure'],b['index']]
 tie=a['pitch']==b['pitch'] and nb.find('lyric') is None and a['absolute']+a['duration']==b['absolute']
 if tie and na.find('tie[@type="start"]') is not None:continue
 role=a['role'];active[role]={k:v for k,v in active[role].items() if v>a['absolute']};num=next(i for i in range(1,17) if i not in active[role])
 if not tie:active[role][num]=b['absolute']
 for n,kind in [(na,'start'),(nb,'stop')]:
  if tie:E.SubElement(n,'tie',type=kind);E.SubElement(notation(n),'tied',type=kind)
  else:E.SubElement(notation(n),'slur',type=kind,number=str(num))
 connections.append(dict(a=ka,b=kb,tie=tie))

def direction(role,bar,onset,tag,value=None):
 m=root.findall('part')[role].findall('measure')[bar-1];d=E.Element('direction',placement='above');dt=E.SubElement(d,'direction-type')
 if value is None:E.SubElement(dt,tag)
 else:text(dt,tag,value)
 if onset:text(d,'offset',int(F(str(onset))*960))
 index=next((i for i,e in enumerate(m) if e.tag=='note'),len(m));m.insert(index,d)
 return dt
expressions=[];artics=[]
with pdfplumber.open(OUT/'original.pdf') as pdf:
 for pi,page in enumerate(pdf.pages,1):
  cs=[c for c in page.chars if 'BoldItalic' in c['fontname']];lines=[]
  for c in sorted(cs,key=lambda c:c['top']):
   line=next((l for l in lines if abs(l[0]['top']-c['top'])<3),None)
   if line is None:lines.append([c])
   else:line.append(c)
  for line in lines:
   groups=[]
   for c in sorted(line,key=lambda c:c['x0']):
    if not groups or c['x0']-groups[-1][-1]['x1']>3:groups.append([])
    groups[-1].append(c)
   for group in groups:
    value=''.join(c['text'] for c in group);x=(group[0]['x0']+group[-1]['x1'])/2;y=page.height-group[0]['matrix'][5]
    st=[(abs(y-staff[0]),s,r) for s in layout['systems'] if s['page']==pi for r,staff in enumerate(s['staves'])];_,sy,role=min(st,key=lambda t:t[0]);bar=sy['first']+sum(b<x+1 for b in sy['bars'])-1;bar=max(sy['first'],min(sy['last'],bar))
    candidates=[e for e in mapped if e['role']==role and e['page']==pi and e['system']==sy['system']];near=min(candidates,key=lambda e:abs(e['x']+3.3-x)) if candidates else None
    if near:bar=near['measure']
    onset=near['onset'] if near else 0
    # These marks sit above the sustained opening note of their bar.
    if pi==7 and value in ['mf','ff']:bar=59 if value=='mf' else 61;onset=0
    if value in ['p','mp','mf','f','ff']:
     dt=direction(role,bar,onset,'dynamics');E.SubElement(dt.find('dynamics'),value)
    elif value=='cresc.':direction(role,bar,onset,'words',value)
    else:continue
    expressions.append(dict(role=role,bar=bar,onset=onset,value=value))
  for c in page.chars:
   if not c['fontname'].endswith('+OpusStd') or c['text'] not in ['>','U','u']:continue
   x=c['x0'];y=page.height-c['matrix'][5];pool=[e for e in mapped if e['page']==pi]
   near=min(pool,key=lambda e:abs(e['x']+3.3-x)*3+abs(e['y']-y)*.35)
   n=primary[near['role'],near['measure'],near['onset']]
   if c['text']=='>':
    a=n.find('notations/articulations')
    if a is None:a=E.SubElement(notation(n),'articulations')
    if a.find('accent') is None:E.SubElement(a,'accent')
   elif n.find('notations/fermata') is None:text(notation(n),'fermata','normal',type='upright' if c['text']=='U' else 'inverted')
   artics.append(dict(role=near['role'],bar=near['measure'],onset=near['onset'],symbol=c['text']))
for bar,value in [(1,'Andante Maestoso'),(6,'Grandioso'),(24,'Colossale'),(46,'Con Forza')]:direction(0,bar,0,'words',value)
root.find('part-list/score-part[@id="P4"]/part-name').text='Barítono / Bajo'
# All lines of each word are represented even through changes of system.
for part in root.findall('part'):
 seq=[n for n in part.findall('.//note') if n.find('chord') is None]
 for i,n in enumerate(seq):
  ly=n.find('lyric')
  if ly is None:continue
  rest=[]
  for later in seq[i+1:]:
   if later.find('rest') is not None or later.find('lyric') is not None:break
   rest.append(later)
  if rest:
   E.SubElement(ly,'extend',type='start')
   for j,later in enumerate(rest):E.SubElement(E.SubElement(later,'lyric',number='1'),'extend',type='stop' if j==len(rest)-1 else 'continue')
E.indent(root);E.ElementTree(root).write(OUT/'final.musicxml',encoding='utf-8',xml_declaration=True)
(OUT/'expression-review.json').write_text(json.dumps(dict(expressions=expressions,articulations=artics,curves=curves,connections=connections,unpaired=unpaired),ensure_ascii=False,indent=2),encoding='utf-8')
print('PDF expressions',len(expressions),'accents/fermatas',len(artics),'connections',len(connections),'unpaired',len(unpaired))
print(expressions)
