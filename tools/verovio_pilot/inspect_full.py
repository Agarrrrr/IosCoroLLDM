from inspect_sources import *
sources=source_files()+[('guerrero-celestial',SOURCE/'Guerrero Celestial.musicxml')]
for key,path in sources:
    midi=json.loads(subprocess.run(['node','-e',NODE,str(path.with_suffix('.mid'))],check=True,capture_output=True,text=True,encoding='utf-8').stdout)
    (OUT/(key+'-midi.json')).write_text(json.dumps(midi),encoding='utf-8')
    root=ET.parse(path).getroot();events=xml_events(root)
    print(key,'parts',len(root.findall('part')),'notes',len(events),'tracks',[(t['name'],len(t['notes'])) for t in midi['tracks']])
    for part in root.findall('part')[:1]:
        for i,measure in enumerate(part.findall('measure')):
            ev=[e for e in events if e['part']==0 and e['measure']==i]
            print(i+1,[(e['local'],e['pitch']) for e in ev])
