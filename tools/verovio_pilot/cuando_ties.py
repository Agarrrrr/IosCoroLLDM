import json
from cuando_model import OUT,plan
def run():
    es=json.loads((OUT/'positioned-events.json').read_text());ex=json.loads((OUT/'expressions-reading.json').read_text());byid={e['id']:e for e in es}
    baseline={e['id']:e for e in json.loads((OUT/'source-events.json').read_text())}
    for e in es:
        for flag in ['tieStart','tieStop']:e[flag]=baseline[e['id']].get(flag,False)
    def select(role,measure,onset,passage):return next(e for e in es if e['role']==role and e['measure']==measure and abs(e['onset']-onset)<.00001 and e['passage']==passage and not e.get('rest'))
    for arc in ex['arcs']:
        if arc['measure']==23 and arc['onset']==2 and arc['toOnset']==2.5:
            arc['kind']='tie';arc['referenceReattacksButPdfTies']=True;arc['tiePassages']=[1] if arc['role']<2 else [1,2,3];arc['slurPassages']=[2,3] if arc['role']<2 else []
        if arc['measure']==9 and arc['role'] in [2,3]:
            arc['tiePassages']=[1,3];arc['slurPassages']=[2]
            select(arc['role'],9,0,2)['tieStart']=False;select(arc['role'],9,1,2)['tieStop']=False
    for role in [0,1]:
        a=select(role,18,0,1);b=select(role,19,0,1)
        ex['arcs'].append(dict(start=a['id'],end=b['id'],role=role,measure=18,onset=0,toMeasure=19,toOnset=0,kind='slur',manualBoundary=True))
    ex['arcs']=list({(a['start'],a['end']):a for a in ex['arcs']}.values())
    for arc in ex['arcs']:
        if arc['kind']!='tie':continue
        a=byid[arc['start']];b=byid[arc['end']]
        assert a['pitch']==b['pitch'] and abs(a['absolute']+a['duration']-b['absolute'])<.001
        for passage in arc.get('tiePassages',[bb['passage'] for bb in plan() if bb['source']==a['measure']]):
            aa=select(a['role'],a['measure'],a['onset'],passage);bb=select(b['role'],b['measure'],b['onset'],passage);aa['tieStart']=True;bb['tieStop']=True
    (OUT/'positioned-events.json').write_text(json.dumps(es,indent=2),encoding='utf-8');(OUT/'expressions-reading.json').write_text(json.dumps(ex,indent=2),encoding='utf-8');print('ties',sum(e.get('tieStop',False) for e in es))
if __name__=='__main__':run()
