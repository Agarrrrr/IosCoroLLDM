import json,collections,unicodedata,xml.etree.ElementTree as E
from fractions import Fraction as F
from aleluya_model import OUT
from aleluya_lyrics import LYRICS
def clean(v):return ''.join(c.casefold() for c in unicodedata.normalize('NFKC',v) if c.isalpha())
def read(path):
    root=E.parse(path).getroot();voices=[];lyrics=[];counts=collections.Counter()
    parts=root.findall('part');assert len(parts)==4
    for role,part in enumerate(parts):
        assert len(part.findall('measure'))==70
        start=F(0);div=960;active={};attacks=[];texts=[]
        for mi,m in enumerate(part.findall('measure'),1):
            div=int(m.findtext('attributes/divisions',str(div)));cursor=F(0);last=F(0);end=F(0)
            for n in m:
                if n.tag in ['backup','forward']:cursor+=F(int(n.findtext('duration')),div)*(-1 if n.tag=='backup' else 1)
                if n.tag!='note':continue
                chord=n.find('chord') is not None;q=last if chord else cursor;d=F(int(n.findtext('duration')),div)
                if n.find('pitch') is not None:
                    pitch=(int(n.findtext('pitch/octave'))+1)*12+dict(C=0,D=2,E=4,F=5,G=7,A=9,B=11)[n.findtext('pitch/step')]+int(n.findtext('pitch/alter','0'));ties={t.get('type') for t in n.findall('tie')}
                    if 'stop' in ties:
                        assert pitch in active,(path,role,mi,q,pitch);a=active.pop(pitch);assert abs(a[0]+a[2]-float(start+q))<.00001;a[2]+=float(d);counts['tieLinks']+=1
                    else:a=[float(start+q),pitch,float(d)];attacks.append(a)
                    if 'start' in ties:assert pitch not in active;active[pitch]=a
                    counts['writtenNotes']+=1
                    for slur in n.findall('notations/slur'):counts['slur'+slur.get('type')]+=1
                    if n.find('time-modification') is not None:counts['tripletNotes']+=1
                    ly=n.find('lyric')
                    if ly is not None and ly.find('text') is not None:
                        assert 'stop' not in ties,(role,mi,q,'fresh text on a held note');assert len(n.findall('lyric'))==1
                        texts.append((mi,float(q),ly.findtext('text')));counts['lyricNotes']+=1
                if not chord:last=cursor;cursor+=d
                end=max(end,cursor)
            assert end==4,(path,role,mi,end);start+=end
        assert start==280 and not active,(path,role,start,active)
        expected=''.join(t.rstrip('-') for b in range(1,71) for t in LYRICS[role][b].split() if t!='.')
        assert clean(''.join(t for _,_,t in texts))==clean(expected),(path,role,'lyric text changed')
        voices.append(sorted(attacks));lyrics.append(texts)
    assert counts['slurstart']==counts['slurstop']==34,counts
    assert counts['tripletNotes']==12,counts
    assert counts['tieLinks']==7,counts
    tempos=[float(n.get('tempo')) for n in root.findall('.//sound') if n.get('tempo')]
    assert tempos and all(abs(n-90)<.001 for n in tempos),tempos
    return voices,lyrics,dict(counts)
def validate():
    midi=json.loads((OUT/'midi-reading.json').read_text());written=json.loads((OUT/'duration-recovery.json').read_text());reference=[]
    for role,t in enumerate(midi['tracks']):
        ds={x['index']:x['written'] for x in written if x['role']==role};reference.append(sorted([[n['ticks']/midi['ppq'],n['pitch'],ds[i]] for i,n in enumerate(t['notes'])]))
    reports=[];original_lyrics=None
    for name in ['Aleluya al Rey - SATB con letra - Cantai.musicxml','render/exported.musicxml','render/reimport.musicxml']:
        voices,lyrics,counts=read(OUT/name)
        for role,(actual,expected) in enumerate(zip(voices,reference)):
            assert len(actual)==len(expected),(name,role,len(actual),len(expected))
            for a,b in zip(actual,expected):assert abs(a[0]-b[0])<.003 and a[1]==b[1] and abs(a[2]-b[2])<.003,(name,role,a,b)
        if original_lyrics is None:original_lyrics=lyrics
        else:assert lyrics==original_lyrics,(name,'lyric assignment changed')
        reports.append(dict(file=name,attacks=[len(v) for v in voices],midiPitchAndOnsetMatch=True,notatedDurationsMatch=True,lyricsOnAllFourStaves=True,counts=counts))
    result=dict(measures=70,quarterBeats=280,staves=4,voices=['Soprano','Alto','Tenor','Bajo'],baseTempo=90,checks=reports,referenceCorrection='Soprano bar 54 last note: MIDI overlap removed; eighth note as printed in PDF.')
    (OUT/'validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
if __name__=='__main__':validate()
