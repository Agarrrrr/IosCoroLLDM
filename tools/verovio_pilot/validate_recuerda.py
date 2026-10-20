import collections,json,xml.etree.ElementTree as E
from fractions import Fraction as F
from recuerda_model import OUT
def read(path):
    root=E.parse(path).getroot();voices=[];lyrics=[];counts=collections.Counter();tempos=[];parts=root.findall('part');assert len(parts)==4
    for role,part in enumerate(parts):
        assert len(part.findall('measure'))==88,(path,role,len(part.findall('measure')))
        start=F(0);div=960;active={};attacks=[];texts=[]
        for mi,m in enumerate(part.findall('measure')):
            div=int(m.findtext('attributes/divisions',str(div)));cursor=F(0);last=F(0);end=F(0)
            for n in m:
                if n.tag in ['forward','backup']:cursor+=F(int(n.findtext('duration')),div)*(-1 if n.tag=='backup' else 1)
                if n.tag=='direction':
                    counts['dynamics']+=len(n.findall('direction-type/dynamics'))
                    if role==0:
                        for sound in n.findall('sound'):
                            if sound.get('tempo'):tempos.append((float(start+cursor+F(int(n.findtext('offset','0')),div)),float(sound.get('tempo'))))
                if n.tag!='note':continue
                chord=n.find('chord') is not None;q=last if chord else cursor;duration=F(int(n.findtext('duration')),div)
                if n.find('pitch') is not None:
                    pitch=(int(n.findtext('pitch/octave'))+1)*12+dict(C=0,D=2,E=4,F=5,G=7,A=9,B=11)[n.findtext('pitch/step')]+int(n.findtext('pitch/alter','0'));ties={t.get('type') for t in n.findall('tie')}
                    if 'stop' in ties:
                        assert pitch in active,(path,role,mi,q,pitch);a=active.pop(pitch);assert abs(a[0]+a[2]-float(start+q))<.00001,(a,start+q);a[2]+=float(duration);counts['tieLinks']+=1
                    else:a=[float(start+q),pitch,float(duration)];attacks.append(a)
                    if 'start' in ties:assert pitch not in active;active[pitch]=a
                    counts['writtenNotes']+=1
                    for s in n.findall('notations/slur'):counts['slur'+s.get('type')]+=1
                    counts['articulations']+=len(n.findall('notations/articulations/*'))
                    ly=n.find('lyric')
                    if ly is not None and ly.find('text') is not None:
                        assert not chord and 'stop' not in ties,(path,role,mi,'fresh lyric on held/chord note');assert len(n.findall('lyric'))==1
                        texts.append((float(start+q),ly.findtext('text')));counts['lyricNotes']+=1
                if not chord:last=cursor;cursor+=duration
                end=max(end,cursor)
            assert end==(1 if mi==0 else 4),(path,role,mi,end);start+=end
        assert start==349 and not active,(path,role,start,active)
        voices.append(sorted(attacks));lyrics.append(texts)
    assert counts['tieLinks']==163 and counts['writtenNotes']==2248,counts
    assert counts['slurstart']==counts['slurstop']==29,counts
    assert counts['lyricNotes']==2014,counts
    return voices,lyrics,dict(counts),sorted(tempos)
def clean_tempos(rows):
    result=[]
    for q,bpm in rows:
        if result and abs(result[-1][1]-bpm)<.000001:continue
        result.append((q,bpm))
    return result
def validate():
    midi=json.loads((OUT/'midi-reading.json').read_text());ds=json.loads((OUT/'duration-recovery.json').read_text());reference=[]
    for role,t in enumerate(midi['tracks']):
        durations={n['index']:n['written'] for n in ds if n['role']==role};reference.append(sorted([[n['ticks']/midi['ppq'],n['pitch'],durations[i]] for i,n in enumerate(t['notes'])]))
    reports=[];first_lyrics=None;first_tempos=None
    for name in ['Recuerda - SATB extendido - Cantai.musicxml','render/exported.musicxml','render/reimport.musicxml']:
        rows,lyrics,counts,tempos=read(OUT/name)
        for role,(actual,expected) in enumerate(zip(rows,reference)):
            assert len(actual)==len(expected),(name,role,len(actual),len(expected))
            for a,b in zip(actual,expected):assert abs(a[0]-b[0])<.003 and a[1]==b[1] and abs(a[2]-b[2])<.003,(name,role,a,b)
        if first_lyrics is None:first_lyrics=lyrics;first_tempos=tempos
        else:assert lyrics==first_lyrics,(name,'underlay changed')
        reports.append(dict(file=name,attacks=[len(r) for r in rows],pitchOnsetAndWrittenDurationMatch=True,lyricTextAndPositionsPreserved=True,counts=counts,tempoEvents=len(tempos)))
    expected_tempos=clean_tempos([(t['ticks']/midi['ppq'],t['bpm']) for t in midi['tempos']]);assert len(first_tempos)==len(expected_tempos)==66
    playback=json.loads((OUT/'render/playback.json').read_text());actual_tempos=clean_tempos([(t['ticks']/playback['ppq'],t['bpm']) for t in playback['tempos']]);assert len(actual_tempos)==len(expected_tempos),(len(actual_tempos),len(expected_tempos))
    for a,b,c in zip(first_tempos,actual_tempos,expected_tempos):
        assert abs(a[0]-c[0])<.003 and abs(b[0]-c[0])<.003 and abs(a[1]-c[1])<.001 and abs(b[1]-c[1])<.001,(a,b,c)
    for role,t in enumerate(playback['tracks']):
        attacks=sorted((n['ticks']/playback['ppq'],n['pitch']) for n in t['notes']);expected=sorted((n['ticks']/midi['ppq'],n['pitch']) for n in midi['tracks'][role]['notes']);assert len(attacks)==len(expected)
        assert all(abs(a[0]-b[0])<.003 and a[1]==b[1] for a,b in zip(attacks,expected)),role
    layout=json.loads((OUT/'pdf-layout.json').read_text());assert not layout['issues'] and not layout['pitchIssues']
    result=dict(measures=88,quarterBeats=349,parts=4,staves=4,pdfNoteColumnsAndPitchesVerified=True,checks=reports,nativePlaybackMidiReferenceAttacks=True,nativePlaybackTempoEventsMatched=66,tempoRange=[min(t[1] for t in expected_tempos),max(t[1] for t in expected_tempos)],musescoreExportLimitation='MuseScore 4.7.5 omits some invisible tempo events from its own MusicXML export. The delivered canonical MusicXML and native MSCZ retain all 66 real tempo changes; verified in native MIDI playback.')
    (OUT/'validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
if __name__=='__main__':validate()
