import json, collections, xml.etree.ElementTree as E
from fractions import Fraction as F
from eleccion_model import OUT, plan

def read(path):
    root=E.parse(path).getroot(); parts=root.findall('part'); assert len(parts)==4
    counts=collections.Counter(); voices=[]; lyrics=[]; tempos=[]
    for role,part in enumerate(parts):
        ms=part.findall('measure'); assert len(ms)==106
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
        assert start==319 and not active
        voices.append(sorted(attacks));lyrics.append(texts)
    assert counts['ties']==38 and counts['notes']==1086 and counts['cueNotes']==0 and counts['slurstart']==counts['slurstop']==13 and counts['fermatas']==15 and counts['articulations']==204,counts
    return voices,lyrics,dict(counts),sorted(tempos)

def run():
    files=['Elección Apostólica - SATB extendido - Cantai.musicxml','render/exported.musicxml','render/reimport.musicxml'];base=None;checks=[]
    for file in files:
        result=read(OUT/file)
        if base is None:base=result
        else:assert result[:3]==base[:3],(file,'notes, lyrics or notation changed')
        for q,bpm in [(0,60),(17,70),(154,90),(213,160),(298,92)]:assert (q,bpm) in result[3],(file,q,result[3])
        checks.append(dict(file=file,notesLyricsTiesAndPhrasesPreserved=True,counts=result[2],explicitTempos=result[3]))
    native=[]
    for name in ['playback','playback-reimport']:
        playback=json.loads((OUT/f'render/{name}.json').read_text());assert len(playback['tracks'])==4
        for q,minimum,maximum in [(214,.45,.55),(229,.1,.2)]:
            n=next(n for n in playback['tracks'][0]['notes'] if abs(n['ticks']/playback['ppq']-q)<.003)
            assert minimum<n['duration']/playback['ppq']<maximum,(name,'printed articulation playback',q,n)
        for q,bpm in [(0,60),(17,70),(154,90),(213,160),(298,92)]:assert any(abs(t['ticks']/playback['ppq']-q)<.003 and abs(t['bpm']-bpm)<.001 for t in playback['tempos']),(name,q,playback['tempos'])
        if name=='playback':
            for q,bpm in base[3]:assert any(abs(t['ticks']/playback['ppq']-q)<.003 and abs(t['bpm']-bpm)<.001 for t in playback['tempos']),('native ritardando',q,bpm)
        for role,t in enumerate(playback['tracks']):
            actual=sorted((n['ticks']/playback['ppq'],n['pitch']) for n in t['notes']);expected=sorted((n[0],n[1]) for n in base[0][role])
            assert len(actual)==len(expected),(name,role,len(actual),len(expected))
            assert all(abs(a[0]-b[0])<.003 and a[1]==b[1] for a,b in zip(actual,expected)),(name,role)
        native.append(name)
    layout=json.loads((OUT/'pdf-layout.json').read_text())
    for key in ['issues','pitchIssues','unrepresentedHeads','glyphMismatches']:assert not layout[key],(key,layout[key])
    words=json.loads((OUT/'word-diagnostics.json').read_text(encoding='utf-8'))
    assert not words['unknown'] and not words['repairs']
    guide=json.loads((OUT/'midi-reading.json').read_text());differences=[]
    for role in range(4):
        original=sorted((n['ticks']/guide['ppq'],n['pitch']) for n in guide['tracks'][role]['notes']);written=sorted((n[0],n[1]) for n in base[0][role])
        for kind,a,b in [('writtenAttack',written,original),('referenceAttack',original,written)]:
            for q,pitch in a:
                if not any(abs(oq-q)<.003 and op==pitch for oq,op in b):differences.append(dict(kind=kind,role=role,beat=q,pitch=pitch))
    assert differences==[dict(kind='writtenAttack',role=0,beat=248.5,pitch=67),dict(kind='writtenAttack',role=1,beat=248.5,pitch=67)],differences
    root=E.parse(OUT/files[0]).getroot();assert len(root.findall('.//dynamics'))==34 and len(root.findall('.//wedge'))==26
    result=dict(originalMeasures=99,expandedMeasures=106,quarterBeats=319,parts=4,pages=len(list((OUT/'render').glob('preview-*.png'))),checks=checks,attacks=[len(r) for r in base[0]],pdfGeometryVerified=True,nativePlaybackAttacksMatchWrittenTies=True,printedTemposPreserved=True,nativeMidiValidated=native,referenceOnsetDifferences=differences,canonicalTempos=base[3],musescoreReexportTemposPreserved=all(c['explicitTempos']==base[3] for c in checks))
    assert sum(result['attacks'])==1048,result['attacks']
    (OUT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':run()
