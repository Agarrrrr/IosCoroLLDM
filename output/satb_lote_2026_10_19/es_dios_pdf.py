"""Read the official one-page Es Dios PDF as the authoritative notation."""
import sys,collections,json,copy,xml.etree.ElementTree as E
from fractions import Fraction as F
from pathlib import Path
import pdfplumber
sys.path.insert(0,str(Path('tools/verovio_pilot').resolve()))
from extract_cantico_moises import beam_y
from digital_text_runs import page_runs
OUT=Path(__file__).resolve().parent/'16'
FIRSTS=[1,6,11,17,22,26,31]

def run():
    events=[];systems=[];issues=[]
    with pdfplumber.open(OUT/'partitura.pdf') as pdf:
        p=pdf.pages[0].dedupe_chars(tolerance=.1);height=p.height
        for c in p.chars:
            if '+Opus' in c['fontname'] and len(c['text'])==1 and ord(c['text'])>=0xf000:
                c['text']={0xcf:'œ',0xfa:'˙',0xe4:'‰'}.get(ord(c['text'])-0xf000,chr(ord(c['text'])-0xf000))
        ys=sorted({round(l['top'],3) for l in p.edges if abs(l['top']-l['bottom'])<.1 and l['width']>100})
        staves=[]
        for y in ys:
            if staves and y<=staves[-1][-1]+1:continue
            g=[min(ys,key=lambda v:abs(v-y-4.8*i)) for i in range(5)]
            if all(abs(v-y-4.8*i)<.2 for i,v in enumerate(g)):staves.append(g)
        assert len(staves)==12,len(staves)
        beams=[s for s in p.curves if s['fill'] and not any(a[0]=='c' for a in s['path'])]
        beams += [dict(x0=s['x0'],x1=s['x1'],pts=[(s['x0'],s['top']),(s['x1'],s['top']),(s['x1'],s['bottom']),(s['x0'],s['bottom'])]) for s in p.rects if 1.4<s['height']<3.1]
        for si,first in enumerate(FIRSTS[:-1]):
            upper,lower=staves[si*2:si*2+2];nxt=FIRSTS[si+1]
            horizontals=[l for l in p.lines if abs(l['top']-upper[0])<.2 and l['width']>100];left=min(l['x0'] for l in horizontals);right=max(l['x1'] for l in horizontals)
            bars=sorted({round(left,3),round(right,3),*[round(l['x0'],3) for l in p.lines if l['width']<.1 and abs(l['top']-upper[0])<.2 and abs(l['bottom']-upper[-1])<.2]})
            bars=[b for j,b in enumerate(bars) if j==0 or b-bars[j-1]>4]
            assert len(bars)-1==nxt-first,(first,bars,nxt)
            systems.append(dict(first=first,last=nxt-1,bars=bars,staves=[upper,lower]))
            for role,staff in enumerate([upper,lower]):
                def owner(c):return min(range(12),key=lambda k:abs(height-c['matrix'][5]-sum(staves[k])/5))
                notes=[c for c in p.chars if c['fontname'].endswith('+Opus') and c['text'] in ['œ','˙','‰'] and owner(c)==si*2+role]
                grouped=collections.defaultdict(list)
                for c in notes:grouped[round(c['x0'],2)].append(c)
                accidental={}
                for x,chars in sorted(grouped.items()):
                    m=first+sum(b<x+1 for b in bars)-1
                    if not first<=m<nxt:issues.append(('outside',m,x));continue
                    heads=[c for c in chars if c['text']!='‰'];d=F(1,2);levels=1;stem=None;dots=0
                    if heads:
                        ypos=[height-c['matrix'][5] for c in heads]
                        if heads[0]['text']=='˙':d=F(2);levels=0
                        else:
                            stems=[l for l in p.lines if l['width']<.01 and abs(l['x0']-(x+3.1))<4 and l['height']>8 and min(abs(l['top']-y) for y in ypos)+0>=0 and min(min(abs(l['top']-y),abs(l['bottom']-y)) for y in ypos)<1.5]
                            stems=list({(round(l['x0'],2),round(l['top'],2),round(l['bottom'],2)):l for l in stems}.values())
                            if not stems:issues.append(('stem',m,x));continue
                            stem=min(stems,key=lambda l:min(min(abs(l['top']-y),abs(l['bottom']-y)) for y in ypos));up=min(abs(stem['bottom']-y) for y in ypos)<1.5;tip=stem['top'] if up else stem['bottom']
                            hits=[(j,v) for j,b in enumerate(beams) if (v:=beam_y(b,stem['x0'])) is not None and abs(v-tip)<8]
                            flags=[c for c in p.chars if c['text'] in ['j','J'] and c['fontname'].endswith('+Opus') and abs(c['x0']-stem['x0'])<.6 and min(abs(height-c['matrix'][5]-y) for y in ypos)<30]
                            levels=max(len(hits),1 if flags else 0);d=F(1,2**levels)
                        dots=[c for c in p.chars if c['text']=='.' and c['fontname'].endswith('+Opus') and 6<c['x0']-x<14 and min(abs(height-c['matrix'][5]-y) for y in ypos)<3]
                        if dots:d*=F(3,2)
                    for c in chars:
                        y=height-c['matrix'][5];rest=c['text']=='‰';e=dict(role=role,measure=m,x=x,y=y,rest=rest,duration=str(d),glyph=c['text'],dot=bool(dots),lyrics=[])
                        if not rest:
                            dia=(30 if role==0 else 18)+round((staff[-1]-y)/2.4);step='CDEFGAB'[dia%7];alter=1 if step in 'FC' else 0
                            acc=[cc for cc in p.chars if cc['text'] in ['#','n','b'] and cc['fontname'].endswith('+Opus') and 1<x-cc['x0']<14 and abs(height-cc['matrix'][5]-y)<.4]
                            if acc:alter={'#':1,'b':-1,'n':0}[max(acc,key=lambda a:a['x0'])['text']];accidental[m,dia]=alter;e['accidental']=alter
                            else:alter=accidental.get((m,dia),alter)
                            e.update(diatonic=dia,alter=alter,pitch=12*(dia//7+1)+[0,2,4,5,7,9,11][dia%7]+alter)
                        events.append(e)
                # Each geometric lyric line is retained as its original verse.
                bottom=lower[0]-5 if role==0 else staves[(si+1)*2][0]-10 if si<5 else p.height
                chars=[c for c in p.chars if ('TimesNewRoman' in c['fontname'] or 'OpusText' in c['fontname']) and abs(c['size']-11.52)<.2 and staff[-1]+4<c['top']<bottom]
                lines=[]
                for c in sorted(chars,key=lambda c:(c['top'],c['x0'])):
                    line=next((l for l in lines if abs(l[0]['top']-c['top'])<4),None)
                    if line is None:lines.append([c])
                    else:line.append(c)
                for verse,line in enumerate(lines,1):
                    tokens=[];token=[]
                    for c in sorted(line,key=lambda c:c['x0']):
                        if c['text'].isspace() or c['text']=='-' or token and c['x0']-token[-1]['x1']>1.5:
                            if token:tokens.append(token);token=[]
                            if c['text'].isspace() or c['text']=='-':continue
                        token.append(c)
                    if token:tokens.append(token)
                    for token in tokens:
                        value=''.join(c['text'] for c in token);cx=(token[0]['x0']+token[-1]['x1'])/2
                        candidates=[e for e in events if e['role']==role and first<=e['measure']<nxt and not e['rest']]
                        e=min(candidates,key=lambda e:abs(e['x']+3.1-cx));same=[a for a in candidates if a['x']==e['x']]
                        for a in same:a['lyrics'].append(dict(verse=verse,text=value))
        totals=[]
        for role in range(2):
            for m in range(1,31):
                row=[e for e in events if e['role']==role and e['measure']==m];q=F(0);lastx=None
                for e in row:
                    if e['x']!=lastx:onset=q;q+=F(e['duration'])
                    e['onset']=str(onset);lastx=e['x']
                if q!=(F(3,2) if m==1 else F(3)):totals.append((role,m,str(q)))
        result=dict(events=events,systems=systems,issues=issues,invalidTotals=totals)
        (OUT/'pdf-reading.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
        print('notes',sum(not e['rest'] for e in events),'issues',issues,'totals',totals)
if __name__=='__main__':run()
