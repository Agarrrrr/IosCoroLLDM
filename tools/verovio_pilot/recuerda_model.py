from pathlib import Path
from fractions import Fraction as F
import json
OUT=Path('output/verovio_pilot_support/recuerda')
LAYOUT=[[(1,[0,2]),(4,[0,2]),(7,[0,2]),(10,[0,2])],[(15,[0,2]),(19,[0,2]),(21,[0,2]),(23,[0,2]),(25,[0,2])],[(28,[0,1,2,3]),(32,[0,1,2,3]),(35,[0,1,2,3])],[(38,[0,1,2,3]),(40,[0,1,2,3]),(43,[0,2]),(45,[0,2])],[(47,[0,2]),(49,[0,2]),(52,[0,2]),(55,[0,2]),(58,[0,2])]]
PDF_SPLITS={}
for bar,roles,onset in [(4,range(4),1),(8,range(4),1),(18,[0,1],2),(20,[0,1],1),(21,[2,3],2),(22,[0,1],2),(24,[0,1],1),(31,[3],1),(32,[3],1),(35,[1],1),(36,[1],1),(43,[0,1],2),(45,[0,1],1),(46,[2,3],2),(47,[0,1],2),(49,[0,1],1)]:
    for role in roles:PDF_SPLITS[(role,bar)]=F(onset)
def plan():
    sequence=list(range(1,30))+list(range(2,29))+list(range(30,62));q=F(0);result=[]
    for i,source in enumerate(sequence):
        length=F(1 if source==1 else 4);result.append(dict(number=i+1,source=source,start=float(q),duration=float(length),passage=2 if 29<=i<56 else 1));q+=length
    assert q==349 and len(result)==88
    return result
def rests(role,bar,start,length):
    result=[]
    while length:
        v=max(v for v in [F(1,4),F(1,2),F(1),F(2),F(4)] if v<=length and start%v==0)
        result.append(dict(id=f'rest-{role}-{bar["number"]}-{float(start)}',role=role,bar=bar['number'],measure=bar['source'],passage=bar['passage'],onset=float(start),absolute=bar['start']+float(start),duration=float(v),rest=True));start+=v;length-=v
    return result
def model():
    m=json.loads((OUT/'midi-reading.json').read_text());bars=plan();events=[];recovery=[]
    for role,t in enumerate(m['tracks']):
        for ni,n in enumerate(t['notes']):
            start=F(n['ticks'],m['ppq']);raw=F(n['duration'],m['ppq']);duration=F(round(float((raw+F(1,480))/F(95,100))*4),4)
            assert abs(float(duration*F(95,100)-F(1,480)-raw))<.00001,(role,ni,raw,duration)
            recovery.append(dict(role=role,index=ni,written=float(duration),raw=float(raw)))
            cursor=start;left=duration;segments=[]
            while left:
                b=next(b for b in bars if b['start']<=float(cursor)<b['start']+b['duration']);local=cursor-F(b['start']);d=min(left,F(b['duration'])-local)
                cut=PDF_SPLITS.get((role,b['source']))
                if cut is not None and local<cut<local+d:d=cut-local
                if d not in [F(1,4),F(1,2),F(3,4),F(1),F(3,2),F(2),F(3),F(7,2),F(4)]:
                    nextbeat=F(int(local)+1)-local
                    d=nextbeat if nextbeat<d else F(1,4)
                segments.append(dict(id=f'recuerda-{role}-{ni}-{len(segments)}',role=role,sourceAttack=ni,bar=b['number'],measure=b['source'],passage=b['passage'],onset=float(local),absolute=float(cursor),duration=float(d),pitch=n['pitch'],tieStart=d<left,tieStop=cursor>start));cursor+=d;left-=d
            events+=segments
        for b in bars:
            row=sorted([e for e in events if e['role']==role and e['bar']==b['number']],key=lambda e:e['onset']);cursor=F(0)
            for e in row:
                onset=F(e['onset'])
                if onset>cursor:events+=rests(role,b,cursor,onset-cursor)
                cursor=max(cursor,onset+F(e['duration']))
            if cursor<F(b['duration']):events+=rests(role,b,cursor,F(b['duration'])-cursor)
    (OUT/'source-events.json').write_text(json.dumps(events,indent=2),encoding='utf-8');(OUT/'duration-recovery.json').write_text(json.dumps(recovery,indent=2),encoding='utf-8')
    print('notes',sum(not e.get('rest') for e in events),'bars',len(bars),'attacks',[len(t['notes']) for t in m['tracks']])
    return events
if __name__=='__main__':model()
