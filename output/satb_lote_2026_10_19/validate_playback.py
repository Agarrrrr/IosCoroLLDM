import json,sys,xml.etree.ElementTree as E
from pathlib import Path
from inventory import OUT
from score_model import parse
sys.path.insert(0,str(Path('output/cantico_144_mil').resolve()))
from midi_reader import read

report=[]
for row in json.loads((OUT/'prepared-index.json').read_text(encoding='utf-8')):
    w=OUT/f"{row['index']:02d}"
    parts=parse(E.parse(w/'reopened.musicxml').getroot())
    tracks=[t for t in read(w/'playback.mid')['tracks'] if t['notes']]
    issues=[]
    if len(parts)!=len(tracks):issues.append(['track count',len(parts),len(tracks)])
    for pi,(part,track) in enumerate(zip(parts,tracks)):
        expected=sorted([(float(e['absolute']),e['pitch']) for m in part for e in m['events'] if e['pitch'] is not None and not any(t.get('type')=='stop' for t in e['node'].findall('tie'))])
        actual=[(n['onset'],n['pitch']) for n in track['notes']]
        if len(expected)!=len(actual):issues.append(['attacks',pi,len(expected),len(actual)])
        else:
            wrong=[(a,b) for a,b in zip(expected,actual) if a[1]!=b[1] or abs(a[0]-b[0])>.025]
            if wrong:issues.append(['pitch/time',pi,len(wrong),wrong[:3]])
    report.append(dict(index=row['index'],issues=issues))
    print(row['index'],'PASS' if not issues else issues,flush=True)
(OUT/'playback-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
