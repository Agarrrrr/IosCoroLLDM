from pathlib import Path
import sys,json,copy,re,xml.etree.ElementTree as E,collections
from fractions import Fraction as F
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
from prepare_batch import split_pair,labels,clean
OUT=Path(__file__).resolve().parent;rows=json.loads((OUT/'inventory.json').read_text(encoding='utf-8'))
def txt(n):return ''.join(x.text or '' for x in n.findall('lyric/text'))
def norm(s):return ''.join(c.casefold() for c in s if c.isalpha())
def node_map(root):
 model=parse(root);maps=[]
 for pi,p in enumerate(model):
  mapped={}
  for mi,m in enumerate(p):
   for e,n in zip(m['events'],root.findall('part')[pi].findall('measure')[mi].findall('note')):
    if e['pitch'] is not None and n.find('chord') is None:mapped[mi+1,e['onset']]=n
  maps.append(mapped)
 return maps
def replace(n,ly):
 for old in n.findall('lyric'):n.remove(old)
 if ly is not None:
  ly=copy.deepcopy(ly);ly.set('number','1');ly.attrib.pop('default-x',None);ly.attrib.pop('default-y',None)
  for t in ly.findall('text'):
   if t.text:t.text=re.sub(r'^\s*\d+[.)]\s*','',t.text)
  n.append(ly)
def raw_version(batch,verse):
 root=E.parse(Path('output/satb_lote_2026_10_19')/f'{batch:02d}/source.musicxml').getroot()
 for part in root.findall('part'):
  for bi,m in enumerate(part.findall('measure'),1):
   for n in m.findall('note'):
    ls=n.findall('lyric')
    if not ls:continue
    if batch==21:
     wanted={1:1,2:2,3:0}[verse] if bi<=16 else 1
     chosen=next((l for l in ls if l.get('number','').endswith('verse'+str(wanted))),None)
    elif batch==22:
     v=(verse+1 if bi==49 and verse<3 else verse)
     options=[l for l in ls if l.get('number','').endswith('verse0')]
     chosen=(options[min(v-1,len(options)-1)] if options else None) if v<=2 else next((l for l in ls if l.get('number','').endswith('verse3')),None)
     if chosen is None:chosen=options[0] if options else ls[0]
    else:
     chosen=next((l for l in ls if l.get('number','').endswith('verse'+str(verse))),None)
     if chosen is None:chosen=next((l for l in ls if l.get('number','').endswith('verse1')),ls[0])
    for ly in ls:n.remove(ly)
    if chosen is not None:chosen=copy.deepcopy(chosen);chosen.set('number','1');n.append(chosen)
 split_pair(root);return root
def extenders(root):
 for part in root.findall('part'):
  for n in part.findall('.//note'):
   for ly in list(n.findall('lyric')):
    for x in ly.findall('extend'):ly.remove(x)
    if ly.find('text') is None:n.remove(ly)
  seq=[n for n in part.findall('.//note') if n.find('chord') is None]
  for i,n in enumerate(seq):
   ly=n.find('lyric')
   if ly is None:continue
   later=[]
   for nn in seq[i+1:]:
    if nn.find('rest') is not None or nn.find('lyric/text') is not None:break
    later.append(nn)
   if later:
    E.SubElement(ly,'extend',type='start')
    for j,nn in enumerate(later):extra=E.SubElement(nn,'lyric',number='1',placement='below');E.SubElement(extra,'extend',type='stop' if j==len(later)-1 else 'continue')
def section(root,bar,label):
 m=root.findall('part')[0].findall('measure')[bar-1];d=E.Element('direction',placement='above');E.SubElement(E.SubElement(d,'direction-type'),'words',{'font-weight':'bold'}).text=label
 m.insert(next((i for i,c in enumerate(m) if c.tag=='note'),len(m)),d)
def save(r,root,report):
 clean(root);extenders(root)
 for part in root.findall('part'):
  ms=part.findall('measure')
  for i,m in enumerate(ms,1):
   m.set('number',str(i))
   for s in m.findall('barline/bar-style'):
    if s.text in ['light-heavy','heavy-light'] and i!=len(ms):s.text='regular'
  last=ms[-1];bl=last.find('barline')
  if bl is None:bl=E.SubElement(last,'barline',location='right')
  bs=bl.find('bar-style')
  if bs is None:bs=E.SubElement(bl,'bar-style')
  bs.text='light-heavy'
 E.indent(root);E.ElementTree(root).write(Path(r['work'])/'corrected.musicxml',encoding='utf-8',xml_declaration=True)
 r['structural']=report;r['changed']=True;print(r['index'],r['name'],report,flush=True)

# Three complete strophes, each followed by the two written chorus endings.
r=next(r for r in rows if r.get('batch')==21);base=E.parse(Path(r['work'])/'source.musicxml').getroot();template=copy.deepcopy(base);versions=[node_map(raw_version(21,v)) for v in [1,2,3]]
chorusparts=[]
for pi,p in enumerate(template.findall('part')):
 for m in p.findall('measure')[16:]:
  for n in m.findall('note'):
   for t in n.findall('lyric/text'):
    if t.text and re.fullmatch(r'Sa',t.text):t.text='Naa'
    elif t.text and t.text.startswith('muel'):t.text=t.text.replace('muel','són')
 # The PDF first ending says "Vive en mi corazón", not "Es mi Padre en la fe".
 for bi,words in [(23,['Vi','ve_en','mi','co','ra']),(24,['zón;'])]:
  ns=[n for n in p.findall('measure')[bi-1].findall('note') if n.find('lyric/text') is not None]
  assert len(ns)==len(words),(pi,bi,len(ns),words)
  for n,value in zip(ns,words):n.find('lyric/text').text=value
for pi,p in enumerate(base.findall('part')):
 ms=template.findall('part')[pi].findall('measure')
 for m in list(p.findall('measure')):p.remove(m)
 for verse in range(1,4):
  vm=versions[verse-1]
  for bi,original in enumerate(ms,1):
   m=copy.deepcopy(original);p.append(m)
   if bi>16:continue
   # Notes retain their original role and rhythm. Only their underlay changes.
   local=node_map(E.Element('empty')) if False else None
   model=parse(template)[pi][bi-1]
   for e,n in zip(model['events'],m.findall('note')):
    if e['pitch'] is None or n.find('chord') is not None:continue
    own=vm[pi].get((bi,e['onset']));ly=own.find('lyric') if own is not None else None
    if ly is None and txt(n):
     common=vm[0].get((bi,e['onset']));ly=common.find('lyric') if common is not None else None
    replace(n,ly)
save(r,base,dict(verses=3,chorusAfterEach=True,bars=96,source='PDF Mi Padre en la Fe',nameCorrection='Samuel -> Naasón',endingCorrection='Vive en mi corazón'))
for v in range(3):section(base,v*32+1,f'Estrofa {v+1}');section(base,v*32+17,'Coro')
E.ElementTree(base).write(Path(r['work'])/'corrected.musicxml',encoding='utf-8',xml_declaration=True)

for batch in [17,18]:
 r=next(r for r in rows if r.get('batch')==batch);root=E.parse(Path(r['work'])/'source.musicxml').getroot();template=copy.deepcopy(root);raw=[raw_version(batch,v) for v in [1,2,3]];maps=[node_map(v) for v in raw]
 for pi,p in enumerate(root.findall('part')):
  for m in list(p.findall('measure')):p.remove(m)
  for verse in [1,2,3]:
   for bi,old in enumerate(template.findall('part')[pi].findall('measure'),1):
    m=copy.deepcopy(old);p.append(m)
    if verse==1:continue
    model=parse(template)[pi][bi-1]
    for e,n in zip(model['events'],m.findall('note')):
     if e['pitch'] is None or n.find('chord') is not None or not txt(n):continue
     donor=pi if pi<2 else 0
     first=maps[0][donor].get((bi,e['onset']));selected=maps[verse-1][donor].get((bi,e['onset']))
     if first is not None and selected is not None and norm(txt(n))==norm(txt(first)):replace(n,selected.find('lyric'))
 save(r,root,dict(verses=3,chorusAfterEach=True,bars=99))

r=next(r for r in rows if r.get('batch')==22);root=E.parse(Path(r['work'])/'source.musicxml').getroot();maps=[node_map(raw_version(22,v)) for v in [1,2,3]];barMap=json.loads(Path('output/satb_lote_2026_10_19/22/preparation.json').read_text(encoding='utf-8'))['barMap'];current=node_map(root);baseFirst=maps[0]
for pi,p in enumerate(root.findall('part')):
 model=parse(root)[pi]
 for outbar,(src,verse) in enumerate(barMap,1):
  bi=src+1
  if verse==1 and bi!=49:continue
  for e,n in zip(model[outbar-1]['events'],p.findall('measure')[outbar-1].findall('note')):
   if e['pitch'] is None or n.find('chord') is not None or not txt(n):continue
   donor=pi if pi<2 else 0;selected=maps[verse-1][donor].get((bi,e['onset']));first=baseFirst[donor].get((bi,e['onset']))
   if selected is not None and selected.find('lyric') is not None:
    if pi<2 or first is not None and norm(txt(n))==norm(txt(first)):replace(n,selected.find('lyric'))
save(r,root,dict(verses=3,chorusAfterEach=True,bars=156,secondVerseRestored=True,pickupForThirdVerseRestored=True))

# These two older delivered files still combined SA/TB. Keep their fully
# developed interpretation and place the existing voices on separate staves.
for r in [r for r in rows if r['index'] in [30,31]]:
 root=E.parse(Path(r['work'])/'source.musicxml').getroot();split_pair(root);labels(root);maps=node_map(root)
 for target,donor in [(1,0),(3,2)]:
  for key,n in maps[target].items():
   if txt(n) or any(t.get('type')=='stop' for t in n.findall('tie')):continue
   source=maps[donor].get(key)
   if source is not None and txt(source):replace(n,source.find('lyric'))
 save(r,root,dict(verses=3,chorusAfterEach=True,bars=109,stavesCorrected=4))
(OUT/'inventory.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
