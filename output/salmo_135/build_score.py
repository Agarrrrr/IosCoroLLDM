from pathlib import Path
from fractions import Fraction as F
import json,collections,xml.etree.ElementTree as E,math
OUT=Path('output/salmo_135')
def text(p,k,v,**attrs):e=E.SubElement(p,k,attrs);e.text=str(v);return e
def notation(n):
 e=n.find('notations')
 return e if e is not None else E.SubElement(n,'notations')
def run():
 data=json.loads((OUT/'aligned-reading.json').read_text(encoding='utf-8'));events=data['events'];nodes={};bypos={}
 for i,e in enumerate(events):
  e['id']=i;e['absolute']=F((e['measure']-1)*4)+F(str(e['onset']))
  if not e['rest']:e['pitch']=(e['diatonic']//7+1)*12+[0,2,4,5,7,9,11][e['diatonic']%7]+e['alter']
  bypos[(e['role'],e['measure'],F(str(e['onset'])))]=e
 # The fast Bass phrase has separate "do", "nues", "tro" syllables.
 source=bypos[3,19,F(1,2)];atom=next(a for a in source['lyrics'] if a['text']=='do');source['lyrics'].remove(atom);bypos[3,19,F(1)]['lyrics'].append(atom)
 source=bypos[3,19,F(3,2)];atom=next(a for a in source['lyrics'] if a['text']=='tro');source['lyrics'].remove(atom);bypos[3,19,F(7,4)]['lyrics'].append(atom)
 # Match every drawn arc to its actual PDF heads. Identical outline traces
 # are duplicates of a single printed arc.
 arcs=[];seen=set();openings=[];closings=[];mapping=[]
 for arc in data['arcs']:
  key=(arc['page'],tuple(round(v,2) for v in arc['start']),tuple(round(v,2) for v in arc['end']))
  if key in seen:continue
  seen.add(key)
  sx,sy=arc['start'];ex,ey=arc['end'];page=arc['page']
  candidates=[e for e in events if e['page']==page and not e['rest']]
  def cost(e,x,y):return abs(e['x']+3.1-x)*3+abs(e['y']-y)*.4
  a=min(candidates,key=lambda e:cost(e,sx,sy));b=min(candidates,key=lambda e:cost(e,ex,ey))
  system=next(s for s in data['systems'] if s['page']==page and s['system']==a['system'])
  if ex>system['bars'][-1]-8:
   openings.append((a,arc));mapping.append(dict(kind='open',a=a['id'],arc=arc));continue
  # A continuation starts at the left system margin before any heads.
  bsys=next(s for s in data['systems'] if s['page']==page and s['system']==b['system'])
  firstx=min(e['x'] for e in candidates if e['system']==b['system'] and e['role']==b['role'])
  if sx<firstx-4:
   closings.append((b,arc));mapping.append(dict(kind='close',b=b['id'],arc=arc));continue
  assert a['role']==b['role'] and a['absolute']<b['absolute'],(arc,a,b)
  assert cost(a,sx,sy)<60 and cost(b,ex,ey)<60,(arc,a,b)
  arcs.append((a,b));mapping.append(dict(kind='arc',a=a['id'],b=b['id'],cost=[cost(a,sx,sy),cost(b,ex,ey)]))
 for a,arc in openings:
  choices=[(b,c) for b,c in closings if b['role']==a['role'] and b['absolute']>a['absolute']]
  assert choices,('unclosed arc',a)
  b,c=min(choices,key=lambda z:z[0]['absolute']);closings.remove((b,c));arcs.append((a,b))
 assert not closings,closings
 root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Salmo 135');ident=E.SubElement(root,'identification');text(ident,'creator','Noé Ovado Rodriguez.',type='composer');misc=E.SubElement(ident,'miscellaneous');text(misc,'miscellaneous-field','Transcripción SATB de las cuatro páginas del PDF del catálogo; 45 compases; tempo original negra = 90.',name='source')
 enc=E.SubElement(ident,'encoding');text(enc,'software','Coro LLDM - transcripción de PDF digital');text(enc,'encoding-date','2026-10-19')
 defaults=E.SubElement(root,'defaults');scale=E.SubElement(defaults,'scaling');text(scale,'millimeters',7);text(scale,'tenths',40);page=E.SubElement(defaults,'page-layout');text(page,'page-height',1697.14);text(page,'page-width',1200);marg=E.SubElement(page,'page-margins',type='both')
 for key in ['left-margin','right-margin','top-margin','bottom-margin']:text(marg,key,65)
 E.SubElement(defaults,'lyric-font',**{'font-family':'Times New Roman','font-size':'11'})
 pl=E.SubElement(root,'part-list');group=E.SubElement(pl,'part-group',number='1',type='start');text(group,'group-symbol','bracket');text(group,'group-barline','no')
 for role,name in enumerate(['Soprano','Alto','Tenor','Bajo']):
  sp=E.SubElement(pl,'score-part',id=f'P{role+1}');text(sp,'part-name',name);text(sp,'part-abbreviation','SATB'[role]+'.');inst=E.SubElement(sp,'score-instrument',id=f'I{role+1}');text(inst,'instrument-name',name);mi=E.SubElement(sp,'midi-instrument',id=f'I{role+1}');text(mi,'midi-channel',role+1);text(mi,'midi-program',53)
 E.SubElement(pl,'part-group',number='1',type='stop')
 for role in range(4):
  part=E.SubElement(root,'part',id=f'P{role+1}')
  for bar in range(1,46):
   m=E.SubElement(part,'measure',number=str(bar))
   if bar==1:
    a=E.SubElement(m,'attributes');text(a,'divisions',960);text(E.SubElement(a,'key'),'fifths',2);tm=E.SubElement(a,'time');text(tm,'beats',4);text(tm,'beat-type',4);cl=E.SubElement(a,'clef');text(cl,'sign','F' if role==3 else 'G');text(cl,'line',4 if role==3 else 2)
    if role==2:text(cl,'clef-octave-change',-1)
    if role==0:
     d=E.SubElement(m,'direction',placement='above');mt=E.SubElement(E.SubElement(d,'direction-type'),'metronome');text(mt,'beat-unit','quarter');text(mt,'per-minute',90);E.SubElement(d,'sound',tempo='90')
   row=[e for e in events if e['role']==role and e['measure']==bar]
   q=F(0)
   for e in row:
    duration=F(str(e['duration']));n=E.SubElement(m,'note',id=f"salmo135-{e['id']}");nodes[e['id']]=n
    if e.get('chord'):E.SubElement(n,'chord')
    else:assert F(str(e['onset']))==q,(role,bar,e,q);q+=duration
    if e['rest']:E.SubElement(n,'rest',**({'measure':'yes'} if e['duration']==4 else {}))
    else:
     p=E.SubElement(n,'pitch');text(p,'step','CDEFGAB'[e['diatonic']%7]);text(p,'alter',e['alter']);text(p,'octave',e['diatonic']//7)
    text(n,'duration',duration*960);text(n,'voice',1)
    base=duration/F(3,2) if e.get('dot') else duration;kind={F(4):'whole',F(2):'half',F(1):'quarter',F(1,2):'eighth',F(1,4):'16th'}[base];text(n,'type',kind)
    if e.get('dot'):E.SubElement(n,'dot')
    if 'accidental' in e:text(n,'accidental',{-1:'flat',0:'natural',1:'sharp'}[e['accidental']])
    if e['lyrics'] and not e.get('chord'):
     ly=E.SubElement(n,'lyric',number='1',placement='below');first=e['lyrics'][0];last=e['lyrics'][-1];before=first['syllabic'] in ['middle','end'];after=last['syllabic'] in ['begin','middle'];text(ly,'syllabic','middle' if before and after else 'end' if before else 'begin' if after else 'single');text(ly,'text',''.join(('‿' if a['join'] else ' ')*bool(j)+a['text'] for j,a in enumerate(e['lyrics'])))
   assert q==4,(role,bar,q)
   if bar==45:text(E.SubElement(m,'barline',location='right'),'bar-style','light-heavy')
 # Preserve actual ties only for adjacent, equal-pitch heads without a new
 # syllable. All other printed curves remain phrase slurs.
 active=collections.defaultdict(dict);tieCount=0
 for a,b in sorted(arcs,key=lambda ab:(ab[0]['role'],ab[0]['absolute'])):
  adjacent=a['absolute']+F(str(a['duration']))==b['absolute'];tie=a['pitch']==b['pitch'] and adjacent and not b['lyrics']
  if tie:
   for e,kind in [(a,'start'),(b,'stop')]:E.SubElement(nodes[e['id']],'tie',type=kind);E.SubElement(notation(nodes[e['id']]),'tied',type=kind)
   tieCount+=1
  else:
   role=a['role'];active[role]={k:v for k,v in active[role].items() if v>=a['absolute']};num=next(i for i in range(1,17) if i not in active[role]);active[role][num]=b['absolute']
   for e,kind in [(a,'start'),(b,'stop')]:E.SubElement(notation(nodes[e['id']]),'slur',type=kind,number=str(num))
 for part in root.findall('part'):
  seq=[n for n in part.findall('.//note') if n.find('chord') is None]
  for i,n in enumerate(seq):
   ly=n.find('lyric')
   if ly is None:continue
   following=[]
   for later in seq[i+1:]:
    if later.find('rest') is not None or later.find('lyric/text') is not None:break
    following.append(later)
   if following:
    E.SubElement(ly,'extend',type='start')
    for j,later in enumerate(following):ext=E.SubElement(later,'lyric',number='1',placement='below');E.SubElement(ext,'extend',type='stop' if j==len(following)-1 else 'continue')
 order=['chord','pitch','rest','duration','tie','voice','type','dot','accidental','notations','lyric']
 for n in nodes.values():n[:]=sorted(n,key=lambda c:order.index(c.tag) if c.tag in order else 999)
 E.indent(root);E.ElementTree(root).write(OUT/'Salmo 135 - SATB - Cantai.musicxml',encoding='utf-8',xml_declaration=True)
 (OUT/'arc-mapping.json').write_text(json.dumps(mapping,ensure_ascii=False,indent=2),encoding='utf-8')
 (OUT/'preparation.json').write_text(json.dumps(dict(staves=4,bars=45,notes=len(root.findall('.//pitch')),lyricNotes=len(root.findall('.//lyric/text')),printedArcs=len(arcs),ties=tieCount,slurs=len(arcs)-tieCount,dynamics='No dynamic symbols printed in this PDF',tempo=90),ensure_ascii=False,indent=2),encoding='utf-8')
 print((OUT/'preparation.json').read_text(encoding='utf-8'))
if __name__=='__main__':run()
