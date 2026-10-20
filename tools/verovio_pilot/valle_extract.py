"""Extract actual digital notehead/lyric coordinates from the open app PDF."""
from pathlib import Path
import collections,json
import pdfplumber
from digital_text_runs import page_runs

OUT=Path('output/verovio_pilot_support/valle')
def extract():
    voices=[[] for _ in range(4)]
    systems=[]
    runs=page_runs(OUT/'original-2.pdf')
    with pdfplumber.open(OUT/'original-2.pdf') as pdf:
        for pi,page in enumerate(pdf.pages[1:],2):
            horizontal=sorted({round(e['top'],2) for e in page.edges
                if abs(e['top']-e['bottom'])<.1 and e['x1']-e['x0']>100})
            staves=[]
            for y in horizontal:
                if staves and y<=staves[-1][-1]+1:continue
                group=[min(horizontal,key=lambda v:abs(v-(y+4.26*i))) for i in range(5)]
                if all(abs(v-(y+4.26*i))<.18 for i,v in enumerate(group)):
                    staves.append(group)
            assert len(staves)%4==0,(pi,staves)
            notes=[[] for _ in staves]
            for c in page.chars:
                if c['text'] not in ['\uf0cf','\uf0fa','\uf077'] or '+Opus' not in c['fontname']:continue
                y=c['top']+c['size']*.359
                si=min(range(len(staves)),key=lambda i:abs(y-sum(staves[i])/5))
                base=18 if si%4==3 else 23 if si%4==2 else 30
                diatonic=base+round((staves[si][-1]-y)/2.13)
                notes[si].append(dict(x=(c['x0']+c['x1'])/2,y=y,diatonic=diatonic,glyph=hex(ord(c['text'])),page=pi,staff=si,syllables=[]))
            for si,staff in enumerate(staves):
                row=sorted(notes[si],key=lambda n:(n['x'],n['y']))
                baseline=staff[-1]+9.2
                chars=sorted([c for c in runs[pi-1] if abs(c['top']-baseline)<1.6 and abs(c['size']-9.83918)<.05
                    and ('TimesNewRoman' in c['fontname'] or 'OpusText' in c['fontname'])],key=lambda c:c['x0'])
                tokens=[];token=[]
                def flush():
                    if token:
                        tokens.append(dict(text=''.join(c['text'] for c in token),x=(token[0]['x0']+token[-1]['x1'])/2))
                        token.clear()
                for c in chars:
                    if c['text'].isspace() or c['text']=='-':
                        flush()
                        if c['text']=='-':tokens.append(dict(text='-',x=(c['x0']+c['x1'])/2))
                    else:
                        if token and (c['run']!=token[-1]['run'] or c['x0']-token[-1]['x1']>1.6):flush()
                        token.append(c)
                flush()
                # Elisions are separate text objects in the source PDF.
                for ti in range(len(tokens)-2,-1,-1):
                    if tokens[ti]['text']=='_' and ti>0 and ti+1<len(tokens):
                        tokens[ti-1:ti+2]=[dict(text=tokens[ti-1]['text']+'_'+tokens[ti+1]['text'],x=tokens[ti]['x'])]
                for ti,t in enumerate(tokens):
                    if t['text']=='-':continue
                    prev=ti>0 and tokens[ti-1]['text']=='-'
                    nxt=ti+1<len(tokens) and tokens[ti+1]['text']=='-'
                    t['syllabic']='middle' if prev and nxt else 'end' if prev else 'begin' if nxt else 'single'
                    note=min(row,key=lambda n:abs(n['x']-t['x']))
                    t['distance']=round(abs(note['x']-t['x']),3)
                    note['syllables'].append(t)
                systems.append(dict(page=pi,staff=si,role=si%4,notes=len(row),syllables=len([t for t in tokens if t['text']!='-']),text=' '.join(t['text'] for t in tokens)))
                voices[si%4].extend(row)
    (OUT/'pdf-note-lyrics.json').write_text(json.dumps(voices,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'pdf-systems.json').write_text(json.dumps(systems,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Notes by role',[len(v) for v in voices])
    print('First lines',json.dumps(systems[:4],ensure_ascii=False))
    print('Multiple tokens per note',sum(len(n['syllables'])>1 for v in voices for n in v))
    return voices,systems
if __name__=='__main__':extract()
