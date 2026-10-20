import json,collections,xml.etree.ElementTree as E
from fractions import Fraction as F
from recuerda_model import OUT,plan
def text(p,k,v,**attrs):n=E.SubElement(p,k,attrs);n.text=str(v);return n
def notation(n):
    block=n.find('notations')
    return block if block is not None else E.SubElement(n,'notations')
ORDER=['chord','pitch','rest','duration','tie','voice','type','dot','accidental','stem','beam','notations','lyric']
def build():
    events=json.loads((OUT/'positioned-events.json').read_text());lyrics=json.loads((OUT/'lyric-atoms.json').read_text(encoding='utf-8'));expr=json.loads((OUT/'expressions-reading.json').read_text());bars=plan();systems=json.loads((OUT/'pdf-layout.json').read_text())['systems'];source_by_id={e['id']:e for e in events};notes={};by_position=collections.defaultdict(list)
    root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Recuerda…');ident=E.SubElement(root,'identification');text(ident,'creator','Benjamín Rangel Valerio',type='composer');enc=E.SubElement(ident,'encoding');text(enc,'software','Coro LLDM · SATB extendido · PDF digital y MIDI de referencia');text(enc,'encoding-date','2026-10-17')
    defaults=E.SubElement(root,'defaults');sc=E.SubElement(defaults,'scaling');text(sc,'millimeters',7);text(sc,'tenths',40);page=E.SubElement(defaults,'page-layout');text(page,'page-height',1697);text(page,'page-width',1200);margin=E.SubElement(page,'page-margins',type='both')
    for k in ['left-margin','right-margin','top-margin','bottom-margin']:text(margin,k,60)
    E.SubElement(defaults,'lyric-font',**{'font-family':'Times New Roman','font-size':'12'})
    pl=E.SubElement(root,'part-list');g=E.SubElement(pl,'part-group',type='start',number='1');text(g,'group-symbol','bracket');text(g,'group-barline','no')
    for r,label in enumerate(['Soprano','Alto','Tenor','Bajo']):
        sp=E.SubElement(pl,'score-part',id=f'P{r+1}');text(sp,'part-name',label);text(sp,'part-abbreviation','SATB'[r]);ins=E.SubElement(sp,'score-instrument',id=f'I{r}');text(ins,'instrument-name',label);mi=E.SubElement(sp,'midi-instrument',id=f'I{r}');text(mi,'midi-channel',r+1);text(mi,'midi-program',1)
    E.SubElement(pl,'part-group',type='stop',number='1');measures={}
    for role in range(4):
        part=E.SubElement(root,'part',id=f'P{role+1}')
        for b in bars:
            m=E.SubElement(part,'measure',number=str(b['number']),**({'implicit':'yes'} if b['number']==1 else {}));measures[(role,b['number'])]=m
            if b['number']==1:
                a=E.SubElement(m,'attributes');text(a,'divisions',960);text(E.SubElement(a,'key'),'fifths',2);tm=E.SubElement(a,'time');text(tm,'beats',4);text(tm,'beat-type',4);clef=E.SubElement(a,'clef');text(clef,'sign','F' if role==3 else 'G');text(clef,'line',4 if role==3 else 2)
                if role==2:text(clef,'clef-octave-change',-1)
            row=sorted([e for e in events if e['role']==role and e['bar']==b['number']],key=lambda e:(e['onset'],e.get('pitch',0)));used=set()
            for e in row:
                n=E.SubElement(m,'note',id=e['id']);notes[e['id']]=n;chord=not e.get('rest') and e['onset'] in used
                if chord:E.SubElement(n,'chord')
                if e.get('rest'):E.SubElement(n,'rest',**({'measure':'yes'} if e['duration']==4 else {}))
                else:
                    used.add(e['onset']);p=E.SubElement(n,'pitch');text(p,'step','CDEFGAB'[e['diatonic']%7]);text(p,'alter',e['alter']);text(p,'octave',e['diatonic']//7);by_position[(role,e['measure'],e['onset'],e['passage'])].append(e)
                text(n,'duration',round(e['duration']*960))
                for flag,kind in [('tieStop','stop'),('tieStart','start')]:
                    if e.get(flag):E.SubElement(n,'tie',type=kind)
                text(n,'voice',1);d=F(e['duration']);dots=2 if d==F(7,2) else 1 if d in [F(3,4),F(3,2),F(3)] else 0;base=d/(2-F(1,2**dots)) if dots else d
                text(n,'type',{F(1,4):'16th',F(1,2):'eighth',F(1):'quarter',F(2):'half',F(4):'whole'}[base])
                for _ in range(dots):E.SubElement(n,'dot')
                for flag,kind in [('tieStop','stop'),('tieStart','start')]:
                    if e.get(flag):E.SubElement(notation(n),'tied',type=kind)
                atoms=lyrics.get(e['id'],[])
                if atoms:
                    assert not chord and not e.get('tieStop'),e
                    ly=E.SubElement(n,'lyric',number='1',placement='below');before=atoms[0]['syllabic'] in ['middle','end'];after=atoms[-1]['syllabic'] in ['begin','middle'];text(ly,'syllabic','middle' if before and after else 'end' if before else 'begin' if after else 'single');value=''.join(('‿' if a['join'] else ' ')*bool(i)+a['text'] for i,a in enumerate(atoms));text(ly,'text',value)
            if b['number']==88:text(E.SubElement(m,'barline',location='right'),'bar-style','light-heavy')
    # Extend each staff's lyric independently, including actual tied notes.
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
    def select(role,source,onset,passage,pitch=None):
        row=by_position[(role,source,onset,passage)]
        if pitch is not None:row=[e for e in row if e['pitch']==pitch]
        assert row,(role,source,onset,passage,pitch)
        return row[0]
    # Match each phrase arc to its exact printed pitch, including divisi.
    slurs=[]
    for a in expr['arcs']:
        if a['kind']!='slur':continue
        src=source_by_id[a['start']];dst=source_by_id[a['end']]
        for passage in ([1,2] if 2<=src['measure']<=28 else [1]):
            na=select(a['role'],src['measure'],src['onset'],passage,src['pitch']);nb=select(a['role'],dst['measure'],dst['onset'],passage,dst['pitch']);slurs.append((na,nb))
    # These printed arcs cross a system/page boundary. They are phrases with
    # different notes, not same-pitch sound ties.
    for role,ma,oa,mb,ob in [(2,31,0,32,0),(0,36,2,38,0),(2,37,2,38,0)]:slurs.append((select(role,ma,oa,1),select(role,mb,ob,1)))
    for na,nb in zip(sorted(by_position[(3,37,2,1)],key=lambda e:e['pitch']),sorted(by_position[(3,38,0,1)],key=lambda e:e['pitch'])):slurs.append((na,nb))
    active=collections.defaultdict(dict)
    for na,nb in sorted(slurs,key=lambda pair:(pair[0]['role'],pair[0]['absolute'])):
        role=na['role'];active[role]={k:v for k,v in active[role].items() if v>=na['absolute']};num=next(i for i in range(1,17) if i not in active[role]);active[role][num]=nb['absolute']
        for e,kind in [(na,'start'),(nb,'stop')]:E.SubElement(notation(notes[e['id']]),'slur',type=kind,number=str(num))
    arts=set()
    for a in expr['articulations']:
        source=source_by_id[a['id']];system=next(s for s in systems if s['page']==source['page'] and s['system']==source['system']);roles=[a['role']] if len(system['roles'])==4 else [a['role']//2*2,a['role']//2*2+1]
        for passage in ([1,2] if 2<=a['measure']<=28 else [1]):
            for role in roles:
                candidates=by_position.get((role,a['measure'],a['onset'],passage),[])
                if not candidates:continue
                e=candidates[0];key=(e['id'],a['kind'])
                if key in arts:continue
                arts.add(key);n=notes[e['id']];block=notation(n);art=block.find('articulations');art=art if art is not None else E.SubElement(block,'articulations');E.SubElement(art,a['kind'])
    def insert(role,bar,onset,direction):
        m=measures[(role,bar)];index=next(i for i,n in enumerate(m) if n.tag=='note');items=[]
        if onset:
            f=E.Element('forward');text(f,'duration',round(onset*960));items.append(f)
        items.append(direction)
        if onset:
            b=E.Element('backup');text(b,'duration',round(onset*960));items.append(b)
        for i,item in enumerate(items):m.insert(index+i,item)
    def source_bars(measure):return [b for b in bars if b['source']==measure]
    values={'p':38,'mp':49,'mf':63,'f':80,'ff':95,'fp':80}
    for mark in expr['dynamics']:
        for b in source_bars(mark['measure']):
            d=E.Element('direction',placement='above');E.SubElement(E.SubElement(E.SubElement(d,'direction-type'),'dynamics'),mark['value']);E.SubElement(d,'sound',dynamics=str(values[mark['value']]));insert(mark['role'],b['number'],mark['onset'],d)
    for w in expr['wedges']:
        for b in source_bars(w['measure']):
            end=next(bb for bb in bars if bb['source']==w['toMeasure'] and bb['passage']==b['passage'])
            for target,onset,kind in [(b,w['onset'],w['kind']),(end,w['toOnset'],'stop')]:
                d=E.Element('direction',placement='above');E.SubElement(E.SubElement(d,'direction-type'),'wedge',type=kind,number='1');insert(w['role'],target['number'],onset,d)
    for source,onset,value in [(9,3.5,'poco rit.'),(11,3.5,'poco accel.'),(13,3.5,'poco rit.'),(15,3.5,'poco accel.')]:
        for b in source_bars(source):
            d=E.Element('direction',placement='above');text(E.SubElement(d,'direction-type'),'words',value,**{'font-style':'italic'});insert(0,b['number'],onset,d)
    # Offsets in tempo directions are ignored by this MuseScore version.
    # Balanced forward/backup positions each real MIDI change without adding
    # notes, rests, ties or visible subdivisions to the musical voices.
    midi=json.loads((OUT/'midi-reading.json').read_text());tempos=[]
    for tempo in midi['tempos']:
        if tempos and abs(tempos[-1]['bpm']-tempo['bpm'])<.000001:continue
        tempos.append(tempo)
        q=tempo['ticks']/midi['ppq'];b=next(b for b in bars if b['start']<=q<b['start']+b['duration']);d=E.Element('direction',placement='above');mt=E.SubElement(E.SubElement(d,'direction-type'),'metronome',**({'print-object':'no'} if q else {}));text(mt,'beat-unit','quarter');text(mt,'per-minute',f"{tempo['bpm']:.8f}" if q else '63');E.SubElement(d,'sound',tempo=f"{tempo['bpm']:.8f}");insert(0,b['number'],q-b['start'],d)
    for bar,onset,value in [(1,.5,'Estrofa 1'),(17,2.75,'Coro'),(29,3.5,'Estrofa 2'),(45,2.75,'Coro')]:
        d=E.Element('direction',placement='above');text(E.SubElement(d,'direction-type'),'words',value,**{'font-weight':'bold'});insert(0,bar,onset,d)
    for n in notes.values():n[:]=sorted(n,key=lambda c:ORDER.index(c.tag) if c.tag in ORDER else 999)
    E.indent(root);target=OUT/'Recuerda - SATB extendido - Cantai.musicxml';E.ElementTree(root).write(target,encoding='utf-8',xml_declaration=True)
    report=dict(bars=88,staves=4,notes=sum(not e.get('rest') for e in events),slurs=len(slurs),ties=sum(e.get('tieStop',False) for e in events),articulations=len(arts),printedDynamicMarks=len(expr['dynamics']),midiTempoChanges=len(tempos));(OUT/'preparation.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(report)
if __name__=='__main__':build()
