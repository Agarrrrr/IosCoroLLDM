from inspect_sources import *
base=OUT/'complete'
midi=json.loads(subprocess.run(['node','-e',NODE,str(base/'app-sample.mid')],check=True,capture_output=True,text=True).stdout)
(base/'app-sample-midi.json').write_text(json.dumps(midi),encoding='utf-8')
r=ET.parse(base/'app-sample-omr.musicxml').getroot();events=xml_events(r)
missing=[];hits=0
for e in events:
    roles=[0] if e['part']==0 else ([0,1] if e['measure']<8 else [1]) if e['part']==1 else [2,3]
    choices=[(ti,ni) for ti in roles for ni,n in enumerate(midi['tracks'][ti]['notes']) if abs(n['ticks']/midi['ppq']-e['onset'])<.02 and n['pitch']==e['pitch']]
    if not choices:missing.append({k:v for k,v in e.items() if k!='element'})
    else:hits+=1
print('matched',hits,'missing',len(missing));print(missing[:30]);print('tempos',midi['tempos'])
for ti,t in enumerate(midi['tracks']):
    print('VOICE',ti)
    for measure in range(16):
        print(measure+1,[(n['ticks']/midi['ppq']-4*measure,n['pitch'],n['duration']/midi['ppq']) for n in t['notes'] if measure*4<=n['ticks']/midi['ppq']<(measure+1)*4])
