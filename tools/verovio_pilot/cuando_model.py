import json
from pathlib import Path
from fractions import Fraction as F
OUT=Path('output/verovio_pilot_support/cuando_oi_su_voz')
LAYOUT=[[(m,[0,2]) for m in row] for row in [[1,5,9,12],[15,19,22,25],[29,32,36,39,43]]]
PDF_SPLITS={(r,7):[1] for r in [0,1]}
PDF_SPLITS.update({(r,9):[1] for r in [2,3]})
PDF_SPLITS.update({(2,13):[2],(2,18):[3]})
def plan():
    sequence=[(m,1) for m in range(1,44)]+[(m,2) for m in range(2,44)]+[(m,3) for m in range(2,41)]+[(m,3) for m in range(44,48)];q=0;bars=[]
    for i,(source,passage) in enumerate(sequence):
        d=2 if source==28 else 4;bars.append(dict(number=i+1,source=source,start=q,duration=d,passage=passage));q+=d
    assert q==506 and len(bars)==128
    return bars
def rests(role,b,start,left):
    result=[]
    while left:
        if left<1 and (left.denominator==3 or start.denominator==3):v=F(1,3)
        else:v=max(v for v in [F(1,12),F(1,6),F(1,4),F(1,3),F(1,2),F(1),F(3,2),F(2),F(4)] if v<=left and start%v==0)
        result.append(dict(id=f"cuando-rest-{role}-{b['number']}-{float(start):.5f}",role=role,bar=b['number'],measure=b['source'],passage=b['passage'],onset=float(start),absolute=b['start']+float(start),duration=float(v),rest=True));start+=v;left-=v
    return result
def run():
    midi=json.loads((OUT/'midi-reading.json').read_text());events=[];bars=plan()
    for role,t in enumerate(midi['tracks']):
        for ni,n in enumerate(t['notes']):
            start=F(n['ticks'],midi['ppq'])+3;duration=F(n['duration']+1,midi['ppq']);cursor=start;left=duration;segments=[]
            while left:
                b=next(b for b in bars if b['start']<=cursor<b['start']+b['duration']);local=cursor-b['start'];d=min(left,F(b['duration'])-local)
                for cut in PDF_SPLITS.get((role,b['source']),[]):
                    cut=F(cut)
                    if local<cut<local+d:d=cut-local
                if d not in [F(1,4),F(1,3),F(1,2),F(2,3),F(3,4),F(1),F(3,2),F(2),F(3),F(7,2),F(4)]:
                    options=[v for v in [F(1,4),F(1,3),F(1,2),F(2,3),F(1),F(2)] if v<=d];d=max(options)
                pitch=64 if role==1 and b['source']==32 and local==3 else 62 if role==1 and b['source']==42 and local>=3 else n['pitch']
                segments.append(dict(id=f'cuando-{role}-{ni}-{len(segments)}',role=role,sourceAttack=ni,bar=b['number'],measure=b['source'],passage=b['passage'],onset=float(local),absolute=float(cursor),duration=float(d),pitch=pitch,tieStart=d<left,tieStop=cursor>start));cursor+=d;left-=d
            events+=segments
        if role in [2,3]:
            for b in bars:
                if b['source']==4:
                    at=F(3,2)
                    for i,(pitch,d) in enumerate(zip([55,57,59,57,59,57],[F(1,4),F(1,4),F(1),F(1,2),F(1,4),F(1,4)])):
                        events.append(dict(id=f"cuando-pdf-{role}-{b['number']}-{i}",role=role,sourceAttack=f'pdf4-{i}',bar=b['number'],measure=4,passage=b['passage'],onset=float(at),absolute=b['start']+float(at),duration=float(d),pitch=pitch,pdfAddition=True));at+=d
                if b['source']==6:
                    events.append(dict(id=f"cuando-cue-{role}-{b['number']}",role=role,sourceAttack='pdf-cue6',bar=b['number'],measure=6,passage=b['passage'],onset=11/3,absolute=b['start']+11/3,duration=1/3,pitch=55,cue=True,pdfAddition=True))
        for b in bars:
            row=sorted([e for e in events if e['role']==role and e['bar']==b['number']],key=lambda e:e['onset']);q=F(0)
            for e in row:
                at=F(e['onset']).limit_denominator(480)
                if at>q:events+=rests(role,b,q,at-q)
                q=max(q,at+F(e['duration']).limit_denominator(480))
            if q<b['duration']:events+=rests(role,b,q,F(b['duration'])-q)
    (OUT/'source-events.json').write_text(json.dumps(events,indent=2),encoding='utf-8');print('bars',len(bars),'notes',sum(not e.get('rest') for e in events))
if __name__=='__main__':run()
