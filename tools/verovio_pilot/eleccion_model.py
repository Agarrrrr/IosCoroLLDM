import json
from pathlib import Path
from fractions import Fraction as F
OUT=Path('output/verovio_pilot_support/eleccion_apostolica')
LAYOUT=[[(m,[0,1,2,3]) for m in row] for row in [[1,11,20],[28,37,45],[53,59,64],[67,70,73],[76,80,83],[86,90,93]]]
def plan():
    seq=[(m,1) for m in range(1,86)]+[(m,2) for m in range(78,85)]+[(m,2) for m in range(86,100)];bars=[];q=0
    for i,(m,passage) in enumerate(seq):
        beats,unit=(2,4) if m<48 else (4,4) if m<86 or m>=97 else (6,8);d=beats*4/unit
        bars.append(dict(number=i+1,source=m,passage=passage,start=q,duration=d,meter=beats,unit=unit));q+=d
    assert q==319 and len(bars)==106
    return bars
SPLITS={(r,54):[2] for r in range(4)}
SPLITS.update({(r,78):[2.5] for r in [0,1]})
def run():
    midi=json.loads((OUT/'midi-reading.json').read_text());events=[];bars=plan()
    for role,t in enumerate(midi['tracks']):
        for ni,n in enumerate(t['notes']):
            gate=1 if n['duration']==479 else .95
            start=F(n['ticks'],480);duration=F(round((n['duration']+1)/480/gate*4),4)
            assert abs(float(duration)-(n['duration']+1)/480/gate)<.03,(role,n)
            cursor=start;left=duration;segments=[]
            while left:
                b=next(b for b in bars if b['start']<=float(cursor)<b['start']+b['duration']);local=cursor-F(b['start']);d=min(left,F(b['duration'])-local)
                for cut in SPLITS.get((role,b['source']),[]):
                    if local<F(cut)<local+d:d=F(cut)-local
                if d not in [F(1,4),F(1,2),F(3,4),F(1),F(3,2),F(2),F(3),F(4),F(6)]:d=F(3,2) if d==F(5,2) else max(v for v in [F(1,4),F(1,2),F(1),F(3,2),F(2),F(3),F(4)] if v<=d)
                segments.append(dict(id=f'eleccion-{role}-{ni}-{len(segments)}',role=role,sourceAttack=ni,bar=b['number'],measure=b['source'],passage=b['passage'],onset=float(local),absolute=float(cursor),duration=float(d),pitch=n['pitch'],tieStart=d<left,tieStop=cursor>start));cursor+=d;left-=d
            events+=segments
        for b in bars:
            row=sorted([e for e in events if e['role']==role and e['bar']==b['number']],key=lambda e:(e['onset'],e['pitch']));q=F(0)
            for e in row+[dict(onset=b['duration'],duration=0)]:
                at=F(e['onset'])
                if at>q:
                    left=at-q
                    while left:
                        d=max(v for v in [F(1,4),F(1,2),F(1),F(3,2),F(2),F(3),F(4)] if v<=left and (q%v==0 or v==left))
                        events.append(dict(id=f"eleccion-rest-{role}-{b['number']}-{q}",role=role,bar=b['number'],measure=b['source'],passage=b['passage'],onset=float(q),absolute=b['start']+float(q),duration=float(d),rest=True));q+=d;left-=d
                q=max(q,at+F(e['duration']))
    # The repeated female text changes "fe" to the two syllables "ha-lla".
    # Keep the same written pitches, with phrase slurs and two sung attacks.
    for e in events:
        if e['role']<2 and e['measure']==78 and e['passage']==2:
            if e['onset']==2:e['tieStart']=False
            if e['onset']==2.5:e['tieStop']=False
    (OUT/'source-events.json').write_text(json.dumps(events,indent=2),encoding='utf-8');print('bars',len(bars),'notes',sum(not e.get('rest') for e in events))
if __name__=='__main__':run()
