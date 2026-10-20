"""Read each printed stanza separately; associate digital text with MIDI notes."""
import json,collections,re
import pdfplumber
from no_hay_amigo_model import OUT,LAYOUT,plan,source_events
from digital_text_runs import page_runs
def run():
    events=source_events();runs=page_runs(OUT/'original.pdf');rows=[]
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,p in enumerate(pdf.pages):
            ys=sorted({round(e['top'],3) for e in p.edges if abs(e['top']-e['bottom'])<.1 and e['x1']-e['x0']>150});staves=[]
            for y in ys:
                if staves and y<=staves[-1][-1]+1:continue
                g=[min(ys,key=lambda v:abs(v-(y+4.60616*i))) for i in range(5)]
                if all(abs(v-y-4.60616*i)<.15 for i,v in enumerate(g)):staves.append(g)
            assert len(staves)==len(LAYOUT[pi])*2,(pi,staves)
            for si,first in enumerate(LAYOUT[pi]):
                upper,lower=staves[si*2:si*2+2];last=LAYOUT[pi][si+1] if si+1<len(LAYOUT[pi]) else LAYOUT[pi+1][0] if pi<2 else 38
                horizontal=[l for l in p.lines if abs(l['top']-upper[0])<.3 and l['width']>150]
                left=min(l['x0'] for l in horizontal);right=max(l['x1'] for l in horizontal)
                xs=sorted({left,right,*[round(l['x0'],3) for l in p.lines if l['width']<.01 and abs(l['top']-upper[0])<.4 and abs(l['bottom']-upper[-1])<.4]})
                bars=[x for i,x in enumerate(xs) if i==0 or x-xs[i-1]>4]
                if len(bars)-1==last-first+1:bars.pop()
                assert len(bars)-1==last-first,(pi,first,bars)
                for m in range(first,last):
                    heads=[c for c in p.chars if 'OpusStd' in c['fontname'] and c['text'] in ['œ','˙','w'] and upper[0]-25<842-c['matrix'][5]<upper[-1]+25 and bars[m-first]<c['x0']<bars[m-first+1]]
                    hx=[]
                    for x in sorted(c['x0'] for c in heads):
                        if not hx or x-hx[-1]>.5:hx.append(x)
                    row=sorted([e for e in events if e['role']==0 and e['measure']==m and not e.get('rest')],key=lambda e:e['onset'])
                    if m==36:
                        # MIDI contains an extra rearticulation before beat 3;
                        # the PDF prints one half note over that whole span.
                        for e in row:
                            x=hx[0] if e['onset']<2 else hx[1] if e['onset']==2 else hx[2]
                            e.update(x=x,page=pi+1,system=si)
                    else:
                        assert len(row)==len(hx),(pi,m,len(row),hx)
                        for e,x in zip(row,hx):e.update(x=x,page=pi+1,system=si)
                row=sorted([e for e in events if e['role']==0 and first<=e['measure']<last and not(e['measure']==36 and 0<e['onset']<2)],key=lambda e:e['absolute'])
                cs=[c for c in runs[pi] if ('AGaramondPro-Regular' in c['fontname'] and 11.8<c['size']<12.4 or 'OpusTextStd' in c['fontname'] and c['text']=='_' and 11.8<c['size']<12.4) and upper[-1]+4<c['top']<lower[0]-5 and not c['text'].isspace()]
                lines=[]
                for c in sorted(cs,key=lambda c:c['top']):
                    match=next((line for line in lines if abs(line[0]['top']-c['top'])<7),None)
                    if match is None:lines.append([c])
                    else:match.append(c)
                for vi,line in enumerate(lines):
                    line.sort(key=lambda c:c['x0']);states={0:(0,[])}
                    for e in row:
                        ns={}
                        def update(j,cost,path):
                            if j not in ns or cost<ns[j][0]:ns[j]=(cost,path)
                        for j,(cost,path) in states.items():
                            update(j,cost+(0 if e.get('tieStop') else 5),path+[None])
                            for k in range(j+1,min(j+18,len(line))+1):
                                chunk=line[j:k];dx=abs((chunk[0]['x0']+chunk[-1]['x1'])/2-e['x']-3.05)
                                if dx>18:continue
                                gaps=[max(0,b['x0']-a['x1']) for a,b in zip(chunk,chunk[1:])]
                                if gaps and max(gaps)>6:break
                                update(k,cost+dx*dx/8+sum(max(0,g-1.5)*4 for g in gaps)+.2+(30 if e.get('tieStop') else 0),path+[(j,k)])
                        states=ns
                    assert len(line) in states,(pi,si,vi,'unassigned')
                    cost,path=states[len(line)];assigned=[]
                    for e,span in zip(row,path):
                        if span:
                            for c in line[span[0]:span[1]]:assigned.append(dict(text=c['text'],id=e['id'],absolute=e['absolute']))
                    rows.append(dict(page=pi+1,system=si,variant=vi+1 if len(lines)>1 else 0,cost=cost,chars=assigned))
    (OUT/'lyric-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'positioned-events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2),encoding='utf-8')
    for r in rows:print(r['page'],r['system'],r['variant'],round(r['cost'],1),''.join(c['text'] for c in r['chars']))
if __name__=='__main__':run()
