import json,collections,xml.etree.ElementTree as E
from fractions import Fraction as F
from apostol_model import OUT,plan
def text(p,k,v,**attrs):n=E.SubElement(p,k,attrs);n.text=str(v);return n
def notation(n):
    block=n.find('notations')
    return block if block is not None else E.SubElement(n,'notations')
ORDER=['chord','pitch','rest','duration','tie','voice','type','dot','accidental','time-modification','stem','beam','notations','lyric']
def build():
    events=json.loads((OUT/'positioned-events.json').read_text());lyrics=json.loads((OUT/'lyric-atoms.json').read_text(encoding='utf-8'));expr=json.loads((OUT/'expressions-reading.json').read_text());bars=plan();systems=json.loads((OUT/'pdf-layout.json').read_text())['systems'];source_by_id={e['id']:e for e in events};notes={};by_position=collections.defaultdict(list)
    root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Apóstol, Padre y Maestro');ident=E.SubElement(root,'identification');text(ident,'creator','Ágel Fabián Linares Ruiz / Gerson Linares Silva',type='composer');text(ident,'creator','Gerson Linares Silva / Á. Fabián Linares Ruiz',type='arranger');text(ident,'rights','© Partitura Oficial. Ministerio Internacional de Cultura y Educación Cristiana. J.U.D Orfeones / Comisiones de Cantos');enc=E.SubElement(ident,'encoding');text(enc,'software','Coro LLDM · SATB extendido · PDF digital y MIDI de referencia');text(enc,'encoding-date','2026-10-17')
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
            m=E.SubElement(part,'measure',number=str(b['number']));measures[(role,b['number'])]=m
            if b['number']==1:
                a=E.SubElement(m,'attributes');text(a,'divisions',960);text(E.SubElement(a,'key'),'fifths',1);tm=E.SubElement(a,'time');text(tm,'beats',4);text(tm,'beat-type',4);clef=E.SubElement(a,'clef');text(clef,'sign','F' if role>=2 else 'G');text(clef,'line',4 if role>=2 else 2)
            if b['source'] in [15,16,55,72]:
                a=E.SubElement(m,'attributes')
                if b['source'] in [55,72]:text(E.SubElement(a,'key'),'fifths',0 if b['source']==55 else 1)
                if b['source'] in [15,16]:
                    tm=E.SubElement(a,'time');text(tm,'beats',1 if b['source']==15 else 4);text(tm,'beat-type',4)
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
                text(n,'voice',1);d=F(e['duration']).limit_denominator(96)
                if e.get('tuplet'):dots=0;base=F(e['written'])
                else:
                    dots=e.get('dots',1 if e.get('dot') else 0);base=d/(2-F(1,2**dots)) if dots else d
                text(n,'type',{F(1,4):'16th',F(1,2):'eighth',F(1):'quarter',F(2):'half',F(4):'whole'}[base])
                for _ in range(dots):E.SubElement(n,'dot')
                if e.get('tuplet'):
                    tm=E.SubElement(n,'time-modification');text(tm,'actual-notes',3);text(tm,'normal-notes',2);text(tm,'normal-type','eighth' if base==F(1,2) else 'quarter')
                    for flag,kind in [('tupletStart','start'),('tupletStop','stop')]:
                        if e.get(flag):E.SubElement(notation(n),'tuplet',type=kind,number='1',bracket='yes' if base==1 else 'no')
                if not e.get('rest'):
                    text(n,'stem',e.get('stem','down' if role==0 else 'up'))
                    if e.get('beams'):
                        peers=sorted([ee for ee in row if ee.get('beamGroup')==e.get('beamGroup')],key=lambda ee:ee['onset']) if e.get('beamGroup') else []
                        for level in range(1,e['beams']+1):
                            same=[ee for ee in peers if ee.get('beams',0)>=level]
                            if len(same)>1:text(n,'beam','begin' if e==same[0] else 'end' if e==same[-1] else 'continue',number=str(level))
                for flag,kind in [('tieStop','stop'),('tieStart','start')]:
                    if e.get(flag):E.SubElement(notation(n),'tied',type=kind)
                atoms=lyrics.get(e['id'],[])
                if atoms:
                    assert not chord and not e.get('tieStop'),e
                    ly=E.SubElement(n,'lyric',number='1',placement='below');before=atoms[0]['syllabic'] in ['middle','end'];after=atoms[-1]['syllabic'] in ['begin','middle'];text(ly,'syllabic','middle' if before and after else 'end' if before else 'begin' if after else 'single');value=''.join(('‿' if a['join'] else ' ')*bool(i)+a['text'] for i,a in enumerate(atoms));text(ly,'text',value)
            if b['number']==95:text(E.SubElement(m,'barline',location='right'),'bar-style','light-heavy')
    # Extend each staff's lyric independently, including actual tied notes.
    for part in root.findall('part'):
        seq=[n for n in part.findall('.//note') if n.find('chord') is None and n.findtext('voice','1')=='1']
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
        for passage in ([1,2] if 63<=src['measure']<=65 else [1]):
            na=select(a['role'],src['measure'],src['onset'],passage,src['pitch']);nb=select(a['role'],dst['measure'],dst['onset'],passage,dst['pitch']);slurs.append((na,nb))
    active=collections.defaultdict(dict)
    for na,nb in sorted(slurs,key=lambda pair:(pair[0]['role'],pair[0]['absolute'])):
        role=na['role'];active[role]={k:v for k,v in active[role].items() if v>=na['absolute']};num=next(i for i in range(1,17) if i not in active[role]);active[role][num]=nb['absolute']
        for e,kind in [(na,'start'),(nb,'stop')]:E.SubElement(notation(notes[e['id']]),'slur',type=kind,number=str(num))
    arts=set()
    for a in expr['articulations']:
        source=source_by_id[a['id']];system=next(s for s in systems if s['page']==source['page'] and s['system']==source['system']);roles=[a['role']] if len(system['roles'])==4 else [a['role']//2*2,a['role']//2*2+1]
        for passage in ([1,2] if 63<=a['measure']<=65 else [1]):
            for role in roles:
                candidates=by_position.get((role,a['measure'],a['onset'],passage),[])
                if not candidates:continue
                e=candidates[0];key=(e['id'],a['kind'])
                if key in arts:continue
                arts.add(key);n=notes[e['id']];block=notation(n)
                if a['kind']=='fermata':text(block,'fermata','normal',type='inverted' if a.get('inverted') else 'upright')
                else:
                    art=block.find('articulations');art=art if art is not None else E.SubElement(block,'articulations');E.SubElement(art,a['kind'])
    def insert(role,bar,onset,direction):
        m=measures[(role,bar)];index=next(i for i,n in enumerate(m) if n.tag=='note');items=[]
        if onset:
            f=E.Element('forward');text(f,'duration',round(onset*960));items.append(f)
        items.append(direction)
        if onset:
            b=E.Element('backup');text(b,'duration',round(onset*960));items.append(b)
        for i,item in enumerate(items):m.insert(index+i,item)
    def source_bars(measure):return [b for b in bars if b['source']==measure]
    values={'p':38,'mp':49,'mf':63,'f':80,'ff':92,'fff':100,'sfz':90,'fp':80}
    for mark in expr['dynamics']:
        for b in source_bars(mark['measure']):
            d=E.Element('direction',placement='above');E.SubElement(E.SubElement(E.SubElement(d,'direction-type'),'dynamics'),mark['value']);E.SubElement(d,'sound',dynamics=str(values[mark['value']]));insert(mark['role'],b['number'],mark['onset'],d)
    for w in expr['wedges']:
        for b in source_bars(w['measure']):
            end=next(bb for bb in bars if bb['source']==w['toMeasure'] and bb['passage']==b['passage'])
            for target,onset,kind in [(b,w['onset'],w['kind']),(end,w['toOnset'],'stop')]:
                d=E.Element('direction',placement='above');E.SubElement(E.SubElement(d,'direction-type'),'wedge',type=kind,number='1');insert(w['role'],target['number'],onset,d)
    # The printed rit. in bar 54 approaches the reference Adagio tempo (78),
    # rather than remaining a text label with no audible change. The three
    # intermediate values are an explicit editorial interpolation.
    tempos=[(0,90,True),(44,78,False),(56.5,90,False),(210,87,False),(211,84,False),(212,81,False),(213,78,False),(244,96,False),(277,90,False)]
    for q,bpm,visible in tempos:
        b=next(b for b in bars if b['start']<=q<b['start']+b['duration'])
        d=E.Element('direction',placement='above');mt=E.SubElement(E.SubElement(d,'direction-type'),'metronome',**({} if visible else {'print-object':'no'}));text(mt,'beat-unit','quarter');text(mt,'per-minute',bpm);E.SubElement(d,'sound',tempo=str(bpm));insert(0,b['number'],q-b['start'],d)
    words=[(1,0,'Andante Maestoso'),(5,0,'Varones · Staccato Risoluto'),(12,0,'poco Rit.'),(15,.5,'dolce'),(25,0,'Afettuoso'),(31,0,'diminuendo'),(43,0,'attacca subito'),(44,0,'Espressivo'),(54,0,'rit.'),(54,3,'Dúo Hombres y Mujeres'),(55,0,'Adagio Afettuoso'),(62,3,'Allegro vivace'),(68,0,'poco Rit.'),(82,3,'decresc.'),(85,0,'attacca subito'),(87,0,'Espressivo'),(88,0,'Ad Libitum'),(89,0,'Ancor Piu Espressivo'),(91,0,'perdondosi')]
    for source,onset,value in words:
        for b in source_bars(source):
            role=2 if 5<=source<=14 else 0
            d=E.Element('direction',placement='above');attrs={'font-style':'italic'}
            if value=='Dúo Hombres y Mujeres':attrs.update(halign='right',**{'font-size':'9'})
            text(E.SubElement(d,'direction-type'),'words',value,**attrs);insert(role,b['number'],onset,d)
    # Keep the unison/solo sections on their own systems, as in the source.
    for b in bars:
        if b['source'] in [5,8,11,15,21,55,89]:
            for role in range(4):measures[(role,b['number'])].insert(0,E.Element('print',**{'new-system':'yes'}))
    # The source labels the men's unison Staccato Risoluto without printing
    # a dot over every note. Encode its playback explicitly and invisibly.
    hidden_staccato=0
    guide=json.loads((OUT/'midi-reading.json').read_text())
    for e in events:
        if e['role'] in [2,3] and 5<=e['measure']<=14 and not e.get('rest'):
            reference=next(n for n in guide['tracks'][e['role']]['notes'] if abs(n['ticks']/guide['ppq']-e['absolute'])<.001 and n['pitch']==e['pitch'])
            if reference['duration']/guide['ppq']>=e['duration']*.65:continue
            block=E.SubElement(notes[e['id']],'notations',**{'print-object':'no'});E.SubElement(E.SubElement(block,'articulations'),'staccato');hidden_staccato+=1
    for n in notes.values():n[:]=sorted(n,key=lambda c:ORDER.index(c.tag) if c.tag in ORDER else 999)
    E.indent(root);target=OUT/'Apóstol, Padre y Maestro - SATB extendido - Cantai.musicxml';E.ElementTree(root).write(target,encoding='utf-8',xml_declaration=True)
    report=dict(bars=95,staves=4,notes=sum(not e.get('rest') for e in events),slurs=len(slurs),ties=sum(e.get('tieStop',False) for e in events),articulations=len(arts),hiddenStaccatoPlayback=hidden_staccato,printedDynamicMarks=len(expr['dynamics']),tempoChanges=len(tempos),fermatas=9,tuplets=sum(e.get('tupletStart',False) for e in events));(OUT/'preparation.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(report)
if __name__=='__main__':build()
