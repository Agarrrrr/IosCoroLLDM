from pathlib import Path
import json,sys,xml.etree.ElementTree as E,collections,hashlib,zipfile
sys.path.insert(0,'output/satb_lote_2026_10_19');from score_model import parse
sys.path.insert(0,'output/cantico_144_mil');from midi_reader import read
OUT=Path('output/salmo_135')
def lyric(n):return ''.join(t.text or '' for t in n.findall('lyric/text')).replace('\ue550','‿').replace('\ue551','‿').replace('\ue552','‿')
def signature(root):
 result=[]
 for part in parse(root):
  notes=[]
  for m in part:
   shared={e['onset']:lyric(e['node']) for e in m['events'] if lyric(e['node'])}
   for e in m['events']:
    if e['pitch'] is not None:notes.append((m['index'],float(e['onset']),float(e['duration']),e['pitch'],shared.get(e['onset'],''),sorted(t.get('type') for t in e['node'].findall('tie'))))
  result.append(sorted(notes,key=lambda x:(x[0],x[1],x[3])))
 return result
source=E.parse(OUT/'Salmo 135 - SATB - Cantai.musicxml').getroot();again=E.parse(OUT/'reopened.musicxml').getroot();a=signature(source);b=signature(again);assert a==b,'A note, rhythm, lyric or tie changed while reopening'
assert len(a)==4 and all(len(p.findall('measure'))==45 for p in again.findall('part'))
assert len(again.findall('.//pitch'))==752
assert len(source.findall('.//slur'))==len(again.findall('.//slur'))==92
assert len(source.findall('.//tied'))==len(again.findall('.//tied'))==2
assert not again.findall('.//dynamics')
midi=read(OUT/'playback.mid');assert midi['tempos']==[[0.0,90.00009000009]] or abs(midi['tempos'][0][1]-90)<.001
tracks=[t for t in midi['tracks'] if t['notes']];assert len(tracks)==4
for part,track in zip(parse(again),tracks):
 expected=sorted((float(e['absolute']),e['pitch']) for m in part for e in m['events'] if e['pitch'] is not None and not any(t.get('type')=='stop' for t in e['node'].findall('tie')))
 actual=[(n['onset'],n['pitch']) for n in track['notes']];assert expected==actual,'MIDI pitch or rhythm mismatch'
p=OUT/'Salmo 135 - SATB - Cantai.mscz'
with zipfile.ZipFile(p) as z:assert z.testzip() is None
report=dict(staves=4,bars=45,notes=752,lyrics=len(again.findall('.//lyric/text')),slurs=46,ties=1,tempo=90,reopened=True,midiVerified=True,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
(OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False))
