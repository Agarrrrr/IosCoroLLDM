from pathlib import Path
from copy import deepcopy
from fractions import Fraction as F
import sys,json,xml.etree.ElementTree as E,collections,pdfplumber
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
OUT=Path(__file__).resolve().parent
root=E.parse(OUT/'corrected.musicxml').getroot()
# Three unison bars were lost from alto during the old voice separation.
for bar in [56,57,58]:
 target=root.findall('part')[1].findall('measure')[bar-1]
 for n in target.findall('note'):target.remove(n)
 for n in root.findall('part')[0].findall('measure')[bar-1].findall('note'):target.append(deepcopy(n))
# The common ce-de-rá requires the three syllabic attacks on the sustained
# F in the lower voices before their anticipatory ja-más answer. The pitch
# and total duration remain the printed F; only vocal articulation divides it.
for role in [2,3]:
 for bar in [26,74]:
  m=root.findall('part')[role].findall('measure')[bar-1];ns=m.findall('note');first=ns[0];second=ns[1]
  extra=deepcopy(first);first.find('duration').text='2';first.find('type').text='quarter'
  extra.find('duration').text='1';extra.find('type').text='eighth'
  for n in [first,extra,second]:
   for el in n.findall('dot')+n.findall('tie'):n.remove(el)
   for el in n.findall('notations/tied'):n.find('notations').remove(el)
  m.insert(list(m).index(first)+1,extra)
parts=parse(root)
notes={}
for role,part in enumerate(root.findall('part')):
 for mi,m in enumerate(part.findall('measure'),1):
  for ei,(node,e) in enumerate(zip(m.findall('note'),parts[role][mi-1]['events'])):notes[role,mi,float(e['onset'])]=node

def text(p,k,v,**attrs):e=E.SubElement(p,k,attrs);e.text=str(v);return e
def notation(n):
 e=n.find('notations')
 return e if e is not None else E.SubElement(n,'notations')
# Pitch changes under a drawn arc are legato, never a tie between unlike notes.
for role in range(4):
 seq=[e for m in parts[role] for e in m['events']]
 for i,e in enumerate(seq[:-1]):
  later=seq[i+1]
  if e['node'].find('tie[@type="start"]') is not None and later['node'].find('tie[@type="stop"]') is not None and e['pitch']!=later['pitch']:
   for ev,kind in [(e,'start'),(later,'stop')]:
    n=notes[role,ev['measure']+1,float(ev['onset'])]
    for t in n.findall(f'tie[@type="{kind}"]'):n.remove(t)
    for t in n.findall(f'notations/tied[@type="{kind}"]'):n.find('notations').remove(t)
    E.SubElement(notation(n),'slur',type=kind,number='1')
parts=parse(root)

def atoms(s):
 result=[]
 for word in s.split():
  chunks=word.split('-')
  for i,ch in enumerate(chunks):
   if not ch:continue
   result.append(dict(text=ch.replace('_','‿'),syllabic='single' if len(chunks)==1 else 'begin' if i==0 else 'end' if i==len(chunks)-1 else 'middle'))
 return result

assigned={}
def put(role,first,last,phrase,omit=(),only=None):
 omit=set(omit)
 row=[(m['index']+1,e) for m in parts[role][first-1:last] for e in m['events'] if e['pitch'] is not None and e['node'].find('tie[@type="stop"]') is None and (m['index']+1,float(e['onset'])) not in omit]
 if only is not None:row=[(b,e) for b,e in row if (b,float(e['onset'])) in set(only)]
 aa=atoms(phrase)
 assert len(row)==len(aa),(role,first,last,len(row),len(aa),phrase,[(b,float(e['onset'])) for b,e in row])
 for (b,e),a in zip(row,aa):
  key=role,b,float(e['onset']);assert key not in assigned,key
  assigned[key]=a

for role in [0,1]:
 put(role,2,6,'La vi-da se va co-mo_el vien-to;',omit=[(5,1)])
 put(role,10,18,'Fu-gaz es cual flor de la hier-ba que_en la ma-ña-na es y_en la tar-de ha muer-to.',omit=[(17,1)])
 put(role,19,22,'Ja-más pue-de_el hom-bre sa-ber',omit=[(22,1),(22,1.5)])
 put(role,23,27,'los dí-as que Dios le con-ce-de-rá',omit=[(25,0)])
 put(role,28,34,'nun-ca ja-más pue-de_el hom-bre sa-ber en cuál a-ma-ne-cer ya sus o-jos no se_a-bri-rán.',omit=[])
 put(role,35,43,'Es por e-so que_el hom-bre ha de bus-car. El sen-de-ro que_a Dios le ha de lle-var. A Je-',omit=[],only=None)

# Continuation and response phrases are placed separately for the independent voices.
for role in [0,1]:
 put(role,44,50,'sús (Je-sús) quien es el ca-mi-no; Quien es el ca-mi-no, ver-dad y la vi-da, la vi-da e-ter-na.',omit=[(44,1.5),(46,1),(50,1)])
 put(role,52,58,'La vi-da se va co-mo_el vien-to, el sen-de-ro que_a Dios le ha de lle-var.',omit=[(54,2.5)],only=None)
 # Alto enters A Jesús a bar before soprano's high response.
 if role==1:
  put(role,59,62,'A Je-sús quien es el ca-mi-no,',omit=[(59,0),(62,1)])
 else:
  put(role,60,62,'A Je-sús quien es el ca-mi-no,',omit=[(62,1)])
 put(role,63,66,'Quien es el ca-mi-no, ver-dad y la vi-da, la vi-da e-ter-na.',omit=[(66,1)])

for role in [2,3]:
 put(role,6,9,'Se va co-mo se va la nie-bla;',omit=[(9,1)])
 put(role,10,18,'Fu-gaz es cual flor de la hier-ba que_en la ma-ña-na es y_en la tar-de ha muer-to.',omit=[(17,1)])
 put(role,20,23,'nun-ca ja-más pue-de_el hom-bre sa-ber ja-más',omit=[(22,1),(22,1.5),(23,1.5)])
 put(role,23,26,'los dí-as que Dios le con-ce-de-rá',omit=[(25,0)],only=[(23,1.5),(24,0),(25,.5),(25,1),(25,1.5),(25,2),(25,2.5),(26,0),(26,1),(26,1.5)])
 # Bass/tenor repeat ja-más while upper voices sustain their own phrase.
 put(role,26,30,'ja-más, Ja-más pue-de_el hom-bre sa-ber',only=[(26,2.5),(27,0),(27,1.5),(28,0),(29,.5),(29,1),(29,1.5),(29,2),(29,2.5),(30,0)])
 put(role,31,34,'en cuál a-ma-ne-cer ya sus o-jos no se_a-bri-rán.',omit=[])
 put(role,35,43,'Es por e-so que_el hom-bre ha de bus-car. El sen-de-ro que_a Dios le ha de lle-var. A Je-',omit=[(39,0),(43,0)])
 put(role,44,50,'sús (Je-sús) ca-mi-no; Quien es el ca-mi-no, ver-dad y la vi-da, la vi-da e-ter-na.',omit=[(44,1.5),(50,1)])
 put(role,51,54,'Es por e-so que_el hom-bre ha de bus-car.')
 put(role,56,58,'él de-be bus-car que_a Dios le ha de lle-var.',omit=[])
 put(role,60,62,'A Je-sús, Je-sús quien es el ca-mi-no,',omit=[(62,1)])
 put(role,63,66,'Quien es el ca-mi-no, ver-dad y la vi-da, la vi-da e-ter-na.',omit=[(66,1)])

# The second full section repeats the written music, including the responses.
for (role,b,onset),a in list(assigned.items()):
 if 19<=b<=50:
  dest=b+48
  dest_onset=1.5 if b==19 and role in [0,1] else onset
  if dest<=98:
   n=notes.get((role,dest,dest_onset))
   if n is not None and n.find('pitch') is not None:assigned[role,dest,dest_onset]=deepcopy(a)
for role in range(4):
 put(role,99,103,'Quien es el ca-mi-no, ver-dad y la vi-da, la vi-da e-ter-na.',omit=[(102,1)])

for role in range(4):
 previous=None
 for key in sorted(k for k in assigned if k[0]==role):
  a=assigned[key]
  if previous is not None and previous['syllabic'] in ['begin','middle'] and a['syllabic']=='single':a['syllabic']='end'
  previous=a
for (role,b,onset),a in assigned.items():
 n=notes[role,b,onset];ly=E.SubElement(n,'lyric',number='1',placement='below');text(ly,'syllabic',a['syllabic']);text(ly,'text',a['text'])

# Recover phrase curves from the PDF, including connections across systems.
layout=json.loads((OUT/'layout.json').read_text(encoding='utf-8'))
mapped=json.loads((OUT/'mapped.json').read_text(encoding='utf-8'))['events']
mapped += [dict(e,role=1) for e in mapped if e['role']==0 and e['measure'] in [56,57,58]]
unique=list({(e['page'],round(e['x'],2),round(e['y'],2),e['measure'],e['onset']):e for e in mapped}.values())
curves=[]
with pdfplumber.open(OUT/'eaeafa56-1d25-4517-b13f-1b3f7f6beced.pdf') as pdf:
 for pi,page in enumerate(pdf.pages,1):
  for c in page.curves:
   if len(c['path'])!=2 or c['path'][1][0]!='c':continue
   start=c['path'][0][1];end=c['path'][1][-1]
   if end[0]-start[0]<3:continue
   def cost(e,x,y):return abs(e['x']+2.8-x)*3+abs(e['y']-y)*.45
   pool=[e for e in unique if e['page']==pi]
   a=min(pool,key=lambda e:cost(e,*start));b=min(pool,key=lambda e:cost(e,*end))
   sa=next(s for s in layout['systems'] if s['page']==pi and s['system']==a['system'])
   sb=next(s for s in layout['systems'] if s['page']==pi and s['system']==b['system'])
   if end[0]>sa['bars'][-1]-6:kind='open'
   elif start[0]<min(e['x'] for e in pool if e['system']==b['system'] and e['role']//2==b['role']//2)-4:kind='close'
   else:kind='arc'
   curves.append(dict(a=a,b=b,kind=kind,start=start,end=end,page=pi))
opens=[c for c in curves if c['kind']=='open'];closes=[c for c in curves if c['kind']=='close'];pairs=[(c['a'],c['b']) for c in curves if c['kind']=='arc']
unpaired=[]
for c in opens:
 choices=[d for d in closes if d['b']['role']//2==c['a']['role']//2 and d['b']['measure']>c['a']['measure']]
 if not choices:unpaired.append(c);continue
 d=min(choices,key=lambda d:(d['b']['measure'],d['b']['onset']));closes.remove(d);pairs.append((c['a'],d['b']))
unpaired+=closes
# The two crossing system continuations at the upper stave before original
# printed bar 72 are disambiguated by the actual soprano/alto heads.
for role in [0,1]:
 a=next(e for e in mapped if e['role']==role and e['measure']==72 and e['onset']==0)
 b=next(e for e in mapped if e['role']==role and e['measure']==73 and e['onset']==0)
 pairs.append((a,b))
for n in root.findall('.//note'):
 for t in n.findall('tie'):n.remove(t)
 for t in n.findall('notations/tied')+n.findall('notations/slur'):n.find('notations').remove(t)
connections=[];seen=set();active=collections.defaultdict(dict)
positions={(role,m['index']+1,float(e['onset'])):i for role,part in enumerate(parts) for i,(m,e) in enumerate((m,e) for m in part for e in m['events'])}
for a,b in sorted(pairs,key=lambda ab:(ab[0]['measure'],ab[0]['onset'],ab[1]['measure'],ab[1]['onset'])):
 if (a['measure'],a['onset'])>=(b['measure'],b['onset']):continue
 aa=[e for e in mapped if e['page']==a['page'] and abs(e['x']-a['x'])<.2 and abs(e['y']-a['y'])<.2]
 bb=[e for e in mapped if e['page']==b['page'] and abs(e['x']-b['x'])<.2 and abs(e['y']-b['y'])<.2]
 for role in {e['role'] for e in aa}&{e['role'] for e in bb}:
  ea=next(e for e in aa if e['role']==role);eb=next(e for e in bb if e['role']==role)
  ka=(role,ea['measure'],ea['onset']);kb=(role,eb['measure'],eb['onset'])
  if (ka,kb) in seen:continue
  seen.add((ka,kb))
  if role in [2,3] and ea['measure'] in [26,74] and eb['measure']==ea['measure']:continue
  na=notes[ka];nb=notes[kb]
  tie=ea['pitch']==eb['pitch'] and kb not in assigned and positions[kb]==positions[ka]+1
  start=ea['measure']*3+ea['onset'];end=eb['measure']*3+eb['onset']
  active[role]={k:v for k,v in active[role].items() if v>start}
  num=next(i for i in range(1,17) if i not in active[role])
  if not tie:active[role][num]=end
  for n,kind in [(na,'start'),(nb,'stop')]:
   if tie:E.SubElement(n,'tie',type=kind);E.SubElement(notation(n),'tied',type=kind)
   else:E.SubElement(notation(n),'slur',type=kind,number=str(num))
  connections.append(dict(a=ka,b=kb,tie=tie))
(OUT/'phrasing-review.json').write_text(json.dumps(dict(connections=connections,unpaired=unpaired),ensure_ascii=False,indent=2),encoding='utf-8')
print('PDF curves',len(curves),'connections',len(connections),'unpaired',len(unpaired))

# Standard SATB labels and sounding tenor in octave treble clef.
for role,sp in enumerate(root.findall('part-list/score-part')):
 name=['Soprano','Alto','Tenor','Bajo'][role];sp.find('part-name').text=name
 a=sp.find('part-abbreviation')
 if a is None:a=E.SubElement(sp,'part-abbreviation')
 a.text='SATB'[role]+'.'
 sp.find('score-instrument/instrument-name').text=name
 mi=sp.find('midi-instrument');mi.find('midi-program').text='53';mi.find('midi-channel').text=str(role+1)
for part in root.findall('part'):
 for m in part.findall('measure'):
  m.attrib={k:v for k,v in m.attrib.items() if k!='width'}
  for pr in m.findall('print'):m.remove(pr)
  for n in m.findall('note'):
   n.attrib={}
   for tag in ['stem']:
    for el in n.findall(tag):n.remove(el)
   for p in n.findall('pitch'):
    children=list(p);p[:]=sorted(children,key=lambda e:['step','alter','octave'].index(e.tag))
 cl=part.find('measure/attributes/clef')
 if part is root.findall('part')[2]:
  cl.find('sign').text='G';cl.find('line').text='2';text(cl,'clef-octave-change',-1)
for el in root.findall('credit'):root.remove(el)
for el in root.findall('defaults'):root.remove(el)
ident=root.find('identification');text(ident,'creator','Jorge Díaz Mora',type='composer');text(ident,'creator','Israel Gómez Morales',type='arranger')
# Restore the complete 6/8 bar split at the change of key in the old export.
# Expand the four introductory rest bars explicitly indicated in the PDF.
for role,part in enumerate(root.findall('part')):
 ms=part.findall('measure');a,b=ms[17:19]
 for el in list(b):a.append(deepcopy(el))
 part.remove(b);a.attrib.pop('implicit',None)
 first=part.find('measure')
 for j in range(3):
  extra=E.Element('measure')
  for n in first.findall('note'):extra.append(deepcopy(n))
  part.insert(list(part).index(first)+1+j,extra)
 if role==0:
  d=E.Element('direction',placement='above');text(E.SubElement(d,'direction-type'),'words','Introducción: 4 compases');first.insert(len(first.findall('attributes')),d)
 for i,m in enumerate(part.findall('measure'),1):m.set('number',str(i))
for part in root.findall('part'):
 seq=part.findall('.//note')
 for i,n in enumerate(seq):
  ly=n.find('lyric')
  if ly is None:continue
  following=[]
  for later in seq[i+1:]:
   if later.find('rest') is not None or later.find('lyric') is not None:break
   following.append(later)
  if following:
   E.SubElement(ly,'extend',type='start')
   for j,later in enumerate(following):E.SubElement(E.SubElement(later,'lyric',number='1'),'extend',type='stop' if j==len(following)-1 else 'continue')
E.indent(root);E.ElementTree(root).write(OUT/'final.musicxml',encoding='utf-8',xml_declaration=True)
print('lyrics',len(assigned))




