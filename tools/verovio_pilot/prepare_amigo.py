"""Unfold three independent lyric stanzas, retaining closed SATB and MIDI."""
import json,unicodedata,collections,copy,xml.etree.ElementTree as E
from no_hay_amigo_model import OUT,plan
TEXTS=[
'No hay amigo mejor que el Señor Mi Jesús es mi amigo más fiel Sólo Él me salvó de la muerte De vivir en las tinieblas de maldad me rescató Ahora tengo mi esperanza en Jesucristo Por amor se entregó el Salvador',
'No hay amigo tan tierno en bondad Que viviendo en maldad y en dolor Me miraste Señor que sufría Me tendiste tu mano y diste dicha a mi vivir Ahora canto feliz con los salvados Porque Cristo me escogió Gloria al Señor',
'Cuando siento aflicción en mi ser Cuando vienen las olas del mar Clamo al único ser Jesucristo Pronto ayuda Él me da y su mano presta está Gloria gloria a mi Señor tengo un amparo El Apóstol del Señor Naasón Joaquín',
'Hoy mi vida es para ti me compraste Salvador Porque tu eres para mi el motivo de vivir Sólo tengo una razón que decirte mi Señor Como Tú no hay amigo mejor']
def norm(s):return ''.join(c.casefold() for c in unicodedata.normalize('NFKC',s) if c.isalpha())
def text(p,k,v,**attrs):n=E.SubElement(p,k,attrs);n.text=str(v);return n
def underlay():
    rows=json.loads((OUT/'lyric-rows.json').read_text(encoding='utf-8'));streams=[[] for _ in range(4)]
    for r in rows:
        for c in r['chars']:
            c=copy.deepcopy(c);c['text']=unicodedata.normalize('NFKC',c['text'])
            if c['absolute']>=62:streams[3].append(c)
            else:streams[r['variant']-1].append(c)
    result=[collections.defaultdict(list) for _ in range(4)];report=[]
    for vi,chars in enumerate(streams):
        letters=[(i,ch) for i,c in enumerate(chars) for ch in norm(c['text'])];stream=''.join(ch for _,ch in letters)
        assert stream==norm(TEXTS[vi]),(vi,stream,norm(TEXTS[vi]))
        pos=0;pending=''
        for word in TEXTS[vi].split():
            count=len(norm(word));start=letters[pos][0];end=letters[pos+count-1][0]+1;pos+=count
            while end<len(chars) and not norm(chars[end]['text']) and chars[end]['text']!='_':end+=1
            chunk=chars[start:end];groups=[]
            for c in chunk:
                if c['text']=='_':continue
                if not groups or groups[-1]['id']!=c['id']:groups.append(dict(id=c['id'],text=''))
                groups[-1]['text']+=c['text']
            if pending:groups[0]['text']=pending+groups[0]['text'];pending=''
            while groups and not norm(groups[-1]['text']) and len(groups)>1:
                punctuation=groups.pop()['text']
                if punctuation in ['¡','"']:pending=punctuation+pending
                else:groups[-1]['text']+=punctuation
            # Resolve sub-letter assignments of tightly printed elisions.
            for _ in range(8):
                bad=next((i for i,g in enumerate(groups) if norm(g['text']) and not any(c in 'aeiouáéíóúüy' for c in norm(g['text']))),None)
                if bad is None or len(groups)==1:break
                dest=bad+1 if bad==0 else bad-1
                if dest<bad:groups[dest]['text']+=groups[bad]['text']
                else:groups[dest]['text']=groups[bad]['text']+groups[dest]['text']
                groups.pop(bad)
            for i,g in enumerate(groups):
                result[vi][g['id']].append(dict(text=g['text'],syllabic='single' if len(groups)==1 else 'begin' if i==0 else 'end' if i==len(groups)-1 else 'middle',join=i==0 and start>0 and chars[start-1]['text']=='_'))
            report.append(dict(variant=vi+1,word=word,groups=groups))
    (OUT/'word-underlay.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    return result
def build():
    lyrics=underlay();source=json.loads((OUT/'positioned-events.json').read_text());bars=plan();expanded=[];q=0
    # Join each two-beat final cadence to the next one-beat pickup.
    for cycle in range(3):
        for b in bars:
            if cycle and b['number']==1:continue
            length=b['duration']+(1 if cycle<2 and b['number']==37 else 0)
            expanded.append(dict(number=len(expanded)+1,start=q,duration=length,source=b['number'],cycle=cycle));q+=length
    assert q==318 and len(expanded)==109
    root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','No Hay Amigo Mejor')
    ident=E.SubElement(root,'identification');text(ident,'creator','Neftalí Medina F.',type='composer');text(ident,'creator','Omar G. Ortega H.',type='arranger')
    text(E.SubElement(ident,'encoding'),'software','Coro LLDM · desarrollo de tres estrofas con coro · referencia MIDI SATB')
    defaults=E.SubElement(root,'defaults');sc=E.SubElement(defaults,'scaling');text(sc,'millimeters',7);text(sc,'tenths',40)
    page=E.SubElement(defaults,'page-layout');text(page,'page-height',1697);text(page,'page-width',1200);margins=E.SubElement(page,'page-margins',type='both')
    for k in ['left-margin','right-margin','top-margin','bottom-margin']:text(margins,k,60)
    E.SubElement(defaults,'lyric-font',**{'font-family':'Times New Roman','font-size':'12'})
    parts=E.SubElement(root,'part-list');group=E.SubElement(parts,'part-group',type='start',number='1');text(group,'group-symbol','bracket');text(group,'group-barline','no')
    for partno,label in enumerate(['Soprano / Alto','Tenor / Bajo']):
        sp=E.SubElement(parts,'score-part',id=f'P{partno+1}');text(sp,'part-name',label);text(sp,'part-abbreviation','S / A' if partno==0 else 'T / B')
        ins=E.SubElement(sp,'score-instrument',id=f'I{partno+1}');text(ins,'instrument-name',label)
        mi=E.SubElement(sp,'midi-instrument',id=f'I{partno+1}');text(mi,'midi-channel',partno+1);text(mi,'midi-program',1)
    E.SubElement(parts,'part-group',type='stop',number='1')
    expanded_events=[]
    for cycle in range(3):
        for e in source:
            n=copy.deepcopy(e);n['absolute']+=106*cycle;n['cycle']=cycle
            b=next(b for b in expanded if b['start']<=n['absolute']<b['start']+b['duration']);n['bar']=b['number'];n['local']=n['absolute']-b['start'];expanded_events.append(n)
    sections={0:'Estrofa 1',62:'Coro',106:'Estrofa 2',168:'Coro',212:'Estrofa 3',274:'Coro'}
    pitchmap={0:('C',0),1:('C',1),2:('D',0),3:('D',1),4:('E',0),5:('E',1),6:('F',1),7:('G',0),8:('G',1),9:('A',0),10:('A',1),11:('B',0)}
    score_notes={}
    soprano_by_time={e['absolute']:e for e in source if e['role']==0}
    # Cantai reads lyrics per staff. Anchor the lower line to tenor attacks,
    # rather than duplicating lyrics on both voices of the same staff.
    tenor_attacks={e['absolute'] for e in source if e['role']==2 and not e.get('rest') and not e.get('tieStop')}
    by_id={e['id']:e for e in source}
    for stanza in lyrics:
        assert all(by_id[key]['absolute'] in tenor_attacks for key in stanza)
    for partno in range(2):
        part=E.SubElement(root,'part',id=f'P{partno+1}');previous_meter=3
        for b in expanded:
            meter=2 if b['source'] in [15,30] else 3
            m=E.SubElement(part,'measure',number=str(b['number']),**({'implicit':'yes'} if b['duration']!=meter else {}))
            if b['number']==1 or meter!=previous_meter:
                at=E.SubElement(m,'attributes')
                if b['number']==1:
                    text(at,'divisions',960);text(E.SubElement(at,'key'),'fifths',4)
                tm=E.SubElement(at,'time');text(tm,'beats',meter);text(tm,'beat-type',4)
                if b['number']==1:
                    clef=E.SubElement(at,'clef');text(clef,'sign','G' if partno==0 else 'F');text(clef,'line',2 if partno==0 else 4)
            previous_meter=meter
            for v in range(2):
                role=partno*2+v
                if v:text(E.SubElement(m,'backup'),'duration',round(b['duration']*960))
                row=sorted([e for e in expanded_events if e['role']==role and e['bar']==b['number']],key=lambda e:e['absolute'])
                assert abs(sum(e['duration'] for e in row)-b['duration'])<.0001,(role,b,row)
                for e in row:
                    if role==0 and e['absolute'] in sections:
                        d=E.SubElement(m,'direction',placement='above');text(E.SubElement(d,'direction-type'),'words',sections[e['absolute']],**{'font-weight':'bold'})
                    if role==0 and e['absolute']==0:
                        d=E.SubElement(m,'direction',placement='above');mt=E.SubElement(E.SubElement(d,'direction-type'),'metronome');text(mt,'beat-unit','quarter');text(mt,'per-minute',85);E.SubElement(d,'sound',tempo='85')
                    n=E.SubElement(m,'note',id=f"{e['id']}-pass{e['cycle']+1}")
                    score_notes[n.get('id')]=n
                    if e.get('rest'):E.SubElement(n,'rest')
                    else:
                        step,alter=pitchmap[e['pitch']%12];octave=e['pitch']//12-1
                        p=E.SubElement(n,'pitch');text(p,'step',step);text(p,'alter',alter);text(p,'octave',octave)
                    text(n,'duration',round(e['duration']*960))
                    for flag,kind in [('tieStop','stop'),('tieStart','start')]:
                        if e.get(flag):E.SubElement(n,'tie',type=kind)
                    text(n,'voice',v+1)
                    duration=e['duration'];dotted=duration in [.75,1.5];base=duration/1.5 if dotted else duration
                    text(n,'type',{.25:'16th',.5:'eighth',1:'quarter',2:'half',3:'half'}[base])
                    if dotted or duration==3:E.SubElement(n,'dot')
                    if not e.get('rest'):text(n,'stem','up' if v==0 else 'down')
                    if e.get('tieStart') or e.get('tieStop'):
                        nt=E.SubElement(n,'notations')
                        for flag,kind in [('tieStop','stop'),('tieStart','start')]:
                            if e.get(flag):E.SubElement(nt,'tied',type=kind)
                    if not e.get('rest') and e['measure'] in [10,18] and e['onset'] in [0,2]:
                        nt=n.find('notations')
                        if nt is None:nt=E.SubElement(n,'notations')
                        E.SubElement(nt,'slur',type='start' if e['onset']==0 else 'stop',number=str(v+1),placement='above' if v==0 else 'below')
                    if role==0 and e['measure'] in [22,37] and e['onset']==0:
                        nt=n.find('notations')
                        if nt is None:nt=E.SubElement(n,'notations')
                        text(nt,'fermata','normal',type='upright')
                    if role in [0,2] and not e.get('rest'):
                        reference=soprano_by_time.get(e['absolute']-106*e['cycle'])
                        atoms=lyrics[3 if e['absolute']%106>=62 else e['cycle']].get(reference['id'],[]) if reference else []
                        if atoms:
                            ly=E.SubElement(n,'lyric',number='1',placement='below');before=atoms[0]['syllabic'] in ['middle','end'];after=atoms[-1]['syllabic'] in ['begin','middle'];text(ly,'syllabic','middle' if before and after else 'end' if before else 'begin' if after else 'single')
                            value=''.join(('‿' if a['join'] else ' ') * bool(i)+a['text'] for i,a in enumerate(atoms));text(ly,'text',value)
            if b['number']==109:text(E.SubElement(m,'barline',location='right'),'bar-style','light-heavy')
    for lyric_role in [0,2]:
        seq=[score_notes[f"{e['id']}-pass{e['cycle']+1}"] for e in sorted(expanded_events,key=lambda e:e['absolute']) if e['role']==lyric_role]
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
    E.indent(root);target=OUT/'No Hay Amigo Mejor - SATB desarrollado.musicxml';E.ElementTree(root).write(target,encoding='utf-8',xml_declaration=True)
    (OUT/'expanded-events.json').write_text(json.dumps(expanded_events,indent=2),encoding='utf-8')
    print(target,'measures',len(expanded),'duration',q,'notes',sum(not e.get('rest') for e in expanded_events))
if __name__=='__main__':build()
