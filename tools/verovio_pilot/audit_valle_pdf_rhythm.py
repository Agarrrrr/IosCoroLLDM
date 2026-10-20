"""Read bass durations/rest placement from digital PDF graphics, not MIDI."""
from pathlib import Path
import collections,json,math,xml.etree.ElementTree as E
import pdfplumber

OUT=Path('output/verovio_pilot_support/valle')
RESTS={'\uf0b7':4,'\uf0ee':2,'\uf0ce':1,'\uf0e4':.5,'\uf0c5':.25}
FLAGS={'\uf06a':1,'\uf04a':1,'\uf072':2,'\uf052':2}
def staff_groups(page):
    ys=sorted({round(e['top'],2) for e in page.edges if abs(e['top']-e['bottom'])<.1 and e['x1']-e['x0']>100})
    result=[]
    for y in ys:
        if result and y<=result[-1][-1]+1:continue
        group=[min(ys,key=lambda v:abs(v-(y+4.26*i))) for i in range(5)]
        if all(abs(v-(y+4.26*i))<.18 for i,v in enumerate(group)):result.append(group)
    return result
def beam_y(shape,x):
    if x<shape['x0']-.3 or x>shape['x1']+.3:return None
    x=min(shape['x1']-.0001,max(shape['x0']+.0001,x));ys=[]
    pts=shape['pts']
    for a,b in zip(pts,pts[1:]+pts[:1]):
        if abs(a[0]-b[0])<.000001:continue
        if min(a[0],b[0])<=x<=max(a[0],b[0]):ys.append(a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0]))
    if len(ys)<2:return None
    if not 1.5<max(ys)-min(ys)<2.6:return None
    return (min(ys)+max(ys))/2
def read(path=OUT/'Valle de los Huesos Secos - SATB con letra.musicxml'):
    root=E.parse(path).getroot()
    part=root.findall('part')[3]
    source=[(int(m.get('number')),n) for m in part.findall('measure') for n in m.findall('note') if n.find('pitch') is not None]
    heads=json.loads((OUT/'pdf-note-lyrics.json').read_text(encoding='utf-8'))[3]
    groups=collections.defaultdict(list)
    for i,((measure,n),head) in enumerate(zip(source,heads)):
        groups[(head['page'],head['staff'])].append((i,measure,n,head))
    # Include systems where bass is silent, using the other printed staves to
    # determine the first numbered bar without consulting MIDI timings.
    all_heads=json.loads((OUT/'pdf-note-lyrics.json').read_text(encoding='utf-8'))
    references=collections.defaultdict(list)
    for role,p in enumerate(root.findall('part')):
        ns=[(int(m.get('number')),n) for m in p.findall('measure') for n in m.findall('note') if n.find('pitch') is not None]
        for (measure,n),h in zip(ns,all_heads[role]):
            key=(h['page'],h['staff']//4*4+3)
            references[key].append((measure,h))
            groups.setdefault(key,[])
    measures=collections.defaultdict(list);issues=[];note_diffs=[]
    with pdfplumber.open(OUT/'original-2.pdf') as pdf:
        for (pi,si),rows in groups.items():
            page=pdf.pages[pi-1];staves=staff_groups(page);staff=staves[si]
            bars=sorted({round(l['x0'],3) for l in page.lines if abs(l['x1']-l['x0'])<.01
                and abs(l['top']-staff[0])<.3 and abs(l['bottom']-staff[-1])<.3})
            # A stem can span exactly one staff. A real barline must recur at
            # the same x on at least three staves in this four-staff system.
            peers=staves[si//4*4:si//4*4+4]
            bars=[x for x in bars if sum(any(abs(l['x0']-x)<.3 and l['width']<.01
                and abs(l['top']-s[0])<.3 and abs(l['bottom']-s[-1])<.3 for l in page.lines) for s in peers)>=3]
            horizontal=[l for l in page.lines if abs(l['top']-staff[0])<.3 and l['width']>100]
            left=min(l['x0'] for l in horizontal);right=max(l['x1'] for l in horizontal)
            bars=sorted({left,right,*bars})
            bars=[x for j,x in enumerate(bars) if j==0 or x-bars[j-1]>1]
            assert len(bars)>1,(pi,si)
            # Every system begins and ends with a barline. Check against all
            # note/measure correspondences instead of assuming bar numbering.
            first_measure,first_head=min(references[(pi,si)],key=lambda e:e[1]['x'])
            first_bin=sum(x<first_head['x'] for x in bars)-1
            offset=first_measure-1-first_bin
            for i,m,n,h in rows:
                b=sum(x<h['x'] for x in bars)-1
                if offset+b+1!=m:issues.append(('bar assignment',pi,si,i,m,offset+b+1))
            beams=[s for s in page.curves if s['fill'] and not any(p[0]=='c' for p in s['path'])]
            beams += [dict(x0=s['x0'],x1=s['x1'],pts=[(s['x0'],s['top']),(s['x1'],s['top']),(s['x1'],s['bottom']),(s['x0'],s['bottom'])])
                for s in page.rects if 1.5<s['height']<2.6]
            for i,m,n,h in rows:
                if h['glyph']=='0xf077':d=4;levels=0
                elif h['glyph']=='0xf0fa':d=2;levels=0
                else:
                    stems=[l for l in page.lines if abs(l['x1']-l['x0'])<.01 and abs(l['x0']-h['x'])<4
                        and l['height']>8 and min(abs(l['top']-h['y']),abs(l['bottom']-h['y']))<1.2]
                    if len(stems)!=1:
                        issues.append(('stems',i,m,len(stems)));continue
                    stem=stems[0];tip=stem['bottom'] if abs(stem['top']-h['y'])<1.2 else stem['top']
                    ys=[y for s in beams if (y:=beam_y(s,stem['x0'])) is not None and abs(y-tip)<8]
                    levels=len(ys)
                    flags=[c for c in page.chars if c['text'] in FLAGS and c['fontname'].endswith('+Opus') and abs(c['x0']-stem['x0'])<.5
                        and abs(c['top']+c['size']*.359-h['y'])<35]
                    if flags:levels=max(levels,max(FLAGS[c['text']] for c in flags))
                    if levels>2:issues.append(('beam levels',i,m,levels))
                    d=1/(2**levels)
                # Augmentation dots are a separate OpusSpecial glyph.
                dots=[c for c in page.chars if c['text']=='\uf0aa' and 3<c['x0']-h['x']<10
                    and abs(c['top']+c['size']*.479-h['y'])<5]
                if dots:d*=1.5
                actual=int(n.findtext('duration'))/480
                event=dict(kind='N',index=i,measure=m,x=h['x'],duration=d,xmlDuration=actual,levels=levels,page=pi,staff=si)
                measures[m].append(event)
                if abs(d-actual)>.001:note_diffs.append(event)
            for c in page.chars:
                if c['text'] not in RESTS or not c['fontname'].endswith('+Opus'):continue
                y=c['top']+c['size']*.359
                owner=min(range(len(staves)),key=lambda s:abs(y-sum(staves[s])/5))
                if owner!=si:continue
                x=(c['x0']+c['x1'])/2;b=sum(xx<x for xx in bars)-1;m=offset+b+1
                measures[m].append(dict(kind='R',x=x,duration=RESTS[c['text']],glyph=hex(ord(c['text'])),page=pi,staff=si))
    # Bars 14/15 omit a rest symbol in the bass PDF itself. Its vacant time
    # column is explicit in the other staves. Read that printed sixteenth-rest
    # column and verify that every bass note aligns with soprano before using it.
    for m in [14,15]:
        bass=sorted([e for e in measures[m] if e['kind']=='N'],key=lambda e:e['x'])
        soprano=[h for (measure,n),h in zip(
            [(int(mm.get('number')),nn) for mm in root.findall('part')[0].findall('measure') for nn in mm.findall('note') if nn.find('pitch') is not None],all_heads[0]) if measure==m]
        assert len(bass)==len(soprano)==8
        assert all(abs(b['x']-s['x'])<.3 for b,s in zip(bass,soprano))
        page=pdfplumber.open(OUT/'original-2.pdf')
        try:
            pg=page.pages[bass[0]['page']-1];ss=staff_groups(pg)[soprano[0]['staff']]
            symbols=[c for c in pg.chars if c['text']=='\uf0c5' and c['fontname'].endswith('+Opus')
                and bass[2]['x']<c['x0']<bass[3]['x'] and abs(c['top']+c['size']*.359-sum(ss)/5)<6]
            assert len(symbols)==1,(m,symbols)
            c=symbols[0]
            measures[m].append(dict(kind='R',x=(c['x0']+c['x1'])/2,duration=.25,
                evidence='unprinted bass rest inferred from identical SATB columns and printed soprano sixteenth rest',page=bass[0]['page']))
        finally:page.close()
    rhythm_diffs=[];totals=[]
    for m,events in sorted(measures.items()):
        events.sort(key=lambda e:e['x']);q=0
        for e in events:e['onset']=q;q+=e['duration']
        if abs(q-4)>.001:totals.append((m,q))
        original=[];q0=0
        for n in part.findall('measure')[m-1].findall('note'):
            original.append(('N' if n.find('pitch') is not None else 'R',q0,int(n.findtext('duration'))/480));q0+=int(n.findtext('duration'))/480
        found=[(e['kind'],e['onset'],e['duration']) for e in events]
        if found!=original:rhythm_diffs.append(dict(measure=m,pdf=found,xml=original))
    result=dict(noteCount=sum(e['kind']=='N' for ev in measures.values() for e in ev),issues=issues,invalidTotals=totals,noteDurationDifferences=note_diffs,rhythmDifferences=rhythm_diffs,measures=measures)
    (OUT/'pdf-bass-rhythm-audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print('notes',result['noteCount'],'issues',issues[:15],'invalid totals',totals[:20])
    print('duration differences',[(e['index'],e['measure'],e['duration'],e['xmlDuration'],e['levels']) for e in note_diffs[:30]])
    print('rhythm differences',[d['measure'] for d in rhythm_diffs])
    return result
if __name__=='__main__':read()
