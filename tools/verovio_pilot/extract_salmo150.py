"""Direct digital-symbol reading; triplets cross-checked against source MIDI."""
from pathlib import Path
import collections,json,pdfplumber
from digital_text_runs import page_runs
from extract_alabad import staff_groups,beam_y,RESTS
OUT=Path('output/verovio_pilot_support/salmo150')
STARTS=[[1,6,10],[16,23,28],[33,38,42],[45,49,54],[59,63,68]]
LYRIC_FONT='AGaramondPro-Regular'
LYRIC_SIZE=12.09
USE_TUPLET_MARKERS=True
def key_signature(measure):return 2
def extract():
    runs=page_runs(OUT/'original.pdf');events=[];systems=[];issues=[];arcs=[];lyric_issues=[];tuplets=[]
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,page in enumerate(pdf.pages,1):
            staves=staff_groups(page);assert len(staves)==12
            for sysi,first in enumerate(STARTS[pi-1]):
                indexes=list(range(sysi*4,sysi*4+4))
                boundary=[l for l in page.lines if l['width']<.01 and abs(l['top']-staves[indexes[0]][0])<.4 and abs(l['bottom']-staves[indexes[0]][-1])<.4]
                hs=[l for l in page.lines if abs(l['top']-staves[indexes[0]][0])<.3 and l['width']>150]
                left=min(l['x0'] for l in hs);right=max(l['x1'] for l in hs)
                bars=sorted({left,right,*[round(l['x0'],3) for l in boundary]});bars=[x for i,x in enumerate(bars) if i==0 or x-bars[i-1]>4]
                expected=STARTS[pi-1][sysi+1] if sysi<2 else STARTS[pi][0] if pi<len(pdf.pages) else first+len(bars)-1
                if len(bars)-1==expected-first+1:
                    caution=[c for c in page.chars if c['fontname'].endswith('+OpusStd') and c['text'] in ['œ','˙','w',*RESTS] and c['x0']>bars[-2] and staves[indexes[0]][0]-25<842-c['matrix'][5]<staves[indexes[-1]][-1]+25]
                    if not caution:bars.pop()
                assert len(bars)-1==expected-first,(pi,first,bars,expected)
                systems.append(dict(page=pi,system=sysi,first=first,last=expected-1,roles=[0,1,2,3],bars=bars))
                for si,role in zip(indexes,range(4)):
                    staff=staves[si];base=18 if role==3 else 23 if role==2 else 30
                    def owner(c):return min(range(len(staves)),key=lambda i:abs((842-c['matrix'][5])-sum(staves[i])/5))
                    musical=[c for c in page.chars if c['fontname'].endswith('+OpusStd') and c['text'] in ['œ','˙','w',*RESTS] and owner(c)==si]
                    beams=[s for s in page.curves if s['fill'] and not any(p[0]=='c' for p in s['path'])]
                    beams += [dict(x0=s['x0'],x1=s['x1'],pts=[(s['x0'],s['top']),(s['x1'],s['top']),(s['x1'],s['bottom']),(s['x0'],s['bottom'])]) for s in page.rects if 1.5<s['height']<3.1]
                    row=[]
                    for c in musical:
                        x=c['x0'];y=842-c['matrix'][5];bin=sum(b<x+1 for b in bars)-1;m=first+bin
                        if not first<=m<expected:issues.append(('outside bar',pi,si,c['text'],x));continue
                        e=dict(role=role,page=pi,staff=si,system=sysi,measure=m,x=x,y=y,clef='F' if role==3 else 'G8' if role==2 else 'G',glyph=c['text'],lyrics=[],beams=0)
                        if c['text'] in RESTS:e['rest']=True;d=RESTS[c['text']] or 4
                        else:
                            e['rest']=False;e['diatonic']=base+round((staff[-1]-y)/2.48015)
                            if c['text']=='w':d=4
                            elif c['text']=='˙':d=2
                            else:
                                cx=x+3.3
                                stems=[l for l in page.lines if l['width']<.01 and abs(l['x0']-cx)<4 and l['height']>8 and min(abs(l['top']-y),abs(l['bottom']-y))<1.4]
                                if len(stems)!=1:issues.append(('stem',pi,si,m,x,len(stems)));continue
                                stem=stems[0];up=abs(stem['bottom']-y)<1.4;tip=stem['top'] if up else stem['bottom'];e['stem']='up' if up else 'down'
                                hits=[(bi,v) for bi,s in enumerate(beams) if (v:=beam_y(s,stem['x0'])) is not None and abs(v-tip)<9]
                                levels=len(hits)
                                if hits:e['beamGroup']=[pi,si,min(hits,key=lambda hit:abs(hit[1]-tip))[0]]
                                flags=[cc for cc in page.chars if cc['text'] in ['j','J','r','R'] and cc['fontname'].endswith('+OpusStd') and abs(cc['x0']-stem['x0'])<.6 and abs((842-cc['matrix'][5])-y)<30]
                                if flags:levels=max(levels,max(2 if cc['text'] in ['r','R'] else 1 for cc in flags))
                                d=1/2**levels;e['beams']=levels
                        dots=[cc for cc in page.chars if cc['text']=='.' and cc['fontname'].endswith('+OpusStd') and 6<cc['x0']-x<14 and abs((842-cc['matrix'][5])-y)<3]
                        if dots:d*=2-2**(-len(dots));e['dot']=True;e['dotCount']=len(dots)
                        e['duration']=d;e['writtenDuration']=d;row.append(e)
                    row.sort(key=lambda e:e['x'])
                    grouped=collections.defaultdict(list)
                    for e in row:
                        if 'beamGroup' in e:grouped[tuple(e['beamGroup'])].append(e)
                    markers=[c for c in page.chars if USE_TUPLET_MARKERS and 'OpusTextStd' in c['fontname'] and c['text']=='3' and owner(c)==si]
                    for c in markers:
                        x=(c['x0']+c['x1'])/2
                        groups=[g for g in grouped.values() if len(g)==3 and all(e['writtenDuration']==.5 for e in g)]
                        if not groups:issues.append(('triplet no group',pi,si,x));continue
                        g=min(groups,key=lambda g:abs((g[0]['x']+g[-1]['x'])/2+3.3-x))
                        dx=abs((g[0]['x']+g[-1]['x'])/2+3.3-x)
                        if dx>15:issues.append(('triplet too far',pi,si,x,dx));continue
                        for e in g:e['duration']=1/3;e['tuplet']=True
                        tuplets.append((role,g[0]['measure'],[e['x'] for e in g]))
                    scopes=collections.defaultdict(dict)
                    for e in row:
                        if e['rest']:continue
                        step='CDEFGAB'[e['diatonic']%7];fifths=key_signature(e['measure'])
                        alteration=1 if fifths>0 and step in 'FCGDAEB'[:fifths] else -1 if fifths<0 and step in 'BEADGCF'[:-fifths] else 0
                        candidates=[cc for cc in page.chars if cc['text'] in ['#','b','n'] and cc['fontname'].endswith('+OpusStd') and 1<e['x']-cc['x0']<13 and abs((842-cc['matrix'][5])-e['y'])<.3]
                        if candidates:
                            cc=min(candidates,key=lambda cc:e['x']-cc['x0']);alteration={'#':1,'b':-1,'n':0}[cc['text']];scopes[e['measure']][e['diatonic']]=alteration;e['accidental']=alteration
                        else:alteration=scopes[e['measure']].get(e['diatonic'],alteration)
                        e['alter']=alteration
                        # Small dots above/below a note are articulation, not augmentation.
                        if any(cc['text']=='.' and cc['fontname'].endswith('+OpusStd') and abs(cc['x0']-(e['x']+3.3))<2 and 5<abs((842-cc['matrix'][5])-e['y'])<35 for cc in page.chars):e['staccato']=True
                    bottom=staves[si+1][0]-5 if si+1<len(staves) else 835
                    chars=[c for c in runs[pi-1] if LYRIC_FONT in c['fontname'] and abs(c['size']-LYRIC_SIZE)<.2 and staff[-1]+4<c['top']<bottom]
                    chars += [c for c in runs[pi-1] if 'OpusTextStd' in c['fontname'] and c['text']=='_' and staff[-1]+4<c['top']<bottom]
                    line=sorted(chars,key=lambda c:c['x0']);tokens=[];token=[]
                    def flush():
                        if token:
                            value=''.join(c['text'] for c in token)
                            # Printed adjacent syllables overlap in a few places.
                            # Split at their real character coordinates.
                            cuts=[4] if value=='Diosde' else [3] if value=='sí,al' else [4] if value.startswith('be_aDios') else []
                            for start,end in zip([0]+cuts,cuts+[len(token)]):
                                chunk=token[start:end];word=''.join(c['text'] for c in chunk)
                                tokens.append(dict(text='a' if word=='aA' else word,x=(chunk[0]['x0']+chunk[-1]['x1'])/2))
                            token.clear()
                    for c in line:
                        if c['text'].isspace():flush();continue
                        if token and c['x0']-token[-1]['x1']>1.3:flush()
                        token.append(c)
                    flush()
                    pitched=[e for e in row if not e['rest']]
                    for t in tokens:
                        e=min(pitched,key=lambda n:abs(n['x']+3.3-t['x']));distance=abs(e['x']+3.3-t['x'])
                        if distance>15:lyric_issues.append((pi,si,e['measure'],t,distance))
                        e['lyrics'].append(dict(verse=1,**t))
                    events.extend(row)
            for curve in page.curves:
                if not any(p[0]=='c' for p in curve['path']) or curve['x1']-curve['x0']<3:continue
                points=curve['path'];arcs.append(dict(page=pi,start=points[0][1],end=next(p[-1] for p in points if p[0]=='c'),stroke=curve['stroke']))
    totals=[]
    for key in sorted({(e['role'],e['measure']) for e in events}):
        row=[e for e in events if (e['role'],e['measure'])==key];q=0
        for e in row:e['onset']=q;q+=e['duration']
        if abs(q-4)>.001:totals.append((key,q))
    result=dict(events=events,systems=systems,arcs=arcs,issues=issues,invalidTotals=totals,lyricIssues=lyric_issues,tuplets=tuplets)
    (OUT/'pdf-reading.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print('notes',sum(not e['rest'] for e in events),'measures',systems[-1]['last'],'tuplets',len(tuplets),'issues',issues[:20],'invalid',totals[:40],'lyric issues',lyric_issues[:20])
    for role in range(4):print('LYRICS',role,' '.join(l['text'] for e in events if e['role']==role for l in e['lyrics']))
if __name__=='__main__':extract()
