import collections,json,xml.etree.ElementTree as E
from fractions import Fraction as F
from no_hay_amigo_model import OUT
from prepare_amigo import norm,TEXTS
def read(path):
    root=E.parse(path).getroot();result=[[] for _ in range(4)];lyric=[];sections=[];totals=[]
    for pi,p in enumerate(root.findall('part')):
        start=F(0);div=960;active={}
        for m in p.findall('measure'):
            if m.findtext('attributes/divisions'):div=int(m.findtext('attributes/divisions'))
            cursor=F(0);end=F(0)
            for n in m:
                if n.tag in ['backup','forward']:
                    cursor+=(-1 if n.tag=='backup' else 1)*F(int(n.findtext('duration')),div);continue
                if n.tag=='direction' and pi==0:
                    word=n.findtext('direction-type/words')
                    if word in ['Estrofa 1','Estrofa 2','Estrofa 3','Coro']:sections.append((float(start+cursor),word))
                if n.tag!='note':continue
                d=F(int(n.findtext('duration')),div);voice=int(n.findtext('voice','1'))-1;role=pi*2+voice
                assert 0<=role<4,(pi,voice)
                if n.find('rest') is None:
                    pch=n.find('pitch');pitch=12*(int(pch.findtext('octave'))+1)+dict(C=0,D=2,E=4,F=5,G=7,A=9,B=11)[pch.findtext('step')]+int(pch.findtext('alter','0'))
                    q=start+cursor;ties={t.get('type') for t in n.findall('tie')}
                    if 'stop' in ties:
                        assert (role,pitch) in active,(path,role,q,pitch)
                        attack=active[(role,pitch)];assert abs(attack[0]+attack[2]-float(q))<.00001,(attack,q);attack[2]+=float(d)
                    else:attack=[float(q),pitch,float(d)];result[role].append(attack)
                    if 'start' in ties:active[(role,pitch)]=attack
                    else:active.pop((role,pitch),None)
                    t=n.findtext('lyric/text')
                    if t:
                        assert role in [0,2],(role,t);lyric.append((role,float(q),t));assert len(n.findall('lyric'))==1
                        assert 'stop' not in ties,('new text on held note',role,q,t)
                if n.find('chord') is None:cursor+=d
                end=max(end,cursor)
            totals.append((pi,m.get('number'),float(end)));start+=end
        assert not active and start==318,(path,start,active)
    assert sections==[(0,'Estrofa 1'),(62,'Coro'),(106,'Estrofa 2'),(168,'Coro'),(212,'Estrofa 3'),(274,'Coro')],sections
    for role in [0,2]:
        for cycle in range(3):
            for a,b,target in [(106*cycle,106*cycle+62,TEXTS[cycle]),(106*cycle+62,106*cycle+106,TEXTS[3])]:
                value=''.join(t for r,q,t in lyric if r==role and a<=q<b);assert norm(value)==norm(target),(path,role,cycle,value,target)
    assert [(q,t) for r,q,t in lyric if r==0]==[(q,t) for r,q,t in lyric if r==2],('staff lyric alignment',path)
    return result
def validate():
    midi=json.loads((OUT/'midi-reading.json').read_text());ref=[[[n['ticks']/midi['ppq'],n['pitch'],n['duration']/midi['ppq']] for n in t['notes']] for t in midi['tracks']]
    files=[OUT/'No Hay Amigo Mejor - SATB desarrollado.musicxml',OUT/'render/exported.musicxml',OUT/'render/reimport.musicxml'];reports=[]
    for p in files:
        rows=read(p)
        for role,(a,b) in enumerate(zip(rows,ref)):
            assert len(a)==len(b),(p,role,len(a),len(b))
            for x,y in zip(a,b):assert abs(x[0]-y[0])<.008 and x[1]==y[1] and abs(x[2]-y[2])<.008,(p,role,x,y)
        reports.append(dict(file=p.name,attacks=[len(r) for r in rows],exactMidiReference=True,lyricsAndSections=True))
    report=dict(checks=reports,measures=109,quarterBeats=318,stanzas=3,choruses=3,staves=2,voices=4,lyricLinesPerStaff=1,lyricsOnBothStaves=True)
    (OUT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2))
if __name__=='__main__':validate()
