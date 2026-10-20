from pathlib import Path
import json,subprocess,zipfile,xml.etree.ElementTree as E
from inspect_sources import NODE
OUT=Path('output/verovio_pilot_support/alabad')
midi=json.loads(subprocess.run(['node','-e',NODE,str(OUT/'original.mid')],check=True,capture_output=True,text=True,encoding='utf-8').stdout)
print('MIDI track activity only; not a pitch/rhythm authority')
(OUT/'midi-comparison.json').write_text(json.dumps(midi),encoding='utf-8')
for i,t in enumerate(midi['tracks']):
    ns=[n for n in t['notes'] if 51<=n['ticks']/midi['ppq']<96]
    print(i,t['name'],len(ns),'range', (min(n['pitch'] for n in ns),max(n['pitch'] for n in ns)) if ns else None)
    print('handover',[(n['ticks']/midi['ppq'],n['pitch'],n['duration']/midi['ppq']) for n in t['notes'] if 91<=n['ticks']/midi['ppq']<=100])
with zipfile.ZipFile(OUT/'omr/original.mxl') as z:
    name=next(n for n in z.namelist() if n.endswith('.xml') and not n.startswith('META-INF'))
    root=E.fromstring(z.read(name))
    for p in root.findall('part'):
        print('OMR part',p.get('id'),'notes18-32',sum(len(m.findall('note/pitch')) for m in p.findall('measure') if 18<=int(m.get('number'))<=32))
