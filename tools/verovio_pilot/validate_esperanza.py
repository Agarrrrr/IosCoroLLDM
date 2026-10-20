import json, collections, xml.etree.ElementTree as E
from fractions import Fraction as F
from esperanza_model import OUT, plan

def read(path):
    root=E.parse(path).getroot(); parts=root.findall('part'); assert len(parts)==4
    counts=collections.Counter(); voices=[]; lyrics=[]; tempos=[]
    for role,part in enumerate(parts):
        ms=part.findall('measure'); assert len(ms)==69
        start=F(0); div=960; active={}; attacks=[]; texts=[]
        for bar,m in zip(plan(),ms):
            div=int(m.findtext('attributes/divisions',str(div))); cursor=F(0); last=F(0); end=F(0)
            for n in m:
                if n.tag in ['forward','backup']:cursor+=F(int(n.findtext('duration')),div)*(-1 if n.tag=='backup' else 1)
                if n.tag=='direction' and role==0:
                    for sound in n.findall('sound'):
                        if sound.get('tempo'):tempos.append((float(start+cursor),float(sound.get('tempo'))))
                if n.tag!='note':continue
                chord=n.find('chord') is not None; cue=n.find('cue') is not None
                q=last if chord else cursor; duration=F(int(n.findtext('duration')),div);counts['fermatas']+=len(n.findall('notations/fermata'));counts['articulations']+=len(n.findall('notations/articulations/*'))
                if n.find('pitch') is not None:
                    pitch=(int(n.findtext('pitch/octave'))+1)*12+dict(C=0,D=2,E=4,F=5,G=7,A=9,B=11)[n.findtext('pitch/step')]+int(n.findtext('pitch/alter','0'))
                    ties={t.get('type') for t in n.findall('tie')}
                    if 'stop' in ties:
                        assert pitch in active,(path,role,bar,q,pitch)
                        a=active.pop(pitch); assert abs(float(start+q)-a[0]-a[2])<.00001,(path,role,bar,q)
                        a[2]=float(start+q+duration)-a[0]; counts['ties']+=1
                    else:
                        a=[float(start+q),pitch,float(duration)]
                        if not cue:attacks.append(a)
                    if 'start' in ties:assert pitch not in active;active[pitch]=a
                    counts['notes']+=1;counts['cueNotes']+=int(cue)
                    for sl in n.findall('notations/slur'):counts['slur'+sl.get('type')]+=1
                    ly=n.find('lyric')
                    if ly is not None and ly.find('text') is not None:
                        assert not chord and not cue and 'stop' not in ties
                        assert len(n.findall('lyric'))==1
                        texts.append((float(start+q),ly.findtext('syllabic'),ly.findtext('text')));counts['lyrics']+=1
                if not chord:last=cursor;cursor+=duration
                end=max(end,cursor)
            assert end==bar['duration'],(path,role,bar,end)
            start+=end
        assert start==411 and not active
        voices.append(sorted(attacks));lyrics.append(texts)
    assert counts['ties']==218 and counts['notes']==1561 and counts['cueNotes']==0 and counts['slurstart']==counts['slurstop']==6 and counts['fermatas']==4 and counts['articulations']==0,counts
    return voices,lyrics,dict(counts),sorted(tempos)

def run():
    files=['Tú Eres mi Esperanza - SATB extendido - Cantai.musicxml','render/exported.musicxml','render/reimport.musicxml'];base=None;checks=[]
    for file in files:
        result=read(OUT/file)
        if base is None:base=result
        else:assert result[:3]==base[:3],(file,'notes, lyrics or notation changed')
        assert (0,85) in result[3]
        checks.append(dict(file=file,notesLyricsTiesAndPhrasesPreserved=True,counts=result[2],explicitTempos=result[3]))
    native=[]
    for name in ['playback','playback-reimport']:
        playback=json.loads((OUT/f'render/{name}.json').read_text());assert len(playback['tracks'])==4
        assert any(t['ticks']==0 and abs(t['bpm']-85)<.001 for t in playback['tempos'])
        if name=='playback':
            for q,bpm in base[3]:
                # MuseScore applies its printed final fermata on top of tempo 60.
                effective=bpm/2 if q==408 else bpm
                assert any(abs(t['ticks']/playback['ppq']-q)<.003 and abs(t['bpm']-effective)<.001 for t in playback['tempos']),('native ritardando',q,bpm)
        for role,t in enumerate(playback['tracks']):
            actual=sorted((n['ticks']/playback['ppq'],n['pitch']) for n in t['notes']);expected=sorted((n[0],n[1]) for n in base[0][role])
            assert len(actual)==len(expected),(name,role,len(actual),len(expected))
            assert all(abs(a[0]-b[0])<.003 and a[1]==b[1] for a,b in zip(actual,expected)),(name,role)
        native.append(name)
    layout=json.loads((OUT/'pdf-layout.json').read_text())
    for key in ['issues','pitchIssues','unrepresentedHeads','glyphMismatches']:assert not layout[key],(key,layout[key])
    words=json.loads((OUT/'word-diagnostics.json').read_text(encoding='utf-8'))
    assert not words['unknown'] and not words['repairs']
    guide=json.loads((OUT/'midi-reading.json').read_text());referenceChecks=[]
    for role in range(4):
        original=[]
        for n in guide['tracks'][role]['notes']:
            q=n['ticks']/guide['ppq']+1
            if q>=145.5:continue
            if q<3:m=1;local=q
            elif q<129:m=2+int((q-3)//6);local=(q-3)%6
            else:m=24+int((q-129)//6);local=(q-129)%6
            original.append(dict(measure=m,onset=local,pitch=n['pitch'],duration=n['duration']/guide['ppq']))
        original += [dict(n,measure=23) for n in original if n['measure']==24]
        expected=[];corrections=[]
        for bar in plan():
            for n in original:
                if n['measure']!=bar['source']:continue
                pitch=n['pitch'];duration=n['duration']
                if role==0 and n['measure']==16 and pitch==74:pitch=73;corrections.append('soprano Db from PDF')
                if role==2 and n['measure']==14 and pitch==50:
                    if n['onset']==3:continue
                    duration=4;corrections.append('tenor lower divisi D tied from PDF')
                expected.append((bar['start']+n['onset'],pitch,duration))
        assert sorted(expected)==[tuple(a) for a in base[0][role]],(role,'guide attack or duration mismatch')
        referenceChecks.append(dict(role=role,attacks=len(expected),documentedCorrections=corrections))
    root=E.parse(OUT/files[0]).getroot();assert len(root.findall('.//dynamics'))==76 and len(root.findall('.//wedge'))==56
    assert len(root.findall('.//lyric/text'))==1296
    assert root.find('.//direction-type/words') is not None
    result=dict(originalMeasures=26,expandedMeasures=69,quarterBeats=411,parts=4,pages=len(list((OUT/'render').glob('preview-*.png'))),checks=checks,attacks=[len(r) for r in base[0]],pdfGeometryVerified=True,nativePlaybackAttacksMatchWrittenTies=True,printedTemposPreserved=True,nativeMidiValidated=native,referenceChecks=referenceChecks,canonicalTempos=base[3],musescoreReexportTemposPreserved=all(c['explicitTempos']==base[3] for c in checks),ritardandoDestinationEditorial=60)
    assert sum(result['attacks'])==1343,result['attacks']
    (OUT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':run()
