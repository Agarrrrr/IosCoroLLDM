from pathlib import Path
import json,collections
OUT=Path('output/verovio_pilot_support/alabad')
def read(prefix='alabad',max_dy=25,source_file='pdf-reading.json'):
    data=json.loads((OUT/source_file).read_text(encoding='utf-8'))
    notes=[e for e in data['events'] if not e['rest']]
    for role in range(4):
        voice=sorted([n for n in notes if n['role']==role],key=lambda n:(n['measure'],n['onset']))
        for i,n in enumerate(voice):n['id']=f'{prefix}-{role}-{i}';n['voiceIndex']=i
    arcs=[];partial=[];seen=set()
    for arc in data['arcs']:
        pair=[]
        for x,y in [arc['start'],arc['end']]:
            candidates=[n for n in notes if n['page']==arc['page']]
            n=min(candidates,key=lambda n:abs(n['x']+3.3-x)+abs(n['y']-y)*.5)
            pair.append(dict(id=n['id'],dx=abs(n['x']+3.3-x),dy=abs(n['y']-y),note=n))
        a,b=pair;na,nb=a['note'],b['note']
        valid=na['role']==nb['role'] and na['staff']==nb['staff'] and na['voiceIndex']<nb['voiceIndex'] and max(a['dx'],b['dx'])<10 and max(a['dy'],b['dy'])<max_dy
        if not valid:
            partial.append(dict(page=arc['page'],start={k:v for k,v in a.items() if k!='note'},end={k:v for k,v in b.items() if k!='note'},geometry=arc));continue
        key=(na['id'],nb['id'])
        if key in seen:continue
        seen.add(key)
        same=(na['diatonic'],na['alter'])==(nb['diatonic'],nb['alter'])
        contiguous=nb['voiceIndex']==na['voiceIndex']+1
        fresh=bool(nb['lyrics'])
        kind='tie' if same and contiguous and not fresh else 'slur'
        arcs.append(dict(start=na['id'],end=nb['id'],kind=kind,role=na['role'],measure=na['measure'],toMeasure=nb['measure']))
    result=dict(notes=notes,arcs=arcs,partial=partial)
    (OUT/'arcs-reading.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print('arcs',len(arcs),collections.Counter(a['kind'] for a in arcs),'partial',len(partial))
    print(json.dumps(partial[:8],ensure_ascii=False))
    return result
if __name__=='__main__':read()
