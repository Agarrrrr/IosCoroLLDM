from fractions import Fraction
from collections import Counter
import json,xml.etree.ElementTree as E
from extract_salmo150 import OUT
def pitch(n):
    p=n.find('pitch')
    if p is None:return None
    return 12*(int(p.findtext('octave'))+1)+dict(C=0,D=2,E=4,F=5,G=7,A=9,B=11)[p.findtext('step')]+int(p.findtext('alter','0'))
def content(root):
    result=[]
    for part in root.findall('part'):
        measures=[];divisions=960
        for m in part.findall('measure'):
            divisions=int(m.findtext('attributes/divisions',str(divisions)))
            row=[]
            for n in m.findall('note'):
                row.append((pitch(n),Fraction(int(n.findtext('duration')),divisions),
                    sorted(t.get('type') for t in n.findall('tie')),
                    (n.findtext('time-modification/actual-notes'),n.findtext('time-modification/normal-notes')),
                    [(l.findtext('syllabic'),''.join(x.text or '' for x in l if x.tag in ['text','elision'])) for l in n.findall('lyric') if l.find('text') is not None]))
            measures.append(row)
        result.append(measures)
    return result
def validate():
    root=E.parse(OUT/'Salmo 150 - SATB con letra.musicxml').getroot();errors=[]
    for role,part in enumerate(root.findall('part')):
        assert len(part.findall('measure'))==73
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
                if n.find('time-modification') is not None and duration!=Fraction(1,3):errors.append(('wrong triplet duration',role,m.get('number'),str(duration)))
            if q!=4:errors.append(('incomplete measure',role,m.get('number'),str(q)))
        if active:errors.append(('unclosed tie',role))
    exported=E.parse(OUT/'render/exported.musicxml').getroot();reimported=E.parse(OUT/'render/reimport.musicxml').getroot()
    if content(root)!=content(exported):errors.append('Native MuseScore export changed musical content')
    if content(exported)!=content(reimported):errors.append('MusicXML reimport changed musical content')
    playback=json.loads((OUT/'render/playback.json').read_text());expected=[(0,100),(2,112)]
    actual=[(t['ticks']/playback['ppq'],round(t['bpm'],3)) for t in playback['tempos']]
    for position,bpm in expected:
        if not any(abs(q-position)<.001 and abs(b-bpm)<.01 for q,b in actual):errors.append(('tempo not active in exported MIDI',position,bpm,actual))
    again=json.loads((OUT/'render/playback-reimport.json').read_text())
    again_tempos=[(t['ticks']/again['ppq'],round(t['bpm'],3)) for t in again['tempos']]
    for position,bpm in expected:
        if not any(abs(q-position)<.001 and abs(b-bpm)<.01 for q,b in again_tempos):errors.append(('tempo lost when reopening MusicXML',position,bpm,again_tempos))
    # Every printed triplet must produce attacks on the third-beat grid.
    data=json.loads((OUT/'pdf-reading.json').read_text(encoding='utf-8'));triplet_errors=[]
    for e in data['events']:
        if not e.get('tuplet'):continue
        q=(e['measure']-1)*4+e['onset'];track=playback['tracks'][e['role']]['notes']
        if not any(abs(n['ticks']/playback['ppq']-q)<.01 for n in track):triplet_errors.append((e['role'],e['measure'],q))
    if triplet_errors:errors.append(('triplet attacks shifted in playback',triplet_errors))
    report=dict(parts=4,measuresPerPart=73,notes=len(root.findall('.//pitch')),tripletGroups=len(data['tuplets']),tripletNotes=len(root.findall('.//time-modification')),hyphenatedSyllables=len(root.findall('.//syllabic[.="begin"]'))+len(root.findall('.//syllabic[.="middle"]'))+len(root.findall('.//syllabic[.="end"]')),ties=len(root.findall('.//tie[@type="start"]')),slurs=len(root.findall('.//slur[@type="start"]')),playbackTempos=actual,errors=errors)
    (OUT/'notation-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False,indent=2));assert not errors
    return report
if __name__=='__main__':validate()
