"""Preserve source notation, unfold written repeats and separate SA/TB voices."""
from pathlib import Path
from fractions import Fraction as F
import copy,json,re,collections,xml.etree.ElementTree as E
from inventory import OUT
from score_model import parse,pitch

NAMES=['Soprano','Alto','Tenor','Bajo']
def text(p,k,v,**a):e=E.SubElement(p,k,a);e.text=str(v);return e
def number(s):
    m=re.search(r'(\d+)$',s or '1');return int(m[1]) if m else 1
def read(path):return E.parse(path).getroot()

def repeat_plan(part):
    measures=part.findall('measure');back=[i for i,m in enumerate(measures) if any(r.get('direction')=='backward' for r in m.findall('barline/repeat'))]
    if not back:
        plan=[(i,1) for i in range(len(measures))]
        dc=any(s.get('dacapo')=='yes' for m in measures for s in m.findall('.//sound'))
        fine=next((i for i,m in enumerate(measures) if any(s.get('fine') for s in m.findall('.//sound'))),None)
        if dc:
            assert fine is not None,'Da Capo requires a defined Fine'
            plan += [(i,2) for i in range(fine+1)]
        return plan
    assert len(back)==1,back
    end=back[0];starts=[i for i,m in enumerate(measures[:end+1]) if any(r.get('direction')=='forward' for r in m.findall('barline/repeat'))];start=starts[-1] if starts else 0
    repeat=next(r for r in measures[end].findall('barline/repeat') if r.get('direction')=='backward');times=int(repeat.get('times','2'))
    endings={};active=None
    for i,m in enumerate(measures):
        es=m.findall('barline/ending')
        for e in es:
            if e.get('type')=='start':active={int(n) for n in re.findall(r'\d+',e.get('number',''))}
        if active:endings[i]=active
        if any(e.get('type') in ['stop','discontinue'] for e in es):active=None
    times=max(times,max([max(v) for i,v in endings.items() if start<=i<=end+2],default=times))
    plan=[(i,1) for i in range(start)]
    for passage in range(1,times+1):plan += [(i,passage) for i in range(start,end+1) if i not in endings or passage in endings[i]]
    plan += [(i,times) for i in range(end+1,len(measures)) if i not in endings or times in endings[i]]
    assert len(plan)<1000
    return plan

def select_lyrics(n,passage):
    ls=n.findall('lyric')
    if not ls:return
    chosen=next((l for l in ls if number(l.get('number'))==passage),None)
    if chosen is None:chosen=next((l for l in ls if number(l.get('number'))==1),ls[0])
    for l in ls:n.remove(l)
    chosen=copy.deepcopy(chosen);chosen.set('number','1');chosen.attrib.pop('default-x',None);chosen.attrib.pop('default-y',None)
    for t in chosen.findall('text'):
        if t.text:t.text=re.sub(r'^\s*\d+[.)]\s*','',t.text)
    n.append(chosen)

def clean(root):
    for p in list(root):
        if p.tag in ['credit','defaults']:root.remove(p)
    defaults=E.Element('defaults');sc=E.SubElement(defaults,'scaling');text(sc,'millimeters',7);text(sc,'tenths',40)
    pl=E.SubElement(defaults,'page-layout');text(pl,'page-height',1697.14);text(pl,'page-width',1200)
    ma=E.SubElement(pl,'page-margins',type='both')
    for key in ['left-margin','right-margin','top-margin','bottom-margin']:text(ma,key,65)
    root.insert(next((i for i,c in enumerate(root) if c.tag=='part-list'),len(root)),defaults)
    for part in root.findall('part'):
        for m in part.findall('measure'):
            m.attrib.pop('width',None)
            for c in list(m):
                if c.tag=='print':m.remove(c)
                elif c.tag=='direction':
                    jump=any(set(v.attrib)&{'dacapo','dalsegno','fine','tocoda'} for v in c.findall('sound'))
                    wordjump=any(re.fullmatch(r'(?:D[. ]*C[. ]*(?:al Fine)?|Fine)',(v.text or '').strip(),flags=re.I) for v in c.findall('direction-type/words'))
                    if jump or wordjump:m.remove(c)
                elif c.tag=='barline':
                    for a in list(c):
                        if a.tag in ['repeat','ending']:c.remove(a)
                    if not len(c):m.remove(c)
            for n in m.findall('note'):
                for a in ['default-x','default-y','relative-x','relative-y','color']:n.attrib.pop(a,None)
            for t in m.findall('.//direction-type/words'):
                if t.text and re.fullmatch(r'\s*\d+\s*',t.text):
                    for d in m.findall('direction'):
                        if t in list(d.iter()):m.remove(d);break
    return root

def labels(root):
    pl=root.find('part-list');parts=root.findall('part');count=len(parts);names=NAMES if count==4 else ['Soprano','Alto','Tenor','Barítono','Bajo'];assert count in [4,5]
    for c in list(pl):pl.remove(c)
    for i,(part,name) in enumerate(zip(parts,names),1):
        part.set('id',f'P{i}');sp=E.SubElement(pl,'score-part',id=f'P{i}');text(sp,'part-name',name);text(sp,'part-abbreviation',['S.','A.','T.','Bar.','B.'][i-1] if count==5 else ['S.','A.','T.','B.'][i-1])
        si=E.SubElement(sp,'score-instrument',id=f'I{i}');text(si,'instrument-name',name);mi=E.SubElement(sp,'midi-instrument',id=f'I{i}');text(mi,'midi-channel',i);text(mi,'midi-program',53)
        for n in part.findall('.//note'):
            for ins in n.findall('instrument'):ins.set('id',f'I{i}')

def unfold(root):
    plan=repeat_plan(root.findall('part')[0]);sourcecount=len(root.findall('part')[0].findall('measure'))
    for part in root.findall('part'):
        ms=part.findall('measure');state={};states=[]
        for m in ms:
            for attrs in m.findall('attributes'):
                for c in attrs:state[c.tag]=copy.deepcopy(c)
            states.append(copy.deepcopy(state))
        for m in ms:part.remove(m)
        previous=None
        for i,(index,passage) in enumerate(plan):
            m=copy.deepcopy(ms[index]);m.set('number',str(i+1))
            if previous is not None and index!=previous+1:
                for at in m.findall('attributes'):m.remove(at)
                at=E.Element('attributes')
                for key,c in states[index].items():at.append(copy.deepcopy(c))
                m.insert(0,at)
            for n in m.findall('note'):select_lyrics(n,passage)
            part.append(m);previous=index
    return plan,sourcecount

def rest_node(q,div):
    n=E.Element('note');E.SubElement(n,'rest');text(n,'duration',int(q*div));text(n,'voice',1)
    values={F(4):('whole',0),F(3):('half',1),F(2):('half',0),F(3,2):('quarter',1),F(1):('quarter',0),F(3,4):('eighth',1),F(1,2):('eighth',0),F(3,8):('16th',1),F(1,4):('16th',0),F(1,8):('32nd',0)}
    if q in values:
        kind,dots=values[q];text(n,'type',kind)
        for _ in range(dots):E.SubElement(n,'dot')
    return n

def split_pair(root):
    model=parse(root);assert len(model)==2
    for mi in range(len(model[0])):
        ends=[max((e['onset']+e['duration'] for e in p[mi]['events']),default=F(0)) for p in model]
        if ends[0]>0 and len(set(ends))==1 and ends[0]<model[0][mi]['meter']:
            for p in model:p[mi]['duration']=ends[0];p[mi]['source'].set('implicit','yes')
    original=root.findall('part')
    for part in original:root.remove(part)
    roleparts=[E.SubElement(root,'part',id=f'P{i+1}') for i in range(4)];splits=[]
    for pi,measures in enumerate(model):
        for m in measures:
            idx=m['index'];groups=collections.defaultdict(list)
            for e in m['events']:
                if e['pitch'] is None and e['node'].get('print-object')=='no':continue
                groups[(e['onset'],e['voice'])].append(e)
            pitchedvoices=sorted({voice for onset,voice in groups},key=lambda v:int(v));multi=len(pitchedvoices)>1
            assigned=[[],[]]
            for (onset,voice),group in sorted(groups.items(),key=lambda v:(v[0][0],int(v[0][1]))):
                heads=[e for e in group if e['pitch'] is not None]
                if len(heads)>=2:
                    assert len(heads)==2,(pi,idx,len(heads))
                    shared=next((e['node'].findall('lyric') for e in heads if e['node'].find('lyric') is not None),[])
                    for role,e in enumerate(sorted(heads,key=lambda e:e['pitch'],reverse=True)):
                        n=copy.deepcopy(e['node'])
                        if n.find('lyric') is None:
                            for l in shared:n.append(copy.deepcopy(l))
                        sharedMarks=[copy.deepcopy(c) for head in heads for no in head['node'].findall('notations') for c in no if c.tag in ['slur','articulations','fermata','tuplet']]
                        if sharedMarks:
                            no=n.find('notations')
                            if no is None:no=E.SubElement(n,'notations')
                            seen={E.tostring(c,encoding='unicode') for c in no}
                            missingKinds={mark.tag for mark in sharedMarks if no.find(mark.tag) is None}
                            for mark in sharedMarks:
                                signature=E.tostring(mark,encoding='unicode')
                                if mark.tag in missingKinds and signature not in seen:no.append(copy.deepcopy(mark));seen.add(signature)
                        tm=next((head['node'].find('time-modification') for head in heads if head['node'].find('time-modification') is not None),None)
                        if tm is not None and n.find('time-modification') is None:n.append(copy.deepcopy(tm))
                        assigned[role].append((onset,e['duration'],n))
                elif multi:
                    role=pitchedvoices.index(voice) if voice in pitchedvoices else min(int(voice)-1,1)
                    assert role<2
                    for e in group:assigned[role].append((onset,e['duration'],copy.deepcopy(e['node'])))
                else:
                    for role in range(2):
                        for e in group:assigned[role].append((onset,e['duration'],copy.deepcopy(e['node'])))
            for role in range(2):
                r=pi*2+role;new=E.SubElement(roleparts[r],'measure',**dict(m['source'].attrib));div=m['div']
                for c in list(m['source']):
                    if c.tag not in ['note','backup','forward','direction','harmony']:new.append(copy.deepcopy(c))
                for attrs in new.findall('attributes'):
                    for c in list(attrs):
                        if c.tag in ['staves','staff-details','transpose']:attrs.remove(c)
                    for clef in attrs.findall('clef'):
                        clef.attrib.pop('number',None)
                        if r==2:
                            for c in list(clef):clef.remove(c)
                            text(clef,'sign','G');text(clef,'line',2);text(clef,'clef-octave-change',-1)
                pitchedSpans=[(onset,onset+dur) for onset,dur,n in assigned[role] if n.find('pitch') is not None]
                assigned[role]=[(onset,dur,n) for onset,dur,n in assigned[role] if n.find('rest') is None or not any(a<onset+dur and b>onset for a,b in pitchedSpans)]
                entries=[];q=F(0)
                for onset,dur,n in sorted(assigned[role],key=lambda v:v[0]):
                    if onset<q-F(1,64):
                        if n.find('rest') is not None:continue
                        raise ValueError(('overlap after split',r,idx,onset,q))
                    if onset>q:entries.append((q,rest_node(onset-q,div)));q=onset
                    for c in list(n):
                        if c.tag in ['chord','staff','instrument','stem']:n.remove(c)
                    durationNode=n.find('duration')
                    if durationNode is not None:durationNode.text=str(int(dur*div))
                    v=n.find('voice')
                    if v is not None:v.text='1'
                    entries.append((onset,n));q=onset+dur
                if q<m['duration']:entries.append((q,rest_node(m['duration']-q,div)))
                # Copy shared directions to both independent singers.
                dirs=[]
                for d in m['directions']:
                    n=copy.deepcopy(d['node'])
                    for c in list(n):
                        if c.tag in ['offset','staff']:n.remove(c)
                    dirs.append((d['onset'],n))
                # MusicXML offsets are relative to the current note cursor.
                todo=sorted([(q,1,n) for q,n in entries]+[(q,0,n) for q,n in dirs],key=lambda v:(v[0],v[1]));cursor=F(0)
                for onset,kind,n in todo:
                    if kind==0:
                        if onset!=cursor:text(n,'offset',int((onset-cursor)*div))
                    else:cursor=onset+F(int(n.findtext('duration','0')),div)
                    new.append(n)
            splits.append((pi,idx))
    return root

def fill_parallel(root):
    """Fill omitted shared text only at matching sung attacks; retain individual text."""
    model=parse(root);filled=[]
    for r,p in enumerate(model):
        target=root.findall('part')[r]
        pitchedCount=sum(e['pitch'] is not None for m in p for e in m['events'])
        textCount=len(target.findall('.//lyric/text'))
        if textCount/max(1,pitchedCount)>=.35:continue
        for mi,m in enumerate(p):
            nodes=target.findall('measure')[mi].findall('note')
            for e,n in zip(m['events'],nodes):
                if e['pitch'] is None or n.find('lyric') is not None or any(t.get('type')=='stop' for t in n.findall('tie')):continue
                candidates=[]
                for rr,other in enumerate(model):
                    if rr==r:continue
                    for a in other[mi]['events']:
                        if a['pitch'] is not None and a['onset']==e['onset'] and a['duration']==e['duration'] and a['node'].find('lyric/text') is not None:
                            candidates.append((abs(rr-r),rr,a))
                if not candidates:continue
                _,rr,a=min(candidates,key=lambda v:(v[0],v[1]))
                for old in n.findall('lyric'):n.remove(old)
                for ly in a['node'].findall('lyric'):n.append(copy.deepcopy(ly))
                filled.append(dict(role=r,bar=mi+1,onset=str(e['onset']),fromRole=rr))
    return filled

def run():
    import sys
    rows=json.loads((OUT/('prepared-index.json' if (OUT/'prepared-index.json').exists() else 'sources.json')).read_text(encoding='utf8'))
    selected={int(x) for x in sys.argv[1:]} if len(sys.argv)>1 else None
    for record in rows:
        i=record['index'];work=OUT/f'{i:02d}'
        if selected is not None and i not in selected:continue
        if i==16:continue
        source=work/'source.musicxml'
        # This native "closed" file duplicates the lower chord notes on existing
        # Alto/Bass staves. Split its original two-staff MusicXML once instead.
        if i==19:source=Path('E:/Respaldo/musescoreactual/03_MusicXML/La Fiesta Universal (closed).musicxml.xml')
        # Both Restauración editables are the Jepthé Hdez./Salvador Castro work;
        # the file with "LA" has a padded pickup and several stale note edits.
        if i==10:source=OUT/'12/source.musicxml'
        root=read(source)
        if i==19:
            for part in root.findall('part'):
                for barline in part.findall('measure')[-1].findall('barline'):
                    for repeat in barline.findall('repeat'):barline.remove(repeat)
        before=len(root.findall('.//pitch'));sourceparts=len(root.findall('part'))
        if sourceparts==2:split_pair(root)
        plan,count=unfold(root);clean(root);labels(root)
        filled=fill_parallel(root)
        for n in root.findall('.//note'):
            order=['grace','cue','chord','pitch','unpitched','rest','duration','tie','instrument','footnote','level','voice','type','dot','accidental','time-modification','stem','notehead','notehead-text','staff','beam','notations','lyric','play','listen']
            n[:]=sorted(n,key=lambda c:order.index(c.tag) if c.tag in order else 999)
        title=record['title'].strip();name=title+' - '+('SATB y barítono' if i==4 else 'SATB')+' - Cantai'
        record.update(finalName=name,sourceMeasures=count,expandedMeasures=len(plan),parts=len(root.findall('part')),sourceNotes=before,finalNotes=len(root.findall('.//pitch')),split=sourceparts==2,filledLyrics=len(filled))
        E.indent(root);E.ElementTree(root).write(work/'prepared.musicxml',encoding='utf-8',xml_declaration=True)
        (work/'preparation.json').write_text(json.dumps(dict(record=record,barMap=plan,editorialLyricFills=filled),ensure_ascii=False,indent=2),encoding='utf8')
        print(i,title,record['parts'],'staves',count,'->',len(plan),'bars; lyric fills',len(filled),flush=True)
    (OUT/'prepared-index.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
if __name__=='__main__':run()
