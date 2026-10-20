from pathlib import Path
from fractions import Fraction as F
import sys,json,collections,xml.etree.ElementTree as E
sys.path.insert(0,'output/cantico_144_mil')
from midi_reader import read
OUT=Path(__file__).resolve().parent
def text(p,k,v,**attrs):e=E.SubElement(p,k,attrs);e.text=str(v);return e
def split_duration(start,duration):
 q=start;end=start+duration
 while q<end:
  remaining=min(end-q,4-q%4)
  d=next(d for d in map(F,['4','3','2','1.5','1','.75','.5','.25']) if d<=remaining)
  yield q,d;q+=d
root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Imperio y Dominio');ident=E.SubElement(root,'identification');text(ident,'creator','Benjamín Rangel Valerio',type='composer')
pl=E.SubElement(root,'part-list');g=E.SubElement(pl,'part-group',number='1',type='start');text(g,'group-symbol','bracket');text(g,'group-barline','no')
midi=read(OUT/'reference.mid');events=[]
for role,name in enumerate(['Soprano','Alto','Tenor','Bajo']):
 sp=E.SubElement(pl,'score-part',id=f'P{role+1}');text(sp,'part-name',name);text(sp,'part-abbreviation','SATB'[role]+'.');inst=E.SubElement(sp,'score-instrument',id=f'I{role+1}');text(inst,'instrument-name',name);text(inst,'instrument-sound',['voice.soprano','voice.alto','voice.tenor','voice.bass'][role]);mi=E.SubElement(sp,'midi-instrument',id=f'I{role+1}');text(mi,'midi-channel',role+1);text(mi,'midi-program',53)
E.SubElement(pl,'part-group',number='1',type='stop')
SPELL={0:('C',0),1:('C',1),2:('D',0),3:('E',-1),4:('E',0),5:('F',0),6:('F',1),7:('G',0),8:('A',-1),9:('A',0),10:('B',-1),11:('B',0)}
for role,track in enumerate(midi['tracks']):
 part=E.SubElement(root,'part',id=f'P{role+1}');measures=[]
 for bar in range(1,80):
  m=E.SubElement(part,'measure',number=str(bar));measures.append(m)
  if bar==1:
   a=E.SubElement(m,'attributes');text(a,'divisions',960);text(E.SubElement(a,'key'),'fifths',-2);t=E.SubElement(a,'time');text(t,'beats',4);text(t,'beat-type',4);c=E.SubElement(a,'clef');text(c,'sign','F' if role==3 else 'G');text(c,'line',4 if role==3 else 2)
   if role==2:text(c,'clef-octave-change',-1)
   if role==0:
    d=E.SubElement(m,'direction',placement='above');mt=E.SubElement(E.SubElement(d,'direction-type'),'metronome');text(mt,'beat-unit','quarter');text(mt,'per-minute',94);E.SubElement(d,'sound',tempo='94')
 groups=collections.defaultdict(list)
 for n in track['notes']:groups[F(round(n['onset']*4),4)].append(n)
 q=F(0)
 def append_group(start,dur,pitches=(),chain=None):
  pieces=list(split_duration(start,dur))
  for j,(absolute,duration) in enumerate(pieces):
   bar=int(absolute//4)+1;onset=absolute%4;m=measures[bar-1]
   for pi,pitch in enumerate(pitches or [None]):
    n=E.SubElement(m,'note')
    if pi:E.SubElement(n,'chord')
    if pitch is None:E.SubElement(n,'rest',**({'measure':'yes'} if duration==4 else {}))
    else:
     step,alter=SPELL[pitch%12];p=E.SubElement(n,'pitch');text(p,'step',step);text(p,'alter',alter);text(p,'octave',pitch//12-1)
    text(n,'duration',int(duration*960));text(n,'voice',1)
    dot=duration in [F(3),F(3,2),F(3,4)];base=duration/F(3,2) if dot else duration;text(n,'type',{F(4):'whole',F(2):'half',F(1):'quarter',F(1,2):'eighth',F(1,4):'16th'}[base])
    if dot:E.SubElement(n,'dot')
    if pitch is not None and len(pieces)>1:
     for kind,condition in [('stop',j>0),('start',j<len(pieces)-1)]:
      if condition:E.SubElement(n,'tie',type=kind);E.SubElement(E.SubElement(n,'notations') if n.find('notations') is None else n.find('notations'),'tied',type=kind)
    events.append(dict(role=role,measure=bar,onset=float(onset),absolute=float(absolute),duration=float(duration),pitch=pitch,chord=bool(pi)))
 ordered=sorted(groups.items())
 for gi,(onset,group) in enumerate(ordered):
  assert onset>=q,(role,onset,q)
  if onset>q:append_group(q,onset-q)
  duration=F(round(group[0]['duration']/.95*4),4)
  if gi+1<len(ordered):duration=min(duration,ordered[gi+1][0]-onset)
  append_group(onset,duration,sorted(n['pitch'] for n in group));q=onset+duration
 if q<316:append_group(q,F(316)-q)
 text(E.SubElement(measures[-1],'barline',location='right'),'bar-style','light-heavy')
E.indent(root);E.ElementTree(root).write(OUT/'source.musicxml',encoding='utf-8',xml_declaration=True)
(OUT/'midi-reading.json').write_text(json.dumps(events,indent=2),encoding='utf-8')
print('quantized notes',sum(e['pitch'] is not None for e in events))

