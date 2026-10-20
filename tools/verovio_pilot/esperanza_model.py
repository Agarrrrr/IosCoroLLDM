import json,copy
from pathlib import Path
from fractions import Fraction as F
OUT=Path('output/verovio_pilot_support/tu_eres_mi_esperanza')
LAYOUT=[[(m,[0,2]) for m in row] for row in [[1,4,7,10],[13,16,20,24]]]
SPLITS={(r,m):[q] for r in range(4) for m,q in [(4,1.5),(6,4.5),(8,4.5),(12,1.5),(14,3),(18,3),(19,3),(20,3),(22,1.5),(26,3)]}
def plan():
    sequence=[(m,1) for m in range(1,24)]+[(m,2) for m in range(2,24)]+[(m,3) for m in list(range(2,23))+[24,25,26]]
    bars=[];q=0
    for i,(m,v) in enumerate(sequence):
        d=3 if m==1 else 6;bars.append(dict(number=i+1,source=m,passage=v,start=q,duration=d,meter=12,unit=8));q+=d
    assert q==411 and len(bars)==69
    return bars
def run():
    midi=json.loads((OUT/'midi-reading.json').read_text());events=[];bars=plan();original=[]
    guide=[];q=0
    for m in list(range(1,23))+[24,25,26]:
        d=3 if m==1 else 6;guide.append(dict(source=m,start=q,duration=d));q+=d
    for role,t in enumerate(midi['tracks']):
        for ni,n in enumerate(t['notes']):
            if n['ticks']/midi['ppq']>=144.5:continue
            start=F(n['ticks'],midi['ppq'])+1;cursor=start;left=F(n['duration'],midi['ppq']);segments=[]
            while left:
                b=next(b for b in guide if b['start']<=cursor<b['start']+b['duration']);local=cursor-b['start'];d=min(left,F(b['duration'])-local)
                for cut in SPLITS.get((role,b['source']),[]):
                    if local<F(cut)<local+d:d=F(cut)-local
                if d not in [F(1,2),F(1),F(3,2),F(2),F(3),F(4),F(6)]:d=F(3,2) if d==F(5,2) else F(3) if d==F(9,2) else max(v for v in [F(1,2),F(1),F(3,2),F(2),F(3),F(4)] if v<=d)
                segments.append(dict(role=role,sourceAttack=ni,measure=b['source'],onset=float(local),duration=float(d),pitch=73 if role==0 and b['source']==16 and n['pitch']==74 else n['pitch'],tieStart=d<left,tieStop=cursor>start));cursor+=d;left-=d
            original+=segments
    original += [dict(e,measure=23) for e in original if e['measure']==24]
    for b in bars:
        for role in range(4):
            row=sorted([e for e in original if e['measure']==b['source'] and e['role']==role],key=lambda e:(e['onset'],e['pitch']));q=F(0)
            for e in row+[dict(onset=b['duration'],duration=0)]:
                at=F(e['onset'])
                while q<at:
                    left=at-q;d=max(v for v in [F(1,2),F(1),F(3,2),F(2),F(3),F(4),F(6)] if v<=left and (q%v==0 or v==left));events.append(dict(id=f"esperanza-rest-{role}-{b['number']}-{q}",role=role,bar=b['number'],measure=b['source'],passage=b['passage'],onset=float(q),absolute=b['start']+float(q),duration=float(d),rest=True));q+=d
                if 'pitch' in e:
                    ee=copy.deepcopy(e);ee.update(id=f"esperanza-{role}-{b['number']}-{e['sourceAttack']}-{e['onset']}",bar=b['number'],passage=b['passage'],absolute=b['start']+e['onset']);events.append(ee)
                q=max(q,at+F(e['duration']))
    # The lower D of the tenor divisi remains tied; its upper Bb moves to Ab.
    for e in events:
        if e['role']==2 and e['measure']==14 and e.get('pitch')==50:
            if e['onset']==0:e['tieStart']=True
            if e['onset']==3:e['tieStop']=True
    (OUT/'source-events.json').write_text(json.dumps(events,indent=2));print('bars',len(bars),'notes',sum(not e.get('rest') for e in events))
if __name__=='__main__':run()
