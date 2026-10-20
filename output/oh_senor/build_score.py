from pathlib import Path
from fractions import Fraction as F
import json,collections,re,unicodedata,copy,xml.etree.ElementTree as E
OUT=Path(__file__).resolve().parent
DATA=json.loads((OUT/'source-notes.json').read_text(encoding='utf8'));NOTES=DATA['events'];FORM=DATA['form'];LENGTH={int(k):v for k,v in DATA['lengths'].items()};START={int(k):v for k,v in DATA['starts'].items()}
PDF=json.loads((OUT/'pdf-alignment.json').read_text(encoding='utf8'))
# Three MIDI note-offs overlap a following attack. The printed quarter/half
# notes settle their durations; pitches and attack times remain unchanged.
duration_corrections=[]
for role in range(4):
 row=[e for e in NOTES if e['role']==role]
 for e in row:
  later=[x['absolute'] for x in row if x['absolute']>e['absolute']]
  if later and e['absolute']+e['duration']>min(later):
   old=e['duration'];e['duration']=min(later)-e['absolute'];duration_corrections.append(dict(role=role,measure=e['measure'],onset=e['onset'],pitch=e['pitch'],before=old,after=e['duration']))
(OUT/'midi-duration-corrections.json').write_text(json.dumps(duration_corrections,indent=2),encoding='utf8')

def norm(s):return ''.join(c for c in unicodedata.normalize('NFD',s.casefold()) if c.isalpha() and not unicodedata.combining(c))
def text(parent,tag,value,**attrs):n=E.SubElement(parent,tag,attrs);n.text=str(value);return n
def notation(n):
 old=n.find('notations');return old if old is not None else E.SubElement(n,'notations')
tokens=[]
for original in PDF['tokens']:
 t=copy.deepcopy(original)
 if t['text']=='porsiem':
  for value in ['por','siem']:tokens.append(dict(t,text=value))
  continue
 t['text']=t['text'].replace('se_a','se_ha')
 if t['measure']==26 and t['text']=='ra':t['text']='rá'
 if t['text']=='ni':t['text']='ní'
 if t['text']=='va?':t['text']='vá?'
 tokens.append(t)

# All source words are explicit. No general-purpose word dictionary is used:
# it could incorrectly treat separate words as a single hyphenated word.
vocab={norm(w) for w in 'Oh Señor mi Eterno eres Tú solo a Ti se ha de alabar grande en victoria Magnífico santidad Rey reyes por siempre señores bendito Salvador poder y gloria tu será exaltado Quién como Jehová entre los dioses gran adorar Aleluya Amén'.split()}
atoms=[]
for occurrence,m in enumerate(FORM):
 for t in tokens:
  if t['measure']!=m:continue
  for j,raw in enumerate(t['text'].split('_')):
   atoms.append(dict(token=t,raw=raw,key=norm(raw),elision=j>0,occurrence=occurrence))
states={len(atoms):(0,[])}
for i in range(len(atoms)-1,-1,-1):
 word='';best=None
 for j in range(i,min(len(atoms),i+8)):
  if j>i and (atoms[j]['elision'] or re.search(r'[,;?!]$',atoms[j-1]['raw'])):break
  word+=atoms[j]['key']
  if word in vocab and j+1 in states:
   candidate=(1+states[j+1][0],[(i,j+1)]+states[j+1][1])
   if best is None or candidate[0]<best[0]:best=candidate
 if best is not None:states[i]=best
assert 0 in states,'Some PDF syllables do not form the sung words'
groups=states[0][1];wordreport=[];buckets=collections.defaultdict(list)
for gi,(i,j) in enumerate(groups):
 wordreport.append(''.join(a['raw'] for a in atoms[i:j]))
 for k,a in enumerate(atoms[i:j]):a.update(group=gi,before=k>0,after=k<j-i-1)
for a in atoms:buckets[a['occurrence'],a['token']['measure'],a['token']['onset']].append(a)
source_lyrics={}
for key,aa in buckets.items():
 value=''
 for j,a in enumerate(aa):
  if j:value+=('‿' if a['elision'] else '-' if aa[j-1]['group']==a['group'] else ' ')
  value+=a['raw']
 before=aa[0]['before'];after=aa[-1]['after']
 sourcekey=(key[1],key[2])
 source_lyrics[sourcekey]=dict(text=value,kind='middle' if before and after else 'end' if before else 'begin' if after else 'single')
(OUT/'lyric-source.json').write_text(json.dumps(dict(words=wordreport,positions=[dict(measure=m,onset=o,**v) for (m,o),v in source_lyrics.items()]),ensure_ascii=False,indent=2),encoding='utf8')

expanded=[];measure_starts=[];position=F(0)
for i,m in enumerate(FORM):
 measure_starts.append(position)
 for e in NOTES:
  if e['measure']==m:expanded.append(dict(e,output=i,absolute=position+F(str(e['onset'])),source=m))
 position+=LENGTH[m]
assert position==328
# Reference performance is used only for checking pitches and rhythm. Score
# duration rounds the reference's gate/release to its written note value.
raw=json.loads((OUT/'midi.json').read_text(encoding='utf8'));checks=[]
for role in range(4):
 intended=sorted((float(e['absolute']),e['pitch']) for e in expanded if e['role']==role)
 actual=sorted((e['onset'],e['pitch']) for e in raw['tracks'][role]['notes'])
 assert intended==actual,(role,len(intended),len(actual),[(x,y) for x,y in zip(intended,actual) if x!=y][:4])
 checks.append(dict(role=role,attacks=len(intended),referenceMatch=True))

root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Oh Señor');ident=E.SubElement(root,'identification');text(ident,'creator','Neftalí Medina',type='composer');text(ident,'creator','Jaasiel Sánchez R.',type='arranger');enc=E.SubElement(ident,'encoding');text(enc,'software','Coro LLDM · PDF y MIDI del catálogo');text(enc,'encoding-date','2026-10-19')
misc=E.SubElement(ident,'miscellaneous');text(misc,'miscellaneous-field','Alabanza. PDF del catálogo, 2 páginas. Repeticiones y regreso al signo desarrollados; cuatro pentagramas SATB. El intermedio grave conserva las divisiones de tenor y bajo.',name='source')
defaults=E.SubElement(root,'defaults');scaling=E.SubElement(defaults,'scaling');text(scaling,'millimeters',7);text(scaling,'tenths',40)
pl=E.SubElement(root,'part-list');group=E.SubElement(pl,'part-group',number='1',type='start');text(group,'group-symbol','bracket');text(group,'group-barline','no')
for role,name in enumerate(['Soprano','Alto','Tenor','Bajo']):
 sp=E.SubElement(pl,'score-part',id=f'P{role+1}');text(sp,'part-name',name);text(sp,'part-abbreviation','SATB'[role]+'.');ins=E.SubElement(sp,'score-instrument',id=f'I{role+1}');text(ins,'instrument-name',name);mi=E.SubElement(sp,'midi-instrument',id=f'I{role+1}');text(mi,'midi-channel',role+1);text(mi,'midi-program',53)
E.SubElement(pl,'part-group',number='1',type='stop')

def duration_node(n,d):
 values={F(4):('whole',False),F(3):('half',True),F(2):('half',False),F(3,2):('quarter',True),F(1):('quarter',False),F(3,4):('eighth',True),F(1,2):('eighth',False),F(1,4):('16th',False)}
 assert d in values,d
 text(n,'duration',int(d*960));text(n,'voice',1);text(n,'type',values[d][0])
 if values[d][1]:E.SubElement(n,'dot')
def split_length(start,length):
 # Split unnotatable values at beats without changing a syllable's attack.
 result=[];left=length;pos=start
 while left:
  options=[F(4),F(3),F(2),F(3,2),F(1),F(3,4),F(1,2),F(1,4)]
  d=next(x for x in options if x<=left and (pos.denominator==1 or x<=1-pos%1))
  result.append(d);left-=d;pos+=d
 return result
def spelling(p):
 ns=[0,2,4,5,7,9,11];pc=p%12;k=min(range(7),key=lambda k:abs(ns[k]-pc));return 'CDEFGAB'[k],pc-ns[k],p//12-1
nodes=collections.defaultdict(list);lyric_count=collections.Counter();missing=[]
for role in range(4):
 part=E.SubElement(root,'part',id=f'P{role+1}');prior_meter=None
 roleevents=[e for e in expanded if e['role']==role]
 for i,m in enumerate(FORM):
  start=measure_starts[i];length=F(LENGTH[m]);measure=E.SubElement(part,'measure',number=str(i+1),**({'implicit':'yes'} if i==0 else {}))
  meter=4 if m==0 else LENGTH[m]
  if i==0 or meter!=prior_meter:
   attrs=E.SubElement(measure,'attributes')
   if i==0:
    text(attrs,'divisions',960);text(E.SubElement(attrs,'key'),'fifths',3)
   tm=E.SubElement(attrs,'time');text(tm,'beats',meter);text(tm,'beat-type',4)
   if i==0:
    cl=E.SubElement(attrs,'clef');text(cl,'sign','F' if role==3 else 'G');text(cl,'line',4 if role==3 else 2)
    if role==2:text(cl,'clef-octave-change',-1)
   prior_meter=meter
  if role==0:
   if i in [0,56,79]:
    labels={0:'dolce',56:'Alabanza',79:'Final'}
    direction=E.SubElement(measure,'direction',placement='above');text(E.SubElement(direction,'direction-type'),'words',labels[i],**{'font-style':'italic'} if i==0 else {'font-weight':'bold'})
   for time,bpm in raw['tempos']:
    if start<=F(str(time))<start+length:
     d=E.SubElement(measure,'direction',placement='above');met=E.SubElement(E.SubElement(d,'direction-type'),'metronome',**({'print-object':'no'} if time%1 or time>=312 else {}));text(met,'beat-unit','quarter');text(met,'per-minute',round(bpm,3));text(d,'offset',int((F(str(time))-start)*960));E.SubElement(d,'sound',tempo=str(bpm))
   if m==56:
    d=E.SubElement(measure,'direction',placement='above');text(E.SubElement(d,'direction-type'),'words','rit.')
  if m==54:
   d=E.SubElement(measure,'direction',placement='below');E.SubElement(E.SubElement(E.SubElement(d,'direction-type'),'dynamics'),'ff');E.SubElement(d,'sound',dynamics='107')
  overlap=[e for e in roleevents if e['absolute']<start+length and e['absolute']+F(str(e['duration']))>start]
  chords=collections.defaultdict(list)
  for e in overlap:
   on=max(start,e['absolute'])-start;end=min(start+length,e['absolute']+F(str(e['duration'])))-start
   chords[on].append((e,end-on))
  q=F(0)
  for on,heads in sorted(chords.items()):
   assert on>=q,(role,i,m,on,q)
   if on>q:
    for d in split_length(q,on-q):n=E.SubElement(measure,'note');E.SubElement(n,'rest');duration_node(n,d)
   ds={d for e,d in heads};assert len(ds)==1,(role,i,heads)
   duration=next(iter(ds));pieces=split_length(on,duration);offset=F(0)
   for ni,durationpart in enumerate(pieces):
    for hi,(e,_) in enumerate(sorted(heads,key=lambda p:p[0]['pitch'])):
     n=E.SubElement(measure,'note')
     if hi:E.SubElement(n,'chord')
     p=E.SubElement(n,'pitch');step,alter,octave=spelling(e['pitch']);text(p,'step',step)
     if alter:text(p,'alter',alter)
     text(p,'octave',octave)
     continuing=e['absolute']<start+on+offset;continues=e['absolute']+F(str(e['duration']))>start+on+offset+durationpart
     text(n,'duration',int(durationpart*960))
     for condition,kind in [(continuing,'stop'),(continues,'start')]:
      if condition:E.SubElement(n,'tie',type=kind)
     text(n,'voice',1)
     tmp=E.Element('tmp');duration_node(tmp,durationpart)
     for child in list(tmp):
      if child.tag in ['type','dot']:n.append(child)
     for condition,kind in [(continuing,'stop'),(continues,'start')]:
      if condition:E.SubElement(notation(n),'tied',type=kind)
     nodes[role,i,on+offset].append(n)
     if not hi and not continuing:
      lyric=source_lyrics.get((m,float(on)))
      if lyric:
       ly=E.SubElement(n,'lyric',number='1',placement='below');text(ly,'syllabic',lyric['kind']);text(ly,'text',lyric['text']);lyric_count[role]+=1
     if m in [58,59] and not hi and (m==59 or ni==len(pieces)-1 and on+offset+durationpart==length):E.SubElement(notation(n),'fermata').text='normal'
    offset+=durationpart
   q=on+duration
  if q<length:
   for d in split_length(q,length-q):n=E.SubElement(measure,'note');E.SubElement(n,'rest',**({'measure':'yes'} if q==0 and d==length else {}));duration_node(n,d)
  if i==len(FORM)-1:text(E.SubElement(measure,'barline',location='right'),'bar-style','light-heavy')

# Build melisma extenders only to the last following note without another
# syllable, and stop at a rest. Each voice keeps its own musical response.
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
   for j,later in enumerate(following):E.SubElement(E.SubElement(later,'lyric',number='1'),'extend',type='stop' if j==len(following)-1 else 'continue')
E.indent(root);E.ElementTree(root).write(OUT/'Oh Señor - SATB desarrollado - Cantai.musicxml',encoding='utf-8',xml_declaration=True)
(OUT/'preparation.json').write_text(json.dumps(dict(title='Oh Señor',staves=4,writtenBars=60,expandedBars=len(FORM),quarters=float(position),referenceChecks=checks,lyricNotes=dict(lyric_count),tenorBassDivisi=True),ensure_ascii=False,indent=2),encoding='utf8')
print((OUT/'preparation.json').read_text(encoding='utf8'))
print('WORDS',' '.join(wordreport))
