"""Recover notated values from the app MIDI's 95% articulation gate."""
from pathlib import Path
from fractions import Fraction as F
import json,collections
OUT=Path('output/verovio_pilot_support/aleluya_al_rey')
VALUES=[F(1,4),F(1,3),F(1,2),F(3,4),F(1),F(3,2),F(2),F(3),F(4),F(8)]
def model():
    m=json.loads((OUT/'midi-reading.json').read_text());events=[];rounding=[]
    for role,t in enumerate(m['tracks']):
        for ni,n in enumerate(t['notes']):
            q=F(n['ticks'],m['ppq']);raw=F(n['duration'],m['ppq']);d=min(VALUES,key=lambda v:abs(float(v*F(95,100)-F(1,480)-raw)))
            assert abs(float(d*F(95,100)-F(1,480)-raw))<.06,(role,ni,raw,d)
            later=[F(x['ticks'],m['ppq']) for x in t['notes'] if x['ticks']>n['ticks']]
            if later and q+d>min(later):
                # One MIDI note overlaps the next attack (S, bar 54). The
                # PDF prints a normal eighth note, not a tied overlap.
                assert role==0 and q==F(431,2),(role,q,d,min(later))
                d=min(later)-q
            rounding.append(dict(role=role,index=ni,raw=float(raw),written=float(d)))
            cursor=q;left=d
            while left:
                bar=int(cursor//4)+1;local=cursor%4;length=min(left,4-local)
                events.append(dict(id=f'rey-{role}-{ni}-{len(events)}',role=role,measure=bar,onset=float(local),absolute=float(cursor),duration=float(length),pitch=n['pitch'],sourceAttack=ni,tieStart=length<left,tieStop=cursor>q))
                cursor+=length;left-=length
        # Insert notated rests, ignoring the tiny MIDI gate between notes.
        for bar in range(1,71):
            row=sorted([e for e in events if e['role']==role and e['measure']==bar],key=lambda e:e['onset']);cursor=F(0)
            for e in row:
                start=F(e['onset']).limit_denominator(12)
                if start>cursor:events+=rest_events(role,bar,cursor,start-cursor)
                cursor=max(cursor,start+F(e['duration']).limit_denominator(12))
            if cursor<4:events+=rest_events(role,bar,cursor,4-cursor)
    (OUT/'source-events.json').write_text(json.dumps(events,indent=2),encoding='utf-8');(OUT/'duration-recovery.json').write_text(json.dumps(rounding,indent=2),encoding='utf-8')
    for role in range(4):
        print('ROLE',role)
        for bar in range(1,71):
            row=sorted([e for e in events if e['role']==role and e['measure']==bar and not e.get('rest')],key=lambda e:(e['onset'],e['pitch']))
            print(bar,' '.join(f"{e['onset']:g}:{e['pitch']}({e['duration']:g})"+('~' if e.get('tieStop') else '') for e in row))
    return events
def rest_events(role,bar,start,duration):
    result=[]
    while duration:
        value=max(v for v in [F(1,4),F(1,2),F(1),F(2),F(4)] if v<=duration and start%v==0)
        result.append(dict(id=f'rest-{role}-{bar}-{float(start)}',role=role,measure=bar,onset=float(start),absolute=(bar-1)*4+float(start),duration=float(value),rest=True));start+=value;duration-=value
    return result
if __name__=='__main__':model()
