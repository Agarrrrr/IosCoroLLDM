import json
from fractions import Fraction as F
from moradas_pdf import OUT,LAYOUT
SPLITS={(2,43):[2]}
def plan():return [dict(number=m,source=m,passage=1,start=(m-1)*4,duration=4,meter=4,unit=4) for m in range(1,92)]
def run():
    midi=json.loads((OUT/'midi-reading.json').read_text());events=[]
    for role,t in enumerate(midi['tracks']):
        for ni,n in enumerate(t['notes']):
            if n['duration']==0:continue
            raw=F(n['ticks'],midi['ppq'])
            if role>0 and raw<195:continue
            if role==4 and raw in [365,366]:continue
            start=raw-(96 if raw<292 else 92);left=F(3) if role==4 and raw==364 else F(n['duration']+1,midi['ppq']);cursor=start;segments=[]
            assert start>=0
            while left:
                measure=int(cursor//4)+1;local=cursor%4;d=min(left,4-local)
                for cut in SPLITS.get((role,measure),[]):
                    if local<F(cut)<local+d:d=F(cut)-local
                if d not in [F(1,4),F(1,2),F(3,4),F(1),F(3,2),F(2),F(3),F(4)]:d=max(v for v in [F(1,4),F(1,2),F(1),F(3,2),F(2),F(3),F(4)] if v<=d)
                segments.append(dict(id=f'moradas-{role}-{ni}-{len(segments)}',role=role,sourceAttack=ni,bar=measure,measure=measure,passage=1,onset=float(local),absolute=float(cursor),duration=float(d),pitch=73 if role==1 and measure==89 and local==3 else n['pitch'],tieStart=d<left,tieStop=cursor>start));cursor+=d;left-=d
            events+=segments
        for b in plan():
            row=sorted([e for e in events if e['role']==role and e['measure']==b['source']],key=lambda e:(e['onset'],e['pitch']));q=F(0)
            for e in row+[dict(onset=4,duration=0)]:
                at=F(e['onset'])
                while q<at:
                    d=max(v for v in [F(1,4),F(1,2),F(1),F(3,2),F(2),F(3),F(4)] if v<=at-q and q%v==0);events.append(dict(id=f"moradas-rest-{role}-{b['number']}-{q}",role=role,bar=b['number'],measure=b['source'],passage=1,onset=float(q),absolute=b['start']+float(q),duration=float(d),rest=True));q+=d
                q=max(q,at+F(e['duration']))
    (OUT/'source-events.json').write_text(json.dumps(events,indent=2));print('notes',sum(not e.get('rest') for e in events))
if __name__=='__main__':run()
