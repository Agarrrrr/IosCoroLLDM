from pathlib import Path
import json,xml.etree.ElementTree as E,copy,zipfile
from fractions import Fraction as F
from score_model import parse
OUT=Path('output/underlay_revision_2026_10_19');rows=json.loads((OUT/'corrections.json').read_text(encoding='utf-8'));exports=json.loads((OUT/'current_exports.json').read_text(encoding='utf-8'))
def text(n):return ''.join(t.text or '' for t in n.findall('lyric/text'))
def native_text(n):
 t=n.find('Lyrics/text');return ''.join(t.itertext()) if t is not None else ''
def xml_map(root):
 parts=parse(root);result={}
 for pi,p in enumerate(parts):
  for mi,m in enumerate(p):
   for e,n in zip(m['events'],root.findall('part')[pi].findall('measure')[mi].findall('note')):
    e['node']=n
    if e['pitch'] is not None and n.find('chord') is None:result[(pi,mi+1,e['onset'])]=e
 return parts,result
def bare(n):
 return (n.tag,tuple(sorted(n.attrib.items())),(n.text or '').strip(),tuple(bare(c) for c in n if c.tag!='Lyrics'))
for i in [2,5,6,7]:
 r=rows[i-1];w=Path(r['work']);actual=Path(next(e['xml'] for e in exports if e['name']==r['name']));baseline=E.parse(actual).getroot();shutil=__import__('shutil');shutil.copy2(actual,w/'before.musicxml')
 desired=E.parse(w/'corrected.musicxml').getroot();_,want=xml_map(desired);parts,current=xml_map(baseline)
 with zipfile.ZipFile(w/'before.mscz') as z:
  native_name=next(n for n in z.namelist() if n.endswith('.mscx') and '/' not in n);native=E.fromstring(z.read(native_name));original=bare(native);bind={}
  for pi,staff in enumerate(native.findall('Score/Staff')):
   for mi,m in enumerate(staff.findall('Measure')):
    chords=[c for v in m.findall('voice') for c in v.findall('Chord')]
    events=[e for e in parts[pi][mi]['events'] if e['pitch'] is not None and e['node'].find('chord') is None]
    assert len(chords)==len(events),(i,pi,mi,len(chords),len(events))
    for chord,e in zip(chords,events):
     group=[a['pitch'] for a in parts[pi][mi]['events'] if a['onset']==e['onset'] and a['voice']==e['voice'] and a['pitch'] is not None]
     assert sorted(int(n.findtext('pitch')) for n in chord.findall('Note'))==sorted(group),(i,pi,mi)
     bind[(pi,mi+1,e['onset'])]=chord
  edits=[]
  for edit in r['edits']:
   key=(edit['role'],edit['bar'],F(edit['onset']));e=current[key];chord=bind[key]
   force=i==7 and edit['bar']==58 and F(edit['onset'])==1
   if text(e['node']) and not force:continue
   ly=copy.deepcopy(want[key]['node'].find('lyric'));assert ly is not None
   old=text(e['node'])
   for x in e['node'].findall('lyric'):e['node'].remove(x)
   e['node'].append(ly)
   # Inherit the local lyric font/size from this same voice.
   neighbors=[(abs(a['absolute']-e['absolute']),bind[k].find('Lyrics')) for k,a in current.items() if k[0]==key[0] and bind[k].find('Lyrics') is not None]
   template=copy.deepcopy(min(neighbors,key=lambda x:x[0])[1]) if neighbors else E.Element('Lyrics')
   for child in list(template):
    if child.tag in ['eid','syllabic','ticks_f','text']:template.remove(child)
   syll=ly.findtext('syllabic','single')
   if syll!='single':E.SubElement(template,'syllabic').text=syll
   E.SubElement(template,'text').text=text(e['node'])
   for x in chord.findall('Lyrics'):chord.remove(x)
   chord.insert(next((j for j,x in enumerate(chord) if x.tag in ['Note','Spanner']),len(chord)),template)
   # Shorten an old melisma only if it crosses one of the restored syllables.
   preceding=sorted([(a,k) for k,a in current.items() if k[0]==key[0] and a['absolute']<e['absolute']],key=lambda x:x[0]['absolute'])
   for previous,k in reversed(preceding):
    oldly=bind[k].find('Lyrics');span=oldly.find('ticks_f') if oldly is not None else None
    if span is None:continue
    if previous['absolute']+4*F(span.text)<e['absolute']:break
    blank=[a for a,kk in preceding if previous['absolute']<a['absolute']<e['absolute'] and not native_text(bind[kk])]
    length=(blank[-1]['absolute']-previous['absolute'])/4 if blank else F(0)
    if length:span.text=str(length)
    else:oldly.remove(span)
    break
   entry=copy.deepcopy(edit);entry['before']=old;edits.append(entry)
  assert bare(native)==original,'A native musical element changed'
  r['edits']=edits;r['skip']=not edits;r['nativePatch']=True
  E.ElementTree(baseline).write(w/'corrected.musicxml',encoding='utf-8',xml_declaration=True)
  if edits:
   with zipfile.ZipFile(w/(r['name']+'.mscz'),'w',zipfile.ZIP_DEFLATED) as out:
    for info in z.infolist():out.writestr(info,E.tostring(native,encoding='utf-8',xml_declaration=True) if info.filename==native_name else z.read(info.filename))
  print(i,'native lyric edits',len(edits),'all notes, expressions and style preserved')
(OUT/'corrections.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
