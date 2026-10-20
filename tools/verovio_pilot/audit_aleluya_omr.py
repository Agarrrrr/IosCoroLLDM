"""OMR is a cross-check, never the musical authority."""
import json,xml.etree.ElementTree as E
from aleluya_model import OUT
def run():
    root=E.parse(OUT/'omr-reading.musicxml').getroot();result=[];notes=[]
    for role,p in enumerate(root.findall('part')):
        div=1
        for mi,m in enumerate(p.findall('measure'),1):
            div=int(m.findtext('attributes/divisions',str(div)));cursor=0;last=0
            for n in m:
                if n.tag in ['backup','forward']:cursor+=int(n.findtext('duration'))/div*(-1 if n.tag=='backup' else 1)
                if n.tag!='note':continue
                dur=int(n.findtext('duration','0'))/div;start=last if n.find('chord') is not None else cursor
                if n.find('pitch') is not None:
                    step=n.findtext('pitch/step');alt=int(n.findtext('pitch/alter','0'));octave=int(n.findtext('pitch/octave'));pitch=(octave+1)*12+dict(C=0,D=2,E=4,F=5,G=7,A=9,B=11)[step]+alt
                    notes.append(dict(role=role,measure=mi,onset=start,pitch=pitch,step=step,alter=alt,octave=octave,duration=dur,lyric=n.findtext('lyric/text'),slurs=[dict(x.attrib) for x in n.findall('notations/slur')]))
                if n.find('chord') is None:last=cursor;cursor+=dur
    source=json.loads((OUT/'source-events.json').read_text());mismatch=[];matched=0
    # OMR inconsistently recognises the octave-transposing tenor clef.
    for bar in range(1,71):
        row=[n for n in notes if n['role']==2 and n['measure']==bar];ref=[e for e in source if e['role']==2 and e['measure']==bar and not e.get('rest')]
        def score(delta):return sum(any(abs(n['onset']-e['onset'])<.02 and n['pitch']+delta==e['pitch'] for e in ref) for n in row)
        delta=max([0,-12,12],key=score)
        for n in row:n['pitch']+=delta;n['octave']+=delta//12
    for e in source:
        if e.get('rest'):continue
        near=[n for n in notes if (n['role'],n['measure'])==(e['role'],e['measure']) and abs(n['onset']-e['onset'])<.02]
        if any(n['pitch']==e['pitch'] for n in near):matched+=1
        else:mismatch.append(dict(reference=e,omr=near))
    report=dict(matched=matched,mismatch=mismatch,omrNotes=notes)
    (OUT/'omr-comparison.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Matched',matched,'differences',len(mismatch));print([(x['reference']['role'],x['reference']['measure'],x['reference']['onset'],x['reference']['pitch'],[(n['pitch'],n['duration']) for n in x['omr']]) for x in mismatch])
if __name__=='__main__':run()
