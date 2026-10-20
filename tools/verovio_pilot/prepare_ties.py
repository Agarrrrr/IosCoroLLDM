"""Audited sustain instructions for the independent pilot; source MIDI stays intact."""
import json,xml.etree.ElementTree as E
from pathlib import Path
from inspect_sources import xml_events
BASE=Path('output/verovio_pilot/assets/scores')

def prepare(key):
    path=BASE/(key+'.musicxml');root=E.parse(path).getroot()
    events=json.loads((BASE/(key+'-events.json')).read_text(encoding='utf-8'))
    by={}
    for e in events:by.setdefault(e['id'],[]).append(e)
    # PDF ending: the final Amen is sustained, not rearticulated.
    corrected=0
    if key=='al-gran-senor':
        for part in root.findall('part'):
            a=part.findall('measure')[89];b=part.findall('measure')[90]
            first=[n for n in a.findall('note') if n.find('pitch') is not None][-1]
            last=[n for n in b.findall('note') if n.find('pitch') is not None][0]
            assert E.tostring(first.find('pitch'))==E.tostring(last.find('pitch'))
            for n,kind in [(first,'start'),(last,'stop')]:
                block=n.find('notations')
                assert block is not None
                for sl in block.findall('slur'):
                    if sl.get('type')==kind:block.remove(sl)
                if n.find("tie[@type='%s']"%kind) is None:
                    duration=n.find('duration');n.insert(list(n).index(duration)+1,E.Element('tie',type=kind))
                if block.find("tied[@type='%s']"%kind) is None:E.SubElement(block,'tied',type=kind)
            corrected+=1
        E.indent(root);E.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
    # Some editable files encode a prolongation with slur rather than tied.
    # Only consecutive notes in the SAME voice, identical pitch, no rest and
    # no fresh syllable qualify. A phrase spanning other pitches is not a tie.
    positions={};opened={};converted=[]
    for e in xml_events(root):
        n=e['element'];rows=by.get(n.get('id'),[])
        if not rows:continue
        role=rows[0]['role'];positions[role]=positions.get(role,0)+1
        for sl in list(n.findall('notations/slur')):
            sig=(role,sl.get('number','1'))
            if sl.get('type')=='start':opened[sig]=(positions[role],e,sl)
            elif sl.get('type')=='stop' and sig in opened:
                index,a,begin=opened.pop(sig)
                if (positions[role]==index+1 and a['pitch']==e['pitch'] and
                    abs(a['onset']+a['duration']-e['onset'])<.01 and
                    not any((t.text or '').strip() for t in n.findall('lyric/text'))):
                    for note,kind,arc in [(a['element'],'start',begin),(n,'stop',sl)]:
                        block=note.find('notations');block.remove(arc)
                        duration=note.find('duration');note.insert(list(note).index(duration)+1,E.Element('tie',type=kind))
                        E.SubElement(block,'tied',type=kind)
                    converted.append(dict(role=role,measure=e['measure']+1))
    E.indent(root);E.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
    plans=[];active={}
    for part in root.findall('part'):
        for measure in part.findall('measure'):
            for note in measure.findall('note'):
                rows=by.get(note.get('id'),[])
                if not rows:continue
                role=rows[0]['role'];pitch=rows[0]['pitch'];signature=(role,pitch)
                stop=note.find("tie[@type='stop']") is not None
                start=note.find("tie[@type='start']") is not None
                if stop:
                    assert signature in active,(key,signature)
                    for begin in active[signature]:
                        end=min((e for e in rows if e['time']>=begin['time']),key=lambda e:e['time'])
                        plans.append(dict(role=role,pitch=pitch,start=begin['time'],continuation=end['time'],end=end['time']+end['duration']))
                if start:active[signature]=rows
                else:active.pop(signature,None)
    (BASE/(key+'-ties.json')).write_text(json.dumps(plans,indent=2),encoding='utf-8')
    manifest_path=BASE/'manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    row=next(r for r in manifest if r['key']==key)
    row['sustainOccurrences']=len(plans)
    if converted:row['additionalProlongations']=converted
    if key=='al-gran-senor':
        row['notation']='Notación completa del editable propio y audio del MIDI empaquetado. El cierre del PDF empaquetado es otra variante: incluye «Canten al Señor». Esta prueba no es una transcripción exacta de ese PDF. Se corrigieron cuatro prolongaciones finales solo en la copia del piloto.'
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(key,'sustains',len(plans),'final ties corrected',corrected,'other prolongations',converted)

if __name__=='__main__':
    for key in ['acercame','al-gran-senor','app-sample']:prepare(key)
