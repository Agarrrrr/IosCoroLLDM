"""Check complete bars, source pitches, same-part ties and the MIDI Alto addition."""
from pathlib import Path
from collections import Counter
import json,xml.etree.ElementTree as E
from extract_alabad import OUT,length
source=OUT/'Alabad a Jehová - SATB revisado contra PDF.musicxml'
root=E.parse(source).getroot();original=json.loads((OUT/'arcs-reading.json').read_text(encoding='utf-8'))
midi=json.loads((OUT/'midi-comparison.json').read_text(encoding='utf-8'))
def pitch(n):
    p=n.find('pitch')
    return 12*(int(p.findtext('octave'))+1)+dict(C=0,D=2,E=4,F=5,G=7,A=9,B=11)[p.findtext('step')]+int(p.findtext('alter','0'))
errors=[];by_id={};ties=0;alto=[]
for role,p in enumerate(root.findall('part')):
    assert len(p.findall('measure'))==138
    opened={}
    for m in p.findall('measure'):
        number=int(m.get('number'));q=0
        for n in m.findall('note'):
            duration=int(n.findtext('duration'))/480
            if n.find('pitch') is not None:
                value=pitch(n);kinds=[t.get('type') for t in n.findall('tie')]
                if 'stop' in kinds:
                    if value not in opened:errors.append(('tie stop without start',role,number,value))
                    else:opened.pop(value)
                if 'start' in kinds:
                    if value in opened:errors.append(('overlapping tie',role,number,value))
                    opened[value]=number;ties+=1
                if opened and value not in opened:errors.append(('tie interrupted by other note',role,number))
                by_id[n.get('id')]=(role,number,q,value)
                if role==1 and 80<=number<=93 and 'stop' not in kinds:alto.append((257+(number-80)*3+q if number<=92 else 296+q,value))
            elif opened:errors.append(('tie interrupted by rest',role,number))
            q+=duration
        if q!=length(number):errors.append(('bar duration',role,number,q))
    if opened:errors.append(('unclosed ties',role,opened))
for n in original['notes']:
    role,number,onset,value=by_id[n['id']]
    expected=12*(n['diatonic']//7+1)+[0,2,4,5,7,9,11][n['diatonic']%7]+n['alter']
    if value!=expected:errors.append(('changed PDF pitch',n['id'],value,expected))
    expected_role=2 if n['id']=='alabad-3-28' else n['role']
    if role!=expected_role:errors.append(('changed PDF voice',n['id'],role,expected_role))
actual=[(n['ticks']/midi['ppq'],n['pitch']) for n in midi['tracks'][1]['notes'] if 257<=n['ticks']/midi['ppq']<300]
if alto!=actual:errors.append(('Alto differs from MIDI',alto,actual))
def musical_content(score):
    result=[]
    for part in score.findall('part'):
        measures=[];divisions=None
        for measure in part.findall('measure'):
            divisions=int(measure.findtext('attributes/divisions',str(divisions or 480)))
            row=[]
            for note in measure.findall('note'):
                row.append((None if note.find('pitch') is None else pitch(note),
                    int(note.findtext('duration'))/divisions,
                    sorted(t.get('type') for t in note.findall('tie')),
                    [(l.get('number','1'),''.join(x.text or '' for x in l if x.tag in ['text','elision'])) for l in note.findall('lyric') if l.find('text') is not None]))
            measures.append(row)
        result.append(measures)
    return result
export=OUT/'render/exported.musicxml'
if export.exists() and musical_content(root)!=musical_content(E.parse(export).getroot()):errors.append('MuseScore roundtrip changed pitches, rhythms, ties or lyric text')
report=dict(parts=4,measuresPerPart=138,pdfNotesPreserved=len(original['notes']),notes=len(by_id),addedAltoNotes=sum(k.startswith('alto-added-') for k in by_id),altoAttacksMatchingMidi=alto==actual,ties=ties,slurs=len(root.findall('.//slur[@type="start"]')),dynamics=len(root.findall('.//dynamics')),fermatas=len(root.findall('.//fermata')),errors=errors)
(OUT/'notation-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2));assert not errors
