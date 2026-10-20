from pathlib import Path
from copy import deepcopy
from fractions import Fraction as F
import json,collections,xml.etree.ElementTree as E
OUT=Path('output/amado_salvador')
raw=json.loads((OUT/'raw-reading.json').read_text(encoding='utf-8'))
model={}
for bar in range(1,31):
 for staff in range(2):
  row=[e for e in raw['events'] if e['measure']==bar and e['staff']==staff]
  whole=sorted([e for e in row if e['direction']=='whole'],key=lambda e:e['diatonic'],reverse=True)
  for e in whole:
   if len(whole)==2:e['direction']='up' if e is whole[0] else 'down'
   else:
    occupied={n['direction'] for n in row if n not in whole}
    # A single open head coexists with the other independent stemmed voice.
    assert len(occupied)==1,(bar,staff,occupied)
    e['direction']='down' if 'up' in occupied else 'up'
  for sub,direction in enumerate(['up','down']):
   role=2*staff+sub
   seq=sorted([deepcopy(e) for e in row if e['direction'] in [direction,'both']],key=lambda e:e['x'])
   q=F(0)
   for i,e in enumerate(seq):
    e.update(role=role,index=i,onset=float(q),duration=float(e['duration']))
    if not e['rest']:e['pitch']=(e['diatonic']//7+1)*12+[0,2,4,5,7,9,11][e['diatonic']%7]+e['alter']
    q+=F(str(e['duration']))
   assert q==4,(bar,role,q)
   model[role,bar]=seq

# Lyrics explicitly follow each printed note, including contracted syllables.
# Hyphens mark syllables within a word; spaces separate complete words.
def atoms(s):
 result=[]
 for word in s.split():
  chunks=word.split('-')
  for i,ch in enumerate(chunks):
   result.append(dict(text=ch.replace('_','‿'),syllabic='single' if len(chunks)==1 else 'begin' if i==0 else 'end' if i==len(chunks)-1 else 'middle'))
 return result

VERSE_BASS=[
 {1:'Por to-do lo que Tú me',2:'das,',3:'por e-se_in-men-so_a-mor por',4:'mí,',5:'te ven-go_a_a-gra-de-cer,',6:'A-ma-do Sal-va-',7:'dor, que te_a-cuer-des de',8:'mí.',9:'Por es-ta san-ta co-mu-',10:'nión,',11:'que sien-to den-tro de mi',12:'ser,',13:'mi al-ma hoy te can-',14:'ta:'},
 {1:'Se sien-te li-bre_el co-ra-',2:'zón,',3:'ins-tan-tes de tran-qui-li-',4:'dad,',5:'es u-na dul-ce paz,',6:'ca-lor es-pi-ri-',7:'tual di-fí-cil de_ex-pli-',8:'car.',9:'So-laz que_in-va-de mi_in-te-',10:'rior,',11:'que no se_a-ca-be quie-ro',12:'yo,',13:'¡oh di-cha_in-des-crip-ti-',14:'ble'},
 {1:'Ins-tan-tes tan her-mo-sos',2:'son',3:'cuan-do a Ti mi al-ma',4:'va,',5:'y pue-do pla-ti-car',6:'con to-da li-ber-',7:'tad mi_hu-mil-de co-ra-',8:'zón.',9:'Pue-do sen-tir que_al cie-lo',10:'voy,',11:'y tan fe-liz con-ti-go_es-',12:'toy,',13:'¡qui-sie-ra pro-lon-gar-',14:'lo'}
]
# A trailing/leading hyphen can cross a bar. Keep complete syllabic chains.
def assign_span(role,bars,string,skip=None):
 notes=[e for b in bars for e in model[role,b] if not e['rest']]
 if skip is not None:notes=[notes[i] for i in skip]
 aa=atoms(string);assert len(notes)==len(aa),(role,bars,len(notes),len(aa),string)
 for e,a in zip(notes,aa):e['lyric']=a

def assign_indices(role,bar,indices,string):assign_span(role,[bar],string,indices)

# Complete phrases avoid losing hyphen state where a word crosses a barline.
BASS_PHRASES=[
 [(1,2,'Por to-do lo que Tú me das,'),(3,4,'por e-se_in-men-so_a-mor por mí,'),(5,8,'te ven-go_a_a-gra-de-cer, A-ma-do Sal-va-dor, que te_a-cuer-des de mí.'),(9,10,'Por es-ta san-ta co-mu-nión,'),(11,12,'que sien-to den-tro de mi ser,'),(13,14,'mi al-ma hoy te can-ta:')],
 [(1,2,'Se sien-te li-bre_el co-ra-zón,'),(3,4,'ins-tan-tes de tran-qui-li-dad,'),(5,8,'es u-na dul-ce paz, ca-lor es-pi-ri-tual di-fí-cil de_ex-pli-car.'),(9,10,'So-laz que_in-va-de mi_in-te-rior,'),(11,12,'que no se_a-ca-be quie-ro yo,'),(13,14,'¡oh di-cha_in-des-crip-ti-ble')],
 [(1,2,'Ins-tan-tes tan her-mo-sos son'),(3,4,'cuan-do a Ti mi al-ma va,'),(5,8,'y pue-do pla-ti-car con to-da li-ber-tad mi_hu-mil-de co-ra-zón.'),(9,10,'Pue-do sen-tir que_al cie-lo voy,'),(11,12,'y tan fe-liz con-ti-go_es-toy,'),(13,14,'¡qui-sie-ra pro-lon-gar-lo')]
]
def set_verse(verse):
 for row in model.values():
  for e in row:e.pop('lyric',None)
 for a,b,s in BASS_PHRASES[verse-1]:assign_span(3,range(a,b+1),s)
 for role in [0,1]:
  for bar in [2,3,4,5,6,7,10,11,12,13,14]:assign_indices(role,bar,[0],'Ah')
  s=['que te_a-cuer-des de mí.','di-fí-cil de_ex-pli-car.','mi_hu-mil-de co-ra-zón.'][verse-1]
  notes=[*model[role,8][1:],model[role,9][0]]
  aa=atoms(s);assert len(notes)==len(aa)
  for e,a in zip(notes,aa):e['lyric']=a
 for bar in [2,3,4,5,6,7,9,10,11,12,13,14]:assign_indices(2,bar,[0],'Ah')
 # The bass holds its final word across bar 14–15; tenor/soprano/alto
 # finish the printed Ah on the initial dotted quarter in bar 15.
 phrase=['¡ben-di-to seas, oh Rey!','ha-blar con mi Se-ñor!','por la e-ter-ni-dad!'][verse-1]
 aa=atoms(phrase);assert len(aa)==6
 for role in range(4):
  notes=[e for e in model[role,15] if not e['rest']][1:]+[model[role,16][0]]
  assert len(notes)==6
  for e,a in zip(notes,aa):e['lyric']=a
 response=['(Ben-di-to seas)','(Con mi Se-ñor,)','(E-ter-ni-dad,)'][verse-1]
 for role in [1,2,3]:
  notes=model[role,16][1:]+[model[role,17][0]];aa=atoms(response);assert len(notes)==len(aa)==4
  for e,a in zip(notes,aa):e['lyric']=a

def chorus(passno):
 # Every voice starts with the common text before alto/tenor answer.
 for role in range(4):
  for b in range(18,31):
   for e in model[role,b]:e.pop('lyric',None)
  notes=[e for e in model[role,17] if not e['rest']][-5:]+[model[role,18][0]]
  for e,a in zip(notes,atoms('A-ma-do Sal-va-dor,')):e['lyric']=a
 for role in [1,2]:
  notes=model[role,18][1:]+[model[role,19][0]]
  for e,a in zip(notes,atoms('(A-ma-do Sal-va-dor)')):e['lyric']=a
 common=['¿por qué no vuel-ves ya por mí?','mi sue-ño es con-ti-go_es-tar.'][passno-1]
 aa=atoms(common);assert len(aa)==8
 for role in range(4):
  notes=model[role,19][1:]+[model[role,20][0]]
  for e,a in zip(notes,aa):e['lyric']=a
 response=['(no vuel-ves ya por mí)','(mi sue-ño es por Ti)'][passno-1]
 for role in [1,2]:
  notes=model[role,20][1:]+[model[role,21][0]];aa=atoms(response);assert len(notes)==len(aa)==6
  for e,a in zip(notes,aa):e['lyric']=a
 common=['Mi al-ma tie-ne sed de Ti,','Ins-tan-tes tan her-mo-sos yo'][passno-1]
 for role in range(4):
  notes=model[role,21][1:]+[model[role,22][0]];aa=atoms(common);assert len(notes)==len(aa)==8
  for e,a in zip(notes,aa):e['lyric']=a
 if passno==1:
  for role in [1,2]:
   notes=model[role,22][1:]+[model[role,23][0]];aa=atoms('(mi al-ma tie-ne sed)');assert len(notes)==len(aa)==6
   for e,a in zip(notes,aa):e['lyric']=a
  for role in range(4):
   notes=model[role,23][1:]+[model[role,24][0]];aa=atoms('con-ti-go quie-ro_es-tar,');assert len(notes)==len(aa)==6
   for e,a in zip(notes,aa):e['lyric']=a
  for role in [2,3]:
   notes=model[role,24][1:]+[model[role,25][0]];aa=atoms('y vi-vir siem-pre fe-liz.');assert len(notes)==len(aa)==7
   for e,a in zip(notes,aa):e['lyric']=a
  # The first ending returns to chorus bar 18 with a new pickup.
  for role in range(4):
   notes=[e for e in model[role,25] if not e['rest']][-5:]
   for e,a in zip(notes,atoms('A-ma-do Sal-va-dor')[:5]):e['lyric']=a
 else:
  for role in [1,2]:
   notes=model[role,22][1:]+[model[role,26][0]];aa=atoms('(ins-tan-tes de pla-cer)');assert len(notes)==len(aa)==6
   for e,a in zip(notes,aa):e['lyric']=a
   model[role,28][0]['lyric']=deepcopy(model[role,26][0]['lyric'])
  for role in range(4):
   for b,nextbar in [(26,27),(28,29)]:
    notes=model[role,b][1:]+[model[role,nextbar][0]];aa=atoms('qui-sie-ra_e-ter-ni-zar.');assert len(notes)==len(aa)==6
    for e,a in zip(notes,aa):e['lyric']=a
  for role in [1,3]:
   notes=model[role,29][1:]+[model[role,30][0]];aa=atoms('(qui-sie-ra_e-ter-ni-zar).');assert len(notes)==len(aa)==6
   for e,a in zip(notes,aa):e['lyric']=a

# Source arcs are traced against the PDF; same-pitch connections below
# are ties only when the second head carries no new sung syllable.
ARCS=[]
def arc(role,a,ai,b,bi,tie=False):ARCS.append((role,a,ai,b,bi,tie))
for role in [0,1]:
 for bar in [5,6,9,10,13]:arc(role,bar,0,bar,len(model[role,bar])-1)
 arc(role,7,0,8,0);arc(role,14,0,15,0)
for bar in [2,4,12]:arc(0,bar,0,bar,3)
arc(2,2,0,3,0)
for bar in [5,6]:arc(2,bar,0,bar,2)
arc(2,7,0,8,0);arc(2,9,0,9,1);arc(2,14,0,15,0)
arc(3,14,1,15,0,True)
for role in [2,3]:arc(role,25,0,25,1)
for role in [0,2]:arc(role,29,0,30,0,True)

expanded=[]
for verse in range(1,4):
 set_verse(verse);chorus(1)
 for bar in range(1,26):expanded.append(dict(source=bar,verse=verse,passno=1,rows=[deepcopy(model[r,bar]) for r in range(4)]))
 chorus(2)
 for bar in [18,19,20,21,22]+([26,27] if verse<3 else [28,29,30]):expanded.append(dict(source=bar,verse=verse,passno=2,rows=[deepcopy(model[r,bar]) for r in range(4)]))
assert len(expanded)==97

def text(p,k,v,**attrs):e=E.SubElement(p,k,attrs);e.text=str(v);return e
def notation(n):
 e=n.find('notations')
 return e if e is not None else E.SubElement(n,'notations')
root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Amado Salvador');ident=E.SubElement(root,'identification');text(ident,'creator','Miguel Ángel Huerta',type='composer');text(ident,'creator','Coreb Efraín López',type='arranger')
misc=E.SubElement(ident,'miscellaneous');text(misc,'miscellaneous-field','Fuente: PDF del catálogo; transcripción original de Héctor Vejar. Tres estrofas, coro de dos pasadas y coda desarrollados. Sin MIDI de referencia.',name='source')
defaults=E.SubElement(root,'defaults');sc=E.SubElement(defaults,'scaling');text(sc,'millimeters',7);text(sc,'tenths',40)
E.SubElement(defaults,'lyric-font',**{'font-family':'Times New Roman','font-size':'11'})
pl=E.SubElement(root,'part-list');g=E.SubElement(pl,'part-group',number='1',type='start');text(g,'group-symbol','bracket');text(g,'group-barline','no')
for role,name in enumerate(['Soprano','Alto','Tenor','Bajo']):
 sp=E.SubElement(pl,'score-part',id=f'P{role+1}');text(sp,'part-name',name);text(sp,'part-abbreviation','SATB'[role]+'.');inst=E.SubElement(sp,'score-instrument',id=f'I{role+1}');text(inst,'instrument-name',name);mi=E.SubElement(sp,'midi-instrument',id=f'I{role+1}');text(mi,'midi-channel',role+1);text(mi,'midi-program',53)
E.SubElement(pl,'part-group',number='1',type='stop')
nodes={}
for role in range(4):
 part=E.SubElement(root,'part',id=f'P{role+1}')
 for bi,bar in enumerate(expanded,1):
  m=E.SubElement(part,'measure',number=str(bi));source=bar['source']
  if bi==1:
   a=E.SubElement(m,'attributes');text(a,'divisions',960);text(E.SubElement(a,'key'),'fifths',-1);t=E.SubElement(a,'time');text(t,'beats',4);text(t,'beat-type',4);cl=E.SubElement(a,'clef');text(cl,'sign','F' if role==3 else 'G');text(cl,'line',4 if role==3 else 2)
   if role==2:text(cl,'clef-octave-change',-1)
   d=E.SubElement(m,'direction',placement='above');text(E.SubElement(d,'direction-type'),'words','dolce',**{'font-style':'italic'})
   if role==0:
    d=E.SubElement(m,'direction',placement='above');mt=E.SubElement(E.SubElement(d,'direction-type'),'metronome');text(mt,'beat-unit','quarter');text(mt,'per-minute',72);E.SubElement(d,'sound',tempo='72')
  if role==0 and (source==1 or source==17 or (source==18 and bar['passno']==2) or source==28):
   d=E.SubElement(m,'direction',placement='above');text(E.SubElement(d,'direction-type'),'rehearsal',f"Estrofa {bar['verse']}" if source==1 else 'Coro 2' if source==18 else 'Coda' if source==28 else 'Coro')
   if source==1 and bi!=1:E.SubElement(d,'sound',tempo='72')
  if source==28:
   d=E.SubElement(m,'direction',placement='above');text(E.SubElement(d,'direction-type'),'words','rit.',**{'font-style':'italic'})
   if role==0:E.SubElement(d,'sound',tempo='66')
  if role==0 and source in [29,30]:
   d=E.SubElement(m,'direction');E.SubElement(E.SubElement(d,'direction-type'),'words');E.SubElement(d,'sound',tempo='60' if source==29 else '54')
  for ei,e in enumerate(bar['rows'][role]):
   n=E.SubElement(m,'note');nodes[role,bi,ei]=n
   if e['rest']:E.SubElement(n,'rest',**({'measure':'yes'} if e['duration']==4 else {}))
   else:
    p=E.SubElement(n,'pitch');text(p,'step','CDEFGAB'[e['diatonic']%7]);text(p,'alter',e['alter']);text(p,'octave',e['diatonic']//7)
   text(n,'duration',int(e['duration']*960));text(n,'voice',1)
   base=F(str(e['duration']))/(F(3,2) if e.get('dot') else 1);text(n,'type',{F(4):'whole',F(2):'half',F(1):'quarter',F(1,2):'eighth'}[base])
   if e.get('dot'):E.SubElement(n,'dot')
   if e.get('lyric'):
    ly=E.SubElement(n,'lyric',number='1',placement='below');text(ly,'syllabic',e['lyric']['syllabic']);text(ly,'text',e['lyric']['text'])
  if bi==len(expanded):text(E.SubElement(m,'barline',location='right'),'bar-style','light-heavy')
# Map every printed connection into each expanded occurrence.
for role,a,ai,b,bi,tie in ARCS:
 for idx,bar in enumerate(expanded):
  if bar['source']!=a:continue
  targets=[j for j in range(idx,min(idx+3,len(expanded))) if expanded[j]['source']==b and expanded[j]['verse']==bar['verse'] and expanded[j]['passno']==bar['passno']]
  if not targets:continue
  target=targets[0]
  for j,i,kind in [(idx,ai,'start'),(target,bi,'stop')]:
   n=nodes[role,j+1,i]
   if tie:E.SubElement(n,'tie',type=kind);E.SubElement(notation(n),'tied',type=kind)
   else:E.SubElement(notation(n),'slur',type=kind,number='1')
# Melisma extenders stop at a rest or the next printed syllable.
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
E.indent(root);E.ElementTree(root).write(OUT/'Amado Salvador.musicxml',encoding='utf-8',xml_declaration=True)
(OUT/'expanded-reading.json').write_text(json.dumps(expanded,ensure_ascii=False,indent=2),encoding='utf-8')
print('Expanded bars',len(expanded),'notes',sum(not e['rest'] for b in expanded for row in b['rows'] for e in row),'lyrics',len(root.findall('.//lyric/text')))



