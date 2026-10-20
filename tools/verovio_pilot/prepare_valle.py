"""Prepare an explicitly sourced SATB MusicXML, with digital PDF underlay.

The existing editable supplies notation, the app MIDI verifies its attacks, and
the OPEN app PDF supplies lyrics. This is not MIDI-only lyric recognition.
"""
from pathlib import Path
import collections,copy,hashlib,json,xml.etree.ElementTree as E
from valle_rhythm_check import duration,TYPES

OUT=Path('output/verovio_pilot_support/valle')
SOURCE=next(Path('C:/Users/Huri_/Downloads/musescore').glob('D__*Huesos*musicxml'))
TARGET=OUT/'Valle de los Huesos Secos - SATB con letra.musicxml'
ORDER=['grace','cue','chord','pitch','unpitched','rest','duration','tie','instrument','voice','type','dot','accidental','time-modification','stem','notehead','staff','beam','notations','lyric']
def text(parent,tag,value,**attrs):
    child=E.SubElement(parent,tag,attrs);child.text=str(value);return child
def main():
    root=E.parse(SOURCE).getroot();root.set('version','4.0')
    voices=json.loads((OUT/'pdf-note-lyrics.json').read_text(encoding='utf-8'))
    midi=json.loads((OUT/'midi.json').read_text())
    repairs=[];report=[]
    work=root.find('work')
    if work is None:work=E.Element('work');root.insert(0,work)
    title=work.find('work-title')
    if title is None:title=E.SubElement(work,'work-title')
    title.text='Valle de los Huesos Secos'
    movement=root.find('movement-title')
    if movement is not None:movement.text=title.text
    identification=root.find('identification')
    creator=E.Element('creator',type='composer');creator.text='M. Salvador Castro S.'
    identification.insert(0,creator)
    encoding=identification.find('encoding')
    encoding.find('encoding-date').text='2026-10-17'
    text(encoding,'software','Coro LLDM: letra digital cotejada con PDF y MIDI')
    for role,sp in enumerate(root.findall('part-list/score-part')):
        sp.find('part-name').text=['Soprano','Alto','Tenor','Bajo'][role]
        for tag,value in [('part-abbreviation',['S','A','T','B'][role])]:
            child=sp.find(tag)
            if child is None:child=E.Element(tag);sp.insert(1,child)
            child.text=value
    for role,part in enumerate(root.findall('part')):
        div=1
        for mi,measure in enumerate(part.findall('measure')):
            div=int(measure.findtext('attributes/divisions',str(div)))
            attrs=measure.find('attributes')
            if attrs is None:attrs=E.Element('attributes');measure.insert(0,attrs)
            for node in measure.iter('offset'):node.text=str(round(int(node.text)/div*480))
            division=attrs.find('divisions')
            if division is None:division=E.Element('divisions');attrs.insert(0,division)
            division.text='480'
            for node in measure:
                if node.tag in ['forward','backup']:
                    node.find('duration').text=str(round(int(node.findtext('duration'))/div*480))
                if node.tag=='note':
                    d=duration(node);old=int(node.findtext('duration'))/div
                    if abs(d-old)>.00001:repairs.append(dict(role=role,measure=mi+1,old=old,new=d,rest=node.find('rest') is not None))
                    node.find('duration').text=str(round(d*480))
            # The source's <forward> omits a sung dotted-half Ab2 in bar 100.
            # It is present in the actual PDF. Restore only in this new file.
            if role==2 and mi==99:
                forward=measure.find('forward');assert forward.findtext('duration')=='1440'
                index=list(measure).index(forward);measure.remove(forward)
                note=E.Element('note');pitch=E.SubElement(note,'pitch')
                text(pitch,'step','A');text(pitch,'alter',-1);text(pitch,'octave',2)
                text(note,'duration',1440);text(note,'voice',1);text(note,'type','half');E.SubElement(note,'dot');text(note,'stem','up');text(note,'staff',1)
                measure.insert(index,note)
                repairs.append(dict(role=role,measure=100,restored='Ab2 dotted half from PDF; absent in source MIDI'))
            total=sum(int(n.findtext('duration')) for n in measure.findall('note'))+sum(int(n.findtext('duration')) for n in measure.findall('forward'))
            assert total<=1920,(role,mi+1,total)
            if total<1920:
                remaining=1920-total;assert remaining==120,(role,mi+1,remaining)
                n=E.SubElement(measure,'note');E.SubElement(n,'rest');text(n,'duration',remaining);text(n,'voice',1);text(n,'type','16th');text(n,'staff',1)
                repairs.append(dict(role=role,measure=mi+1,addedTailRest=remaining/480))
            if mi<147:
                bar=measure.find("barline[@location='right']")
                if bar is None:bar=E.SubElement(measure,'barline',location='right')
                style=bar.find('bar-style')
                if style is None:style=E.SubElement(bar,'bar-style')
                style.text='none'
        pitched=[(m,n) for m in part.findall('measure') for n in m.findall('note') if n.find('pitch') is not None]
        assert len(pitched)==len(voices[role]),(role,len(pitched),len(voices[role]))
        lyric_count=0;unlabeled=[]
        for ni,((measure,note),pdf) in enumerate(zip(pitched,voices[role])):
            diatonic=int(note.findtext('pitch/octave'))*7+'CDEFGAB'.index(note.findtext('pitch/step'))
            assert diatonic==pdf['diatonic'],(role,ni,measure.get('number'))
            expected='0xf077' if note.findtext('type')=='whole' else '0xf0fa' if note.findtext('type')=='half' else '0xf0cf'
            assert expected==pdf['glyph'],(role,ni)
            note.set('id',f'valle-{role}-{ni}')
            for ly in note.findall('lyric'):note.remove(ly)
            syllables=pdf['syllables']
            if syllables:
                value=''.join(s['text'] for s in syllables)
                if role==3 and ni==480:
                    assert value=='lglo';value='glo'
                    repairs.append(dict(role=role,measure=measure.get('number'),pdfTypo='lglo',text='glo'))
                lyric=E.SubElement(note,'lyric',number='1',placement='below',**{'default-y':'-50'})
                text(lyric,'syllabic',syllables[0]['syllabic'] if len(syllables)==1 else 'single')
                for vi,word in enumerate(value.split('_')):
                    if vi:text(lyric,'elision','\u203f')
                    text(lyric,'text',word)
                lyric_count+=1
            elif note.find("tie[@type='stop']") is None:
                unlabeled.append(dict(measure=measure.get('number'),index=ni,page=pdf['page']))
            note[:]=sorted(note,key=lambda n:ORDER.index(n.tag) if n.tag in ORDER else 999)
        # All original MIDI attacks retain pitch and musical onset; one restored
        # PDF note is explicitly excluded from this source comparison.
        attacks=[]
        for mi,m in enumerate(part.findall('measure')):
            local=0
            for n in m:
                if n.tag=='note':
                    if n.find('pitch') is not None and n.find("tie[@type='stop']") is None and not(role==2 and mi==99):
                        pitch=12*(int(n.findtext('pitch/octave'))+1)+{'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[n.findtext('pitch/step')]+int(n.findtext('pitch/alter','0'))
                        attacks.append((mi*4+local/480,pitch))
                    local+=int(n.findtext('duration'))
                elif n.tag=='forward':local+=int(n.findtext('duration'))
            assert local==1920,(role,mi,local)
        assert len(attacks)==len(midi['tracks'][role]['notes'])
        for (q,pitch),n in zip(attacks,midi['tracks'][role]['notes']):
            assert pitch==n['pitch'] and abs(q-n['ticks']/midi['ppq'])<.0021,(role,q,pitch,n)
        report.append(dict(role=role,notes=len(pitched),lyricNotes=lyric_count,verifiedMidiAttacks=len(attacks),unlabeledNonTies=unlabeled))
    # Recover the one within-system phrase slur from PDF geometry. All other
    # matched arcs already have sound ties in the editable.
    pitched_parts=[[n for n in p.findall('.//note') if n.find('pitch') is not None] for p in root.findall('part')]
    for arc in json.loads((OUT/'pdf-arcs.json').read_text()):
        if not arc['valid']:continue
        a,b=arc['start'],arc['end'];start=pitched_parts[a['role']][a['index']];end=pitched_parts[b['role']][b['index']]
        if start.find("tie[@type='start']") is not None and end.find("tie[@type='stop']") is not None:continue
        assert (a['role'],a['index'],b['index'])==(0,360,361)
        for note,kind in [(start,'start'),(end,'stop')]:
            block=note.find('notations')
            if block is None:block=E.SubElement(note,'notations')
            E.SubElement(block,'slur',type=kind,number='1')
        repairs.append(dict(role=0,measure=87,restored='PDF phrase slur E5 to Eb5; pitches differ, so not a sound tie'))
    # Two PDF ties cross the page 7/8 boundary. The exported editable omitted
    # these links and the bundled MIDI reattacks them. Preserve the PDF sustain
    # in this new notation; do not rewrite the app MIDI.
    for role in [2,3]:
        a,b=pitched_parts[role][317:319]
        assert E.tostring(a.find('pitch'))==E.tostring(b.find('pitch'))
        for note,kind in [(a,'start'),(b,'stop')]:
            assert note.find(f"tie[@type='{kind}']") is None
            E.SubElement(note,'tie',type=kind)
            block=note.find('notations')
            if block is None:block=E.SubElement(note,'notations')
            E.SubElement(block,'tied',type=kind)
        repairs.append(dict(role=role,measure=66,restored='PDF sustain tie across page 7/8; source MIDI reattacks this continuation'))
    # Validate the full tie graph, not merely the number of tie tags.
    links=0
    for role,notes in enumerate(pitched_parts):
        active={}
        for note in notes:
            pitch=tuple(note.findtext('pitch/'+x,'0') for x in ['step','alter','octave'])
            if note.find("tie[@type='stop']") is not None:
                assert pitch in active,(role,note.get('id'),'orphan tie stop')
                active.pop(pitch);links+=1
            if note.find("tie[@type='start']") is not None:
                assert pitch not in active,(role,note.get('id'),'double tie start')
                active[pitch]=note.get('id')
            block=note.find('notations')
            if block is not None:
                block[:]=sorted(block,key=lambda n:0 if n.tag=='tied' and n.get('type')=='stop' else 1)
            note[:]=sorted(note,key=lambda n:(ORDER.index(n.tag) if n.tag in ORDER else 999,0 if n.tag=='tie' and n.get('type')=='stop' else 1))
        assert not active,(role,'unclosed ties',active)
    # The open PDF's printed initial marking is 100, not the editable's 80.
    for part in root.findall('part'):
        for mark in part.find('measure').findall('.//per-minute'):mark.text='100'
        for sound in part.find('measure').findall('.//sound'):
            if sound.get('tempo') is not None:sound.set('tempo','100')
    E.indent(root);E.ElementTree(root).write(TARGET,encoding='utf-8',xml_declaration=True)
    result=dict(source=str(SOURCE),pdf='original-2.pdf',sourcePdfSha256=hashlib.sha256((OUT/'original-2.pdf').read_bytes()).hexdigest(),output=str(TARGET),parts=4,measures=148,validatedTieLinks=links,roles=report,repairs=repairs)
    (OUT/'preparation-report.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
