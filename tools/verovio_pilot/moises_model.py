import json,copy,collections
from pathlib import Path
from fractions import Fraction as F
import pdfplumber
from extract_cantico_moises import staff_groups,LAYOUT
OUT=Path('output/verovio_pilot_support/cantico_moises')
def plan():
    seq=list(range(1,6))+list(range(1,5))+list(range(6,119));q=0;bars=[]
    for i,m in enumerate(seq):
        d=2 if m in [10,85] else 4
        bars.append(dict(number=i+1,source=m,start=q,duration=d,passage=2 if 5<=i<9 else 1));q+=d
    assert q==484 and len(bars)==122
    return bars
def run():
    data=json.loads((OUT/'pdf-reading.json').read_text());src=data['events'];systems=data['systems']
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,page in enumerate(pdf.pages,1):
            ss=staff_groups(page)
            for s in [s for s in systems if s['page']==pi]:
                s['staffIndexes']=list(range(s['system']*4,s['system']*4+4));s['staves']=[ss[i] for i in s['staffIndexes']]
    for role in range(4):
        for m in range(1,119):
            row=sorted([e for e in src if e['role']==role and e['measure']==m],key=lambda e:e['x'])
            if role in [0,1] and m==1:
                for i,e in enumerate(row):e['duration']=1/3;e['tuplet']=True;e['tupletStart']=i%3==0;e['tupletStop']=i%3==2;e['written']=.5
            if role==0 and m==58:
                for i,e in enumerate(row[:3]):e['duration']=2/3;e['tuplet']=True;e['tupletStart']=i==0;e['tupletStop']=i==2;e['written']=1
            if role==0 and m in [33,76] or role in [1,2,3] and m==48:
                e=next(e for e in row if e['glyph']=='˙');e['duration']=3.5;e['dots']=2
            q=F(0);last=None
            for i,e in enumerate(row):
                chord=last is not None and abs(e['x']-last['x'])<.1
                e['onset']=last['onset'] if chord else float(q)
                if not chord:q+=F(e['duration']).limit_denominator(96)
                e['chord']=chord
                if not e.get('rest'):e['pitch']=12*(e['diatonic']//7+1)+[0,2,4,5,7,9,11][e['diatonic']%7]+e['alter']
                last=e
            assert q==(2 if m in [10,85] else 4),(role,m,q)
    events=[]
    for b in plan():
        for e in [e for e in src if e['measure']==b['source']]:
            n=copy.deepcopy(e);n.update(id=f"moises-{e['role']}-{b['number']}-{e['onset']:.5f}-{e.get('pitch','r')}",bar=b['number'],passage=b['passage'],absolute=b['start']+e['onset']);events.append(n)
    (OUT/'positioned-events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'pdf-layout.json').write_text(json.dumps(dict(systems=systems),indent=2),encoding='utf-8')
    print('bars',len(plan()),'notes',sum(not e.get('rest') for e in events))
if __name__=='__main__':run()
