import json
from moises_model import OUT
def run():
    es=json.loads((OUT/'positioned-events.json').read_text());ex=json.loads((OUT/'expressions-reading.json').read_text());byid={e['id']:e for e in es}
    for role,ma,oa,mb,ob in [(3,56,0,59,0),(2,60,0,62,0),(3,60,0,62,0),(2,90,2,91,0),(2,96,0,97,0),(3,99,0,100,0),(2,101,0,102,0)]:
        a=next(e for e in es if e['role']==role and e['measure']==ma and e['onset']==oa and e['passage']==1)
        b=next(e for e in es if e['role']==role and e['measure']==mb and e['onset']==ob and e['passage']==1)
        ex['arcs'].append(dict(start=a['id'],end=b['id'],role=role,measure=ma,onset=oa,toMeasure=mb,toOnset=ob,kind='slur',manualBoundary=True))
    ex['arcs']=list({(a['start'],a['end']):a for a in ex['arcs']}.values())
    for arc in ex['arcs']:
        if arc['role']==3 and arc['measure']==95 and arc['onset']==2.5 and arc['toOnset']==3:
            # Printed F# tie passes over an intervening E sixteenth. The
            # reference MIDI confirms F# sustains while E sounds underneath.
            arc['kind']='tie';arc['interveningOrnament']=True
        if arc['kind']!='tie':continue
        a=byid[arc['start']];b=byid[arc['end']]
        assert a['pitch']==b['pitch'] and (abs(a['absolute']+a['duration']-b['absolute'])<.001 or arc.get('interveningOrnament'))
        for passage in ([1,2] if a['measure']<=4 else [1]):
            aa=next(e for e in es if e['role']==a['role'] and e['measure']==a['measure'] and e['onset']==a['onset'] and e['passage']==passage and e.get('pitch')==a['pitch'])
            bb=next(e for e in es if e['role']==b['role'] and e['measure']==b['measure'] and e['onset']==b['onset'] and e['passage']==passage and e.get('pitch')==b['pitch'])
            aa['tieStart']=True;bb['tieStop']=True
    (OUT/'positioned-events.json').write_text(json.dumps(es,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'expressions-reading.json').write_text(json.dumps(ex,ensure_ascii=False,indent=2),encoding='utf-8')
    print('sound ties',sum(e.get('tieStop',False) for e in es))
if __name__=='__main__':run()
