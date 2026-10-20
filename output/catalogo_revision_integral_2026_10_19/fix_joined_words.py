from pathlib import Path
import json,xml.etree.ElementTree as E,re,collections
from syllable_audit import OUT,atoms_for,norm
rows=json.loads((OUT/'inventory.json').read_text(encoding='utf8'))
phrases=['temor alguno','averno lleno','frente va','con solo','Cordero digno','al gran','al que','de la','gloria Dios','la voz','le reveló','nuestro Dios','secos eran','se levantó','su Siervo','todo ser','tu Señor','sí alabad','a la']
corrections={norm(p):p for p in phrases};report=[]
def apply(group,phrase):
 # A correction applies only to a COMPLETE existing word chain. Matching
 # partial syllables inside valid words such as a-la-bad is prohibited.
 words=phrase.split();boundaries=[];size=0
 for word in words[:-1]:size+=len(norm(word));boundaries.append(size)
 position=0;edits=[]
 for lyric in group:
  text=lyric.findtext('text','');letters=[j for j,c in enumerate(text) if norm(c)]
  start=position;end=position+len(letters);before=next((b for b in boundaries if b>=start),None)
  # Native begin/middle/end refer to the word at this note's edges.
  wordstart=max([0]+[b for b in boundaries if b<=start]);wordend=min([len(norm(phrase))]+[b for b in boundaries if b>=end])
  continues_before=start>wordstart;continues_after=end<wordend
  kind='middle' if continues_before and continues_after else 'end' if continues_before else 'begin' if continues_after else 'single'
  old=lyric.find('syllabic')
  if old is None:old=E.SubElement(lyric,'syllabic')
  if old.text!=kind:edits.append((text,old.text,kind));old.text=kind
  inside=[b-start for b in boundaries if start<b<end]
  if inside:
   # Space between two complete words sharing one musical attack.
   for offset in sorted(inside,reverse=True):
    at=letters[offset];text=text[:at].rstrip('- ')+ ' '+text[at:]
   lyric.find('text').text=text;edits.append(('text',text))
  position=end
 return edits
for r in rows:
 if r['index']==19:continue
 p=Path(r['work']);f=p/'corrected.musicxml' if r.get('changed') else p/'source.musicxml';root=E.parse(f).getroot();edits=[]
 for pi,part in enumerate(root.findall('part')):
  for number in sorted({l.get('number','1') for l in part.findall('.//lyric') if l.find('text') is not None}):
   atoms=atoms_for(part,number);lyrics=[]
   for a in atoms:
    if not lyrics or lyrics[-1][0] is not a['lyric']:lyrics.append((a['lyric'],a['bar']))
   group=[]
   def flush():
    if not group:return
    raw=''.join(l.findtext('text','') for l,_ in group)
    # Already explicit spaces/elisions separate words on a single note.
    if any(c in raw for c in '_‿\ue550\ue551\ue552 '):return
    phrase=corrections.get(norm(raw))
    if phrase:
     changes=apply([l for l,_ in group],phrase)
     if changes:edits.append(dict(part=pi,bar=group[0][1],phrase=phrase,changes=changes))
   for ly,bar in lyrics:
    kind=ly.findtext('syllabic','single')
    if kind in ['begin','single']:flush();group=[]
    group.append((ly,bar))
    if kind in ['end','single']:flush();group=[]
   flush()
 if edits:
  E.ElementTree(root).write(p/'corrected.musicxml',encoding='utf-8',xml_declaration=True);r['changed']=True
  report.append(dict(index=r['index'],edits=edits));print(r['index'],len(edits),sorted(set(x['phrase'] for x in edits)))
(OUT/'joined-word-corrections.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
(OUT/'inventory.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
