from pathlib import Path
import json,sys,xml.etree.ElementTree as E,collections,hashlib,zipfile
from score_model import parse
from validate_batch import data
sys.path.insert(0,str(Path('output/cantico_144_mil').resolve()))
from midi_reader import read
OUT=Path('output/underlay_revision_2026_10_19');rows=json.loads((OUT/'corrections.json').read_text(encoding='utf-8'));report=[]
def pitches(root):return [[(m['index'],str(e['onset']),str(e['duration']),e['pitch'],tuple(t.get('type') for t in e['node'].findall('tie'))) for m in p for e in m['events'] if e['pitch'] is not None] for p in parse(root)]
def dyn(root):return collections.Counter(c.tag for d in root.findall('.//dynamics') for c in d)
def norm(s):return s.replace('\ue550','‿').replace('\ue551','‿').replace('\ue552','‿')
for i,r in enumerate(rows,1):
 if r.get('skip'):
  report.append(dict(name=r['name'],changes=0,issues=[],unchanged=True));print(i,'UNCHANGED',r['name'],flush=True);continue
 w=Path(r['work']);expected=E.parse(w/'corrected.musicxml').getroot();before=E.parse(w/'before.musicxml').getroot();after=E.parse(w/'reopened.musicxml').getroot();issues=[]
 if i not in [3,4] and pitches(expected)!=pitches(before):issues.append('Unintended source note edit')
 if i==4:
  orig=pitches(before);new=pitches(expected)
  assert sorted(x for p in orig for x in p)==sorted(x for p in new for x in p),'Unexpected note change during tenor/bass routing repair'
  assert orig[:2]==new[:2]
 if i==3:
  orig=pitches(before);new=pitches(expected)
  assert len(new[1])==len(orig[1])+2
  assert all(orig[pi]==new[pi] for pi in [0,2,3])
 if dyn(expected)!=dyn(before) or dyn(after)!=dyn(expected):issues.append('Dynamics changed')
 aa=data(expected);bb=data(after)
 for pi,(a,b) in enumerate(zip(aa,bb)):
  if len(a)!=len(b):issues.append(['note count',pi,len(a),len(b)]);continue
  wrong=[]
  for x,y in zip(a,b):
   x['lyric']=x['lyric'].replace('‿','');y['lyric']=y['lyric'].replace('‿','')
   if any(x[k]!=y[k] for k in ['bar','pitch','lyric','ties']) or abs(x['onset']-y['onset'])>.012 or abs(x['duration']-y['duration'])>.012:wrong.append([x,y])
  if wrong:issues.append(['reopen',pi,len(wrong),wrong[:2]])
 midi=read(w/'playback.mid');tracks=[t for t in midi['tracks'] if t['notes']]
 parts=parse(after)
 if len(parts)!=4 or len(tracks)!=4:issues.append('Staff/track count')
 originalMidi=read(w/'actual-before.mid') if r.get('nativePatch') and (w/'actual-before.mid').exists() else None
 if originalMidi:
  # Existing playback repeats are preserved; compare to the saved native file.
  originalTracks=[t for t in originalMidi['tracks'] if t['notes']]
  if [t['notes'] for t in originalTracks]!=[t['notes'] for t in tracks] or midi['tempos']!=originalMidi['tempos']:issues.append('Native playback changed')
 for pi,(p,t) in enumerate(zip(parts,tracks)):
  if originalMidi:continue
  target=sorted((float(e['absolute']),e['pitch']) for m in p for e in m['events'] if e['pitch'] is not None and not any(x.get('type')=='stop' for x in e['node'].findall('tie')))
  actual=[(n['onset'],n['pitch']) for n in t['notes']]
  if len(target)!=len(actual):issues.append(['MIDI attacks',pi,len(target),len(actual)]);continue
  bad=[(x,y) for x,y in zip(target,actual) if x[1]!=y[1] or abs(x[0]-y[0])>.025]
  if bad:issues.append(['MIDI pitch/time',pi,len(bad),bad[:2]])
 final=w/(r['name']+'.mscz')
 with zipfile.ZipFile(final) as z:assert z.testzip() is None
 summary=dict(name=r['name'],changes=len(r['edits']),issues=issues,sha256=hashlib.sha256(final.read_bytes()).hexdigest());report.append(summary)
 print(i,'PASS' if not issues else 'FAIL',r['name'],str(issues)[:1000],flush=True)
(OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
