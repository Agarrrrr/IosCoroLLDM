"""Read notation and lyric geometry from our digital PDF, without MIDI."""
from pathlib import Path
import collections,json
import pdfplumber
from digital_text_runs import page_runs

OUT=Path('output/verovio_pilot_support/apostol_padre_maestro')
LAYOUT=[[(1,[0,1,2,3]),(5,[2]),(8,[2]),(11,[2]),(15,[0]),(21,[0,1,2,3])]]+[[(n,[0,1,2,3]) for n in row] for row in [[25,28,30],[33,36,38],[41,44,46],[49,52,55],[58,61,63],[65,67,70],[73,77,80],[83,86,89]]]
RESTS={'\u2211':None,'\u00d3':2,'\u0152':1,'\u2030':.5,'\u2248':.25}
def staff_groups(page):
    ys=sorted({round(e['top'],3) for e in page.edges if abs(e['top']-e['bottom'])<.1 and e['x1']-e['x0']>150})
    groups=[]
    for y in ys:
        if groups and y<=groups[-1][-1]+1:continue
        g=[min(ys,key=lambda v:abs(v-(y+4.9603*i))) for i in range(5)]
        if all(abs(v-(y+4.9603*i))<.15 for i,v in enumerate(g)):groups.append(g)
    return groups
def beam_y(shape,x):
    if not shape['x0']-.3<=x<=shape['x1']+.3:return None
    x=min(shape['x1']-.0001,max(shape['x0']+.0001,x));ys=[];pts=shape['pts']
    for a,b in zip(pts,pts[1:]+pts[:1]):
        if abs(a[0]-b[0])<.000001:continue
        if min(a[0],b[0])<=x<=max(a[0],b[0]):ys.append(a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0]))
    if len(ys)<2 or not 1.5<max(ys)-min(ys)<3.1:return None
    return (min(ys)+max(ys))/2
def length(measure):return 1 if measure==15 else 4
def extract():
    runs=page_runs(OUT/'original.pdf');events=[];systems=[];issues=[];arcs=[];lyric_issues=[]
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,page in enumerate(pdf.pages,1):
            page=page.dedupe_chars(tolerance=.1)
            staves=staff_groups(page);assert len(staves)==sum(len(roles) for _,roles in LAYOUT[pi-1]),(pi,len(staves))
            start_staff=0
            for sysi,(first,roles) in enumerate(LAYOUT[pi-1]):
                indexes=list(range(start_staff,start_staff+len(roles)));start_staff+=len(roles)
                boundary=[l for l in page.lines if l['width']<.01 and abs(l['top']-staves[indexes[0]][0])<.4 and abs(l['bottom']-staves[indexes[0]][-1])<.4]
                bars=sorted({round(l['x0'],3) for l in boundary})
                hs=[l for l in page.lines if abs(l['top']-staves[indexes[0]][0])<.3 and l['width']>150]
                left=min(l['x0'] for l in hs);right=max(l['x1'] for l in hs)
                bars=sorted({left,right,*bars});bars=[x for i,x in enumerate(bars) if i==0 or x-bars[i-1]>4]
                expected_next=LAYOUT[pi-1][sysi+1][0] if sysi+1<len(LAYOUT[pi-1]) else LAYOUT[pi][0][0] if pi<9 else 93
                if len(bars)-1==expected_next-first+1:
                    intro=[c for c in page.chars if 'OpusStd' in c['fontname'] and c['text'] in ['œ','˙','w',*RESTS] and bars[0]<c['x0']<bars[1] and staves[indexes[0]][0]-25<842-c['matrix'][5]<staves[indexes[-1]][-1]+25]
                    if not intro:bars.pop(0)
                if len(bars)-1==expected_next-first+1:
                    caution=[c for c in page.chars if c['fontname'].endswith('+OpusStd') and c['text'] in ['\u0153','\u02d9','w',*RESTS]
                        and c['x0']>bars[-2] and staves[indexes[0]][0]-25<842-c['matrix'][5]<staves[indexes[-1]][-1]+25]
                    if not caution:bars.pop()
                assert len(bars)-1==expected_next-first,(pi,first,len(bars)-1,expected_next-first,bars)
                systems.append(dict(page=pi,system=sysi,first=first,last=expected_next-1,roles=roles,bars=bars))
                for si,role in zip(indexes,roles):
                    staff=staves[si];centre=sum(staff)/5
                    clefs=[c for c in page.chars if c['text'] in ['&','?'] and c['fontname'].endswith('+OpusStd') and c['x0']<left+22]
                    clef=min(clefs,key=lambda c:abs(842-c['matrix'][5]-centre))
                    clef_f=clef['text']=='?';base=18 if clef_f else 23 if role==2 else 30
                    def owner(c):return min(range(len(staves)),key=lambda i:abs((842-c['matrix'][5])-sum(staves[i])/5))
                    musical=[c for c in page.chars if c['fontname'].endswith('+OpusStd') and c['text'] in ['\u0153','\u02d9','w',*RESTS] and owner(c)==si]
                    beams=[s for s in page.curves if s['fill'] and not any(p[0]=='c' for p in s['path'])]
                    beams += [dict(x0=s['x0'],x1=s['x1'],pts=[(s['x0'],s['top']),(s['x1'],s['top']),(s['x1'],s['bottom']),(s['x0'],s['bottom'])]) for s in page.rects if 1.5<s['height']<3.1]
                    row=[]
                    for c in musical:
                        x=c['x0'];y=842-c['matrix'][5];bin=sum(b<x+1 for b in bars)-1;m=first+bin
                        if not first<=m<expected_next:issues.append(('outside bar',pi,si,c['text'],x));continue
                        e=dict(role=role,page=pi,staff=si,system=sysi,measure=m,x=x,y=y,clef='F' if clef_f else 'G8' if role==2 else 'G',glyph=c['text'],lyrics=[],beams=0)
                        if c['text'] in RESTS:e['rest']=True;d=RESTS[c['text']] or length(m)
                        else:
                            e['rest']=False;e['diatonic']=base+round((staff[-1]-y)/2.48015)
                            if c['text']=='w':d=4
                            elif c['text']=='\u02d9':d=2
                            else:
                                # Notehead ink is narrower than the font advance.
                                cx=x+3.3
                                stems=[l for l in page.lines if l['width']<.01 and abs(l['x0']-cx)<4 and l['height']>8 and min(abs(l['top']-y),abs(l['bottom']-y))<1.4]
                                stems=list({(round(s['x0'],2),round(s['top'],2),round(s['bottom'],2)):s for s in stems}.values())
                                if len(stems)!=1:issues.append(('stem',pi,si,m,x,len(stems)));continue
                                stem=stems[0];up=abs(stem['bottom']-y)<1.4;tip=stem['top'] if up else stem['bottom'];e['stem']='up' if up else 'down'
                                hits=[(bi,v) for bi,s in enumerate(beams) if (v:=beam_y(s,stem['x0'])) is not None and abs(v-tip)<9]
                                levels=len(hits)
                                if hits:e['beamGroup']=[pi,si,min(hits,key=lambda hit:abs(hit[1]-tip))[0]]
                                flags=[cc for cc in page.chars if cc['text'] in ['j','J','r','R'] and cc['fontname'].endswith('+OpusStd') and abs(cc['x0']-stem['x0'])<.6 and abs((842-cc['matrix'][5])-y)<30]
                                if flags:levels=max(levels,max(2 if cc['text'] in ['r','R'] else 1 for cc in flags))
                                if levels>2:issues.append(('beam levels',pi,si,m,x,levels))
                                d=1/2**levels;e['beams']=levels
                        dots=[cc for cc in page.chars if cc['text']=='.' and cc['fontname'].endswith('+OpusStd') and 6<cc['x0']-x<14 and abs((842-cc['matrix'][5])-y)<3]
                        if dots:d*=1.5;e['dot']=True
                        e['duration']=d;row.append(e)
                    row.sort(key=lambda e:e['x'])
                    # Chromatic spelling is read from PDF, with bar-local scope.
                    scopes=collections.defaultdict(dict)
                    for e in row:
                        if e['rest']:continue
                        step='CDEFGAB'[e['diatonic']%7];fifths=0 if 55<=e['measure']<72 else 1
                        alteration=1 if fifths==1 and step=='F' else 0
                        candidates=[cc for cc in page.chars if cc['text'] in ['#','b','n'] and cc['fontname'].endswith('+OpusStd')
                            and 1<e['x']-cc['x0']<13 and abs((842-cc['matrix'][5])-e['y'])<.3]
                        if candidates:
                            cc=min(candidates,key=lambda cc:e['x']-cc['x0']);alteration={'#':1,'b':-1,'n':0}[cc['text']]
                            scopes[e['measure']][e['diatonic']]=alteration;e['accidental']=alteration
                        else:alteration=scopes[e['measure']].get(e['diatonic'],alteration)
                        e['alter']=alteration
                    # Text is digital. Keep separate lyric baselines/verses.
                    bottom_limit=staves[si+1][0]-5 if si+1<len(staves) else 835
                    chars=[c for c in runs[pi-1] if 'TimesNewRoman' in c['fontname'] and abs(c['size']-13.02)<.1 and staff[-1]+4<c['top']<bottom_limit]
                    elisions=[c for c in runs[pi-1] if 'OpusTextStd' in c['fontname'] and c['text']=='_' and abs(c['size']-13.02)<.1 and staff[-1]+4<c['top']<bottom_limit]
                    lines=[]
                    for c in sorted(chars+elisions,key=lambda c:(c['top'],c['x0'])):
                        # The engraver shifts single-line syllables several
                        # points vertically. Real parallel verses are farther
                        # apart; do not turn those shifts into extra verses.
                        match=next((line for line in lines if abs(line[0]['top']-c['top'])<7),None)
                        if match is None:lines.append([c])
                        else:match.append(c)
                    pitched=[e for e in row if not e['rest']]
                    for verse,line in enumerate(lines,1):
                        line.sort(key=lambda c:c['x0']);tokens=[];token=[]
                        def flush():
                            if token:tokens.append(dict(text=''.join(c['text'] for c in token),x=(token[0]['x0']+token[-1]['x1'])/2));token.clear()
                        for c in line:
                            if c['text'].isspace():flush();continue
                            if token and c['x0']-token[-1]['x1']>1.3:flush()
                            token.append(c)
                        flush()
                        for ti in range(len(tokens)-2,-1,-1):
                            if tokens[ti]['text']=='_' and ti>0 and ti+1<len(tokens):tokens[ti-1:ti+2]=[dict(text=tokens[ti-1]['text']+'_'+tokens[ti+1]['text'],x=tokens[ti]['x'])]
                        for t in tokens:
                            if t['text']=='rit.':continue  # Direction under the bass staff, not sung text.
                            if not pitched:lyric_issues.append((pi,si,t));continue
                            e=min(pitched,key=lambda n:abs(n['x']+3.3-t['x']))
                            distance=abs(e['x']+3.3-t['x'])
                            if distance>15:lyric_issues.append((pi,si,e['measure'],t,distance))
                            e['lyrics'].append(dict(verse=verse,**t))
                    events.extend(row)
            for curve in page.curves:
                if not any(p[0]=='c' for p in curve['path']):continue
                if curve['x1']-curve['x0']<3:continue
                points=curve['path'];start=points[0][1];end=next(p[-1] for p in points if p[0]=='c')
                arcs.append(dict(page=pi,start=start,end=end,stroke=curve['stroke']))
    totals=[]
    for key,row in sorted(collections.defaultdict(list, {k:[e for e in events if (e['role'],e['measure'])==k] for k in {(e['role'],e['measure']) for e in events}}).items()):
        q=0
        for e in row:e['onset']=q;q+=e['duration']
        if abs(q-length(key[1]))>.001:totals.append((key,q,length(key[1])))
    result=dict(events=events,systems=systems,arcs=arcs,issues=issues,invalidTotals=totals,lyricIssues=lyric_issues)
    (OUT/'pdf-reading.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print('events',len(events),'notes',sum(not e['rest'] for e in events),'systems',len(systems),'issues',issues[:20])
    print('invalid totals',totals[:40]);print('lyric issues',lyric_issues[:15])
if __name__=='__main__':extract()
