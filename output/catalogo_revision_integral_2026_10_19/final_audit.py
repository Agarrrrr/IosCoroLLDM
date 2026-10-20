from pathlib import Path
import json,xml.etree.ElementTree as E,zipfile,hashlib,collections,sys
from fractions import Fraction as F
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
sys.path.insert(0,'output/cantico_144_mil')
from midi_reader import read
OUT=Path(__file__).resolve().parent
rows=json.loads((OUT/'inventory.json').read_text(encoding='utf8'))
def norm(s):return s.replace('\ue550','‿').replace('\ue551','‿').replace('\ue552','‿')
def events(root):return [[(b,round(float(e['onset']),4),round(float(e['duration']),4),e['pitch'],tuple(t.get('type') for t in e['node'].findall('tie'))) for b,m in enumerate(p,1) for e in m['events'] if e['pitch'] is not None] for p in parse(root)]
def lyrics(root,markers=False):
 result=[]
 for pi,p in enumerate(parse(root)):
  for b,m in enumerate(p,1):
   for e in m['events']:
    for l in e['node'].findall('lyric'):
     value=norm(''.join(t.text or '' for t in l.findall('text')))
     if value:result.append((pi,b,round(float(e['onset']),4),int(l.get('number','1')),value,l.findtext('syllabic','single') if markers else ''))
 return sorted(result)
report=[];manifest=[]
for r in rows:
 p=Path(r['work']);changed=r.get('changed',False);issues=[]
 expected=E.parse(p/('corrected.musicxml' if changed else 'source.musicxml')).getroot()
 file=p/('final.mscz' if changed else 'original.mscz')
 with zipfile.ZipFile(file) as z:
  assert z.testzip() is None
  native=E.fromstring(z.read(next(n for n in z.namelist() if n.endswith('.mscx'))))
  staves=len(native.find('Score').findall('Staff'))
 if staves!=(5 if r['index'] in [6,10] else 4):issues.append('Staff count')
 if changed:
  actual=E.parse(p/'reopened.musicxml').getroot()
  if events(expected)!=events(actual):issues.append('Notes, timing, or ties changed when reopened')
  if lyrics(expected,True)!=lyrics(actual,True):issues.append('Lyric text, position, or syllabic markers changed when reopened')
  def dyn(x):return collections.Counter(c.tag for d in x.findall('.//dynamics') for c in d)
  if dyn(expected)!=dyn(actual):issues.append('Dynamics changed when reopened')
  midi=read(p/'playback.mid');tracks=[t for t in midi['tracks'] if t['notes']]
  if len(tracks)!=staves:issues.append('MIDI staff count')
  if r.get('structural'):
   for pi,(part,track) in enumerate(zip(parse(actual),tracks)):
    intended=sorted((round(float(e['absolute']),3),e['pitch']) for m in part for e in m['events'] if e['pitch'] is not None and not any(t.get('type')=='stop' for t in e['node'].findall('tie')))
    heard=sorted((round(n['onset'],3),n['pitch']) for n in track['notes'])
    if len(intended)!=len(heard) or any(x[1]!=y[1] or abs(x[0]-y[0])>.025 for x,y in zip(intended,heard)):issues.append(['MIDI notes/timing',pi,len(intended),len(heard)])
  sha=hashlib.sha256(file.read_bytes()).hexdigest()
  manifest.append(dict(index=r['index'],source=str(file.resolve()),destination=r['destination'],originalHash=r['originalHash'],sha256=sha))
 if r['index']==27:
  assert len(expected.findall('part')[0].findall('measure'))==96
  assert not any('samuel' in s.casefold() for s in expected.itertext())
  assert all(sum(1 for l in part.findall('.//lyric/text') if 'són' in (l.text or ''))>=6 for part in expected.findall('part'))
 markers=collections.Counter(l.findtext('syllabic','single') for l in expected.findall('.//lyric') if l.find('text') is not None)
 if not markers['begin']:issues.append('No syllabic hyphen markers')
 record=dict(index=r['index'],name=r['name'],changed=changed,staves=staves,bars=len(expected.findall('part')[0].findall('measure')),lyrics=len(lyrics(expected)),markers=dict(markers),issues=issues)
 report.append(record);print(r['index'],'PASS' if not issues else 'FAIL',issues)
(OUT/'final-all41-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
assert all(not x['issues'] for x in report),'Unresolved validation issues'
(OUT/'delivery-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
print('VERIFIED',len(rows),'scores;',len(manifest),'corrected files ready for delivery')
