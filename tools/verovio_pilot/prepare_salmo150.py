"""Complete SATB score: PDF underlay/notation, verified MIDI pitches and tempo."""
from pathlib import Path
import collections,contextlib,copy,io,json,re,unicodedata,xml.etree.ElementTree as E
import alabad_arcs
from extract_salmo150 import OUT
ORDER=['pitch','rest','duration','tie','voice','type','dot','accidental','time-modification','stem','beam','notations','lyric']
VOCAB='aleluya alabad alabaad alabadle alabaadle al señor y dios en su santidad engrandeced con alma voz de todo poder conforme grandeza gloria toda majestad canten los redimidos que él salvó amor santa iglesia le alabe cánticos resonantes gran júbilo prorrumpe alta loado sea el corazón espíritu cantad load sí férvida canción unidos hoy rey la creación lo respira potencia todos a'.split()
def text(parent,tag,value,**attrs):
    n=E.SubElement(parent,tag,attrs);n.text=str(value);return n
def clean(value):return ''.join(c for c in value.casefold() if c.isalpha())
def note_pitch(e):return 12*(e['diatonic']//7+1)+[0,2,4,5,7,9,11][e['diatonic']%7]+e['alter']
def notation(n):
    block=n.find('notations')
    return block if block is not None else E.SubElement(n,'notations')
def prepare():
    data=json.loads((OUT/'pdf-reading.json').read_text(encoding='utf-8'))
    assert not data['issues'] and not data['invalidTotals'] and not data['lyricIssues']
    alabad_arcs.OUT=OUT
    with contextlib.redirect_stdout(io.StringIO()):arc_data=alabad_arcs.read('salmo150')
    events=copy.deepcopy(data['events']);lookup={(e['role'],e['measure'],e['x']):e for e in arc_data['notes']}
    for e in events:
        if not e['rest']:e['id']=lookup[(e['role'],e['measure'],e['x'])]['id']
    arcs=copy.deepcopy(arc_data['arcs']);by_id={e['id']:e for e in events if not e['rest']}
    incoming=set();outgoing=set()
    for a in arc_data['partial']:
        na=by_id[a['start']['id']];nb=by_id[a['end']['id']]
        sa=next(s for s in data['systems'] if s['page']==na['page'] and s['system']==na['system'])
        sb=next(s for s in data['systems'] if s['page']==nb['page'] and s['system']==nb['system'])
        if a['start']['dx']<3 and a['start']['dy']<12 and a['geometry']['end'][0]>sa['bars'][-1]-5:outgoing.add(na['id'])
        if a['end']['dx']<3 and a['end']['dy']<12 and a['geometry']['start'][0]<nb['x']:incoming.add(nb['id'])
    for key in sorted(outgoing):
        n=by_id[key];original=next(x for x in arc_data['notes'] if x['id']==key)
        nxt=next(x for x in arc_data['notes'] if x['role']==n['role'] and x['voiceIndex']==original['voiceIndex']+1)
        assert nxt['id'] in incoming,(key,nxt['id'])
        kind='tie' if note_pitch(n)==note_pitch(nxt) and not nxt['lyrics'] else 'slur'
        arcs.append(dict(start=key,end=nxt['id'],kind=kind,role=n['role']))
    assert len(outgoing)==7 and len(incoming)==7
    # Deliberate MIDI-reference changes, retained explicitly in the audit.
    changes={'salmo150-3-115':(26,0),'salmo150-3-123':(26,0),
             'salmo150-0-141':(35,1),'salmo150-1-243':(31,1),
             'salmo150-3-285':(29,0)}
    applied=[]
    for key,(diatonic,alter) in changes.items():
        e=by_id[key];before=note_pitch(e);e['diatonic']=diatonic;e['alter']=alter;e.pop('accidental',None)
        applied.append(dict(id=key,role=e['role'],measure=e['measure'],pdf=before,midi=note_pitch(e)))
    # Segment the PDF's actual syllables into words; use MusicXML syllabic
    # metadata so MuseScore draws real hyphens, rather than literal hyphens.
    unknown=[];groups=[]
    for role in range(4):
        atoms=[]
        for e in sorted([e for e in events if e['role']==role and not e['rest']],key=lambda e:(e['measure'],e['onset'])):
            value=' '.join(t['text'] for t in sorted(e['lyrics'],key=lambda t:t['x']))
            if value:
                for i,chunk in enumerate(value.split('_')):atoms.append(dict(id=e['id'],text=chunk,join=i>0))
        i=0
        while i<len(atoms):
            options=[]
            for size in range(1,min(7,len(atoms)-i)+1):
                chunk=atoms[i:i+size]
                if any(re.search(r'[,.;:!?]',a['text']) for a in chunk[:-1]):break
                if ''.join(clean(a['text']) for a in chunk) in VOCAB:options.append(size)
            size=max(options) if options else 1
            if not options:unknown.append((role,atoms[i]['id'],atoms[i]['text']))
            chunk=atoms[i:i+size];groups.append(dict(role=role,word=''.join(a['text'] for a in chunk),ids=[a['id'] for a in chunk]))
            for j,a in enumerate(chunk):a['syllabic']='single' if size==1 else 'begin' if j==0 else 'end' if j==size-1 else 'middle'
            i+=size
        for a in atoms:by_id[a['id']].setdefault('lyricAtoms',[]).append(a)
    assert not unknown,unknown
    root=E.Element('score-partwise',version='4.0');work=E.SubElement(root,'work');text(work,'work-title','Salmo 150')
    ident=E.SubElement(root,'identification');text(ident,'creator','Louis Lewandovsky',type='composer')
    encoding=E.SubElement(ident,'encoding');text(encoding,'software','Coro LLDM: PDF digital contrastado con MIDI SATB');text(encoding,'encoding-date','2026-10-17')
    defaults=E.SubElement(root,'defaults');sc=E.SubElement(defaults,'scaling');text(sc,'millimeters',7);text(sc,'tenths',40)
    page=E.SubElement(defaults,'page-layout');text(page,'page-height',1697);text(page,'page-width',1200);margins=E.SubElement(page,'page-margins',type='both')
    for k in ['left-margin','right-margin','top-margin','bottom-margin']:text(margins,k,60)
    E.SubElement(defaults,'lyric-font',**{'font-family':'Times New Roman','font-size':'12'})
    pl=E.SubElement(root,'part-list');g=E.SubElement(pl,'part-group',type='start',number='1');text(g,'group-symbol','bracket');text(g,'group-barline','no')
    for role,label in enumerate(['Soprano','Alto','Tenor','Bajo']):
        sp=E.SubElement(pl,'score-part',id=f'P{role+1}');text(sp,'part-name',label);text(sp,'part-abbreviation','SATB'[role])
        instrument=E.SubElement(sp,'score-instrument',id=f'I{role}');text(instrument,'instrument-name',label)
        mi=E.SubElement(sp,'midi-instrument',id=f'I{role}');text(mi,'midi-channel',role+1);text(mi,'midi-program',1)
    E.SubElement(pl,'part-group',type='stop',number='1')
    midi=json.loads((OUT/'midi-reading.json').read_text());notes={}
    for role in range(4):
        part=E.SubElement(root,'part',id=f'P{role+1}')
        for number in range(1,74):
            system=next(s for s in data['systems'] if s['first']<=number<=s['last']);bi=number-system['first'];width=(system['bars'][bi+1]-system['bars'][bi])*40/19.8413+8
            m=E.SubElement(part,'measure',number=str(number),width=f'{width:.3f}')
            # Explicit boundaries only for major sections; normal bars flow.
            if number in [14,18,33,54,68,71]:E.SubElement(m,'print',**{'new-system':'yes'})
            if number==1:
                a=E.SubElement(m,'attributes');text(a,'divisions',960);key=E.SubElement(a,'key');text(key,'fifths',2)
                tm=E.SubElement(a,'time');text(tm,'beats',4);text(tm,'beat-type',4)
                clef=E.SubElement(a,'clef');text(clef,'sign','F' if role==3 else 'G');text(clef,'line',4 if role==3 else 2)
                if role==2:text(clef,'clef-octave-change',-1)
            row=sorted([e for e in events if e['role']==role and e['measure']==number],key=lambda e:e['onset'])
            assert row
            for e in row:
                n=E.SubElement(m,'note',**({'id':e['id']} if not e['rest'] else {}));n.set('default-x',f"{(e['x']-system['bars'][bi])*40/19.8413+20:.3f}")
                if e['rest']:E.SubElement(n,'rest',**({'measure':'yes'} if e['glyph']=='∑' else {}))
                else:
                    p=E.SubElement(n,'pitch');text(p,'step','CDEFGAB'[e['diatonic']%7]);text(p,'alter',e['alter']);text(p,'octave',e['diatonic']//7);notes[e['id']]=n
                text(n,'duration',round(e['duration']*960));text(n,'voice',1)
                base=e['writtenDuration']/(1.5 if e.get('dot') else 1)
                text(n,'type',{4:'whole',2:'half',1:'quarter',.5:'eighth',.25:'16th'}[base])
                if e.get('dot'):E.SubElement(n,'dot')
                if 'accidental' in e:text(n,'accidental',{-1:'flat',0:'natural',1:'sharp'}[e['accidental']])
                if e.get('tuplet'):
                    mod=E.SubElement(n,'time-modification');text(mod,'actual-notes',3);text(mod,'normal-notes',2);text(mod,'normal-type','eighth')
                if 'stem' in e:text(n,'stem',e['stem'])
                if not e['rest']:
                    if e.get('staccato'):E.SubElement(E.SubElement(notation(n),'articulations'),'staccato')
                    if number==73:text(notation(n),'fermata','normal',type='upright')
                    if e.get('lyricAtoms'):
                        ly=E.SubElement(n,'lyric',number='1',placement='below')
                        previous=e['lyricAtoms'][0]['syllabic'] in ['middle','end'];following=e['lyricAtoms'][-1]['syllabic'] in ['begin','middle']
                        text(ly,'syllabic','middle' if previous and following else 'end' if previous else 'begin' if following else 'single')
                        for i,a in enumerate(e['lyricAtoms']):
                            if i:text(ly,'elision','‿' if a['join'] else ' ')
                            text(ly,'text',a['text'])
            if role==0:
                for tempo in midi['tempos']:
                    q=tempo['ticks']/midi['ppq']
                    if not (number-1)*4<=q<number*4:continue
                    local=q-(number-1)*4;cursor=0;anchor=None
                    for candidate in m.findall('note'):
                        if abs(cursor-local)<.0001:anchor=candidate;break
                        cursor+=int(candidate.findtext('duration'))/960
                    assert anchor is not None,('tempo between attacks',q)
                    bpm=round(tempo['bpm'],4);d=E.Element('direction',placement='above');dt=E.SubElement(d,'direction-type');mt=E.SubElement(dt,'metronome');text(mt,'beat-unit','quarter');text(mt,'per-minute',f'{bpm:g}')
                    E.SubElement(d,'sound',tempo=f'{bpm:g}');m.insert(list(m).index(anchor),d)
            if number==73:b=E.SubElement(m,'barline',location='right');text(b,'bar-style','light-heavy')
    beam_groups=collections.defaultdict(list)
    for e in events:
        if 'beamGroup' in e:beam_groups[(e['role'],e['measure'],*e['beamGroup'])].append(e)
    for row in beam_groups.values():
        for j,e in enumerate(row):
            n=notes[e['id']];text(n,'beam','begin' if j==0 else 'end' if j==len(row)-1 else 'continue',number='1')
            if e['beams']==2:
                before=j>0 and row[j-1]['beams']==2;after=j+1<len(row) and row[j+1]['beams']==2
                text(n,'beam','continue' if before and after else 'end' if before else 'begin' if after else 'forward hook' if j==0 else 'backward hook',number='2')
            if e.get('tuplet') and j in [0,len(row)-1]:
                E.SubElement(notation(n),'tuplet',type='start' if j==0 else 'stop',number='1',bracket='yes',**{'show-number':'actual'})
    active=collections.defaultdict(dict)
    for arc in sorted(arcs,key=lambda a:(by_id[a['start']]['role'],by_id[a['start']]['measure'],by_id[a['start']]['onset'])):
        a=by_id[arc['start']];b=by_id[arc['end']]
        if arc['kind']=='tie':
            assert note_pitch(a)==note_pitch(b),(a,b)
            for key,kind in [(a['id'],'start'),(b['id'],'stop')]:E.SubElement(notes[key],'tie',type=kind);E.SubElement(notation(notes[key]),'tied',type=kind)
        else:
            role=a['role'];q=(a['measure'],a['onset']);active[role]={k:v for k,v in active[role].items() if v>=q};num=next(i for i in range(1,17) if i not in active[role]);active[role][num]=(b['measure'],b['onset'])
            for key,kind in [(a['id'],'start'),(b['id'],'stop')]:E.SubElement(notation(notes[key]),'slur',type=kind,number=str(num))
    for part in root.findall('part'):
        seq=part.findall('.//note')
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
    for n in notes.values():
        block=n.find('notations')
        if block is not None:block[:]=sorted(block,key=lambda c:0 if c.tag=='tied' and c.get('type')=='stop' else 1)
        n[:]=sorted(n,key=lambda c:(ORDER.index(c.tag) if c.tag in ORDER else 999,0 if c.tag=='tie' and c.get('type')=='stop' else 1))
    E.indent(root);target=OUT/'Salmo 150 - SATB con letra.musicxml';E.ElementTree(root).write(target,encoding='utf-8',xml_declaration=True)
    report=dict(notes=len(notes),crossSystemArcs=len(outgoing),ties=sum(a['kind']=='tie' for a in arcs),slurs=sum(a['kind']=='slur' for a in arcs),triplets=len(data['tuplets']),syllabifiedWords=len(groups),pitchChanges=applied,midiTempos=midi['tempos'])
    (OUT/'preparation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');(OUT/'lyric-words.json').write_text(json.dumps(groups,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2));print(target)
if __name__=='__main__':prepare()
