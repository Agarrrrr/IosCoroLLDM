import json
from pathlib import Path
from fractions import Fraction as F
OUT=Path('output/verovio_pilot_support/como_la_aurora')
LAYOUT=[[(m,[0,2]) for m in row] for row in [[0,4,8,13,18],[22,27,31,35,39,43]]]
METERS={0:6,2:12,3:6,10:12,11:6,17:9,18:12,19:6,21:12,22:6,23:9,24:6,28:9,29:6,30:9,31:6,32:12,33:6,36:9,37:6,40:12,41:6,44:9,45:6}

def plan():
    seq=[(m,1) for m in range(31)]+[(m,2) for m in range(31,47)]+[(m,2) for m in range(18,31)]+[(m,3) for m in range(31,47)]+[(m,3) for m in range(18,31)]
    bars=[];q=F(0)
    for i,(source,passage) in enumerate(seq):
        meter=METERS[max(m for m in METERS if m<=source)];d=F(3,2) if source==0 else F(5,2) if i==len(seq)-1 else F(meter,2)
        bars.append(dict(number=i+1,source=source,passage=passage,start=float(q),duration=float(d),meter=meter));q+=d
    assert q==F(641,2) and len(bars)==89
    return bars

def run():
    midi=json.loads((OUT/'midi-reading.json').read_text());events=[];bars=plan()
    for role,t in enumerate(midi['tracks']):
        gate=.95 if role in [0,2] else 1
        for ni,n in enumerate(t['notes']):
            start=F(n['ticks'],480);duration=F(round((n['duration']+1)/480/gate*4),4)
            assert abs(float(duration)-(n['duration']+1)/480/gate)<.03,(role,n)
            cursor=start;left=duration;segments=[]
            while left:
                b=next(b for b in bars if b['start']<=float(cursor)<b['start']+b['duration'])
                local=cursor-F(b['start']);d=min(left,F(b['duration'])-local)
                cuts=[3] if b['source'] in [18,21] and role<2 else [F(3,2)] if b['source']==30 and role<2 or b['source']==29 and role==3 else []
                for cut in cuts:
                    if local<cut<local+d:d=cut-local
                segments.append(dict(id=f'aurora-{role}-{ni}-{len(segments)}',role=role,sourceAttack=ni,bar=b['number'],measure=b['source'],passage=b['passage'],onset=float(local),absolute=float(cursor),duration=float(d),pitch=n['pitch'],tieStart=d<left,tieStop=cursor>start));cursor+=d;left-=d
            events+=segments
        for b in bars:
            q=F(0)
            for e in sorted([e for e in events if e['role']==role and e['bar']==b['number']],key=lambda e:e['onset']):
                at=F(e['onset'])
                if at>q:
                    left=at-q
                    while left:
                        d=max(v for v in [F(1,4),F(1,2),F(1),F(3,2),F(2),F(3),F(4)] if v<=left and (q%v==0 or v==left))
                        events.append(dict(id=f"aurora-rest-{role}-{b['number']}-{q}",role=role,bar=b['number'],measure=b['source'],passage=b['passage'],onset=float(q),absolute=b['start']+float(q),duration=float(d),rest=True));q+=d;left-=d
                q=at+F(e['duration'])
            if q<b['duration']:events.append(dict(id=f"aurora-rest-{role}-{b['number']}-end",role=role,bar=b['number'],measure=b['source'],passage=b['passage'],onset=float(q),absolute=b['start']+float(q),duration=b['duration']-float(q),rest=True))
    # The reference MIDI reattacks the tenor's printed tie in source bar 29.
    for e in events:
        if e['role']==2 and e['measure']==29:
            if e['onset']==1:e['tieStart']=True
            elif e['onset']==1.5:e['tieStop']=True
    (OUT/'source-events.json').write_text(json.dumps(events,indent=2),encoding='utf-8');print('bars',len(bars),'notes',sum(not e.get('rest') for e in events))

if __name__=='__main__':run()
