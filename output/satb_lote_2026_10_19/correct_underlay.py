from pathlib import Path
import xml.etree.ElementTree as E,json,copy,hashlib,shutil
from fractions import Fraction as F
from score_model import parse

OUT=Path('output/underlay_revision_2026_10_19');BATCH=Path('output/satb_lote_2026_10_19')
allrows=json.loads((OUT/'audit.json').read_text(encoding='utf-8'));jobs=[]
def build(match):
 r=next(r for r in allrows if match(r));r=copy.deepcopy(r);r['root']=E.parse(r['xml']).getroot();r['edits']=[]
 r['sourceMscz']=str(Path('E:/MusescoreCantai')/(r['name']+'.mscz'))
 r['originalHash']=hashlib.sha256(Path(r['sourceMscz']).read_bytes()).hexdigest()
 w=OUT/('score-'+str(len(jobs)+1));w.mkdir(exist_ok=True);r['work']=str(w)
 shutil.copy2(r['sourceMscz'],w/'before.mscz');shutil.copy2(r['xml'],w/'before.musicxml');jobs.append(r);return r
def model(r):
 parts=parse(r['root'])
 for ri,p in enumerate(parts):
  for mi,m in enumerate(p):
   for e,n in zip(m['events'],r['root'].findall('part')[ri].findall('measure')[mi].findall('note')):e['node']=n
 return parts
def txt(n):return ''.join(t.text or '' for t in n.findall('lyric/text'))
def put(r,role,bar,onset,lyric,force=False):
 events=model(r)[role][bar-1]['events'];e=next(e for e in events if e['pitch'] is not None and e['onset']==F(onset) and e['node'].find('chord') is None);n=e['node']
 if txt(n) and not force:return
 assert not any(t.get('type')=='stop' for t in n.findall('tie')),(r['name'],role,bar,onset)
 before=txt(n)
 for old in n.findall('lyric'):n.remove(old)
 if isinstance(lyric,str):
  ly=E.Element('lyric',number='1',placement='below');value=lyric.rstrip('-');E.SubElement(ly,'syllabic').text='begin' if lyric.endswith('-') else 'single';E.SubElement(ly,'text').text=value
 else:ly=copy.deepcopy(lyric)
 for x in ly.findall('extend'):ly.remove(x)
 n.append(ly);r['edits'].append(dict(role=role,bar=bar,onset=str(onset),before=before,after=txt(n)))
def share(r,role,donor,bars):
 p=model(r)
 for b in bars:
  for e in p[role][b-1]['events']:
   n=e['node']
   if e['pitch'] is None or txt(n) or n.find('chord') is not None or any(t.get('type')=='stop' for t in n.findall('tie')):continue
   source=next((a for a in p[donor][b-1]['events'] if a['pitch'] is not None and a['onset']==e['onset'] and txt(a['node'])),None)
   if source:put(r,role,b,e['onset'],source['node'].find('lyric'))

# The figure supplied by the user: common sentence first, lower response later.
r=build(lambda r:r.get('batch')==21)
for role in [2,3]:share(r,role,0,[1,2,9,10,23,24,25,31,32])
for bar in [18,26]:put(r,1,bar,0,'fe,')

r=build(lambda r:r['name'].startswith('Recuerda -'))
for role in [2,3]:share(r,role,0,[17,45])

r=build(lambda r:r.get('batch')==20)
for offset in [0,34]:
 share(r,1,2,range(18+offset,23+offset))
 share(r,1,0,range(27+offset,31+offset))
 # At the common unison entry "La Iglesia", the split import retained a rest
 # in Alto. The PDF shows the same single head for both upper voices.
 p=model(r);bar=22+offset;m=r['root'].findall('part')[1].findall('measure')[bar-1]
 rest=next(e['node'] for e in p[1][bar-1]['events'] if e['onset']==3 and e['pitch'] is None)
 donor=next(e['node'] for e in p[0][bar-1]['events'] if e['onset']==3 and e['pitch'] is not None)
 m[list(m).index(rest)]=copy.deepcopy(donor);r['edits'].append(dict(role=1,bar=bar,onset='3',before='rest',after='La‿I',noteCorrection='shared unison visible in PDF'))

r=build(lambda r:r.get('batch')==14)
for role in [2,3]:
 share(r,role,1,[39,40,73])
 share(r,role,0,[46,71,80])
share(r,2,3,[43,79])
put(r,3,36,0,'rei-')

r=build(lambda r:r['name'].startswith('Mi Torre Fuerte -'))
share(r,3,0,[6])

r=build(lambda r:r['name'].startswith('Cuando Oí Su Voz -'))
for role in [2,3]:
 # Three written verses have the same shared entry following their response.
 # The explicitly printed Uh passages retain their vocalization and melismas.
 share(r,role,0,[4,17,18,46,59,60,88,101,102])

r=build(lambda r:r['name'].startswith('Alabad a Jehová -'))
put(r,3,58,0,'tó,');put(r,3,58,1,'Los',force=True)
for bar in [60,61,62]:
 put(r,3,bar,0,'bad,');put(r,3,bar,1,'a');put(r,3,bar,3,'la')

def extenders(root):
 for part in root.findall('part'):
  for n in part.findall('.//note'):
   for ly in n.findall('lyric'):
    for ex in ly.findall('extend'):ly.remove(ex)
   for ly in list(n.findall('lyric')):
    if ly.find('text') is None:n.remove(ly)
  # Each independent staff has a single sung line in these seven scores.
  seq=[n for n in part.findall('.//note') if n.find('chord') is None]
  for i,n in enumerate(seq):
   ly=n.find('lyric')
   if ly is None or ly.find('text') is None:continue
   following=[]
   for later in seq[i+1:]:
    if later.find('rest') is not None or later.find('lyric/text') is not None:break
    following.append(later)
   if following:
    E.SubElement(ly,'extend',type='start')
    for j,later in enumerate(following):
     extra=E.SubElement(later,'lyric',number='1',placement='below');E.SubElement(extra,'extend',type='stop' if j==len(following)-1 else 'continue')

for r in jobs:
 root=r.pop('root');extenders(root);w=Path(r['work']);p=w/'corrected.musicxml';E.indent(root);E.ElementTree(root).write(p,encoding='utf-8',xml_declaration=True)
 r['correctedXml']=str(p);style=Path(r['xml']).parent/'choral-spacing.mss';r['style']=str(style if style.exists() else BATCH/'choral.mss');r.pop('candidates',None)
 print(r['name'],'changes',len(r['edits']))
(OUT/'corrections.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2),encoding='utf-8')
