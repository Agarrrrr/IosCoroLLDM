import json,collections,xml.etree.ElementTree as E
from fractions import Fraction as F
from apostol_model import OUT,plan
def read(path):
    root=E.parse(path).getroot();parts=root.findall('part');assert len(parts)==4;counts=collections.Counter();voices=[];lyrics=[];tempos=[]
    for role,part in enumerate(parts):
        ms=part.findall('measure');assert len(ms)==95;start=F(0);div=960;active={};attacks=[];texts=[]
        for bar,m in zip(plan(),ms):
            div=int(m.findtext('attributes/divisions',str(div)));cursor=F(0);last=F(0);end=F(0)
            for n in m:
                if n.tag in ['forward','backup']:cursor+=F(int(n.findtext('duration')),div)*(-1 if n.tag=='backup' else 1)
                if n.tag=='direction' and role==0:
                    for sound in n.findall('sound'):
                        if sound.get('tempo'):tempos.append((float(start+cursor),float(sound.get('tempo'))))
                if n.tag!='note':continue
                chord=n.find('chord') is not None;q=last if chord else cursor;duration=F(int(n.findtext('duration')),div)
                if n.find('pitch') is not None:
                    pitch=(int(n.findtext('pitch/octave'))+1)*12+dict(C=0,D=2,E=4,F=5,G=7,A=9,B=11)[n.findtext('pitch/step')]+int(n.findtext('pitch/alter','0'));ties={t.get('type') for t in n.findall('tie')}
                    if 'stop' in ties:
                        assert pitch in active,(path,role,bar,q,pitch);a=active.pop(pitch)
                        gap=float(start+q)-a[0]-a[2];assert abs(gap)<.00001 ,(path,role,bar,q,gap)
                        a[2]=float(start+q+duration)-a[0];counts['ties']+=1
                    else:a=[float(start+q),pitch,float(duration)];attacks.append(a)
                    if 'start' in ties:assert pitch not in active;active[pitch]=a
                    counts['notes']+=1
                    for sl in n.findall('notations/slur'):counts['slur'+sl.get('type')]+=1
                    counts['fermatas']+=len(n.findall('notations/fermata'));counts['tripletNotes']+=len(n.findall('time-modification'))
                    ly=n.find('lyric')
                    if ly is not None and ly.find('text') is not None:
                        assert not chord and 'stop' not in ties;assert len(n.findall('lyric'))==1;texts.append((float(start+q),ly.findtext('text')));counts['lyrics']+=1
                if not chord:last=cursor;cursor+=duration
                end=max(end,cursor)
            assert end==bar['duration'],(path,role,bar,end);start+=end
        assert start==377 and not active;voices.append(sorted(attacks));lyrics.append(texts)
    assert counts['ties']==54 and counts['notes']==1427 and counts['slurstart']==counts['slurstop']==21 and counts['fermatas']==9 and counts['tripletNotes']==12,counts
    return voices,lyrics,dict(counts),sorted(tempos)
def run():
    assert len(list((OUT/'render').glob('preview-*.png')))==11,'Complete final rendering before validation/delivery'
    files=['Apóstol, Padre y Maestro - SATB extendido - Cantai.musicxml','render/exported.musicxml','render/reimport.musicxml'];base=None;checks=[]
    for file in files:
        result=read(OUT/file)
        if base is None:base=result
        else:assert result[:3]==base[:3],(file,'notes, lyrics or notation changed')
        checks.append(dict(file=file,notesLyricsTiesAndPhrasesPreserved=True,counts=result[2],explicitTempos=result[3]))
    expected_tempos=[(0,90),(44,78),(56.5,90),(210,87),(211,84),(212,81),(213,78),(244,96),(277,90)];assert base[3]==expected_tempos
    playback=json.loads((OUT/'render/playback.json').read_text());guide=json.loads((OUT/'midi-reading.json').read_text());assert len(playback['tracks'])==4
    for q,bpm in expected_tempos:assert any(abs(t['ticks']/playback['ppq']-q)<.003 and (abs(t['bpm']-bpm)<.001 or q==213 and abs(t['bpm']-bpm/2)<.001) for t in playback['tempos']),(q,bpm)
    for role,t in enumerate(playback['tracks']):
        actual=sorted((n['ticks']/playback['ppq'],n['pitch']) for n in t['notes']);expected=sorted((n[0],n[1]) for n in base[0][role]);assert len(actual)==len(expected),(role,len(actual),len(expected));assert all(abs(a[0]-b[0])<.003 and a[1]==b[1] for a,b in zip(actual,expected)),role
    # Reference MIDI reattacks three printed cross-page ties at bar 73 and
    # changes the Alto rhythm in bar 63. Preserve the printed interpretation.
    differences=[]
    for role in range(4):
        original=sorted((n['ticks']/guide['ppq'],n['pitch']) for n in guide['tracks'][role]['notes']);written=sorted((n[0],n[1]) for n in base[0][role])
        for q,pitch in written:
            if not any(abs(oq-q)<.003 and op==pitch for oq,op in original):differences.append(dict(kind='writtenAttack',role=role,beat=q,pitch=pitch))
        for q,pitch in original:
            if not any(abs(wq-q)<.003 and wp==pitch for wq,wp in written):differences.append(dict(kind='referenceAttack',role=role,beat=q,pitch=pitch))
    es=json.loads((OUT/'positioned-events.json').read_text());unmatched=[]
    for e in es:
        if e.get('rest'):continue
        matches=[n for n in guide['tracks'][e['role']]['notes'] if n['pitch']==e['pitch'] and n['ticks']/guide['ppq']-.26<=e['absolute']<=(n['ticks']+n['duration'])/guide['ppq']+.26]
        if not matches:unmatched.append(e)
    assert not unmatched,unmatched
    # The first written dotted eighth of the men's staccato passage is short;
    # its closing whole note remains sustained, as in the reference.
    for role in [2,3]:
        start=next(n for n in playback['tracks'][role]['notes'] if n['ticks']/playback['ppq']==16)
        close=next(n for n in playback['tracks'][role]['notes'] if n['ticks']/playback['ppq']==52)
        assert .32<start['duration']/playback['ppq']<.43,(role,'staccato',start)
        expected_close=next(n for n in guide['tracks'][role]['notes'] if n['ticks']/guide['ppq']==52)
        assert abs(close['duration']/playback['ppq']-expected_close['duration']/guide['ppq'])<.1,(role,'closing whole',close)
    root=E.parse(OUT/files[0]).getroot();marks=sum(len(p.findall('.//direction-type/dynamics')) for p in root.findall('part'));wedges=root.findall('.//direction-type/wedge');assert marks==76 and len(wedges)==22
    result=dict(originalMeasures=92,expandedMeasures=95,quarterBeats=377,parts=4,pages=len(list((OUT/'render').glob('preview-*.png'))),checks=checks,attacks=[len(r) for r in base[0]],allReferencePitchesMatch=True,nativePlaybackAttacksMatchWrittenTies=True,nativeStaccatoAndClosingSustainVerified=True,printedDynamicMarks=marks,regulators=11,explicitTempos=expected_tempos,referenceOnsetDifferences=differences,canonicalXmlRecommended=True,musescoreExportTemposPreserved=all(check['explicitTempos']==expected_tempos for check in checks))
    (OUT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(result,ensure_ascii=False,indent=2))
if __name__=='__main__':run()
