from pathlib import Path
import json,sys,collections,xml.etree.ElementTree as E,zipfile,hashlib
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
sys.path.insert(0,'output/cantico_144_mil')
from midi_reader import read
OUT=Path(__file__).resolve().parent;STEM='La Vida Se Va Como El Viento - Israel Gómez Morales - SATB - Cantai'
expected=E.parse(OUT/'final.musicxml').getroot();actual=E.parse(OUT/'reopened.musicxml').getroot();issues=[]
def norm(s):return s.replace('\ue550','‿').replace('\ue551','‿').replace('\ue552','‿')
def events(root):
 return [[(i,round(float(e['onset']),4),round(float(e['duration']),4),e['pitch'],tuple(t.get('type') for t in e['node'].findall('tie'))) for i,m in enumerate(p,1) for e in m['events'] if e['pitch'] is not None] for p in parse(root)]
def lyrics(root):
 result=[]
 for pi,p in enumerate(parse(root)):
  for i,m in enumerate(p,1):
   for e in m['events']:
    for l in e['node'].findall('lyric'):
     value=norm(''.join(t.text or '' for t in l.findall('text')))
     if value:result.append((pi,i,round(float(e['onset']),4),value,l.findtext('syllabic','single')))
 return sorted(result)
if events(expected)!=events(actual):issues.append('Written note events differ after reopening')
if lyrics(expected)!=lyrics(actual):
 a=collections.Counter(lyrics(expected));b=collections.Counter(lyrics(actual));issues.append(dict(lyricMissing=list((a-b).elements())[:8],lyricExtra=list((b-a).elements())[:8]))
def dynamics(root):return collections.Counter(c.tag for d in root.findall('.//dynamics') for c in d)
if dynamics(expected)!=dynamics(actual):issues.append('Dynamics differ')
if len(actual.findall('part'))!=4 or any(len(p.findall('measure'))!=105 for p in actual.findall('part')):issues.append('SATB staff/bar count')
played=read(OUT/'playback.mid');tracks=[t for t in played['tracks'] if t['notes']];comparison=[]
if len(tracks)!=4:issues.append('Playback track count')
for pi,(part,track) in enumerate(zip(parse(expected),tracks)):
 a=sorted((float(e['absolute']),e['pitch']) for m in part for e in m['events'] if e['pitch'] is not None and not e['node'].findall('tie[@type="stop"]'))
 b=sorted((n['onset'],n['pitch']) for n in track['notes'])
 wrong=[(x,y) for x,y in zip(a,b) if x[1]!=y[1] or abs(x[0]-y[0])>.025]
 if len(a)!=len(b) or wrong:issues.append(dict(role=pi,expectedAttacks=len(a),actualAttacks=len(b),mismatch=wrong[:3]))
 comparison.append(dict(role=pi,expectedAttacks=len(a),actualAttacks=len(b),exactPitchAndAttackMatch=not wrong and len(a)==len(b)))
with zipfile.ZipFile(OUT/(STEM+'.mscz')) as z:
 assert z.testzip() is None
 native=E.fromstring(z.read(next(n for n in z.namelist() if n.endswith('.mscx'))))
 assert len(native.find('Score').findall('Staff'))==4
assert sum(1 for l in actual.findall('.//lyric') if l.findtext('syllabic')=='begin')>200
report=dict(title='La Vida Se Va Como El Viento — Israel Gómez Morales',issues=issues,staves=4,bars=105,noteHeads=len(actual.findall('.//pitch')),lyricNotes=len(lyrics(actual)),slurs=len(actual.findall('.//slur[@type="start"]')),ties=len(actual.findall('.//tie[@type="start"]')),dynamics=dict(dynamics(actual)),midiComparison=comparison,sha256=hashlib.sha256((OUT/(STEM+'.mscz')).read_bytes()).hexdigest())
(OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8');print(json.dumps(report,ensure_ascii=False,indent=2));assert not issues
