import json
from pathlib import Path
from fractions import Fraction as F
OUT=Path('output/verovio_pilot_support/mi_torre_fuerte')
LAYOUT=[[(m,[0,1,2,3]) for m in row] for row in [[1,4,6],[9,12,15],[17,19,23],[29,31,33],[36,38,41],[43,45,47],[49,54,59]]]
METERS={1:(6,8),2:(12,8),18:(15,8),20:(2,2),28:(9,8),29:(12,8),45:(15,8),47:(12,8),48:(9,8),49:(6,8)}
SPLITS={(r,2):[1.5]+([4.5] if r<3 else []) for r in range(4)}
def cuts(roles,measures,positions):
    for r in roles:
        for m in measures:SPLITS[(r,m)]=positions
cuts([0,1,3],[3],[4.5])
cuts([0,1],[4,31],[1.5,4.5])
cuts([0,1,3],[7,34],[3])
cuts([0,1],[8,35],[1.5])
cuts([0,2],[9,36],[1.5])
cuts([1,3],[9,36],[3])
cuts([0,1],[11,38],[1.5,3])
cuts([2,3],[11,38],[1.5,2.5])
cuts([3],[16,43],[3])
cuts(range(4),[17,44],[1.5,4.5])
cuts([0,1,3],[18,45],[3.5,4.5,6])
cuts([2],[18,45],[6])
cuts([0],[29],[1.5,4.5])
cuts([2],[29],[3])
cuts([0],[30],[4.5])
cuts([1],[30],[1.5,4.5])
cuts([0,1,2],[47],[3])
cuts(range(4),[54],[1.5])
cuts(range(4),[58,60,62],[2])

def plan():
    bars=[];q=F(0)
    for m in range(1,66):
        beats,unit=METERS[max(n for n in METERS if n<=m)];d=F(beats*4,unit)
        bars.append(dict(number=m,source=m,passage=1,start=float(q),duration=float(d),meter=beats,unit=unit));q+=d
    assert q==323
    return bars

def run():
    midi=json.loads((OUT/'midi-reading.json').read_text());events=[];bars=plan()
    for role,t in enumerate(midi['tracks']):
        for ni,n in enumerate(t['notes']):
            start=F(n['ticks'],480);duration=F(round((n['duration']+1)/480/.95*4),4)
            assert abs(float(duration)-(n['duration']+1)/480/.95)<.03,(role,n)
            cursor=start;left=duration;segments=[]
            while left:
                b=next(b for b in bars if b['start']<=float(cursor)<b['start']+b['duration']);local=cursor-F(b['start']);d=min(left,F(b['duration'])-local)
                for cut in SPLITS.get((role,b['source']),[]):
                    if local<F(cut)<local+d:d=F(cut)-local
                if d not in [F(1,4),F(1,2),F(3,4),F(1),F(3,2),F(2),F(3),F(4),F(6)]:d=F(3,2) if d==F(5,2) else F(3) if d==F(9,2) else max(v for v in [F(1,4),F(1,2),F(1),F(3,2),F(2),F(3),F(4)] if v<=d)
                pitch=70 if role==1 and b['source']==64 and local==0 else n['pitch']
                segments.append(dict(id=f'torre-{role}-{ni}-{len(segments)}',role=role,sourceAttack=ni,bar=b['number'],measure=b['source'],passage=1,onset=float(local),absolute=float(cursor),duration=float(d),pitch=pitch,tieStart=d<left,tieStop=cursor>start));cursor+=d;left-=d
            events+=segments
        for b in bars:
            row=sorted([e for e in events if e['role']==role and e['bar']==b['number']],key=lambda e:(e['onset'],e['pitch']));q=F(0)
            for e in row+[dict(onset=b['duration'],duration=0)]:
                at=F(e['onset'])
                if at>q:
                    left=at-q
                    while left:
                        choices=[F(1,4),F(1,2),F(1),F(3,2),F(2),F(3),F(4),F(6)]
                        if b['unit']==8 and left>=F(3,2) and q%F(3,2)==0:d=F(3) if left>=3 else F(3,2)
                        else:d=max(v for v in choices if v<=left and (q%v==0 or v==left))
                        events.append(dict(id=f"torre-rest-{role}-{b['number']}-{q}",role=role,bar=b['number'],measure=b['source'],passage=1,onset=float(q),absolute=b['start']+float(q),duration=float(d),rest=True));q+=d;left-=d
                q=max(q,at+F(e['duration']))
    # The PDF prolongs the accompaniment across the page turn; the MIDI
    # reattacks the same pitch at the start of source bar 29.
    for e in events:
        if e['role'] in [1,2,3]:
            if e['measure']==28 and e['onset']==1.5:e['tieStart']=True
            if e['measure']==29 and e['onset']==0:e['tieStop']=True
        if e['role']==1:
            if e['measure']==63 and e['onset']==1.5:e['tieStart']=False
            if e['measure']==64 and e['onset']==0:e['tieStop']=False
    (OUT/'source-events.json').write_text(json.dumps(events,indent=2),encoding='utf-8');print('bars',len(bars),'notes',sum(not e.get('rest') for e in events))

if __name__=='__main__':run()
