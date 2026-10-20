from fractions import Fraction
import json,xml.etree.ElementTree as E
from extract_dios_poderoso import OUT
from validate_salmo150 import content,pitch
from dios_poderoso_expressions import TEMPOS
from digital_text_runs import page_runs
from extract_alabad import staff_groups
import pdfplumber
def attacks(root):
    result=[]
    for part in root.findall('part'):
        row=[];absolute=0;divisions=960
        for m in part.findall('measure'):
            divisions=int(m.findtext('attributes/divisions',str(divisions)));q=Fraction(0)
            for n in m.findall('note'):
                if pitch(n) is not None and not any(t.get('type')=='stop' for t in n.findall('tie')):row.append((float(absolute+q),pitch(n)))
                q+=Fraction(int(n.findtext('duration')),divisions)
            absolute+=q
        result.append(row)
    return result
def validate():
    root=E.parse(OUT/'Dios Poderoso - SATB con letra.musicxml').getroot();errors=[]
    source_letters=['']*4;runs=page_runs(OUT/'original.pdf')
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,page in enumerate(pdf.pages):
            staves=staff_groups(page)
            for si,staff in enumerate(staves):
                bottom=staves[si+1][0]-5 if si+1<len(staves) else 835
                chars=sorted([c for c in runs[pi] if 'TimesNewRomanPSMT' in c['fontname'] and 11.3<c['size']<13.3 and staff[-1]+4<c['top']<bottom],key=lambda c:c['x0'])
                source_letters[si%4]+=''.join(c['text'].casefold() for c in chars if c['text'].isalpha())
    for role,part in enumerate(root.findall('part')):
        actual=''.join(c.casefold() for t in part.findall('.//lyric/text') for c in t.text or '' if c.isalpha())
        if actual!=source_letters[role]:errors.append(('lyric letters differ from PDF',role,len(actual),len(source_letters[role])))
    for role,part in enumerate(root.findall('part')):
        assert len(part.findall('measure'))==103
        active={};divisions=960
        for m in part.findall('measure'):
            divisions=int(m.findtext('attributes/divisions',str(divisions)));q=Fraction(0)
            for n in m.findall('note'):
                value=pitch(n);duration=Fraction(int(n.findtext('duration')),divisions);q+=duration
                ties=[t.get('type') for t in n.findall('tie')]
                if 'stop' in ties:
                    if value not in active:errors.append(('tie stop without start',role,m.get('number'),value))
                    else:active.pop(value)
                if active and value not in active:errors.append(('tie interrupted',role,m.get('number'),value))
                if 'start' in ties:
                    if value in active:errors.append(('duplicate tie',role,m.get('number'),value))
                    active[value]=True
            if q!=4:errors.append(('bar duration',role,m.get('number'),str(q)))
        if active:errors.append(('unclosed tie',role))
    exported=E.parse(OUT/'render/exported.musicxml').getroot();again=E.parse(OUT/'render/reimport.musicxml').getroot()
    if content(root)!=content(exported):errors.append('Native export changed notes, durations, ties or lyric syllabification')
    if content(exported)!=content(again):errors.append('MusicXML reimport changed musical content')
    expected=attacks(root);midi=json.loads((OUT/'midi-reading.json').read_text());reference_errors=[]
    for role,row in enumerate(expected):
        source=[(n['ticks']/midi['ppq'],n['pitch']) for n in midi['tracks'][role]['notes']]
        if len(row)!=len(source):reference_errors.append(('attack count',role,len(row),len(source)))
        for i,(a,b) in enumerate(zip(row,source)):
            if abs(a[0]-b[0])>.008 or a[1]!=b[1]:reference_errors.append((role,i,a,b))
    if reference_errors:errors.append(('source MIDI mismatch',reference_errors[:30]))
    playback_reports=[]
    for filename in ['playback.json','playback-reimport.json']:
        play=json.loads((OUT/'render'/filename).read_text());tempos=[(t['ticks']/play['ppq'],t['bpm']) for t in play['tempos']]
        for q,bpm in TEMPOS:
            if not any(abs(x-q)<.008 and min(abs(y-bpm),abs(y-bpm/2))<.02 for x,y in tempos):errors.append(('tempo not reproduced',filename,q,bpm,tempos))
        for role,row in enumerate(expected):
            actual=[(n['ticks']/play['ppq'],n['pitch']) for n in play['tracks'][role]['notes']]
            if len(row)!=len(actual):errors.append(('rendered MIDI attack count',filename,role,len(row),len(actual)))
            mismatches=[(i,a,b) for i,(a,b) in enumerate(zip(row,actual)) if abs(a[0]-b[0])>.008 or a[1]!=b[1]]
            if mismatches:errors.append(('rendered MIDI attack mismatch',filename,role,mismatches[:10]))
        playback_reports.append(dict(source=filename,tempos=tempos,attacks=[len(t['notes']) for t in play['tracks']]))
    report=dict(parts=4,measuresPerPart=103,notes=len(root.findall('.//pitch')),attacksPerVoice=[len(row) for row in expected],referenceMidiMatches=not reference_errors,ties=len(root.findall('.//tie[@type="start"]')),slurs=len(root.findall('.//slur[@type="start"]')),words=json.loads((OUT/'underlay-validation.json').read_text())['words'],doubleDottedNotes=sum(len(n.findall('dot'))==2 for n in root.findall('.//note')),playback=playback_reports,errors=errors)
    (OUT/'notation-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False,indent=2));assert not errors
    return report
if __name__=='__main__':validate()
