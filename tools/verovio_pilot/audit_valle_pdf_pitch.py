"""Independent chromatic reading of the digital PDF (no MIDI input)."""
from pathlib import Path
import collections,json,xml.etree.ElementTree as E
import pdfplumber

OUT=Path('output/verovio_pilot_support/valle')
XML=OUT/'Valle de los Huesos Secos - SATB con letra.musicxml'
def read(path=XML):
    root=E.parse(path).getroot()
    voices=json.loads((OUT/'pdf-note-lyrics.json').read_text(encoding='utf-8'))
    changes=[];checked=[];ambiguous=[];keys=[]
    with pdfplumber.open(OUT/'original-2.pdf') as pdf:
        for role,part in enumerate(root.findall('part')):
            notes=[(int(m.get('number')),n) for m in part.findall('measure') for n in m.findall('note') if n.find('pitch') is not None]
            scope={};previous=None;last_measure=0;system_keys={};assigned={}
            for index,((measure,n),head) in enumerate(zip(notes,voices[role])):
                page=pdf.pages[head['page']-1];system=(head['page'],head['staff'])
                # Locate the staff's clef, then its contiguous signature flats.
                if system not in system_keys:
                    candidates=[c for c in page.chars if c['text']==('\uf03f' if role==3 else '\uf026') and c['x0']<120]
                    same=[v for v in voices[role] if (v['page'],v['staff'])==system]
                    mean_y=sum(v['y'] for v in same)/len(same)
                    clef=min(candidates,key=lambda c:abs(c['top']-mean_y))
                    # Accidental glyphs are centred on the staff note position.
                    # Signature starts immediately after the clef, at ~4.8pt
                    # spacing; an individual accidental is separated by a gap.
                    flats=sorted([c for c in page.chars if c['text']=='\uf062' and c['fontname'].endswith('+Opus')
                        and clef['x0']+10<c['x0']<clef['x0']+45 and abs(c['top']-clef['top'])<20],key=lambda c:c['x0'])
                    run=[]
                    for c in flats:
                        if run and not 4.3<c['x0']-run[-1]['x0']<5.2:break
                        run.append(c)
                    assert len(run) in [4,5],(role,system,len(run))
                    system_keys[system]=-len(run)
                    keys.append(dict(role=role,page=system[0],staff=system[1],firstMeasure=measure,fifths=-len(run)))
                fifths=system_keys[system];flat_steps=set('BEADG'[:abs(fifths)])
                if measure!=last_measure:scope={};last_measure=measure
                step=n.findtext('pitch/step');diatonic=head['diatonic']
                choices=[]
                for ci,c in enumerate(page.chars):
                    if c['text'] not in ['\uf062','\uf06e'] or not c['fontname'].endswith('+Opus'):continue
                    cy=c['top']+c['size']*.359
                    if abs(cy-head['y'])<.4 and 1<head['x']-c['x0']<12:
                        choices.append((head['x']-c['x0'],ci,c))
                explicit=None
                if choices:
                    _,ci,c=min(choices,key=lambda c:c[0])
                    if (head['page'],ci) in assigned:ambiguous.append((role,index,'accidental reused'))
                    assigned[(head['page'],ci)]=index
                    explicit=-1 if c['text']=='\uf062' else 0
                    scope[diatonic]=explicit
                alter=scope.get(diatonic,-1 if step in flat_steps else 0)
                # A tied continuation keeps its pitch across a barline.
                if explicit is None and n.find("tie[@type='stop']") is not None:
                    assert previous is not None and previous['diatonic']==diatonic
                    alter=previous['pdfAlter']
                actual=int(n.findtext('pitch/alter','0'))
                row=dict(role=role,index=index,id=n.get('id'),measure=measure,step=step,
                    octave=int(n.findtext('pitch/octave')),xmlAlter=actual,pdfAlter=alter,diatonic=diatonic,
                    explicit=explicit,page=head['page'],staff=head['staff'],fifths=fifths)
                checked.append(row)
                if actual!=alter:changes.append(row)
                previous=row
    report=dict(checked=len(checked),changes=changes,ambiguous=ambiguous,keys=keys)
    (OUT/'pdf-pitch-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('Chromatic PDF notes checked',len(checked),'differences',len(changes),'ambiguous',ambiguous)
    print('Key transitions',[(k['role'],k['firstMeasure'],k['fifths']) for i,k in enumerate(keys) if i==0 or keys[i-1]['role']!=k['role'] or keys[i-1]['fifths']!=k['fifths']])
    print('Bass differences',json.dumps([x for x in changes if x['role']==3]))
    return report
if __name__=='__main__':read()
