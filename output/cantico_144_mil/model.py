"""Digital PDF is authoritative. MIDI is compared separately, never converted."""
import json, copy, collections
from pathlib import Path
from fractions import Fraction as F
import pdfplumber
from extract_pdf import staff_groups, length

OUT=Path(__file__).resolve().parent

def plan():
    seq=list(range(1,62))+list(range(54,62))+list(range(62,84))+list(range(77,82))+list(range(84,98))
    counts=collections.Counter();q=0;bars=[]
    for i,m in enumerate(seq):
        counts[m]+=1
        bars.append(dict(number=i+1,source=m,start=q,duration=length(m),passage=counts[m]))
        q+=length(m)
    assert len(bars)==110 and q==411
    return bars

def run():
    data=json.loads((OUT/'pdf-reading.json').read_text(encoding='utf8'));src=data['events'];systems=data['systems']
    with pdfplumber.open(OUT/'fuente.pdf') as pdf:
        for pi,page in enumerate(pdf.pages,1):
            staves=staff_groups(page);offset=0
            for s in [s for s in systems if s['page']==pi]:
                n=len(s['roles']);s['staffIndexes']=list(range(offset,offset+n));s['staves']=staves[offset:offset+n];offset+=n
    for role in range(4):
        for m in range(1,98):
            row=sorted([e for e in src if e['role']==role and e['measure']==m],key=lambda e:e['x'])
            if role in [1,2,3] and m==61:
                row[-1]['duration']=1;row[-1].pop('dot',None)
            if role in [0,1] and m==66:
                for i,e in enumerate(row[1:]):
                    e.update(duration=1/3,tuplet=True,written=.5,tupletStart=i==0,tupletStop=i==2)
            q=F(0)
            for i,e in enumerate(row):
                e.update(id=f"src-{role}-{m}-{i}",onset=float(q),absolute=sum(length(k) for k in range(1,m))+float(q),passage=1)
                q+=F(e['duration']).limit_denominator(96)
                if not e['rest']:e['pitch']=12*(e['diatonic']//7+1)+[0,2,4,5,7,9,11][e['diatonic']%7]+e['alter']
            assert not row or q==length(m),(role,m,q)
    (OUT/'source-events.json').write_text(json.dumps(src,ensure_ascii=False,indent=2),encoding='utf8')
    (OUT/'pdf-layout.json').write_text(json.dumps(dict(systems=systems),indent=2),encoding='utf8')
    (OUT/'bar-map.json').write_text(json.dumps(plan(),indent=2),encoding='utf8')
    print('Source notes:',sum(not e['rest'] for e in src),'expanded bars:',len(plan()))

if __name__=='__main__':run()
