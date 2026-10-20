"""Complete pilot scores. Bundled MIDI is never modified; sources are copied.

The third work uses ONLY bundled PDF/MIDI plus an OMR pass on that PDF.
The two existing examples retain their own previously supplied editable notation.
"""
from pathlib import Path
import collections,copy,difflib,hashlib,json,math,shutil,subprocess,xml.etree.ElementTree as E
from inspect_sources import SOURCE,OUT,NODE,xml_events,source_files
from prepare_scores import text,rest
from complete_lyrics import AC,VEN,VEN_ALTO

BASE=OUT/'complete';ASSETS=Path('output/verovio_pilot/assets/scores')
ORDER=['grace','cue','chord','pitch','unpitched','rest','duration','tie','instrument','voice','type','dot','accidental','time-modification','stem','notehead','staff','beam','notations','lyric']
def tidy(n):n[:]=sorted(n,key=lambda e:ORDER.index(e.tag) if e.tag in ORDER else 999)
def lyric(n,value,verse=1,placement='below'):
    if value=='_':
        l=E.SubElement(n,'lyric',number=str(verse),placement=placement);E.SubElement(l,'extend',type='continue');return
    l=E.SubElement(n,'lyric',number=str(verse),placement=placement)
    text(l,'syllabic','single')
    for i,word in enumerate(value.split('~')):
        if i:text(l,'elision',' ')
        text(l,'text',word)
def write(root,key):
    for n in root.findall('.//note'):tidy(n)
    E.indent(root);E.ElementTree(root).write(ASSETS/(key+'.musicxml'),encoding='utf-8',xml_declaration=True)
def dump_midi(key):
    path=BASE/(key+'.mid')
    data=json.loads(subprocess.run(['node','-e',NODE,str(path)],check=True,capture_output=True,text=True).stdout)
    (BASE/(key+'-midi.json')).write_text(json.dumps(data),encoding='utf-8')
    shutil.copy2(path,ASSETS/(key+'.mid'));return data
def note_ref(key,role,mi,ni):return f'{key}-{role}-{mi}-{ni}'
def q_of(n,midi):return n['ticks']/midi['ppq']
def automatic_beams(notes):
    """Beam short notes within a beat; quarter notes are never beamed."""
    groups=collections.defaultdict(list)
    for n,local,dur in notes:
        for b in n.findall('beam'):n.remove(b)
        if dur<=.75 and n.find('rest') is None:groups[int(local)].append((n,local,dur))
    for group in groups.values():
        group.sort(key=lambda e:e[1]);runs=[];run=[]
        for row in group:
            if run and abs(run[-1][1]+run[-1][2]-row[1])>.01:runs.append(run);run=[]
            run.append(row)
        runs.append(run)
        for run in runs:
            if len(run)<2:continue
            for i,(n,_,dur) in enumerate(run):
                text(n,'beam','begin' if i==0 else 'end' if i==len(run)-1 else 'continue',number='1')
            short=[(i,n) for i,(n,_,dur) in enumerate(run) if dur<=.25]
            for i,n in short:
                prev=any(j==i-1 for j,_ in short);nxt=any(j==i+1 for j,_ in short)
                text(n,'beam',('continue' if prev and nxt else 'end' if prev else 'begin' if nxt else 'forward hook' if i==0 else 'backward hook'),number='2')
def notation(n,tag,**attrs):
    block=n.find('notations')
    if block is None:block=E.SubElement(n,'notations')
    return E.SubElement(block,tag,attrs)

def ac_complete():
    key='acercame';source=source_files()[0][1];original=E.parse(source).getroot();midi=dump_midi(key)
    assigned=[];notes_by={};route=list(range(25))*2+list(range(24))+[25,26,27]
    for e in xml_events(original):
        q=e['onset']+(196 if e['measure']>=25 else 0);tick=round(q*midi['ppq']);matches=[]
        for role in range(e['part']*2,e['part']*2+2):
            for n in midi['tracks'][role]['notes']:
                tied=e['element'].find("tie[@type='stop']") is not None
                if n['pitch']==e['pitch'] and (n['ticks']==tick or tied and n['ticks']<tick<n['ticks']+n['duration']+2):matches.append((role,n))
        assert len(matches)==1,(e['measure'],e['pitch'],len(matches))
        role,n=matches[0];assigned.append(e|dict(role=role,midi=n))
    root=E.Element('score-partwise',version='4.0');work=E.SubElement(root,'work');text(work,'work-title','Acércame a Ti')
    pl=E.SubElement(root,'part-list');sp=E.SubElement(pl,'score-part',id='P1');text(sp,'part-name','SATB');part=E.SubElement(root,'part',id='P1')
    events=[];unassigned=[]
    for mi in range(28):
        m=E.SubElement(part,'measure',number=str(mi+1));a=E.SubElement(m,'attributes');text(a,'divisions',480)
        old=original.find('part').findall('measure')[mi]
        for field in ['key','time']:
            v=old.find('attributes/'+field)
            if v is not None:a.append(copy.deepcopy(v))
        if mi==0:
            text(a,'staves',2)
            for sn,sign,line in [(1,'G',2),(2,'F',4)]:c=E.SubElement(a,'clef',number=str(sn));text(c,'sign',sign);text(c,'line',line)
            d=E.SubElement(m,'direction');dt=E.SubElement(d,'direction-type');text(dt,'words','Estrofas 1, 2 y 3');E.SubElement(d,'sound',tempo='90')
        if mi==16:d=E.SubElement(m,'direction');dt=E.SubElement(d,'direction-type');text(dt,'words','CORO')
        for role in range(4):
            if role:b=E.SubElement(m,'backup');text(b,'duration',1920)
            cursor=0;rows=sorted([e for e in assigned if e['role']==role and e['measure']==mi],key=lambda e:e['local']);beam_rows=[]
            for ni,e in enumerate(rows):
                local=e['local'];dur=e['duration'];start=round(local*480);rest(m,start-cursor,role//2+1,role%2+1)
                n=copy.deepcopy(e['element']);n.set('id',note_ref(key,role,mi,ni));notes_by[(role,mi,round(local,4))]=n
                for tag in ['chord','voice','staff','stem','beam','lyric']:
                    for child in n.findall(tag):n.remove(child)
                n.find('duration').text=str(round(dur*480));text(n,'voice',role%2+1);text(n,'stem','up' if role%2==0 else 'down');text(n,'staff',role//2+1)
                if role==0:
                    for verse,phrase in enumerate(AC[mi],1):
                        values=phrase.split('|')
                        if ni<len(values):lyric(n,values[ni],verse,'above' if 8<=mi<=12 or mi==26 else 'below')
                        elif n.find("tie[@type='stop']") is None:unassigned.append((mi+1,ni,verse))
                m.append(n);beam_rows.append((n,local,dur));cursor=start+round(dur*480)
                # Explicit traversal, rather than Verovio's inference of complex endings.
                offset=0
                for occurrence,measure_index in enumerate(route):
                    if measure_index!=mi:continue
                    pq=occurrence*4+local;pt=round(pq*midi['ppq'])
                    candidates=[x for x in midi['tracks'][role]['notes'] if x['pitch']==e['pitch'] and (x['ticks']==pt or n.find("tie[@type='stop']") is not None and x['ticks']<pt<x['ticks']+x['duration']+2)]
                    assert len(candidates)==1,(mi,role,pq,e['pitch'])
                    hit=candidates[0];start_time=hit['time']+max(0,pt-hit['ticks'])/midi['ppq']*60/90
                    events.append(dict(id=n.get('id'),role=role,pitch=e['pitch'],q=pq,scoreQ=e['onset'],time=start_time,duration=min(dur*60/90,max(.03,hit['time']+hit['seconds']-start_time)),measure=mi+1,verse=min(3,occurrence//25+1) if mi<16 else 0))
            rest(m,1920-cursor,role//2+1,role%2+1);automatic_beams(beam_rows)
        for b in old.findall('barline'):m.append(copy.deepcopy(b))
    # Distinct counterpoint is retained; shared text is not repeated four times.
    echo={
      (1,3):(['Ti,','mi','Se','ñor,','Tu','Tu'],['quí,','oh','Se','ñor,','Con','Con'],['ción,','con','a','mor,','Tu','A']),
      (1,8):(['Yo','quie','ro','vol','ver','oh','Se'],['Fue','muy','gra','ve','mi','e','_'],['Que','en','e','lla~en','cuen','tre','_']),
      (1,10):(['Yo','quie','ro','vol','ver','ha','cia'],['Que','me','a','par','tó','de','_'],['Que','en','e','lla~en','cuen','tre','per']),
      (2,1):(['_','Quie','ro~es','tar','jun','to~a'],['_','Me','a','cer','co','a'],['_','Y','su','bli','me~ex','pia']),
    }
    for (role,mi),verses in echo.items():
        rows=sorted([(k,n) for k,n in notes_by.items() if k[0]==role and k[1]==mi])
        for vi,values in enumerate(verses,1):
            for (_,n),value in zip(rows,values):lyric(n,value,vi)
    for local,value in [(0,'Quie'),(1.5,'ro'),(3,'Se')]:
        n=notes_by.get((1,26,local))
        if n is not None:lyric(n,value)
    # Restore phrase slurs recognized from OUR PDF, paired by role and measure.
    omr=BASE/'acercame-omr.musicxml';added=0
    if omr.exists():
        pending={}
        for e in xml_events(E.parse(omr).getroot()):
            for slur in e['element'].findall('notations/slur'):
                candidates=[(k,n) for k,n in notes_by.items() if k[0]//2==e['part'] and k[1]==e['measure'] and abs(k[2]-e['local'])<.02]
                signature=(e['part'],slur.get('number','1'))
                if slur.get('type')=='start':pending[signature]=candidates
                elif slur.get('type')=='stop' and signature in pending:
                    pairs=[(a,b) for a in pending.pop(signature) for b in candidates if a[0][0]==b[0][0]]
                    if pairs:
                        a,b=pairs[0];number=str(added%6+1);notation(a[1],'slur',type='start',number=number);notation(b[1],'slur',type='stop',number=number);added+=1
    write(root,key);(ASSETS/(key+'-events.json')).write_text(json.dumps(events),encoding='utf-8')
    assert not unassigned,unassigned
    return dict(key=key,title='Acércame a Ti',layout='closed',layoutLabel='Cerrado · 2',measures=28,verses=3,notes=len(assigned),events=len(events),slursAddedFromBundledPdf=added,duration=max(n['time']+n['seconds'] for t in midi['tracks'] for n in t['notes']),lyrics='Tres estrofas y coro transcritos del PDF de la app; letra compartida y respuestas distintas.')

def al_complete():
    key='al-gran-senor';root=E.parse(source_files()[1][1]).getroot();midi=dump_midi(key);events=[];groups=[];warnings=[]
    for role,part in enumerate(root.findall('part')):
        chains=[];active={}
        for index,e in enumerate(sorted([x for x in xml_events(root) if x['part']==role],key=lambda x:(x['onset'],x['pitch']))):
            n=e['element'];n.set('id',note_ref(key,role,e['measure'],index))
            for ly in n.findall('lyric'):
                ly.set('number','1')
                for t in ly.findall('text'):
                    if t.text=='granSe':t.text='gran Se'
            pitch=e['pitch'];stop=n.find("tie[@type='stop']") is not None
            if stop and pitch in active:chain=active[pitch];chain.append(e)
            else:chain=[e];chains.append(chain)
            if n.find("tie[@type='start']") is not None:active[pitch]=chain
            else:active.pop(pitch,None)
        # Musical pitch order is checked independently of the native timing.
        expected=[c[0]['pitch'] for c in chains];actual=[n['pitch'] for n in midi['tracks'][role]['notes']]
        assert len(expected)==len(actual)
        different=[i for i,(a,b) in enumerate(zip(expected,actual)) if a!=b]
        assert len(different)<=1,('unexpected source differences',role,different)
        for index in different:warnings.append(dict(role=role,measure=chains[index][0]['measure']+1,written=expected[index],midi=actual[index]))
        for chain,hit in zip(chains,midi['tracks'][role]['notes']):
            base=chain[0]['onset'];total=sum(e['duration'] for e in chain)
            for e in chain:
                fraction=max(0,(e['onset']-base)/total);start=hit['time']+fraction*hit['seconds']
                events.append(dict(id=e['element'].get('id'),role=role,pitch=hit['pitch'],writtenPitch=e['pitch'],pitchVerified=e['pitch']==hit['pitch'],q=q_of(hit,midi),scoreQ=e['onset'],time=start,duration=hit['seconds']*e['duration']/total,measure=e['measure']+1,verse=0))
        groups.append(len(chains))
    # Keep original clefs, key changes, note grouping, slurs, ties and all text.
    write(root,key);(ASSETS/(key+'-events.json')).write_text(json.dumps(events),encoding='utf-8')
    return dict(key=key,title='Al Gran Señor',layout='open',layoutLabel='Abierto · 4',measures=len(root.find('part').findall('measure')),verses=1,notes=len(events),events=len(events),nativeNotes=groups,warnings=warnings,duration=max(n['time']+n['seconds'] for t in midi['tracks'] for n in t['notes']),lyrics='Texto y notación del editable propio completo. Disposición abierta bloqueada.')

def sample_complete():
    key='app-sample';midi=dump_midi(key);root=E.Element('score-partwise',version='4.0')
    work=E.SubElement(root,'work');text(work,'work-title','Ven a la Cena')
    pl=E.SubElement(root,'part-list')
    # The source PDF has two staves in the stanzas and three in the chorus.
    for pi,label in enumerate(['S','S/A','T/B']):
        sp=E.SubElement(pl,'score-part',id='P'+str(pi+1));text(sp,'part-name',label)
    events=[];pitches=[('C',0),('C',1),('D',0),('E',-1),('E',0),('F',0),('F',1),('G',0),('A',-1),('A',0),('B',-1),('B',0)]
    for pi in range(3):
        part=E.SubElement(root,'part',id='P'+str(pi+1))
        for mi in range(16):
            measure=E.SubElement(part,'measure',number=str(mi+1))
            if mi==0:
                a=E.SubElement(measure,'attributes');text(a,'divisions',480);k=E.SubElement(a,'key');text(k,'fifths',-2)
                tm=E.SubElement(a,'time');text(tm,'beats',4);text(tm,'beat-type',4)
                c=E.SubElement(a,'clef');text(c,'sign','F' if pi==2 else 'G');text(c,'line',4 if pi==2 else 2)
                if pi==0:d=E.SubElement(measure,'direction');dt=E.SubElement(d,'direction-type');text(dt,'words','Estrofas 1–4');E.SubElement(d,'sound',tempo='90')
            if mi==8 and pi==0:d=E.SubElement(measure,'direction');dt=E.SubElement(d,'direction-type');text(dt,'words','CORO')
            roles=([0] if mi>=8 else []) if pi==0 else ([0,1] if mi<8 else [1]) if pi==1 else [2,3]
            if not roles:rest(measure,1920,None,1)
            for ri,role in enumerate(roles):
                if ri:b=E.SubElement(measure,'backup');text(b,'duration',1920)
                voice=ri+1;cursor=0;rows=[];verse_index=0
                native=[n for n in midi['tracks'][role]['notes'] if mi*4<=q_of(n,midi)<(mi+1)*4]
                for ni,hit in enumerate(native):
                    local=q_of(hit,midi)-mi*4;duration=round(hit['duration']/midi['ppq']/(.95 if role in [0,2] else 1)*4)/4
                    duration=min(duration,4-local)
                    # PDF sustain ties: retain one audio event with two visual notes.
                    splits=[2,duration-2] if (role==0 and mi in [8,10,12] and duration>2 or role==3 and mi==7 and duration==4) else [duration]
                    offset=0
                    for si,dur in enumerate(splits):
                        start=round((local+offset)*480);rest(measure,start-cursor,None,voice)
                        n=E.SubElement(measure,'note',id=note_ref(key,role,mi,ni*2+si));pitch=E.SubElement(n,'pitch');step,alter=pitches[hit['pitch']%12]
                        text(pitch,'step',step)
                        if alter:text(pitch,'alter',alter)
                        text(pitch,'octave',hit['pitch']//12-1);text(n,'duration',round(dur*480))
                        if len(splits)>1:E.SubElement(n,'tie',type='start' if si==0 else 'stop')
                        text(n,'voice',voice)
                        type_map={4:('whole',False),3:('half',True),2:('half',False),1.5:('quarter',True),1:('quarter',False),.75:('eighth',True),.5:('eighth',False),.25:('16th',False)}
                        kind,dot=type_map[dur];text(n,'type',kind)
                        if dot:E.SubElement(n,'dot')
                        key_alter=-1 if step in ['B','E'] else 0
                        if alter!=key_alter:text(n,'accidental','natural' if alter==0 else 'sharp' if alter==1 else 'flat')
                        if dur<4:text(n,'stem','up' if role in [0,2] else 'down')
                        if len(splits)>1:notation(n,'tied',type='start' if si==0 else 'stop')
                        if role==0:
                            for vi,phrase in enumerate(VEN[mi],1):
                                vals=phrase.split('|')
                                if verse_index<len(vals):lyric(n,vals[verse_index],vi)
                        elif role==1 and mi>=8:
                            vals=VEN_ALTO[mi].split('|')
                            if verse_index<len(vals):lyric(n,vals[verse_index])
                        rows.append((n,local+offset,dur));verse_index+=1
                        start_time=hit['time']+offset*60/90
                        events.append(dict(id=n.get('id'),role=role,pitch=hit['pitch'],q=mi*4+local+offset,scoreQ=mi*4+local+offset,time=start_time,duration=min(dur*60/90,max(.03,hit['time']+hit['seconds']-start_time)),measure=mi+1,verse=0))
                        cursor=start+round(dur*480);offset+=dur
                rest(measure,1920-cursor,None,voice);automatic_beams(rows)
                if mi==7 and role in [0,1,2] and len(rows)==2:
                    notation(rows[0][0],'slur',type='start',number='1');notation(rows[1][0],'slur',type='stop',number='1')
            if mi==15:b=E.SubElement(measure,'barline',location='right');text(b,'bar-style','light-heavy')
    write(root,key);(ASSETS/(key+'-events.json')).write_text(json.dumps(events),encoding='utf-8')
    selection=json.loads((BASE/'app-sample-selection.json').read_text(encoding='utf-8'))
    return dict(key=key,title='Ven a la Cena',layout='mixed',layoutLabel='Original · 2/3',measures=16,verses=4,notes=len(events),events=len(events),duration=max(n['time']+n['seconds'] for t in midi['tracks'] for n in t['notes']),lyrics='Cuatro estrofas y coro transcritos del PDF empaquetado; MIDI empaquetado sin eventos de letra. Audio: una vuelta.',catalogId=selection['row']['id'],pdfSha256=selection['pdfSha256'],midiSha256=selection['midSha256'],notation='Ritmo y voces del MIDI de la app; ligaduras y letra cotejadas con su PDF. El PDF y el MIDI tienen pequeñas variantes rítmicas, conservadas en los originales.')

def main():
    ASSETS.mkdir(parents=True,exist_ok=True)
    scores=[ac_complete(),al_complete(),sample_complete()]
    print(json.dumps(scores,ensure_ascii=False,indent=2))
    (BASE/'complete-manifest.json').write_text(json.dumps(scores,ensure_ascii=False,indent=2),encoding='utf-8')
    (ASSETS/'manifest.json').write_text(json.dumps(scores,ensure_ascii=False,indent=2),encoding='utf-8')
    from prepare_ties import prepare
    for row in scores:prepare(row['key'])

if __name__=='__main__':main()
