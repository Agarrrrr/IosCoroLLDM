from pathlib import Path
from copy import deepcopy
from fractions import Fraction as F
import json,collections,sys,xml.etree.ElementTree as E
import build_score as build
from score_model import parse
OUT=Path(__file__).resolve().parent
root=build.root;notes=build.notes;assigned=build.assigned;parts=parse(root)
text=build.text;notation=build.notation
data=json.loads((OUT/'layout.json').read_text(encoding='utf-8'));mapped=json.loads((OUT/'mapped.json').read_text(encoding='utf-8'))['events']
unique=list({(e['page'],round(e['x'],2),round(e['y'],2),e['measure'],e['onset']):e for e in mapped}.values())
curves=[]
for c in data['curves']:
 if len(c['path'])!=2:continue
 start=c['path'][0][1];end=c['path'][1][-1];pi=c['page']
 def cost(e,x,y):return abs(e['x']+2.9-x)*3+abs(e['y']-y)*.55
 pool=[e for e in unique if e['page']==pi];a=min(pool,key=lambda e:cost(e,*start));b=min(pool,key=lambda e:cost(e,*end))
 sa=next(s for s in data['systems'] if s['page']==pi and s['system']==a['system']);sb=next(s for s in data['systems'] if s['page']==pi and s['system']==b['system'])
 if end[0]>sa['bars'][-1]-6:kind='open'
 elif start[0]<min(e['x'] for e in pool if e['system']==b['system'] and e['staff']==b['staff'])+.5:kind='close'
 else:kind='arc'
 curves.append(dict(a=a,b=b,kind=kind,start=start,end=end,page=pi))
opens=[c for c in curves if c['kind']=='open'];closes=[c for c in curves if c['kind']=='close'];pairs=[(c['a'],c['b']) for c in curves if c['kind']=='arc'];unpaired=[]
for c in opens:
 roles={e['role'] for e in mapped if e['page']==c['a']['page'] and abs(e['x']-c['a']['x'])<.2 and abs(e['y']-c['a']['y'])<.2}
 choices=[d for d in closes if d['b']['measure']>c['a']['measure'] and roles & {e['role'] for e in mapped if e['page']==d['b']['page'] and abs(e['x']-d['b']['x'])<.2 and abs(e['y']-d['b']['y'])<.2}]
 if not choices:unpaired.append(c);continue
 d=min(choices,key=lambda d:(d['b']['measure'],abs(d['b']['pitch']-c['a']['pitch'])));closes.remove(d);pairs.append((c['a'],d['b']))
unpaired+=closes
# Parallel soprano/alto arcs share almost the same attachment height in
# these two places; resolve them against the printed heads, not proximity.
for role,a,ao,b,bo in [(0,31,2,32,0),(0,44,2,45,0),(2,10,0,10,1)]:
 ea=next(e for e in mapped if e['role']==role and e['measure']==a and e['onset']==ao)
 eb=next(e for e in mapped if e['role']==role and e['measure']==b and e['onset']==bo)
 pairs.append((ea,eb))
for n in root.findall('.//note'):
 for t in n.findall('tie'):n.remove(t)
 for t in n.findall('notations/tied')+n.findall('notations/slur'):n.find('notations').remove(t)
positions={(r,m['index']+1,float(e['onset'])):i for r,p in enumerate(parts) for i,(m,e) in enumerate((m,e) for m in p for e in m['events'] if e['node'].find('chord') is None)}
connections=[];seen=set();active=collections.defaultdict(dict)
for a,b in sorted(pairs,key=lambda ab:(ab[0]['measure'],ab[0]['onset'],ab[1]['measure'],ab[1]['onset'])):
 if (a['measure'],a['onset'])>=(b['measure'],b['onset']):continue
 aa=[e for e in mapped if e['page']==a['page'] and abs(e['x']-a['x'])<.2 and abs(e['y']-a['y'])<.2]
 bb=[e for e in mapped if e['page']==b['page'] and abs(e['x']-b['x'])<.2 and abs(e['y']-b['y'])<.2]
 for role in {e['role'] for e in aa}&{e['role'] for e in bb}:
  ea=next(e for e in aa if e['role']==role);eb=next(e for e in bb if e['role']==role)
  ka=(role,ea['measure'],ea['onset']);kb=(role,eb['measure'],eb['onset'])
  if (ka,kb) in seen:continue
  seen.add((ka,kb));tie=ea['pitch']==eb['pitch'] and kb not in assigned and positions[kb]==positions[ka]+1
  now=ea['measure']*4+ea['onset'];finish=eb['measure']*4+eb['onset'];active[role]={k:v for k,v in active[role].items() if v>now};num=next(i for i in range(1,17) if i not in active[role])
  if not tie:active[role][num]=finish
  for n,kind in [(notes[ka],'start'),(notes[kb],'stop')]:
   if tie:E.SubElement(n,'tie',type=kind);E.SubElement(notation(n),'tied',type=kind)
   else:E.SubElement(notation(n),'slur',type=kind,number=str(num))
  connections.append(dict(a=ka,b=kb,tie=tie))
(OUT/'phrasing-review.json').write_text(json.dumps(dict(connections=connections,unpaired=unpaired,curves=curves),ensure_ascii=False,indent=2),encoding='utf-8')
print('connections',len(connections),'unpaired',len(unpaired))

def direction(role,bar,onset,tag,value=None,attrs=None,tempo=None):
 m=root.findall('part')[role].findall('measure')[bar-1];d=E.Element('direction',placement='above');dt=E.SubElement(d,'direction-type')
 if value is None:E.SubElement(dt,tag,**(attrs or {}))
 else:text(dt,tag,value,**(attrs or {}))
 if onset:text(d,'offset',int(F(str(onset))*parts[role][bar-1]['div']))
 if tempo is not None:E.SubElement(d,'sound',tempo=str(tempo))
 index=next((i for i,e in enumerate(m) if e.tag=='note'),len(m));m.insert(index,d)
 return dt
def dynamic(role,bar,onset,value):
 d=direction(role,bar,onset,'dynamics');E.SubElement(d.find('dynamics'),value)
dynamic(0,1,0,'mf')
for role in [1,2,3]:dynamic(role,2,0,'p')
for bar,onset,value in [(13,3,'f'),(17,3,'mf'),(20,3,'f'),(27,2,'mf'),(39,3,'f'),(53,3,'ff')]:
 for role in range(4):dynamic(role,bar,onset,value)
dynamic(2,41,2,'mf')
for role in [0,1,3]:dynamic(role,42,2,'mp')
for role in [2,3]:dynamic(role,47,2,'f')
direction(0,1,0,'words','Largo',{'font-style':'italic'})
WEDGES=[(12,2,13,3,'crescendo'),(17,0,17,3,'diminuendo'),(26,3,27,2,'diminuendo'),(38,3,39,3,'crescendo'),(40,3,41,1,'diminuendo'),(52,3,53,3,'crescendo'),(57,0,58,0,'crescendo')]
for a,ao,b,bo,kind in WEDGES:
 for role in range(4):
  direction(role,a,ao,'wedge',attrs={'type':kind,'number':'1','spread':'0' if kind=='crescendo' else '15'})
  direction(role,b,bo,'wedge',attrs={'type':'stop','number':'1','spread':'15' if kind=='crescendo' else '0'})
# The written ritardandi are realized smoothly without adding printed tempos.
for bar,span,target in [(40,4,55),(54,7,50)]:
 for j in range(1,8):
  q=F(span*j,8);b=bar+int(q//4);onset=q%4
  direction(0,b,float(onset),'words','',tempo=65+(target-65)*j/8)
for bar in [56,57]:
 for onset in [0,1,2,3]:direction(0,bar,onset,'words','',tempo=50-1.15*((bar-56)*4+onset))

# Standard four-part choral instruments, preserving sounding pitches.
for role,sp in enumerate(root.findall('part-list/score-part')):
 name=['Soprano','Alto','Tenor','Bajo'][role];sp.find('part-name').text=name
 a=sp.find('part-abbreviation')
 if a is None:a=E.SubElement(sp,'part-abbreviation')
 a.text='SATB'[role]+'.';sp.find('score-instrument/instrument-name').text=name
 sound=sp.find('score-instrument/instrument-sound')
 if sound is not None:sound.text=['voice.soprano','voice.alto','voice.tenor','voice.bass'][role]
 mi=sp.find('midi-instrument');mi.find('midi-program').text='53';mi.find('midi-channel').text=str(role+1)
for c in root.findall('credit')+root.findall('defaults'):root.remove(c)
ident=root.find('identification');text(ident,'creator','David Jared Ramírez',type='composer');text(ident,'creator','Jeffrey Pérez · Comisión de Arreglistas MCEC',type='arranger')
misc=ident.find('miscellaneous')
if misc is None:misc=E.SubElement(ident,'miscellaneous')
text(misc,'miscellaneous-field','PDF oficial del catálogo, cuatro páginas. Tres estrofas y coro desarrollados; MIDI usado para identificar y comprobar las voces.',name='source')
FORM=list(range(1,40))+list(range(14,26))+list(range(40,54))+list(range(14,26))+list(range(54,59))
assert len(FORM)==82
for role,part in enumerate(root.findall('part')):
 original=part.findall('measure')
 for m in original:part.remove(m)
 for i,source in enumerate(FORM,1):
  m=deepcopy(original[source-1]);m.attrib={k:v for k,v in m.attrib.items() if k not in ['width','number']};m.set('number',str(i))
  if source==1:m.set('implicit','yes')
  for pr in m.findall('print'):m.remove(pr)
  for bl in m.findall('barline'):
   for el in bl.findall('repeat')+bl.findall('ending'):bl.remove(el)
   for el in bl.findall('bar-style'):
    if i!=len(FORM):bl.remove(el)
   if not len(bl):m.remove(bl)
  for n in m.findall('note'):
   n.attrib={}
   for s in n.findall('stem'):n.remove(s)
  part.append(m)
 # Join syllabic fragments across the actual performed order, not the jumps.
 prev=None
 for ly in part.findall('.//lyric'):
  if ly.find('text') is None:continue
  state=ly.find('syllabic')
  if prev in ['begin','middle'] and state.text in ['single','begin']:state.text='end' if state.text=='single' else 'middle'
  prev=state.text
 # Proper melismas stop before rests or the next printed syllable.
 seq=[n for n in part.findall('.//note') if n.find('chord') is None]
 for i,n in enumerate(seq):
  ly=n.find('lyric')
  if ly is None:continue
  later_notes=[]
  for later in seq[i+1:]:
   if later.find('rest') is not None or later.find('lyric') is not None:break
   later_notes.append(later)
  if later_notes:
   E.SubElement(ly,'extend',type='start')
   for j,later in enumerate(later_notes):E.SubElement(E.SubElement(later,'lyric',number='1'),'extend',type='stop' if j==len(later_notes)-1 else 'continue')
E.indent(root);E.ElementTree(root).write(OUT/'final.musicxml',encoding='utf-8',xml_declaration=True)
(OUT/'form.json').write_text(json.dumps(FORM),encoding='utf-8')
print('bars',len(FORM),'notes',len(root.findall('.//pitch')),'lyrics',len(root.findall('.//lyric/text')))
