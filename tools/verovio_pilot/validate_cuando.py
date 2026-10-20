import json, collections, xml.etree.ElementTree as E
from fractions import Fraction as F
from cuando_model import OUT, plan

def read(path):
    root=E.parse(path).getroot(); parts=root.findall('part'); assert len(parts)==4
    counts=collections.Counter(); voices=[]; lyrics=[]; tempos=[]
    for role,part in enumerate(parts):
        ms=part.findall('measure'); assert len(ms)==128
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
                q=last if chord else cursor; duration=F(int(n.findtext('duration')),div)
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
        assert start==506 and not active
        voices.append(sorted(attacks));lyrics.append(texts)
    assert counts['ties']==48 and counts['notes']==2015 and counts['cueNotes']==6 and counts['slurstart']==counts['slurstop']==12,counts
    return voices,lyrics,dict(counts),sorted(tempos)

def run():
    files=['Cuando Oí Su Voz - SATB extendido - Cantai.musicxml','render/exported.musicxml','render/reimport.musicxml'];base=None;checks=[]
    for file in files:
        result=read(OUT/file)
        if base is None:base=result
        else:assert result[:3]==base[:3],(file,'notes, lyrics or notation changed')
        assert result[3]==[(0.0,78.0)],(file,result[3])
        checks.append(dict(file=file,notesLyricsTiesAndPhrasesPreserved=True,counts=result[2],explicitTempos=result[3]))
    native=[]
    for name in ['playback','playback-reimport']:
        playback=json.loads((OUT/f'render/{name}.json').read_text());assert len(playback['tracks'])==4
        assert all(abs(t['bpm']-78)<.001 for t in playback['tempos']),playback['tempos']
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
        original=sorted((n['ticks']/guide['ppq']+3,n['pitch']) for n in guide['tracks'][role]['notes']);written=sorted((n[0],n[1]) for n in base[0][role])
        for kind,a,b in [('writtenAttack',written,original),('referenceAttack',original,written)]:
            for q,pitch in a:
                if not any(abs(oq-q)<.003 and op==pitch for oq,op in b):differences.append(dict(kind=kind,role=role,beat=q,pitch=pitch))
    result=dict(originalMeasures=47,expandedMeasures=128,quarterBeats=506,parts=4,pages=len(list((OUT/'render').glob('preview-*.png'))),checks=checks,attacks=[len(r) for r in base[0]],pdfGeometryVerified=True,nativePlaybackAttacksMatchWrittenTies=True,cueNotesExcludedFromPlayback=True,nativeMidiValidated=native,referenceOnsetDifferences=differences,tempo=78)
    assert sum(result['attacks'])==1961,result['attacks']
    (OUT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':run()
