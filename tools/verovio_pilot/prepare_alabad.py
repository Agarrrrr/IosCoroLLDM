"""Read PDF notation; apply the two voice corrections confirmed by its MIDI."""
from pathlib import Path
import collections,copy,json,xml.etree.ElementTree as E
from extract_alabad import length
OUT=Path('output/verovio_pilot_support/alabad')
ORDER=['pitch','rest','duration','tie','voice','type','dot','accidental','stem','beam','notations','lyric']
def text(parent,tag,value,**attrs):n=E.SubElement(parent,tag,attrs);n.text=str(value);return n
def prepare(duet='pending'):
    assert duet in ['pending','tenor','bass']
    data=json.loads((OUT/'pdf-reading.json').read_text(encoding='utf-8'))
    arc_data=json.loads((OUT/'arcs-reading.json').read_text(encoding='utf-8'))
    assert not data['issues'] and not data['invalidTotals'] and not data['lyricIssues']
    by_location={(n['role'],n['measure'],n['x']):n for n in arc_data['notes']}
    events=copy.deepcopy(data['events'])
    for e in events:
        if not e['rest']:e['id']=by_location[(e['role'],e['measure'],e['x'])]['id']
        if duet=='bass' and e['role']==2 and 18<=e['measure']<=32:e['role']=3
    arcs=copy.deepcopy(arc_data['arcs'])
    if duet=='tenor':
        # The MIDI keeps the duet's D3 in Tenor across the page turn.
        continuation=next(e for e in events if e.get('id')=='alabad-3-28')
        silence=next(e for e in events if e['role']==2 and e['measure']==33 and e['rest'])
        continuation['role']=2;continuation['clef']='G8'
        silence['role']=3;silence['clef']='F'
        arcs.append(dict(start='alabad-2-63',end='alabad-3-28',kind='tie',role=2))
        # In the supplied arrangement Alto doubles Tenor one octave higher
        # in 80--93. Read rhythm/underlay from the PDF and verify pitches
        # against MIDI, instead of quantising its gated note durations.
        events=[e for e in events if not(e['role']==1 and 80<=e['measure']<=93)]
        added=[];mapping={}
        for e in list(events):
            if e['role']!=2 or not 80<=e['measure']<=93:continue
            a=copy.deepcopy(e);a['role']=1;a['clef']='G'
            if not a['rest']:
                a['diatonic']+=7;mapping[a['id']]='alto-added-'+a['id'];a['id']=mapping[a['id']]
            added.append(a)
        events+=added
        arcs += [dict(a,start=mapping[a['start']],end=mapping[a['end']],role=1)
                 for a in list(arcs) if a['start'] in mapping and a['end'] in mapping]
    # These two complete links are split across source system/page boundaries.
    arcs += [dict(start='alabad-0-60',end='alabad-0-61',kind='tie',role=0),
             dict(start='alabad-0-157',end='alabad-0-158',kind='tie',role=0)]
    if duet=='bass':arcs.append(dict(start='alabad-2-63',end='alabad-3-28',kind='tie',role=3))
    root=E.Element('score-partwise',version='4.0')
    work=E.SubElement(root,'work');text(work,'work-title','Alabad a Jehová')
    ident=E.SubElement(root,'identification')
    text(ident,'creator','Jerson Hernández / Fabián Linares / Gerson Linares',type='composer')
    text(ident,'creator','Fabián Linares / Gerson Linares',type='arranger')
    enc=E.SubElement(ident,'encoding');text(enc,'encoding-date','2026-10-17');text(enc,'software','Coro LLDM: reconstrucción desde geometría y texto del PDF digital')
    defaults=E.SubElement(root,'defaults');sc=E.SubElement(defaults,'scaling');text(sc,'millimeters',7);text(sc,'tenths',40)
    page=E.SubElement(defaults,'page-layout');text(page,'page-height',1697);text(page,'page-width',1200)
    margins=E.SubElement(page,'page-margins',type='both')
    for k,v in [('left-margin',60),('right-margin',60),('top-margin',60),('bottom-margin',60)]:text(margins,k,v)
    E.SubElement(defaults,'lyric-font',**{'font-family':'Times New Roman','font-size':'12'})
    pl=E.SubElement(root,'part-list');group=E.SubElement(pl,'part-group',type='start',number='1');text(group,'group-symbol','bracket');text(group,'group-barline','no')
    for role,label in enumerate(['Soprano','Alto','Tenor','Bajo']):
        sp=E.SubElement(pl,'score-part',id=f'P{role+1}');text(sp,'part-name',label);text(sp,'part-abbreviation','SATB'[role])
        instrument=E.SubElement(sp,'score-instrument',id=f'I{role}');text(instrument,'instrument-name',label)
        mi=E.SubElement(sp,'midi-instrument',id=f'I{role}');text(mi,'midi-channel',role+1);text(mi,'midi-program',1)
    E.SubElement(pl,'part-group',type='stop',number='1')
    notes={};starts={s['first']:s for s in data['systems']}
    known_words={1:'Maestoso con vigore',18:'Dueto: Soprano / '+('Bajo' if duet=='bass' else 'Tenor'),33:'Trío: Soprano / Tenor / Bajo',
        51:'Con brio',59:'Marziale',69:'rit.',72:'Dolce',73:'Solista Soprano',80:'Dueto solistas: Soprano / Tenor',
        94:'Risoluto',101:'rit.',105:'Molto solemne',129:'rit.',138:'cresc.'}
    if duet=='tenor':known_words[80]='Trío: Soprano / Alto / Tenor'
    for role in range(4):
        part=E.SubElement(root,'part',id=f'P{role+1}');previous_clef=None
        for number in range(1,139):
            source=next(s for s in data['systems'] if s['first']<=number<=s['last']);bi=number-source['first']
            width=(source['bars'][bi+1]-source['bars'][bi])*40/19.8413+8
            m=E.SubElement(part,'measure',number=str(number),width=f'{width:.3f}')
            if number in [8,13,18,33,42,51,71,75,80,93,105,112,133]:E.SubElement(m,'print',**{'new-system':'yes'})
            attrs=E.SubElement(m,'attributes');text(attrs,'divisions',480)
            if number in [1,51,71]:
                key=E.SubElement(attrs,'key');text(key,'fifths',-2 if number==51 else 1)
            if number in [1,51,71,93,112]:
                tm=E.SubElement(attrs,'time');text(tm,'beats',6 if length(number)==3 else 4);text(tm,'beat-type',8 if length(number)==3 else 4)
            row=sorted([e for e in events if e['role']==role and e['measure']==number],key=lambda e:e['x'])
            clef=row[0]['clef'] if row else previous_clef or ('F' if role==3 else 'G8' if role==2 else 'G')
            if clef!=previous_clef:
                c=E.SubElement(attrs,'clef');text(c,'sign','F' if clef=='F' else 'G');text(c,'line',4 if clef=='F' else 2)
                if clef=='G8':text(c,'clef-octave-change',-1)
                previous_clef=clef
            if role==0 and number in known_words:
                d=E.SubElement(m,'direction',placement='above');dt=E.SubElement(d,'direction-type');text(dt,'words',known_words[number])
            if role==3 and number in [97,122]:
                d=E.SubElement(m,'direction',placement='below');dt=E.SubElement(d,'direction-type');text(dt,'words','rit.')
            if role==0 and number==1:
                d=E.SubElement(m,'direction',placement='above');dt=E.SubElement(d,'direction-type');mt=E.SubElement(dt,'metronome');text(mt,'beat-unit','quarter');text(mt,'per-minute',68);E.SubElement(d,'sound',tempo='68')
            if not row:
                n=E.SubElement(m,'note');E.SubElement(n,'rest',measure='yes');text(n,'duration',round(length(number)*480));text(n,'voice',1)
            for e in row:
                n=E.SubElement(m,'note',**({'id':e['id']} if not e['rest'] else {}))
                n.set('default-x',f"{(e['x']-source['bars'][bi])*40/19.8413+20:.3f}")
                if e['rest']:E.SubElement(n,'rest',**({'measure':'yes'} if e['glyph']=='\u2211' else {}))
                else:
                    p=E.SubElement(n,'pitch');text(p,'step','CDEFGAB'[e['diatonic']%7]);text(p,'alter',e['alter']);text(p,'octave',e['diatonic']//7)
                    notes[e['id']]=n
                text(n,'duration',round(e['duration']*480));text(n,'voice',1)
                base=e['duration']/(1.5 if e.get('dot') else 1)
                if base in [4,2,1,.5,.25]:text(n,'type',{4:'whole',2:'half',1:'quarter',.5:'eighth',.25:'16th'}[base])
                if e.get('dot'):E.SubElement(n,'dot')
                if 'accidental' in e:text(n,'accidental',{-1:'flat',0:'natural',1:'sharp'}[e['accidental']])
                if 'stem' in e:text(n,'stem',e['stem'])
                if not e['rest']:
                    verses=collections.defaultdict(list)
                    for ly in e['lyrics']:verses[ly['verse']].append(ly)
                    for verse,tokens in verses.items():
                        value=' '.join(t['text'] for t in sorted(tokens,key=lambda t:t['x']))
                        ly=E.SubElement(n,'lyric',number=str(verse),placement='below');text(ly,'syllabic','single')
                        for i,word in enumerate(value.split('_')):
                            if i:text(ly,'elision','\u203f')
                            text(ly,'text',word)
            # Preserve original repeat and ending structure.
            if number==94:b=E.SubElement(m,'barline',location='left');E.SubElement(b,'repeat',direction='forward')
            if number==98:b=E.SubElement(m,'barline',location='left');E.SubElement(b,'ending',number='1',type='start')
            if number==100:
                b=E.SubElement(m,'barline',location='right');E.SubElement(b,'ending',number='1',type='stop');E.SubElement(b,'repeat',direction='backward')
            if number==101:b=E.SubElement(m,'barline',location='left');E.SubElement(b,'ending',number='2',type='start')
            if number==102:b=E.SubElement(m,'barline',location='right');E.SubElement(b,'ending',number='2',type='discontinue')
            if number==138:b=E.SubElement(m,'barline',location='right');text(b,'bar-style','light-heavy')
    # Group the printed beams within runs of adjacent short notes. The PDF
    # duration reader already distinguished eighths and sixteenths per note.
    for p in root.findall('part'):
        for m in p.findall('measure'):
            row=[n for n in m.findall('note')]
            group=[];group_id=None
            def flush():
                if len(group)>1:
                    for i,n in enumerate(group):text(n,'beam','begin' if i==0 else 'end' if i==len(group)-1 else 'continue',number='1')
                    for i,n in enumerate(group):
                        if n.findtext('type')!='16th':continue
                        prev=i>0 and group[i-1].findtext('type')=='16th';nxt=i+1<len(group) and group[i+1].findtext('type')=='16th'
                        text(n,'beam','continue' if prev and nxt else 'end' if prev else 'begin' if nxt else 'forward hook' if i==0 else 'backward hook',number='2')
                group.clear()
            # Only source notes with actual beams belong to a group; flags
            # remain flags, and quarter notes never acquire beams.
            for n in row:
                e=next((e for e in events if e.get('id')==n.get('id')),None) if n.get('id') else None
                if e and 'beamGroup' in e:
                    if group_id!=e['beamGroup']:flush()
                    group_id=e['beamGroup']
                    group.append(n)
                else:flush();group_id=None
            flush()
    # Slur numbering is interval-coloured so nested arcs retain separate IDs.
    note_order={e['id']:(e['role'],e['measure'],e['onset']) for e in events if not e['rest']}
    active=collections.defaultdict(dict)
    for a in sorted(arcs,key=lambda a:note_order[a['start']]):
        start,end=notes[a['start']],notes[a['end']];kind=a['kind']
        if kind=='tie':
            assert E.tostring(start.find('pitch'))==E.tostring(end.find('pitch'))
            for n,t in [(start,'start'),(end,'stop')]:
                E.SubElement(n,'tie',type=t);block=n.find('notations')
                if block is None:block=E.SubElement(n,'notations')
                E.SubElement(block,'tied',type=t)
        else:
            role=note_order[a['start']][0];q=note_order[a['start']][1:]
            active[role]={k:v for k,v in active[role].items() if v>=q}
            num=next(i for i in range(1,17) if i not in active[role]);active[role][num]=note_order[a['end']][1:]
            for n,t in [(start,'start'),(end,'stop')]:
                block=n.find('notations')
                if block is None:block=E.SubElement(n,'notations')
                E.SubElement(block,'slur',type=t,number=str(num))
    for n in notes.values():
        block=n.find('notations')
        if block is not None:block[:]=sorted(block,key=lambda c:0 if c.tag=='tied' and c.get('type')=='stop' else 1)
        n[:]=sorted(n,key=lambda c:(ORDER.index(c.tag) if c.tag in ORDER else 999,0 if c.tag=='tie' and c.get('type')=='stop' else 1))
    from alabad_dynamics import read
    for mark in read():
        candidates=[e for e in events if e['page']==mark['page'] and e['staff']==mark['staff'] and e['role']==mark['role']]
        e=min(candidates,key=lambda e:abs(e['x']-mark['x']))
        m=root.findall('part')[e['role']].findall('measure')[e['measure']-1]
        d=E.Element('direction',placement='above');dt=E.SubElement(d,'direction-type');dyn=E.SubElement(dt,'dynamics');E.SubElement(dyn,mark['value'])
        text(d,'offset',round(e['onset']*480))
        index=next(i for i,c in enumerate(m) if c.tag=='note');m.insert(index,d)
    for role in range(4):
        n=root.findall('part')[role].findall('measure')[-1].find('note')
        block=n.find('notations')
        if block is None:block=E.SubElement(n,'notations')
        text(block,'fermata','normal',type='upright')
        n[:]=sorted(n,key=lambda c:(ORDER.index(c.tag) if c.tag in ORDER else 999,0 if c.tag=='tie' and c.get('type')=='stop' else 1))
    # Continue a printed syllable through its following notes, including ties.
    # Stop at a rest or the next syllable; never duplicate words per attack.
    for part in root.findall('part'):
        sequence=part.findall('.//note')
        for i,n in enumerate(sequence):
            for lyric in list(n.findall('lyric')):
                if lyric.find('text') is None:continue
                verse=lyric.get('number','1');following=[]
                for later in sequence[i+1:]:
                    if later.find('rest') is not None or any(l.get('number','1')==verse and l.find('text') is not None for l in later.findall('lyric')):break
                    following.append(later)
                if not following:continue
                E.SubElement(lyric,'extend',type='start')
                for j,later in enumerate(following):
                    extra=E.SubElement(later,'lyric',number=verse,placement='below')
                    E.SubElement(extra,'extend',type='stop' if j==len(following)-1 else 'continue')
    E.indent(root);target=OUT/('Alabad a Jehová - borrador.musicxml' if duet=='pending' else 'Alabad a Jehová - SATB revisado contra PDF.musicxml')
    E.ElementTree(root).write(target,encoding='utf-8',xml_declaration=True)
    print(target,'notes',len(notes),'arcs',len(arcs),'duet18_32',duet)
    return target
if __name__=='__main__':
    import sys
    prepare(sys.argv[1] if len(sys.argv)>1 else 'pending')
