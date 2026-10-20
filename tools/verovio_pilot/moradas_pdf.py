"""Read the digital official score's noteheads without replacing its arrangement."""
import json,pdfplumber,collections
from pathlib import Path
OUT=Path('output/verovio_pilot_support/cuan_amables_oficial')
LAYOUT=[[(1,[0]),(7,[0]),(13,[0]),(18,[0]),(23,[0,1,2,3,4])],[(27,[1,2,3,4]),(31,[1,2,3,4]),(35,[1,2,3,4])],[(39,[1,2,3,4]),(43,[1,2,3,4]),(47,[0,1,2,3,4])],[(54,[0]),(58,[0]),(62,[0,1,2,3,4]),(66,[0,1,2,3,4])],[(70,[0,1,2,3,4]),(73,[0,1,2,3,4]),(76,[0,1,2,3,4])],[(79,[0,1,2,3,4]),(83,[0,1,2,3,4]),(87,[0,1,2,3,4])]]
def staves(page):
    ys=sorted({round(e['top'],3) for e in page.edges if abs(e['top']-e['bottom'])<.1 and e['x1']-e['x0']>150});groups=[]
    for y in ys:
        if groups and y<=groups[-1][-1]+1:continue
        g=[min(ys,key=lambda v:abs(v-y-4.9603*i)) for i in range(5)]
        if all(abs(v-y-4.9603*i)<.15 for i,v in enumerate(g)):groups.append(g)
    return groups
def run():
    events=[];systems=[]
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,page in enumerate(pdf.pages):
            ss=staves(page);assert len(ss)==sum(len(r) for _,r in LAYOUT[pi]),(pi,len(ss));offset=0
            for si,(first,roles) in enumerate(LAYOUT[pi]):
                last=LAYOUT[pi][si+1][0] if si+1<len(LAYOUT[pi]) else LAYOUT[pi+1][0][0] if pi<5 else 92
                indexes=list(range(offset,offset+len(roles)));offset+=len(roles);top=ss[indexes[0]]
                lines=[l for l in page.lines if abs(l['top']-top[0])<.3 and l['width']>150];left=min(l['x0'] for l in lines);right=max(l['x1'] for l in lines)
                xs=sorted({left,right,*[round(l['x0'],3) for l in page.lines if l['width']<.01 and abs(l['top']-top[0])<.4 and abs(l['bottom']-top[-1])<.4]});bars=[x for i,x in enumerate(xs) if i==0 or x-xs[i-1]>4]
                assert len(bars)-1==last-first,(pi,first,bars,last)
                sy=dict(page=pi+1,system=si,first=first,last=last-1,roles=roles,staffIndexes=indexes,staves=[ss[i] for i in indexes],bars=bars);systems.append(sy)
                for staff_index,role in zip(indexes,roles):
                    for measure in range(first,last):
                        heads=[c for c in page.chars if 'OpusStd' in c['fontname'] and c['text'] in ['œ','˙','w'] and bars[measure-first]<c['x0']<bars[measure-first+1] and min(range(len(ss)),key=lambda j:abs(page.height-c['matrix'][5]-sum(ss[j])/5))==staff_index]
                        scopes={};row=[]
                        for c in sorted(heads,key=lambda c:c['x0']):
                            y=page.height-c['matrix'][5];base=18 if role==4 else 23 if role==3 else 30;dia=base+round((ss[staff_index][-1]-y)/2.48015);step='CDEFGAB'[dia%7]
                            candidates=[cc for cc in page.chars if 'OpusStd' in cc['fontname'] and cc['text'] in ['#','b','n'] and .5<c['x0']-cc['x0']<14 and abs(page.height-cc['matrix'][5]-y)<.3]
                            if candidates:scopes[dia]={'#':1,'b':-1,'n':0}[min(candidates,key=lambda cc:c['x0']-cc['x0'])['text']]
                            alter=scopes.get(dia,1 if step in 'FC' else 0);pitch=12*(dia//7+1)+[0,2,4,5,7,9,11][dia%7]+alter
                            row.append(dict(role=role,measure=measure,page=pi+1,system=si,staff=staff_index,x=c['x0'],y=y,diatonic=dia,alter=alter,pitch=pitch,glyph=c['text']))
                        events+=list({(round(h['x'],3),h['pitch']):h for h in row}.values())
    (OUT/'pdf-heads.json').write_text(json.dumps(events,indent=2));(OUT/'pdf-layout.json').write_text(json.dumps(dict(systems=systems),indent=2))
    print('PDF',collections.Counter(e['role'] for e in events))
if __name__=='__main__':run()
