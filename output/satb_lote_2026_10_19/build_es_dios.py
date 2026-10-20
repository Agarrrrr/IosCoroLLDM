import json,copy,collections,re,unicodedata,xml.etree.ElementTree as E
from fractions import Fraction as F
from pathlib import Path
import pdfplumber
from prepare_batch import text,labels,clean,select_lyrics
from inventory import OUT

VERSES=[
 ['Cuan|do','pien|so|del|sol|y|su','fuer|za|_|que','gran|de|ful|gor,','_|Cuan|do','pien|so|del|mar|y|sus','a|guas|_|qué','gran|de|po|der;','_|Cuan|do','pien|so|que|to|das|las','co|sas|_|son','su|yas,','_|De|mis','la|bios|bro|tan|las|pa','la|bras:|_|¡Qué','gran|de_es|Dios!'],
 ['Cuan|do','pien|so|de|Dios|y|su_I','gle|sia|_|qué','gran|de_a|mor,|_','_|Al|en','viar|con|a|mor|a|su','hi|jo|_|qué','gran|Sal|va|dor;','_|Cuan|do','pien|so|que|Cris|to|ha_en','via|do_a|_|su_A','pós|tol,','_|De|mis','la|bios|bro|tan|las|pa','la|bras:|_|¡Qué','ben|di|ción!'],
 ['Al|o','ir|el|tri|nar|de|las','a|ves|_|que_her','mo|so|tri|nar,','_|Y_a|la_I','gle|sia|can|tan|do_a|la','ban|zas|_|que_her','mo|so|can|tar;','_|Cuan|do','sien|to|en|mí|su|pre','sen|cia|_|di','vi|na,','_|De|mis','la|bios|bro|tan|las|pa','la|bras:|_|¡Qué','gran|de_es|Dios!']]
# The printed second stanza has four independent attacks: gran-de-a-mor.
VERSES[1][3]='gran|de|a|mor,'
CHORUS=['_|El|que','hi|zo|los|cie|los,|la','tie|rra,|_|es','Dios.|Y|quien','hi|zo|el|mar,|las|es','tre|llas,|_|es','Dios,|_|_','_|Y|no','so|tros|tam|bién|so|mos','o|bra|_|de','Dios;|Y|por','e|so|le|da|mos|la','glo|ria,|_|a','Dios.']
LEX='cuando pienso del sol y su fuerza qué grande fulgor al enviar con amor a hijo salvador cristo ha enviado apóstol de mis labios brotan las palabras bendición dios ir el trinar aves hermoso iglesia cantando alabanzas cantar siento en mí presencia divina todas cosas son suyas cielos la tierra es quien hizo mar estrellas nosotros también somos obra por eso le damos gloria poder sus aguas'
def norm(s):return ''.join(c for c in unicodedata.normalize('NFD',s.casefold()) if c.isalpha())

def run():
    work=OUT/'16';data=json.loads((work/'pdf-reading.json').read_text(encoding='utf8'));src=[];groups=collections.defaultdict(list)
    for e in data['events']:groups[e['role'],e['measure'],e['onset']].append(e)
    for (staff,m,onset),row in groups.items():
        heads=sorted([e for e in row if not e['rest']],key=lambda e:e['pitch'],reverse=True)
        for v in [0,1]:
            e=copy.deepcopy(heads[min(v,len(heads)-1)] if heads else row[0]);e.update(role=staff*2+v,staffGroup=staff,measure=m,onset=F(onset),duration=F(e['duration']),id=f'{staff*2+v}-{m}-{onset}')
            src.append(e)
    src.sort(key=lambda e:(e['role'],e['measure'],e['onset']))
    arcs=[];partial=[]
    with pdfplumber.open(work/'partitura.pdf') as pdf:
        p=pdf.pages[0];seen=set()
        for curve in p.curves:
            if not any(q[0]=='c' for q in curve['path']) or curve['width']<3:continue
            a=curve['path'][0][1];b=next(q[-1] for q in curve['path'] if q[0]=='c');key=tuple(round(v,2) for pt in [a,b] for v in pt)
            if key in seen:continue
            seen.add(key);pairs=[]
            for x,y in [a,b]:pairs.append([(abs(e['x']+3-x)+abs(e['y']-y)*.6,e) for e in src if not e['rest'] and abs(e['x']+3-x)<11 and abs(e['y']-y)<18])
            options=[]
            for ca,na in pairs[0]:
                for cb,nb in pairs[1]:
                    if na['role']!=nb['role'] or (na['measure'],na['onset'])>=(nb['measure'],nb['onset']):continue
                    tied=na['pitch']==nb['pitch'] and (na['measure']==nb['measure'] and na['onset']+na['duration']==nb['onset'] or nb['measure']==na['measure']+1 and nb['onset']==0 and na['onset']+na['duration']==(F(3,2) if na['measure']==1 else F(3)))
                    options.append((ca+cb-(4 if tied else 0),na,nb,tied))
            if options:
                cost,na,nb,tied=min(options,key=lambda v:v[0]);arcs.append(dict(start=na['id'],end=nb['id'],kind='tie' if tied else 'slur',role=na['role'],cost=cost))
            else:partial.append(dict(start=a,end=b,near=[[e['id'] for cost,e in pp] for pp in pairs]))
        # Ties broken at the six printed systems are paired by exact pitch/role.
        for m in [5,10,16,21,25]:
            for role in range(4):
                a=max([e for e in src if e['role']==role and e['measure']==m and not e['rest']],key=lambda e:e['onset']);b=min([e for e in src if e['role']==role and e['measure']==m+1 and not e['rest']],key=lambda e:e['onset'])
                if a['pitch']!=b['pitch'] or b['onset']!=0:continue
                ta=any(abs(pt['start'][0]-(a['x']+3))<10 or abs(pt['end'][0]-(a['x']+3))<10 for pt in partial)
                if ta:arcs.append(dict(start=a['id'],end=b['id'],kind='tie',role=role,cost=0))
    arcs=list({(a['start'],a['end']):a for a in arcs}.values())
    # Underlay is transcribed from the original printed syllables, not MIDI.
    for role in range(4):
        for m in range(1,31):
            row=[e for e in src if e['role']==role and e['measure']==m and not e['rest']]
            upper=[e for e in src if e['role']==0 and e['measure']==m and not e['rest']]
            for verse in range(1,4):
                tokens=(VERSES[verse-1][m-1] if m<=16 else CHORUS[m-17]).split('|');assert len(tokens)==len(upper),(m,tokens,len(upper))
                for e in row:
                    j=next((i for i,a in enumerate(upper) if a['onset']==e['onset']),None)
                    if j is not None and tokens[j]!='_':e.setdefault('text',{})[verse]=tokens[j]
    lookup={e['id']:e for e in src}
    arcs=[a for a in arcs if not (a['kind']=='tie' and lookup[a['end']].get('text') and a['cost']==0)]
    for a in arcs:
        if a['kind']=='tie' and lookup[a['end']].get('text'):a['kind']='slur'
    tiedends={a['end'] for a in arcs if a['kind']=='tie'}
    for e in src:
        if e['id'] in tiedends:e.pop('text',None)
    # Apply syllabification independently in every expanded vocal part.
    root=E.Element('score-partwise',version='4.0');text(E.SubElement(root,'work'),'work-title','Es Dios');ident=E.SubElement(root,'identification');text(ident,'creator','Miguel A. Huerta',type='composer');E.SubElement(root,'part-list')
    byid={};lex={norm(s) for s in (LEX+' los con sino gran oír' ).split()};expanded=[]
    for role in range(4):
        part=E.SubElement(root,'part',id=f'P{role+1}');atoms=[]
        for verse in range(1,4):
            for m in range(1,31):
                bar=(verse-1)*30+m;measure=E.SubElement(part,'measure',number=str(bar),**({'implicit':'yes'} if m in [1,30] else {}))
                if bar==1:
                    at=E.SubElement(measure,'attributes');text(at,'divisions',960);text(E.SubElement(at,'key'),'fifths',2);time=E.SubElement(at,'time');text(time,'beats',6);text(time,'beat-type',8);clef=E.SubElement(at,'clef');text(clef,'sign','F' if role==3 else 'G');text(clef,'line',4 if role==3 else 2)
                    if role==2:text(clef,'clef-octave-change',-1)
                    if role==0:
                        d=E.SubElement(measure,'direction',placement='above');met=E.SubElement(E.SubElement(d,'direction-type'),'metronome');text(met,'beat-unit','quarter');text(met,'per-minute',75);E.SubElement(d,'sound',tempo='75')
                row=[e for e in src if e['role']==role and e['measure']==m]
                for e in row:
                    n=E.SubElement(measure,'note');byid[verse,e['id']]=n
                    if e['rest']:E.SubElement(n,'rest')
                    else:
                        pitch=E.SubElement(n,'pitch');text(pitch,'step','CDEFGAB'[e['diatonic']%7])
                        if e['alter']:text(pitch,'alter',e['alter'])
                        text(pitch,'octave',e['diatonic']//7)
                    text(n,'duration',int(e['duration']*960));text(n,'voice',1);base=e['duration']/F(3,2) if e['dot'] else e['duration'];text(n,'type',{F(1,2):'eighth',F(1):'quarter',F(2):'half'}[base])
                    if e['dot']:E.SubElement(n,'dot')
                    if not e['rest'] and e.get('accidental') is not None:text(n,'accidental',{-1:'flat',0:'natural',1:'sharp'}[e['accidental']])
                    t=e.get('text',{}).get(verse)
                    if t:
                        ly=E.SubElement(n,'lyric',number='1');pieces=[]
                        for i,value in enumerate(t.split('_')):a=dict(text=value,join=i>0,node=ly);atoms.append(a);pieces.append(a)
                        e.setdefault('lyricPieces',{})[verse]=pieces
                    if m==30:
                        no=E.SubElement(n,'notations');text(no,'fermata','normal')
                if m==30:text(E.SubElement(measure,'barline',location='right'),'bar-style','light-heavy' if verse==3 else 'light-light')
        pos=0
        while pos<len(atoms):
            matches=[]
            for j in range(pos,min(len(atoms),pos+9)):
                if norm(''.join(a['text'] for a in atoms[pos:j+1])) in lex:matches.append(j+1)
                if re.search('[,.;!?]',atoms[j]['text']):break
            assert matches,(role,pos,[a['text'] for a in atoms[pos:pos+7]])
            end=max(matches)
            for i in range(pos,end):atoms[i]['syllabic']='single' if end==pos+1 else 'begin' if i==pos else 'end' if i==end-1 else 'middle'
            pos=end
        for e in src:
            if e['role']!=role:continue
            for verse,pieces in e.get('lyricPieces',{}).items():
                ly=pieces[0]['node'];before=pieces[0]['syllabic'] in ['middle','end'];after=pieces[-1]['syllabic'] in ['begin','middle'];text(ly,'syllabic','middle' if before and after else 'end' if before else 'begin' if after else 'single');text(ly,'text','‿'.join(a['text'] for a in pieces))
    for verse in range(1,4):
        for i,a in enumerate(arcs):
            for key,kind in [('start','start'),('end','stop')]:
                n=byid[verse,a[key]];no=n.find('notations')
                if no is None:no=E.SubElement(n,'notations')
                if a['kind']=='tie':n.insert(3,E.Element('tie',type=kind));E.SubElement(no,'tied',type=kind)
                else:E.SubElement(no,'slur',type=kind,number=str(i%6+1))
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
                for j,later in enumerate(following):E.SubElement(E.SubElement(later,'lyric',number='1'),'extend',type='stop' if j==len(following)-1 else 'continue')
    clean(root);labels(root)
    order=['grace','chord','pitch','rest','duration','tie','voice','type','dot','accidental','time-modification','stem','beam','notations','lyric']
    for n in root.findall('.//note'):n[:]=sorted(n,key=lambda c:order.index(c.tag) if c.tag in order else 999)
    E.indent(root);E.ElementTree(root).write(work/'prepared.musicxml',encoding='utf-8',xml_declaration=True)
    print('ES DIOS notes',len(root.findall('.//pitch')),'lyrics',len(root.findall('.//lyric/text')),'arcs',len(arcs),'partial',partial)
    (work/'pdf-arcs.json').write_text(json.dumps(arcs,ensure_ascii=False,indent=2),encoding='utf8')
    rows=json.loads((OUT/'prepared-index.json').read_text(encoding='utf8'));record=rows[15];record.update(finalName='Es Dios - SATB - Cantai',sourceMeasures=30,expandedMeasures=90,parts=4,sourceNotes=476,finalNotes=len(root.findall('.//pitch')),split=True,sourceAuthority='Official PDF, not ensemble backup')
    (OUT/'prepared-index.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
if __name__=='__main__':run()
