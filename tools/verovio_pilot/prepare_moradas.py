import json,collections,math,xml.etree.ElementTree as E
from fractions import Fraction as F
from moradas_model import OUT,plan
from prepare_apostol import text,notation
ORDER=['cue','chord','pitch','rest','duration','tie','voice','type','dot','accidental','time-modification','stem','notehead','beam','notations','lyric']
def build():
    events=json.loads((OUT/'positioned-events.json').read_text());lyrics=json.loads((OUT/'lyric-atoms.json').read_text(encoding='utf-8'));expr=json.loads((OUT/'expressions-reading.json').read_text());bars=plan();notes={};measures={};byid={e['id']:e for e in events}
    root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Cuán Amables Son Tus Moradas - Oficial');ident=E.SubElement(root,'identification');text(ident,'creator','S. Liddle; Arthur Fagge · George P. Simmonds',type='composer');text(ident,'rights','Alabanza · versión oficial con solista');enc=E.SubElement(ident,'encoding');text(enc,'software','Coro LLDM · SATB desarrollado · PDF digital y MIDI de referencia');text(enc,'encoding-date','2026-10-18')
    defaults=E.SubElement(root,'defaults');scale=E.SubElement(defaults,'scaling');text(scale,'millimeters',7);text(scale,'tenths',40);page=E.SubElement(defaults,'page-layout');text(page,'page-height',1697);text(page,'page-width',1200);margins=E.SubElement(page,'page-margins',type='both')
    for k in ['left-margin','right-margin','top-margin','bottom-margin']:text(margins,k,60)
    E.SubElement(defaults,'lyric-font',**{'font-family':'Times New Roman','font-size':'12'})
    pl=E.SubElement(root,'part-list');group=E.SubElement(pl,'part-group',type='start',number='1');text(group,'group-symbol','bracket');text(group,'group-barline','no')
    for r,label in enumerate(['Solista','Soprano','Alto','Tenor','Bajo']):
        p=E.SubElement(pl,'score-part',id=f'P{r+1}');text(p,'part-name',label);text(p,'part-abbreviation',['Solo','S','A','T','B'][r]);text(E.SubElement(p,'score-instrument',id=f'I{r}'),'instrument-name',label);mi=E.SubElement(p,'midi-instrument',id=f'I{r}');text(mi,'midi-channel',r+1);text(mi,'midi-program',1)
    E.SubElement(pl,'part-group',type='stop',number='1')
    for role in range(5):
        p=E.SubElement(root,'part',id=f'P{role+1}')
        for b in bars:
            m=E.SubElement(p,'measure',number=str(b['number']));measures[(role,b['number'])]=m
            if b['number']==1:
                a=E.SubElement(m,'attributes');text(a,'divisions',960);text(E.SubElement(a,'key'),'fifths',2);tm=E.SubElement(a,'time');text(tm,'beats',4);text(tm,'beat-type',4);clef=E.SubElement(a,'clef');text(clef,'sign','G' if role<4 else 'F');text(clef,'line',2 if role<4 else 4);text(clef,'clef-octave-change',-1) if role==3 else None
            previous=bars[b['number']-2] if b['number']>1 else b
            if (b['meter'],b['unit'])!=(previous['meter'],previous['unit']):
                tm=E.SubElement(E.SubElement(m,'attributes'),'time');text(tm,'beats',b['meter']);text(tm,'beat-type',b['unit'])
            if b['source'] in [25,51,62,66,79]:m.insert(0,E.Element('print',**{'new-system':'yes'}))
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
    def select(role,measure,onset,passage):return next(e for e in events if e['role']==role and e['measure']==measure and abs(e['onset']-onset)<.00001 and e['passage']==passage and not e.get('rest'))
    slurs=[(byid[a['start']],byid[a['end']]) for a in expr['arcs'] if a['kind']=='slur']
    active=collections.defaultdict(dict)
    for a,b in sorted(slurs,key=lambda pair:(pair[0]['role'],pair[0]['absolute'])):
        role=a['role'];active[role]={k:v for k,v in active[role].items() if v>=a['absolute']};number=next(i for i in range(1,17) if i not in active[role]);active[role][number]=b['absolute']
        for e,kind in [(a,'start'),(b,'stop')]:E.SubElement(notation(notes[e['id']]),'slur',type=kind,number=str(number))
    def direction(role,b,onset,d):
        m=measures[(role,b['number'])];at=next(i for i,n in enumerate(m) if n.tag=='note');items=[]
        if onset:f=E.Element('forward');text(f,'duration',round(onset*960));items.append(f)
        items.append(d)
        if onset:backup=E.Element('backup');text(backup,'duration',round(onset*960));items.append(backup)
        for i,item in enumerate(items):m.insert(at+i,item)
    arts=set()
    for mark in expr['articulations']:
        original=byid[mark['id']]
        for b in [b for b in bars if b['source']==mark['measure']]:
            e=next(e for e in events if e['role']==mark['role'] and e['bar']==b['number'] and e['onset']==mark['onset'] and e.get('pitch')==original['pitch'])
            n=notes[e['id']];block=notation(n);arts.add((e['id'],mark['kind']))
            if mark['kind']=='fermata':text(block,'fermata','normal',type='upright')
            else:
                art=block.find('articulations');art=art if art is not None else E.SubElement(block,'articulations');E.SubElement(art,mark['kind'])
    values={'pp':28,'p':38,'mp':49,'mf':63,'f':80,'ff':92,'fp':80}
    for mark in expr['dynamics']:
        for b in [b for b in bars if b['source']==mark['measure']]:
            d=E.Element('direction',placement='above');E.SubElement(E.SubElement(E.SubElement(d,'direction-type'),'dynamics'),mark['value']);E.SubElement(d,'sound',dynamics=str(values[mark['value']]));direction(mark['role'],b,mark['onset'],d)
    for w in expr['wedges']:
        for b in [b for b in bars if b['source']==w['measure']]:
            end=next(bb for bb in bars if bb['source']==w['toMeasure'] and bb['passage']==b['passage'])
            for target,onset,kind in [(b,w['onset'],w['kind']),(end,w['toOnset'],'stop')]:
                d=E.Element('direction',placement='above');E.SubElement(E.SubElement(d,'direction-type'),'wedge',type=kind,number='1');direction(w['role'],target,onset,d)
    # PDF quarter=70 governs the official arrangement. Text-only slowing
    # indications use a documented editorial destination of 55 BPM.
    tempos={0:(70,True,None)}
    ramps=[(18,2,19,1,'rit.'),(23,0,25,3,'allargando'),(41,1,42,0,'rit.'),(46,0,51,1,'allarg.'),(64,3,67,2,'rall.'),(78,0,79,1,'rit.'),(82,1.5,83,1,'rit.'),(88,2,90,0,'rall.')]
    for m,on,tm,to,label in ramps:
        begin=(m-1)*4+on;restore=(tm-1)*4+to
        finish=(49-1)*4 if m==46 else restore-.5
        for i in range(round((finish-begin)*2)+1):
            q=begin+i*.5;tempos[q]=(70-15*(q-begin)/(finish-begin),False,label if i==0 else None)
        tempos[restore]=(70,False,'a tempo' if m in [18,23,41,64,82,88] else None)
    for q,(bpm,visible,label) in sorted(tempos.items()):
        b=bars[int(q//4)];d=E.Element('direction',placement='above')
        if label:text(E.SubElement(d,'direction-type'),'words',label,**{'font-style':'italic'})
        else:
            mt=E.SubElement(E.SubElement(d,'direction-type'),'metronome',**({} if visible else {'print-object':'no'}));text(mt,'beat-unit','quarter');text(mt,'per-minute',round(bpm,6))
        E.SubElement(d,'sound',tempo=str(round(bpm,6)));direction(0,b,q-b['start'],d)
    for role,m,on,value in [(0,2,3,'Andante tranquillo · Soprano o Tenor'),(0,51,1,'Solo'),(0,67,0,'Con fervor'),(1,42,2,'cresc.'),(1,63,0,'cresc.'),(2,63,0,'cresc.'),(3,63,0,'cresc.'),(4,63,0,'cresc.')]:
        d=E.Element('direction',placement='above');text(E.SubElement(d,'direction-type'),'words',value,**{'font-style':'italic'});direction(role,bars[m-1],on,d)
    for n in notes.values():n[:]=sorted(n,key=lambda c:ORDER.index(c.tag) if c.tag in ORDER else 999)
    E.indent(root);target=OUT/'Cuán Amables Son Tus Moradas - Oficial - SATB y solista - Cantai.musicxml';E.ElementTree(root).write(target,encoding='utf-8',xml_declaration=True)
    result=dict(bars=len(bars),quarterBeats=364,staves=5,notes=sum(not e.get('rest') for e in events),cueNotes=sum(e.get('cue',False) for e in events),ties=sum(e.get('tieStop',False) for e in events),slurs=len(slurs),lyricNotes=len(lyrics),tempoChanges=len(tempos),articulations=len(arts),dynamics=len(expr['dynamics']),wedges=len(expr['wedges']))
    (OUT/'preparation.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(result)
if __name__=='__main__':build()
