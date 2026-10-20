import json,collections,xml.etree.ElementTree as E
from fractions import Fraction as F
from moises_model import OUT,plan
def read(path):
    root=E.parse(path).getroot();parts=root.findall('part');assert len(parts)==4;counts=collections.Counter();voices=[];lyrics=[];tempos=[]
    for role,part in enumerate(parts):
        ms=part.findall('measure');assert len(ms)==122;start=F(0);div=960;active={};attacks=[];texts=[]
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
                        gap=float(start+q)-a[0]-a[2];assert abs(gap)<.00001 or role==3 and bar['source']==95 and q==3 and abs(gap-.25)<.00001,(path,role,bar,q,gap)
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
        assert start==484 and not active;voices.append(sorted(attacks));lyrics.append(texts)
    assert counts['ties']==43 and counts['notes']==2214 and counts['slurstart']==counts['slurstop']==62 and counts['fermatas']==24 and counts['tripletNotes']==51,counts
    return voices,lyrics,dict(counts),sorted(tempos)
def run():
    files=['El Cántico de Moisés - SATB extendido - Cantai.musicxml','render/exported.musicxml','render/reimport.musicxml'];base=None;checks=[]
    for file in files:
        result=read(OUT/file)
        if base is None:base=result
        else:assert result[:3]==base[:3],(file,'roundtrip changed notes or lyrics')
        checks.append(dict(file=file,notesLyricsTiesAndPhrasesPreserved=True,counts=result[2],retainedExplicitTempos=result[3]))
    assert base[3]==[(0,90),(178,80),(270,90),(317.5,80),(428,135),(479,130),(479.75,40)],base[3]
    playback=json.loads((OUT/'render/playback.json').read_text());assert len(playback['tracks'])==4
    for q,bpm in base[3]:assert any(abs(t['ticks']/playback['ppq']-q)<.003 and abs(t['bpm']-bpm)<.001 for t in playback['tempos']),(q,bpm,'missing in native playback')
    for role,t in enumerate(playback['tracks']):
        a=sorted((n['ticks']/playback['ppq'],n['pitch']) for n in t['notes']);b=sorted((n[0],n[1]) for n in base[0][role]);assert len(a)==len(b),(role,len(a),len(b));assert all(abs(aa[0]-bb[0])<.003 and aa[1]==bb[1] for aa,bb in zip(a,b)),role
    held=next(n for n in playback['tracks'][3]['notes'] if n['pitch']==54 and abs(n['ticks']/playback['ppq']-390.5)<.003)
    assert .9<held['duration']/playback['ppq']<=1.01,'Bass F# must sustain the full beat across E ornament, allowing normal release gating'
    es=json.loads((OUT/'positioned-events.json').read_text());reference=json.loads((OUT/'midi-reading.json').read_text());mismatch=[]
    for role,t in enumerate(reference['tracks']):
        for n in t['notes']:
            q=n['ticks']/reference['ppq'];c=[e for e in es if e['role']==role and abs(e['absolute']-q)<.03 and e.get('pitch')==n['pitch']]
            if not c:mismatch.append(dict(role=role,midiBeat=q,midiPitch=n['pitch'],nearbyPrinted=[{k:e[k] for k in ['measure','onset','pitch','duration']} for e in es if e['role']==role and 'pitch' in e and abs(e['absolute']-q)<=.6]))
    printed_extra=[]
    for role,row in enumerate(base[0]):
        for q,pitch,duration in row:
            if not any(abs(n['ticks']/reference['ppq']-q)<.03 and n['pitch']==pitch for n in reference['tracks'][role]['notes']):
                b=next(b for b in plan() if b['start']<=q<b['start']+b['duration']);printed_extra.append(dict(role=role,sourceMeasure=b['source'],onset=q-b['start'],pitch=pitch,duration=duration))
    result=dict(sourceMeasures=118,expandedMeasures=122,quarterBeats=484,parts=4,pages=14,checks=checks,nativePlaybackAttacksMatchWrittenTies=True,nativePlaybackPreservesSevenExplicitTempos=True,attacks=[len(r) for r in base[0]],tempoChanges=base[3],midiReferenceDiscrepancies=mismatch,sourcePriority='PDF notation and printed initial quarter=90; MIDI used to cross-check pitches and support nonnumeric tempo indications. Fermata playback generated by MuseScore.',musescoreExportLimitation='MuseScore 4.7.5 drops hidden metronomes in its own MusicXML export. Delivered canonical MusicXML and native MSCZ preserve all seven real tempo changes, verified in native MIDI playback. Use the delivered XML directly for Cantai.')
    result['printedAttacksDifferentFromReference']=printed_extra;result['bassOrnamentSustainVerified']=True
    (OUT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(result,ensure_ascii=False,indent=2))
if __name__=='__main__':run()
