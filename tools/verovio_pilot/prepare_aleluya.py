"""Open SATB from the app MIDI, manually checked against the image PDF."""
import collections,json,xml.etree.ElementTree as E
from fractions import Fraction as F
from aleluya_model import OUT
from aleluya_lyrics import LYRICS
def text(parent,tag,value,**attrs):n=E.SubElement(parent,tag,attrs);n.text=str(value);return n
def notations(n):
    b=n.find('notations')
    return b if b is not None else E.SubElement(n,'notations')
ORDER=['chord','pitch','rest','duration','tie','voice','type','dot','accidental','time-modification','stem','beam','notations','lyric']
SLURS=[(2,7,2,7,3),(2,11,2,11,3),(0,13,3,13,3.5),
 (0,34,0,35,0),(1,34,3,34,3.25),(2,34,1.5,34,1.75),(2,34,2,34,2.75),(3,34,2,34,2.75),
 (0,36,2,36,2.75),(0,36,3,36,3.75),
 (0,37,0,37,.75),(0,37,1,37,1.75),(0,37,2,37,3.75),(1,37,3,37,3.25),(2,37,2,37,2.75),(3,37,2,37,2.75),
 (3,50,3,50,3.5),(0,56,2,56,3),(3,57,3,57,3.5),(3,62,3,62,3.5),(0,68,0,68,2)]
SLURS += [(r,a+8,b,c+8,d) for r,a,b,c,d in list(SLURS) if 34<=a<=37]
def prepare():
    events=json.loads((OUT/'source-events.json').read_text());omr=json.loads((OUT/'omr-comparison.json').read_text())['omrNotes']
    root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Aleluya al Rey');ident=E.SubElement(root,'identification');text(ident,'creator','Noé Ovando Rodríguez.',type='composer');text(ident,'creator','Armonía Coral.',type='arranger');text(E.SubElement(ident,'encoding'),'software','Coro LLDM · MIDI cotejado con PDF · letra por pentagrama para Cantai')
    defaults=E.SubElement(root,'defaults');sc=E.SubElement(defaults,'scaling');text(sc,'millimeters',7);text(sc,'tenths',40)
    page=E.SubElement(defaults,'page-layout');text(page,'page-height',1697);text(page,'page-width',1200);margin=E.SubElement(page,'page-margins',type='both')
    for k in ['left-margin','right-margin','top-margin','bottom-margin']:text(margin,k,60)
    E.SubElement(defaults,'lyric-font',**{'font-family':'Times New Roman','font-size':'12'})
    pl=E.SubElement(root,'part-list');g=E.SubElement(pl,'part-group',type='start',number='1');text(g,'group-symbol','bracket');text(g,'group-barline','no')
    for role,label in enumerate(['Soprano','Alto','Tenor','Bajo']):
        sp=E.SubElement(pl,'score-part',id=f'P{role+1}');text(sp,'part-name',label);text(sp,'part-abbreviation','SATB'[role]);ins=E.SubElement(sp,'score-instrument',id=f'I{role+1}');text(ins,'instrument-name',label);mi=E.SubElement(sp,'midi-instrument',id=f'I{role+1}');text(mi,'midi-channel',role+1);text(mi,'midi-program',1)
    E.SubElement(pl,'part-group',type='stop',number='1')
    lookup={};part_measures={};lyric_report=[]
    fallback={0:('C',0),1:('C',1),2:('D',0),3:('D',1),4:('E',0),5:('F',0),6:('F',1),7:('G',0),8:('G',1),9:('A',0),10:('A',1),11:('B',0)}
    for role in range(4):
        part=E.SubElement(root,'part',id=f'P{role+1}');continuing=False
        for bar in range(1,71):
            m=E.SubElement(part,'measure',number=str(bar));part_measures[(role,bar)]=m
            if bar==1:
                at=E.SubElement(m,'attributes');text(at,'divisions',960);text(E.SubElement(at,'key'),'fifths',0);tm=E.SubElement(at,'time',symbol='common');text(tm,'beats',4);text(tm,'beat-type',4);clef=E.SubElement(at,'clef');text(clef,'sign','F' if role==3 else 'G');text(clef,'line',4 if role==3 else 2)
                if role==2:text(clef,'clef-octave-change',-1)
            row=sorted([e for e in events if e['role']==role and e['measure']==bar],key=lambda e:(e['onset'],e.get('pitch',0)))
            starts=sorted({e['onset'] for e in row if not e.get('rest')});tokens=LYRICS[role][bar].split();assert len(tokens)==len(starts),(role,bar,len(tokens),starts);tokenmap=dict(zip(starts,tokens));used=set()
            for e in row:
                n=E.SubElement(m,'note',id=e['id']);is_chord=not e.get('rest') and e['onset'] in used
                if is_chord:E.SubElement(n,'chord')
                if e.get('rest'):E.SubElement(n,'rest',**({'measure':'yes'} if e['duration']==4 else {}))
                else:
                    spell=next((o for o in omr if o['role']==role and o['measure']==bar and abs(o['onset']-e['onset'])<.01 and o['pitch']==e['pitch']),None)
                    step,alter=(spell['step'],spell['alter']) if spell else fallback[e['pitch']%12];octave=spell['octave'] if spell else e['pitch']//12-1
                    pitch=E.SubElement(n,'pitch');text(pitch,'step',step);text(pitch,'alter',alter);text(pitch,'octave',octave);lookup.setdefault((role,bar,e['onset']),[]).append(n)
                text(n,'duration',round(e['duration']*960))
                for flag,kind in [('tieStop','stop'),('tieStart','start')]:
                    if e.get(flag):E.SubElement(n,'tie',type=kind)
                text(n,'voice',1);duration=F(e['duration']).limit_denominator(12);triplet=duration==F(1,3);dotted=duration in [F(3,4),F(3,2),F(3)];base=F(1,2) if triplet else duration/F(3,2) if dotted else duration
                text(n,'type',{F(1,4):'16th',F(1,2):'eighth',F(1):'quarter',F(2):'half',F(4):'whole'}[base])
                if dotted:E.SubElement(n,'dot')
                if triplet:
                    mod=E.SubElement(n,'time-modification');text(mod,'actual-notes',3);text(mod,'normal-notes',2);text(mod,'normal-type','eighth')
                    if abs(e['onset']-3)<.01 or abs(e['onset']-11/3)<.01:E.SubElement(notations(n),'tuplet',type='start' if abs(e['onset']-3)<.01 else 'stop',number='1',bracket='yes')
                for flag,kind in [('tieStop','stop'),('tieStart','start')]:
                    if e.get(flag):E.SubElement(notations(n),'tied',type=kind)
                if not e.get('rest') and not is_chord:
                    token=tokenmap[e['onset']];used.add(e['onset'])
                    if token!='.':
                        assert not e.get('tieStop'),(role,bar,e,token)
                        next_cont=token.endswith('-');value=token.rstrip('-');ly=E.SubElement(n,'lyric',number='1',placement='below');text(ly,'syllabic','middle' if continuing and next_cont else 'end' if continuing else 'begin' if next_cont else 'single');text(ly,'text',value);continuing=next_cont;lyric_report.append(dict(role=role,measure=bar,onset=e['onset'],text=value))
            if bar in [14,30,38]:text(E.SubElement(m,'barline',location='right'),'bar-style','light-light')
            if bar==70:text(E.SubElement(m,'barline',location='right'),'bar-style','light-heavy')
    # A lyric extender follows the real notes of its own voice, through ties
    # and melismas, stopping at rests or a fresh syllable.
    for part in root.findall('part'):
        seq=[n for n in part.findall('.//note') if n.find('chord') is None]
        for i,n in enumerate(seq):
            ly=n.find('lyric')
            if ly is None or ly.find('text') is None:continue
            following=[]
            for later in seq[i+1:]:
                if later.find('rest') is not None or later.find('lyric/text') is not None:break
                following.append(later)
            if following:
                E.SubElement(ly,'extend',type='start')
                for j,later in enumerate(following):extra=E.SubElement(later,'lyric',number='1',placement='below');E.SubElement(extra,'extend',type='stop' if j==len(following)-1 else 'continue')
    for si,(role,a,b,c,d) in enumerate(SLURS):
        for bar,onset,kind in [(a,b,'start'),(c,d,'stop')]:E.SubElement(notations(lookup[(role,bar,onset)][0]),'slur',type=kind,number=str(si%6+1))
    def direction(role,bar,onset):
        m=part_measures[(role,bar)];anchor=next(n for n in m.findall('note') if n.get('id') in {e['id'] for e in events if e['role']==role and e['measure']==bar and abs(e['onset']-onset)<.01})
        d=E.Element('direction',placement='above');m.insert(list(m).index(anchor),d);return d
    d=direction(0,1,0);mt=E.SubElement(E.SubElement(d,'direction-type'),'metronome');text(mt,'beat-unit','quarter');text(mt,'per-minute',90);E.SubElement(d,'sound',tempo='90')
    for label,bar,onset in [('A',1,2),('B',15,2),('C',31,0),('D',39,0),('E',50,0)]:text(E.SubElement(direction(0,bar,onset),'direction-type'),'rehearsal',label)
    for role in range(4):
        for bar,onset,value in [(1,2,'ff'),(15,0,'mf'),(31,0,'f'),(48,0,'ff'),(50,0,'f')]:E.SubElement(E.SubElement(E.SubElement(direction(role,bar,onset),'direction-type'),'dynamics'),value)
    for role,bar,onset,value in [(3,3,3.5,'f'),(2,4,0,'f'),(0,8,0,'f'),(1,8,0,'f'),(0,18,3.5,'mf'),(2,19,0,'mf'),(3,19,0,'mf'),(0,64,3.5,'ff'),(1,64,3.5,'ff')]:E.SubElement(E.SubElement(E.SubElement(direction(role,bar,onset),'direction-type'),'dynamics'),value)
    text(E.SubElement(direction(0,15,2),'direction-type'),'words','dolce',**{'font-style':'italic'})
    for wi,(a,b,c,d) in enumerate([(17,0,18,3.5),(28,2,30,0),(46,2,48,0)]):
        for bar,onset,kind in [(a,b,'crescendo'),(c,d,'stop')]:E.SubElement(E.SubElement(direction(0,bar,onset),'direction-type'),'wedge',type=kind,number=str(wi+1))
    for n in root.findall('.//note'):
        n[:]=sorted(n,key=lambda c:ORDER.index(c.tag) if c.tag in ORDER else 999)
    E.indent(root);target=OUT/'Aleluya al Rey - SATB con letra - Cantai.musicxml';E.ElementTree(root).write(target,encoding='utf-8',xml_declaration=True)
    (OUT/'lyric-underlay.json').write_text(json.dumps(lyric_report,ensure_ascii=False,indent=2),encoding='utf-8');print(target,'lyrics',len(lyric_report),'slurs',len(SLURS))
if __name__=='__main__':prepare()
