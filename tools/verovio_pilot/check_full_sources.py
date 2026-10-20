from inspect_sources import *
for key,path in source_files()+[('guerrero-celestial',SOURCE/'Guerrero Celestial.musicxml')]:
    root=ET.parse(path).getroot();events=xml_events(root);midi=json.loads((OUT/(key+'-midi.json')).read_text())
    missing=[];ambiguous=[];matched=0;unisons=0
    for e in events:
        q=e['onset']
        if key=='acercame' and e['measure']>=25:q+=196
        possible=[]
        for ti,t in enumerate(midi['tracks']):
            if (ti//2 if key=='acercame' else ti)!=e['part']:continue
            for ni,n in enumerate(t['notes']):
                tick=round(q*midi['ppq'])
                if n['pitch']==e['pitch'] and (n['ticks']==tick or (e['element'].find("tie[@type='stop']") is not None and n['ticks']<tick<n['ticks']+n['duration']+2)):
                    possible.append((ti,ni))
        if not possible:missing.append({k:v for k,v in e.items() if k!='element'})
        elif len(possible)>1:ambiguous.append({k:v for k,v in e.items() if k!='element'}|{'candidates':possible})
        else:matched+=1
    print(key,'events',len(events),'match',matched,'missing',len(missing),'ambiguous',len(ambiguous))
    print('missing sample',missing[:8],'ambiguous sample',ambiguous[:5])
    (OUT/(key+'-full-mismatch.json')).write_text(json.dumps({'missing':missing,'ambiguous':ambiguous},indent=2),encoding='utf-8')
