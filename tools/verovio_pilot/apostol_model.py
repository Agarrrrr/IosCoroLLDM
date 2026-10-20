import json,copy
from pathlib import Path
from fractions import Fraction as F
import pdfplumber
from extract_apostol import staff_groups,LAYOUT
OUT=Path('output/verovio_pilot_support/apostol_padre_maestro')
def plan():
    seq=list(range(1,67))+list(range(63,66))+list(range(67,93));q=0;bars=[]
    for i,m in enumerate(seq):
        d=1 if m==15 else 4;bars.append(dict(number=i+1,source=m,start=q,duration=d,passage=2 if 66<=i<69 else 1));q+=d
    assert len(bars)==95 and q==377
    return bars
def run():
    data=json.loads((OUT/'pdf-reading.json').read_text());src=data['events'];systems=data['systems']
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,page in enumerate(pdf.pages,1):
            ss=staff_groups(page);offset=0
            for s in [s for s in systems if s['page']==pi]:
                s['staffIndexes']=list(range(offset,offset+len(s['roles'])));s['staves']=[ss[i] for i in s['staffIndexes']];offset+=len(s['roles'])
    for m in range(1,93):
        for role in range(4):
            row=sorted([e for e in src if e['role']==role and e['measure']==m],key=lambda e:e['x'])
            if m==52:
                for i,e in enumerate(row[1:]):e.update(duration=1/3,tuplet=True,written=.5,tupletStart=i==0,tupletStop=i==2)
            if role==0 and m==66:row[-1]['duration']=.25;row[-1].pop('dot',None)
            q=F(0)
            for e in row:
                e['onset']=float(q);q+=F(e['duration']).limit_denominator(96)
                if not e.get('rest'):e['pitch']=12*(e['diatonic']//7+1)+[0,2,4,5,7,9,11][e['diatonic']%7]+e['alter']
            if row:assert q==(1 if m==15 else 4),(role,m,q)
    # The explicitly labelled men's unison is sung by both lower voices.
    for e in list(src):
        if e['role']==2 and 5<=e['measure']<=14:n=copy.deepcopy(e);n['role']=3;src.append(n)
    for m in range(1,93):
        for role in range(4):
            if not any(e['measure']==m and e['role']==role for e in src):src.append(dict(role=role,measure=m,onset=0,duration=1 if m==15 else 4,rest=True))
    events=[]
    for b in plan():
        for e in [e for e in src if e['measure']==b['source']]:
            n=copy.deepcopy(e);n.update(id=f"apostol-{e['role']}-{b['number']}-{e['onset']:.5f}-{e.get('pitch','r')}",bar=b['number'],passage=b['passage'],absolute=b['start']+e['onset']);events.append(n)
    (OUT/'positioned-events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2),encoding='utf-8');(OUT/'pdf-layout.json').write_text(json.dumps(dict(systems=systems),indent=2),encoding='utf-8');print('bars',len(plan()),'notes',sum(not e.get('rest') for e in events))
if __name__=='__main__':run()
