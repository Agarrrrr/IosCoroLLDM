"""Edit a native voice timeline while retaining independently timed user marks.

Use only with reviewed note events. This does not infer music or lyric ownership.
"""
from fractions import Fraction as F
import copy
import xml.etree.ElementTree as E

VALUES={'128th':F(1,32),'64th':F(1,16),'32nd':F(1,8),'16th':F(1,4),'eighth':F(1,2),'quarter':F(1),'half':F(2),'whole':F(4),'breve':F(8),'long':F(16)}


def value(node, measure_length):
    kind=node.findtext('durationType')
    if kind=='measure':
        return F(node.findtext('duration'))*4 if node.find('duration') is not None else F(measure_length)
    if node.find('Tuplet') is not None or node.find('noteType') is not None:
        raise ValueError('Tuplets/grace notes require an explicit native timing adapter')
    return VALUES[kind]*(2-F(1,2**int(node.findtext('dots','0'))))


def read_voice(voice, length):
    q=F(0);music=[];objects=[]
    for node in voice:
        if node.tag=='location':
            if node.findtext('measures','0')!='0':
                raise ValueError('Cross-measure cursor location needs explicit handling')
            q+=4*F(node.findtext('fractions','0'))
        elif node.tag in ('Chord','Rest'):
            d=value(node,length);music.append((q,d,node));q+=d
        elif node.tag in ('tick','Tuplet'):
            raise ValueError('Unsupported absolute cursor/tuplet object')
        else:objects.append((q,node))
    return music,objects


def set_value(node, duration):
    duration=F(duration)
    chosen=next(((kind,dots) for kind,base in VALUES.items() for dots in range(3) if base*(2-F(1,2**dots))==duration),None)
    if chosen is None:raise ValueError('Unrepresentable duration: '+str(duration))
    kind,dots=chosen
    for tag in ('durationType','duration','dots'):
        for old in list(node.findall(tag)):node.remove(old)
    index=1 if len(node) and node[0].tag=='eid' else 0
    if dots:
        n=E.Element('dots');n.text=str(dots);node.insert(index,n);index+=1
    n=E.Element('durationType');n.text=kind;node.insert(index,n)


def set_pitch(chord, event):
    notes=chord.findall('Note')
    if len(notes)!=1:raise ValueError('A single melodic note template is required')
    n=notes[0]
    changed=int(n.findtext('pitch'))!=event['pitch']
    n.find('pitch').text=str(event['pitch'])
    tpc=[14,16,18,13,15,17,19][event['diatonic']%7]+7*event.get('alter',0)
    n.find('tpc').text=str(tpc)
    if n.find('tpc2') is not None:n.find('tpc2').text=str(tpc)
    if changed:
        for accidental in list(n.findall('Accidental')):n.remove(accidental)


def rewrite_voice(voice, notes, length):
    """notes are (quarter onset, duration, native Chord) tuples."""
    length=F(length);_,objects=read_voice(voice,length)
    notes=sorted(notes,key=lambda x:x[0]);scheduled=[];q=F(0)
    rest_values=sorted({base*(2-F(1,2**d)) for base in VALUES.values() for d in range(3)},reverse=True)
    def rests(start,end):
        while start<end:
            d=next(v for v in rest_values if v<=end-start)
            node=E.Element('Rest');set_value(node,d);scheduled.append((start,1,d,node));start+=d
    for onset,d,node in notes:
        onset,d=F(onset),F(d)
        if onset<q or onset+d>length:raise ValueError('Overlapping/out-of-measure replacement')
        rests(q,onset);set_value(node,d);scheduled.append((onset,1,d,node));q=onset+d
    rests(q,length)
    scheduled.extend((onset,0,F(0),copy.deepcopy(node)) for onset,node in objects)
    for node in list(voice):voice.remove(node)
    cursor=F(0)
    for onset,priority,d,node in sorted(scheduled,key=lambda x:(x[0],x[1])):
        if onset!=cursor:
            loc=E.SubElement(voice,'location');E.SubElement(loc,'fractions').text=str((onset-cursor)/4)
        voice.append(node);cursor=onset+d
    return voice
