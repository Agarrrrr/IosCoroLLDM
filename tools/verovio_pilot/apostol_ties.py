import json,copy
from apostol_model import OUT
def run():
    es=json.loads((OUT/'positioned-events.json').read_text());ex=json.loads((OUT/'expressions-reading.json').read_text());byid={e['id']:e for e in es}
    # A tie carries the D# accidental into bar 75, even though the sharp is
    # not repeated there. The reference sustains D# over both whole notes.
    held=next(e for e in es if e['role']==2 and e['measure']==75 and e['onset']==0);held.update(pitch=63,alter=1)
    for arc in ex['arcs']:
        if arc['role']==2 and arc['measure']==74 and arc['toMeasure']==75:arc['kind']='tie';arc['carriedAccidental']=True
    for role in [0,1,2]:
        a=next(e for e in es if e['role']==role and e['measure']==72 and e['onset']==0)
        b=next(e for e in es if e['role']==role and e['measure']==73 and e['onset']==0)
        ex['arcs'].append(dict(start=a['id'],end=b['id'],role=role,measure=72,onset=0,toMeasure=73,toOnset=0,kind='tie',manualBoundary=True))
    for arc in list(ex['arcs']):
        if arc['role']==2 and 5<=arc['measure']<=14 and arc['toMeasure']<=14:
            a=next(e for e in es if e['role']==3 and e['measure']==arc['measure'] and e['onset']==arc['onset'])
            b=next(e for e in es if e['role']==3 and e['measure']==arc['toMeasure'] and e['onset']==arc['toOnset'])
            na=copy.deepcopy(arc);na.update(start=a['id'],end=b['id'],role=3);ex['arcs'].append(na)
    ex['arcs']=list({(a['start'],a['end']):a for a in ex['arcs']}.values())
    for arc in ex['arcs']:
        if arc['kind']!='tie':continue
        a=byid[arc['start']];b=byid[arc['end']]
        assert a['pitch']==b['pitch'] and abs(a['absolute']+a['duration']-b['absolute'])<.001,(arc,a,b)
        a['tieStart']=True;b['tieStop']=True
    ex['dynamics']=[a for a in ex['dynamics'] if not (a['role']==1 and 15<=a['measure']<=20)]
    ex['wedges']=[a for a in ex['wedges'] if not (a['role']==1 and 15<=a['measure']<=20) and a['measure']!=33]
    for role in range(4):ex['wedges'].append(dict(role=role,measure=32,onset=0,toMeasure=33,toOnset=2,kind='diminuendo'))
    ex['wedges']=list({tuple(a[k] for k in ['role','measure','onset','toMeasure','toOnset','kind']):a for a in ex['wedges']}.values())
    (OUT/'positioned-events.json').write_text(json.dumps(es,ensure_ascii=False,indent=2),encoding='utf-8');(OUT/'expressions-reading.json').write_text(json.dumps(ex,ensure_ascii=False,indent=2),encoding='utf-8');print('ties',sum(e.get('tieStop',False) for e in es),'arcs',len(ex['arcs']))
if __name__=='__main__':run()
