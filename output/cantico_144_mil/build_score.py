"""Write four independent sung parts from the checked digital PDF model."""
import json,copy,xml.etree.ElementTree as E
from fractions import Fraction as F
from model import OUT,plan

TITLE='El Cántico de los 144 Mil'
STEM=TITLE+' - SATB desarrollado - Cantai'
DIV=960
def text(p,t,v,**attrs):
    e=E.SubElement(p,t,attrs);e.text=str(v);return e
def notation(n):
    e=n.find('notations')
    return e if e is not None else E.SubElement(n,'notations')
def ticks(q):return int(F(q).limit_denominator(96)*DIV)

def build():
    events=json.loads((OUT/'events.json').read_text(encoding='utf8'))
    expr=json.loads((OUT/'expressions-reading.json').read_text(encoding='utf8'))
    source=json.loads((OUT/'source-events.json').read_text(encoding='utf8'))
    lookup={e['id']:e for e in source};bars=plan()
    # Broken arcs cross a printed system/page boundary.
    for r,a,b in [(0,'src-0-8-5','src-0-9-0'),(2,'src-2-8-5','src-2-9-0'),(3,'src-3-85-0','src-3-86-0'),(3,'src-3-89-1','src-3-90-0')]:
        na,nb=lookup[a],lookup[b];assert na['pitch']==nb['pitch']
        expr['arcs'].append(dict(start=a,end=b,role=r,measure=na['measure'],onset=na['onset'],toMeasure=nb['measure'],toOnset=nb['onset'],kind='tie'))
    # Fermatas printed above the rests in bar 41 were omitted by the pitched-note probe.
    for r in [2,3]:
        e=next(e for e in source if e['role']==r and e['measure']==41 and e['rest'])
        expr['articulations'].append(dict(id=e['id'],role=r,measure=41,onset=e['onset'],kind='fermata'))
    for r in range(4):expr['articulations'].append(dict(role=r,measure=28,onset=0,kind='staccato'))
    for r in [2,3]:expr['articulations'].append(dict(role=r,measure=40,onset=3,kind='staccato'))
    root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title',TITLE);text(root,'movement-title',TITLE)
    ident=E.SubElement(root,'identification');text(ident,'creator','Sebastian Zapata O.',type='composer');text(ident,'rights','Partitura Oficial · M.I.C.E.C.')
    defaults=E.SubElement(root,'defaults');sc=E.SubElement(defaults,'scaling');text(sc,'millimeters',7);text(sc,'tenths',40)
    layout=E.SubElement(defaults,'page-layout');text(layout,'page-height',1697.14);text(layout,'page-width',1200)
    margins=E.SubElement(layout,'page-margins',type='both')
    for k in ['left-margin','right-margin','top-margin','bottom-margin']:text(margins,k,70)
    E.SubElement(defaults,'lyric-font',{'font-family':'Times New Roman','font-size':'11'})
    parts=E.SubElement(root,'part-list');roles=['Soprano','Alto','Tenor','Bajo']
    for r,name in enumerate(roles):
        p=E.SubElement(parts,'score-part',id=f'P{r+1}');text(p,'part-name',name);text(p,'part-abbreviation',['S.','A.','T.','B.'][r])
        ins=E.SubElement(p,'score-instrument',id=f'I{r+1}');text(ins,'instrument-name',name)
        ins=E.SubElement(p,'midi-instrument',id=f'I{r+1}');text(ins,'midi-channel',r+1);text(ins,'midi-program',53)
    allnotes={};allevents={};directions=[]
    for r in range(4):
        part=E.SubElement(root,'part',id=f'P{r+1}');previous_meter=None
        for bar in bars:
            m=E.SubElement(part,'measure',number=str(bar['number']))
            if bar['source'] in [42,66,77,84,94] or (bar['source']==81 and bar['passage']==1):E.SubElement(m,'print',**{'new-system':'yes'})
            if bar['number']==1 or bar['duration']!=previous_meter:
                at=E.SubElement(m,'attributes')
                if bar['number']==1:
                    text(at,'divisions',DIV);text(E.SubElement(at,'key'),'fifths',-2)
                time=E.SubElement(at,'time');text(time,'beats',bar['duration']);text(time,'beat-type',4)
                if bar['number']==1:
                    clef=E.SubElement(at,'clef');text(clef,'sign','F' if r==3 else 'G');text(clef,'line',4 if r==3 else 2)
                    if r==2:text(clef,'clef-octave-change',-1)
            previous_meter=bar['duration']
            row=sorted([e for e in events if e['role']==r and e['bar']==bar['number']],key=lambda e:e['onset'])
            if not row:
                row=[dict(id=f"rest-{r}-{bar['number']}",rest=True,duration=bar['duration'],onset=0,bar=bar['number'],measure=bar['source'],role=r)]
            for e in row:
                n=E.SubElement(m,'note',id=e['id']);allnotes[e['id']]=n;allevents[e['id']]=e
                if e['rest']:E.SubElement(n,'rest',**({'measure':'yes'} if e['duration']==bar['duration'] else {}))
                else:
                    p=E.SubElement(n,'pitch');text(p,'step','CDEFGAB'[e['diatonic']%7])
                    if e['alter']:text(p,'alter',e['alter'])
                    text(p,'octave',e['diatonic']//7)
                text(n,'duration',ticks(e['duration']));text(n,'voice',1)
                duration=F(e['duration']).limit_denominator(96)
                base=F(e['written']) if e.get('tuplet') else duration/F(3,2) if e.get('dot') else duration
                base=F(4) if e['rest'] and e['duration']==bar['duration'] else base
                text(n,'type',{F(1,4):'16th',F(1,2):'eighth',F(1):'quarter',F(2):'half',F(4):'whole'}[base])
                if e.get('dot'):E.SubElement(n,'dot')
                if not e['rest'] and e.get('accidental') is not None:text(n,'accidental',{-1:'flat',0:'natural',1:'sharp'}[e['accidental']])
                if e.get('tuplet'):
                    t=E.SubElement(n,'time-modification');text(t,'actual-notes',3);text(t,'normal-notes',2);text(t,'normal-type','eighth')
                    if e.get('tupletStart'):E.SubElement(notation(n),'tuplet',type='start',number='1',bracket='no')
                    if e.get('tupletStop'):E.SubElement(notation(n),'tuplet',type='stop',number='1')
                if e.get('beams'):
                    peers=[a for a in row if a.get('beamGroup')==e.get('beamGroup') and a.get('beamGroup') is not None]
                    for level in range(1,e['beams']+1):
                        same=[a for a in peers if a.get('beams',0)>=level]
                        if len(same)>1:text(n,'beam','begin' if e==same[0] else 'end' if e==same[-1] else 'continue',number=str(level))
                if e.get('atoms'):
                    atoms=e['atoms'];ly=E.SubElement(n,'lyric',number='1',placement='below');before=atoms[0]['syllabic'] in ['middle','end'];after=atoms[-1]['syllabic'] in ['begin','middle']
                    text(ly,'syllabic','middle' if before and after else 'end' if before else 'begin' if after else 'single')
                    text(ly,'text',''.join(('‿' if a['join'] else ' ')*bool(i)+a['text'] for i,a in enumerate(atoms)))
            if bar['number']==len(bars):text(E.SubElement(m,'barline',location='right'),'bar-style','light-heavy')
    def find(r,source_m,onset,bar_index):
        return next((e for e in events if e['role']==r and e['bar']==bar_index and e['measure']==source_m and abs(e['onset']-onset)<.0001),None)
    arc_count=0
    for bar in bars:
        for a in expr['arcs']:
            if a['measure']!=bar['source']:continue
            later=next((b for b in bars if b['number']>=bar['number'] and b['source']==a['toMeasure']),None)
            if later is None or later['number']-bar['number']>a['toMeasure']-a['measure']:continue
            start=find(a['role'],a['measure'],a['onset'],bar['number']);end=find(a['role'],a['toMeasure'],a['toOnset'],later['number'])
            assert start and end,a
            for e,t in [(start,'start'),(end,'stop')]:
                n=allnotes[e['id']]
                if a['kind']=='tie':
                    assert not (t=='stop' and e.get('lyric')),(a,e.get('lyric'))
                    n.insert(list(n).index(n.find('voice')),E.Element('tie',type=t));E.SubElement(notation(n),'tied',type=t)
                else:E.SubElement(notation(n),'slur',type=t,number=str(arc_count%6+1))
            arc_count+=1
    for bar in bars:
        for a in expr['articulations']:
            if a['measure']!=bar['source']:continue
            e=find(a['role'],a['measure'],a['onset'],bar['number']);assert e,a
            no=notation(allnotes[e['id']])
            if a['kind']=='fermata':text(no,'fermata','normal')
            else:
                art=no.find('articulations')
                if art is None:art=E.SubElement(no,'articulations')
                E.SubElement(art,a['kind'])
    def direction(r,bar,onset,kind,value,**kwargs):directions.append(dict(role=r,bar=bar,onset=onset,kind=kind,value=value,**kwargs))
    for bar in bars:
        for d in expr['dynamics']:
            if d['measure']==bar['source']:direction(d['role'],bar['number'],d['onset'],'dynamic',d['value'])
        for w in expr['wedges']:
            if w['measure']!=bar['source']:continue
            endbar=next(b for b in bars if b['number']>=bar['number'] and b['source']==w['toMeasure'])
            direction(w['role'],bar['number'],w['onset'],'wedge',w['kind']);direction(w['role'],endbar['number'],w['toOnset'],'wedge','stop')
        for sm,onset,tempo,words in [(1,0,55,'Misteriously'),(10,3,90,None),(28,1,70,'Tranquilo'),(32,0,65,'Sublime'),(42,0,160,'Agressivo'),(66,0,70,'Andante'),(77,0,65,'Grandiosso')]:
            if sm==bar['source']:direction(0,bar['number'],onset,'tempo',tempo,words=words)
        if bar['source']==9:
            direction(0,bar['number'],0,'words','rit.')
            for onset in [0,.5,1,2.5,2.75,3,3.5]:direction(0,bar['number'],onset,'tempo',round(55-13*onset/3.5,3),hidden=True)
        if bar['source']==78:direction(0,bar['number'],0,'words','Maestoso')
        if bar['source']==54:direction(0,bar['number'],0,'words','Tutto')
        if bar['source']==28:direction(0,bar['number'],0,'words','Staccato')
    for d in sorted(directions,key=lambda d:(d['role'],d['bar'],d['onset'],d['kind'])):
        m=root.findall('part')[d['role']].findall('measure')[d['bar']-1];dr=E.Element('direction',placement='above' if d['kind'] in ['tempo','words','rehearsal'] else 'below')
        dt=E.SubElement(dr,'direction-type');kind=d['kind'];v=d['value']
        if kind=='dynamic':E.SubElement(E.SubElement(dt,'dynamics'),v)
        elif kind=='wedge':E.SubElement(dt,'wedge',type=v,number='1')
        elif kind=='tempo':
            if d.get('hidden'):
                met=E.SubElement(dt,'metronome',**{'print-object':'no'});text(met,'beat-unit','quarter');text(met,'per-minute',v)
            else:
                met=E.SubElement(dt,'metronome',parentheses='no');text(met,'beat-unit','quarter');text(met,'per-minute',v)
                if d.get('words'):text(E.SubElement(dr,'direction-type'),'words',d['words'])
        else:text(dt,kind,v)
        candidates=[(nid,e) for nid,e in allevents.items() if e['role']==d['role'] and e['bar']==d['bar'] and e['onset']<=d['onset']+.0001]
        nid,anchor=max(candidates,key=lambda v:v[1]['onset'])
        if abs(d['onset']-anchor['onset'])>.0001:text(dr,'offset',ticks(d['onset']-anchor['onset']))
        if kind=='tempo':E.SubElement(dr,'sound',tempo=str(v))
        if kind=='dynamic':E.SubElement(dr,'sound',dynamics=str({'p':44,'mp':55,'mf':65,'f':80,'ff':95,'sfz':100}[v]))
        m.insert(list(m).index(allnotes[nid]),dr)
    # Extend each actual syllable through subsequent melisma/tied notes only.
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
                for j,later in enumerate(following):
                    extra=E.SubElement(later,'lyric',number='1',placement='below');E.SubElement(extra,'extend',type='stop' if j==len(following)-1 else 'continue')
    E.indent(root);E.ElementTree(root).write(OUT/(STEM+'.musicxml'),encoding='utf-8',xml_declaration=True)
    (OUT/'expressions-checked.json').write_text(json.dumps(expr,ensure_ascii=False,indent=2),encoding='utf8')
    print('Created MusicXML:',len(bars),'bars,',arc_count,'arcs,',len(directions),'directions')

if __name__=='__main__':build()
