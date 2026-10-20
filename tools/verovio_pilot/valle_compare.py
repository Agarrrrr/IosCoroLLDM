from pathlib import Path
import collections,json,subprocess,xml.etree.ElementTree as E
from inspect_sources import NODE,xml_events
OUT=Path('output/verovio_pilot_support/valle')
source=next(Path('C:/Users/Huri_/Downloads/musescore').glob('D__*Huesos*musicxml'))
root=E.parse(source).getroot()
midi=json.loads(subprocess.run(['node','-e',NODE,str(OUT/'original-2.mid')],check=True,capture_output=True,text=True,encoding='utf-8').stdout)
(OUT/'midi.json').write_text(json.dumps(midi),encoding='utf-8')
print('MIDI',midi['ppq'],midi['tempos'])
for role,track in enumerate(midi['tracks']):
    events=[e for e in xml_events(root) if e['part']==role]
    expected=[e for e in events if e['element'].find("tie[@type='stop']") is None]
    print(role,track['name'],'MIDI notes',len(track['notes']),'XML attacks',len(expected))
    lookup=collections.defaultdict(list)
    for n in track['notes']:lookup[(round(n['ticks']/midi['ppq'],6),n['pitch'])].append(n)
    missing=[e for e in expected if (round(e['onset'],6),e['pitch']) not in lookup]
    print('missing at written time',len(missing),[{k:v for k,v in e.items() if k!='element'} for e in missing[:4]])
