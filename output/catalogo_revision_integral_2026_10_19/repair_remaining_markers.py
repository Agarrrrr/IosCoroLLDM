from pathlib import Path
import json,collections,xml.etree.ElementTree as E
from syllable_audit import OUT,atoms_for,segment,load_vocab,text
rows=json.loads((OUT/'inventory.json').read_text(encoding='utf8'));vocab=load_vocab(rows)
vocab.update('levantado derramado reedificado restauración levantará glorificaré'.split())
report=[]
for i in [9,18,39,41]:
 r=rows[i-1];p=Path(r['work']);root=E.parse(p/'source.musicxml').getroot();changes=[];unknown=[]
 for pi,part in enumerate(root.findall('part')):
  for bar,m in enumerate(part.findall('measure'),1):
   for t in m.findall('.//lyric/text'):
    if i==9 and t.text=='Dad':t.text='dad'
    if i==18:
     if t.text:t.text=t.text.replace('noes','no_es')
     if bar==49 and t.text=='ve':t.text='ver'
     if bar==122 and t.text=='ra':t.text='ran'
    if i==41 and pi==2 and bar==67 and t.text=='tam':t.text='ta'
    if i==41 and pi==0 and bar==80 and t.text=='ta':t.text='tam'
  for number in sorted({l.get('number','1') for l in part.findall('.//lyric') if text(l)}):
   atoms=atoms_for(part,number);flags=collections.defaultdict(list)
   for start,end,known in segment(atoms,vocab):
    if not known:unknown.append(dict(part=pi,bar=atoms[start]['bar'],token=atoms[start]['raw'],context=' '.join(a['raw'] for a in atoms[max(0,start-5):min(len(atoms),end+6)])))
    lyrics=[]
    for a in atoms[start:end]:
     if not lyrics or lyrics[-1] is not a['lyric']:lyrics.append(a['lyric'])
    for j,l in enumerate(lyrics):flags[l].append((j>0,j<len(lyrics)-1))
   for l,ff in flags.items():
    before=ff[0][0];after=ff[-1][1];value='middle' if before and after else 'end' if before else 'begin' if after else 'single'
    old=l.find('syllabic')
    if old is None:old=E.SubElement(l,'syllabic')
    if old.text!=value:changes.append([pi,text(l),old.text,value]);old.text=value
 E.ElementTree(root).write(p/'corrected.musicxml',encoding='utf-8',xml_declaration=True)
 r['changed']=True;r['syllabicEdits']=len(changes)
 report.append(dict(index=i,changes=changes,unknown=unknown));print(i,'edits',len(changes),'unknown',len(unknown))
 seen=set()
 for u in unknown:
  if u['context'] not in seen:print(u);seen.add(u['context'])
(OUT/'remaining-marker-review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
(OUT/'inventory.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
