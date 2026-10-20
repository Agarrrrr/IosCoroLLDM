from pathlib import Path
import json,collections,xml.etree.ElementTree as E
from syllable_audit import OUT,atoms_for,norm
rows=json.loads((OUT/'inventory.json').read_text(encoding='utf8'))
# These are word boundaries, not new phonetic divisions. The source scores
# had explicitly joined several separate words into single hyphen chains.
phrases=['temor alguno','averno lleno','frente va','con solo','Cordero digno','al gran','al que','de la','gloria Dios','la voz','le reveló','nuestro Dios','secos eran','se levantó','su Siervo','todo ser','tu Señor','sí alabad','si alabad','a la','Dios es']
report=[]
for r in rows:
 if r['index']==19:continue
 p=Path(r['work']);file=p/'corrected.musicxml' if (p/'corrected.musicxml').exists() else p/'source.musicxml';root=E.parse(file).getroot();edits=[]
 for pi,part in enumerate(root.findall('part')):
  for number in sorted({l.get('number','1') for l in part.findall('.//lyric') if l.find('text') is not None}):
   atoms=atoms_for(part,number)
   for i in range(len(atoms)):
    for phrase in phrases:
     wanted=[norm(w) for w in phrase.split()];groups=[];start=i;okay=True
     for word in wanted:
      value='';end=start
      while end<len(atoms) and len(value)<len(word):value+=atoms[end]['key'];end+=1
      if value!=word:okay=False;break
      groups.append(atoms[start:end]);start=end
     if not okay:continue
     # Keep references to the whole printed lyric when a sinalefa joins
     # the ending of one word and the beginning of the next on one note.
     flags=collections.defaultdict(list)
     for group in groups:
      ls=[]
      for a in group:
       if not ls or ls[-1] is not a['lyric']:ls.append(a['lyric'])
      for j,l in enumerate(ls):flags[l].append((j>0,j<len(ls)-1))
     touched={a['lyric'] for g in groups for a in g}
     for ly,ff in flags.items():
      # A phrase may start/end in a lyric that also holds another word.
      # Preserve that outside word's continuation flags.
      before=ff[0][0];after=ff[-1][1]
      idxs=[j for j,a in enumerate(atoms) if a['lyric'] is ly]
      if idxs[0]<i:before=ly.findtext('syllabic','single') in ['middle','end']
      if idxs[-1]>=start:after=ly.findtext('syllabic','single') in ['middle','begin']
      value='middle' if before and after else 'end' if before else 'begin' if after else 'single'
      old=ly.find('syllabic')
      if old is None:old=E.SubElement(ly,'syllabic')
      if old.text!=value:edits.append(dict(part=pi,bar=groups[0][0]['bar'],phrase=phrase,text=ly.findtext('text'),before=old.text,after=value));old.text=value
 if edits:
  E.ElementTree(root).write(p/'corrected.musicxml',encoding='utf-8',xml_declaration=True);r['changed']=True
  report.append(dict(index=r['index'],edits=edits));print(r['index'],len(edits),sorted(set(e['phrase'] for e in edits)))
(OUT/'word-boundary-corrections.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
(OUT/'inventory.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
