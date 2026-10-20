import json,collections,math,xml.etree.ElementTree as E
from fractions import Fraction as F
from aurora_model import OUT,plan
from prepare_apostol import text,notation
ORDER=['cue','chord','pitch','rest','duration','tie','voice','type','dot','accidental','time-modification','stem','notehead','beam','notations','lyric']
def build():
    events=json.loads((OUT/'positioned-events.json').read_text());lyrics=json.loads((OUT/'lyric-atoms.json').read_text(encoding='utf-8'));expr=json.loads((OUT/'expressions-reading.json').read_text());bars=plan();notes={};measures={};byid={e['id']:e for e in events}
    root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Como la Aurora');ident=E.SubElement(root,'identification');text(ident,'creator','José Pérez',type='composer');text(ident,'creator','Calep',type='arranger');text(ident,'creator','Job Ruiz P.',type='transcriber');enc=E.SubElement(ident,'encoding');text(enc,'software','Coro LLDM · SATB desarrollado · PDF digital y MIDI de referencia');text(enc,'encoding-date','2026-10-17')
    defaults=E.SubElement(root,'defaults');scale=E.SubElement(defaults,'scaling');text(scale,'millimeters',7);text(scale,'tenths',40);page=E.SubElement(defaults,'page-layout');text(page,'page-height',1697);text(page,'page-width',1200);margins=E.SubElement(page,'page-margins',type='both')
    for k in ['left-margin','right-margin','top-margin','bottom-margin']:text(margins,k,60)
    E.SubElement(defaults,'lyric-font',**{'font-family':'Times New Roman','font-size':'12'})
    pl=E.SubElement(root,'part-list');group=E.SubElement(pl,'part-group',type='start',number='1');text(group,'group-symbol','bracket');text(group,'group-barline','no')
    for r,label in enumerate(['Soprano','Alto','Tenor','Bajo']):
        p=E.SubElement(pl,'score-part',id=f'P{r+1}');text(p,'part-name',label);text(p,'part-abbreviation','SATB'[r]);text(E.SubElement(p,'score-instrument',id=f'I{r}'),'instrument-name',label);mi=E.SubElement(p,'midi-instrument',id=f'I{r}');text(mi,'midi-channel',r+1);text(mi,'midi-program',1)
    E.SubElement(pl,'part-group',type='stop',number='1')
    for role in range(4):
        p=E.SubElement(root,'part',id=f'P{role+1}')
        for b in bars:
            m=E.SubElement(p,'measure',number=str(b['number']),**({'implicit':'yes'} if b['number'] in [1,len(bars)] else {}));measures[(role,b['number'])]=m
            if b['number']==1:
                a=E.SubElement(m,'attributes');text(a,'divisions',960);text(E.SubElement(a,'key'),'fifths',0);tm=E.SubElement(a,'time');text(tm,'beats',6);text(tm,'beat-type',8);clef=E.SubElement(a,'clef');text(clef,'sign','G' if role<2 else 'F');text(clef,'line',2 if role<2 else 4)
            previous=bars[b['number']-2] if b['number']>1 else b
            if b['meter']!=previous['meter']:
                tm=E.SubElement(E.SubElement(m,'attributes'),'time');text(tm,'beats',b['meter']);text(tm,'beat-type',8)
            if b['source']==31:m.insert(0,E.Element('print',**{'new-system':'yes'}))
            row=sorted([e for e in events if e['role']==role and e['bar']==b['number']],key=lambda e:(e['onset'],e.get('pitch',0)));used=set();triplets=collections.defaultdict(list)
            for e in row:
                d=F(e['duration']).limit_denominator(480)
                if d in [F(1,3),F(1,6),F(2,3)]:
                    span=1 if d==F(1,3) else F(1,2) if d==F(1,6) else 2;triplets[(float(math.floor(e['onset']/span)*span),d)].append(e)
            for e in row:
                n=E.SubElement(m,'note',id=e['id']);notes[e['id']]=n;chord=not e.get('rest') and e['onset'] in used
                if e.get('cue'):E.SubElement(n,'cue')
                if chord:E.SubElement(n,'chord')
                if e.get('rest'):E.SubElement(n,'rest',**({'measure':'yes'} if e['duration']==b['duration'] else {}))
                else:
                    used.add(e['onset']);pitch=E.SubElement(n,'pitch');text(pitch,'step','CDEFGAB'[e['diatonic']%7]);text(pitch,'alter',e['alter']);text(pitch,'octave',e['diatonic']//7)
                text(n,'duration',round(e['duration']*960))
                for flag,kind in [('tieStop','stop'),('tieStart','start')]:
                    if e.get(flag):E.SubElement(n,'tie',type=kind)
                text(n,'voice',1);d=F(e['duration']).limit_denominator(480);tuplet=d in [F(1,3),F(1,6),F(2,3)];dots=2 if d==F(7,2) else 1 if d in [F(3,4),F(3,2),F(3)] else 0;base=d*F(3,2) if tuplet else d/(2-F(1,2**dots)) if dots else d
                text(n,'type',{F(1,4):'16th',F(1,2):'eighth',F(1):'quarter',F(2):'half',F(4):'whole'}[base])
                for _ in range(dots):E.SubElement(n,'dot')
                if tuplet:
                    tm=E.SubElement(n,'time-modification');text(tm,'actual-notes',3);text(tm,'normal-notes',2);text(tm,'normal-type','quarter' if base==1 else 'eighth' if base==F(1,2) else '16th');span=1 if d==F(1,3) else F(1,2) if d==F(1,6) else 2;peers=triplets[(float(math.floor(e['onset']/span)*span),d)]
                    if e is peers[0]:E.SubElement(notation(n),'tuplet',type='start',number='1',bracket='yes')
                    if e is peers[-1]:E.SubElement(notation(n),'tuplet',type='stop',number='1')
                if e.get('cue'):text(n,'notehead','normal',parentheses='yes')
                for flag,kind in [('tieStop','stop'),('tieStart','start')]:
                    if e.get(flag):E.SubElement(notation(n),'tied',type=kind)
                atoms=lyrics.get(e['id'],[])
                if atoms:
                    assert not chord and not e.get('tieStop') and not e.get('cue'),e
                    ly=E.SubElement(n,'lyric',number='1',placement='below');before=atoms[0]['syllabic'] in ['middle','end'];after=atoms[-1]['syllabic'] in ['begin','middle'];text(ly,'syllabic','middle' if before and after else 'end' if before else 'begin' if after else 'single');text(ly,'text',''.join(('‿' if a['join'] else ' ')*bool(i)+a['text'] for i,a in enumerate(atoms)))
            if b['number']==len(bars):text(E.SubElement(m,'barline',location='right'),'bar-style','light-heavy')
    for part in root.findall('part'):
        seq=[n for n in part.findall('.//note') if n.find('chord') is None and n.find('cue') is None]
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
    # All eight printed curves prolong an equal pitch. The tenor's bar 29
    # curve overrides an erroneous reattack in the reference MIDI.
    for e in events:
        if e['measure']==30 and e['onset']==1.5 and not e.get('rest'):
            text(notation(notes[e['id']]),'fermata','normal',type='upright')
    def direction(role,b,onset,d):
        m=measures[(role,b['number'])];at=next(i for i,n in enumerate(m) if n.tag=='note');items=[]
        if onset:f=E.Element('forward');text(f,'duration',round(onset*960));items.append(f)
        items.append(d)
        if onset:backup=E.Element('backup');text(backup,'duration',round(onset*960));items.append(backup)
        for i,item in enumerate(items):m.insert(at+i,item)
    d=E.Element('direction',placement='above');mt=E.SubElement(E.SubElement(d,'direction-type'),'metronome');text(mt,'beat-unit','quarter');text(mt,'per-minute',90);E.SubElement(d,'sound',tempo='90');direction(0,bars[0],0,d)
    for b in bars:
        label='Estrofa 1' if b['source']==0 else f"Estrofa {b['passage']+1}" if b['source']==30 and b['passage']<3 else 'Coro' if b['source'] in [17,46] else None
        if label:
            d=E.Element('direction',placement='above');text(E.SubElement(d,'direction-type'),'words',label,**{'font-weight':'bold'});direction(0,b,0 if b['source']==0 else 3 if b['source'] in [17,30] else 1.5,d)
    for n in notes.values():n[:]=sorted(n,key=lambda c:ORDER.index(c.tag) if c.tag in ORDER else 999)
    E.indent(root);target=OUT/'Como la Aurora - SATB extendido - Cantai.musicxml';E.ElementTree(root).write(target,encoding='utf-8',xml_declaration=True)
    result=dict(bars=len(bars),quarterBeats=320.5,staves=4,notes=sum(not e.get('rest') for e in events),cueNotes=sum(e.get('cue',False) for e in events),ties=sum(e.get('tieStop',False) for e in events),slurs=0,fermatas=12,lyricNotes=len(lyrics),tempo=90)
    (OUT/'preparation.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(result)
if __name__=='__main__':build()
