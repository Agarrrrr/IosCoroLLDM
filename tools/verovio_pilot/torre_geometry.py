"""Position the MIDI-based written events in the digital source PDF."""
import json,pdfplumber
from torre_model import OUT,LAYOUT
def staves(page):
    ys=sorted({round(e['top'],3) for e in page.edges if abs(e['top']-e['bottom'])<.1 and e['x1']-e['x0']>150});groups=[]
    for y in ys:
        if groups and y<=groups[-1][-1]+1:continue
        g=[min(ys,key=lambda v:abs(v-y-4.6062*i)) for i in range(5)]
        if all(abs(v-y-4.6062*i)<.15 for i,v in enumerate(g)):groups.append(g)
    return groups
def run():
    events=json.loads((OUT/'source-events.json').read_text());systems=[];issues=[];pitch_issues=[];unrepresented=[];glyph_mismatches=[]
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,page in enumerate(pdf.pages):
            ss=staves(page);assert len(ss)==sum(len(roles) for _,roles in LAYOUT[pi]),(pi,ss);offset=0
            for si,(first,roles) in enumerate(LAYOUT[pi]):
                last=LAYOUT[pi][si+1][0] if si+1<len(LAYOUT[pi]) else LAYOUT[pi+1][0][0] if pi<6 else 66
                indexes=list(range(offset,offset+len(roles)));offset+=len(roles);top=ss[indexes[0]]
                horizontal=[l for l in page.lines if abs(l['top']-top[0])<.3 and l['width']>150];left=min(l['x0'] for l in horizontal);right=max(l['x1'] for l in horizontal)
                xs=sorted({left,right,*[round(l['x0'],3) for l in page.lines if l['width']<.01 and abs(l['top']-top[0])<.4 and abs(l['bottom']-top[-1])<.4]});bars=[x for i,x in enumerate(xs) if i==0 or x-xs[i-1]>4]
                while len(bars)-1>last-first:
                    intro=[c for c in page.chars if 'OpusStd' in c['fontname'] and c['text'] in ['œ','˙','w'] and bars[0]<c['x0']<bars[1] and top[0]-25<842-c['matrix'][5]<ss[indexes[-1]][-1]+25]
                    ending=[c for c in page.chars if 'OpusStd' in c['fontname'] and c['text'] in ['œ','˙','w'] and bars[-2]<c['x0']<bars[-1] and top[0]-25<842-c['matrix'][5]<ss[indexes[-1]][-1]+25]
                    if not intro:bars.pop(0)
                    elif not ending:bars.pop()
                    else:break
                assert len(bars)-1==last-first,(pi,first,bars,last)
                systems.append(dict(page=pi+1,system=si,first=first,last=last-1,roles=roles,staffIndexes=indexes,staves=[ss[i] for i in indexes],bars=bars))
                for staff_index,role in zip(indexes,roles):
                    owners=[role] if len(roles)==4 else [role,role+1]
                    for measure in range(first,last):
                        row=[e for e in events if e['measure']==measure and e['role'] in owners and not e.get('rest') and e['passage']==1]
                        heads=[c for c in page.chars if 'OpusStd' in c['fontname'] and c['text'] in ['œ','˙','w'] and bars[measure-first]<c['x0']<bars[measure-first+1] and min(range(len(ss)),key=lambda j:abs(842-c['matrix'][5]-sum(ss[j])/5))==staff_index]
                        hx=[]
                        for x in sorted(c['x0'] for c in heads):
                            # Seconds in a chord displace one notehead by its
                            # width (6.17 pt); they share the same onset.
                            if not hx or x-hx[-1]>6.1:hx.append(x)
                        times=sorted({e['onset'] for e in row})
                        if len(times)!=len(hx):issues.append(dict(page=pi+1,measure=measure,role=role,times=times,xs=hx));continue
                        for e in row:
                            x=hx[times.index(e['onset'])];e.update(x=x,page=pi+1,system=si,staff=staff_index)
                            matching=[c for c in heads if 0<=c['x0']-x<6.1]
                            # Read diatonic spelling from the printed clef and
                            # match chromatic pitches against the MIDI.
                            base=18 if role==2 and len(roles)==2 or role==3 else 23 if role==2 else 30
                            possibilities=[]
                            for c in matching:
                                y=842-c['matrix'][5];diatonic=base+round((ss[staff_index][-1]-y)/2.3031);natural=12*(diatonic//7+1)+[0,2,4,5,7,9,11][diatonic%7];alter=e['pitch']-natural
                                if -1<=alter<=1:possibilities.append((abs(alter-(1 if 'CDEFGAB'[diatonic%7] in 'FC' else 0)),diatonic,alter,y))
                            if possibilities:
                                _,dia,alt,y=min(possibilities);e.update(diatonic=dia,alter=alt,y=y)
                        scopes={}
                        pdf_pitches={}
                        for c in sorted(heads,key=lambda c:c['x0']):
                            y=842-c['matrix'][5];base=18 if role==2 and len(roles)==2 or role==3 else 23 if role==2 else 30;dia=base+round((ss[staff_index][-1]-y)/2.3031);step='CDEFGAB'[dia%7]
                            candidates=[cc for cc in page.chars if 'OpusStd' in cc['fontname'] and cc['text'] in ['#','b','n'] and .5<c['x0']-cc['x0']<14 and abs(842-cc['matrix'][5]-y)<.3]
                            if candidates:
                                cc=min(candidates,key=lambda cc:c['x0']-cc['x0']);scopes[dia]={'#':1,'b':-1,'n':0}[cc['text']]
                            alter=scopes.get(dia,1 if step in 'FC' else 0);pitch=12*(dia//7+1)+[0,2,4,5,7,9,11][dia%7]+alter
                            x=min(hx,key=lambda xx:abs(xx-c['x0']));pdf_pitches[(x,dia)]=(pitch,alter,y)
                        for e in row:
                            matches=[(dia,pp) for (x,dia),pp in pdf_pitches.items() if x==e['x'] and pp[0]==e['pitch']]
                            if matches:
                                dia,(pitch,alt,y)=min(matches,key=lambda item:abs(item[0]-e.get('diatonic',item[0])));e.update(diatonic=dia,alter=alt,y=y,pdfPitchVerified=True)
                            else:pitch_issues.append(dict(role=e['role'],measure=measure,onset=e['onset'],midi=e['pitch'],printed=[pp[0] for (x,dia),pp in pdf_pitches.items() if x==e['x']]))
                            match=[c for c in heads if abs(c['x0']-e['x'])<6.1 and abs(842-c['matrix'][5]-e.get('y',0))<.2]
                            if match:
                                e['glyph']=match[0]['text']
                                if e['glyph']=='˙' and e['duration'] not in [2,3,3.5] or e['glyph']=='w' and e['duration'] not in [4,6]:glyph_mismatches.append(dict(role=e['role'],measure=measure,onset=e['onset'],duration=e['duration'],glyph=e['glyph']))
                        assigned={(e['x'],e.get('diatonic')) for e in row}
                        for (x,dia),(pitch,alt,y) in pdf_pitches.items():
                            if (x,dia) not in assigned:unrepresented.append(dict(role=role,measure=measure,onset=times[hx.index(x)],pitch=pitch,x=x,y=y))
            # All source curves retained for later tie/slur matching.
    for e in events:
        if e['passage']>1 and e['measure']<44:
            original=next(n for n in events if n['passage']==1 and n['role']==e['role'] and n['measure']==e['measure'] and n['onset']==e['onset'] and n.get('pitch')==e.get('pitch') and n.get('rest')==e.get('rest'))
            for key in ['x','y','diatonic','alter','page','system','staff','glyph','pdfPitchVerified']:
                if key in original:e[key]=original[key]
    (OUT/'positioned-events.json').write_text(json.dumps(events,indent=2),encoding='utf-8');(OUT/'pdf-layout.json').write_text(json.dumps(dict(systems=systems,issues=issues,pitchIssues=pitch_issues,unrepresentedHeads=unrepresented,glyphMismatches=glyph_mismatches),indent=2),encoding='utf-8');print('issues',json.dumps(issues,indent=2));print('pitch issues',pitch_issues);print('unrepresented',unrepresented);print('glyph mismatches',glyph_mismatches)
if __name__=='__main__':run()
