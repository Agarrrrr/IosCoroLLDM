import json,collections,math,xml.etree.ElementTree as E
from fractions import Fraction as F
from eleccion_model import OUT,plan
from prepare_apostol import text,notation
ORDER=['cue','chord','pitch','rest','duration','tie','voice','type','dot','accidental','time-modification','stem','notehead','beam','notations','lyric']
def build():
    events=json.loads((OUT/'positioned-events.json').read_text());lyrics=json.loads((OUT/'lyric-atoms.json').read_text(encoding='utf-8'));expr=json.loads((OUT/'expressions-reading.json').read_text());bars=plan();notes={};measures={};byid={e['id']:e for e in events}
    root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Elección Apostólica');ident=E.SubElement(root,'identification');text(ident,'creator','Zimri Y. Gutiérrez.',type='composer');text(ident,'rights','© Partitura Oficial. Ministerio Internacional de Cultura y Educación Cristiana. J.U.D Orfeones / Comisiones de Cantos');enc=E.SubElement(ident,'encoding');text(enc,'software','Coro LLDM · SATB desarrollado · PDF digital y MIDI de referencia');text(enc,'encoding-date','2026-10-18')
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
            m=E.SubElement(p,'measure',number=str(b['number']));measures[(role,b['number'])]=m
            if b['number']==1:
                a=E.SubElement(m,'attributes');text(a,'divisions',960);text(E.SubElement(a,'key'),'fifths',1);tm=E.SubElement(a,'time');text(tm,'beats',2);text(tm,'beat-type',4);clef=E.SubElement(a,'clef');text(clef,'sign','G' if role<3 else 'F');text(clef,'line',2 if role<3 else 4);text(clef,'clef-octave-change',-1) if role==2 else None
            previous=bars[b['number']-2] if b['number']>1 else b
            if (b['meter'],b['unit'])!=(previous['meter'],previous['unit']):
                tm=E.SubElement(E.SubElement(m,'attributes'),'time');text(tm,'beats',b['meter']);text(tm,'beat-type',b['unit'])
            if b['source']==18:m.insert(0,E.Element('print',**{'new-system':'yes'}))
            if b['source']==90:m.insert(0,E.Element('print',**{'new-page':'yes'}))
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
    slurs=[]
    for arc in expr['arcs']:
        if arc['kind']=='tie':continue
        for b in [b for b in bars if b['source']==arc['measure']]:
            slurs.append((select(arc['role'],arc['measure'],arc['onset'],b['passage']),select(arc['role'],arc['toMeasure'],arc['toOnset'],b['passage'])))
    for role in [0,1]:slurs.append((select(role,78,2,2),select(role,78,2.5,2)))
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
    # These four printed fermatas belong to the quarter rests, not to "vo".
    for role in range(4):
        e=next(e for e in events if e['role']==role and e['measure']==62 and e['onset']==3 and e.get('rest'));text(notation(notes[e['id']]),'fermata','normal',type='upright');arts.add((e['id'],'fermata'))
    values={'p':38,'mp':49,'mf':63,'f':80,'ff':92,'fp':80}
    for mark in expr['dynamics']:
        for b in [b for b in bars if b['source']==mark['measure']]:
            d=E.Element('direction',placement='above');E.SubElement(E.SubElement(E.SubElement(d,'direction-type'),'dynamics'),mark['value']);E.SubElement(d,'sound',dynamics=str(values[mark['value']]));direction(mark['role'],b,mark['onset'],d)
    for w in expr['wedges']:
        for b in [b for b in bars if b['source']==w['measure']]:
            end=next(bb for bb in bars if bb['source']==w['toMeasure'] and bb['passage']==b['passage'])
            for target,onset,kind in [(b,w['onset'],w['kind']),(end,w['toOnset'],'stop')]:
                d=E.Element('direction',placement='above');E.SubElement(E.SubElement(d,'direction-type'),'wedge',type=kind,number='1');direction(w['role'],target,onset,d)
    guide=json.loads((OUT/'midi-reading.json').read_text());tempos=[(0,60,True),(17,70,False),(154,90,True),(213,160,False)]
    for t in guide['tempos']:
        q=t['ticks']/guide['ppq'];bpm=t['bpm']
        if q>=299.5:tempos.append((q,bpm,False))
    # The final rit. begins at the printed "su"; the guide inserts an
    # unprinted slowdown to 46 at that point. Use its following 92 BPM value.
    tempos.append((298,92,False));tempos.sort()
    for q,bpm,visible in tempos:
        b=next(b for b in bars if b['start']<=q<b['start']+b['duration']);d=E.Element('direction',placement='above')
        if q in [17,213,298]:text(E.SubElement(d,'direction-type'),'words',{17:'A tempo',213:'Presto',298:'rit.'}[q],**{'font-style':'italic'})
        else:
            mt=E.SubElement(E.SubElement(d,'direction-type'),'metronome',**({} if visible else {'print-object':'no'}));text(mt,'beat-unit','quarter');text(mt,'per-minute',round(bpm,6))
        E.SubElement(d,'sound',tempo=str(round(bpm,6)));direction(0,b,q-b['start'],d)
    for source,onset,value in [(1,0,'Adagio'),(18,0,'Solemne')]:
        for b in [b for b in bars if b['source']==source]:
            d=E.Element('direction',placement='above');text(E.SubElement(d,'direction-type'),'words',value,**{'font-style':'italic'});direction(0,b,onset,d)
    for n in notes.values():n[:]=sorted(n,key=lambda c:ORDER.index(c.tag) if c.tag in ORDER else 999)
    E.indent(root);target=OUT/'Elección Apostólica - SATB extendido - Cantai.musicxml';E.ElementTree(root).write(target,encoding='utf-8',xml_declaration=True)
    result=dict(bars=len(bars),quarterBeats=319,staves=4,notes=sum(not e.get('rest') for e in events),cueNotes=sum(e.get('cue',False) for e in events),ties=sum(e.get('tieStop',False) for e in events),slurs=len(slurs),lyricNotes=len(lyrics),tempoChanges=len(tempos),articulations=len(arts),dynamics=len(expr['dynamics']),wedges=len(expr['wedges']))
    (OUT/'preparation.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(result)
if __name__=='__main__':build()
