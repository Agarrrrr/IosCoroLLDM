import json,xml.etree.ElementTree as E
from fractions import Fraction as F
from collections import Counter
from model import OUT,plan
from build_score import STEM
from midi_reader import read

def score(path):
    root=E.parse(path).getroot();result=[];attacks=[];summaries=[]
    for role,part in enumerate(root.findall('part')):
        div=1;absolute=F(0);counts=Counter()
        for mi,m in enumerate(part.findall('measure')):
            q=F(0);last=F(0);end=F(0)
            for c in m:
                if c.tag=='attributes':div=int(c.findtext('divisions',str(div)))
                elif c.tag in ['forward','backup']:q+=F(int(c.findtext('duration')),div)*(1 if c.tag=='forward' else -1)
                elif c.tag=='note':
                    dur=F(int(c.findtext('duration','0')),div);onset=last if c.find('chord') is not None else q
                    if c.find('chord') is None:last=q;q+=dur
                    end=max(end,q);p=c.find('pitch');pitch=None
                    if p is not None:
                        pitch=12*(int(p.findtext('octave'))+1)+{'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[p.findtext('step')]+int(p.findtext('alter','0'));counts['notes']+=1
                    lyric=''.join(t.text or '' for t in c.findall('lyric/text'));ties=sorted(t.get('type') for t in c.findall('tie'))
                    counts['lyrics']+=bool(lyric);counts['ties']+=len(ties)
                    result.append((role,mi,str(onset),str(dur),pitch,lyric,tuple(ties)))
                    if pitch is not None and 'stop' not in ties:attacks.append((role,float(absolute+onset),pitch))
            assert end==plan()[mi]['duration'],(path.name,role,mi,end)
            absolute+=end
        assert absolute==411
        summaries.append(dict(role=role,bars=len(part.findall('measure')),**counts))
    return result,attacks,summaries

def run():
    a,attacks,summary=score(OUT/(STEM+'.musicxml'));b,_,summary2=score(OUT/'render/exported.musicxml')
    assert a==b,[(x,y) for x,y in zip(a,b) if x!=y][:8]
    playback=read(OUT/'render/playback.mid');actual=[(r,n['onset'],n['pitch']) for r,t in enumerate(playback['tracks']) for n in t['notes']]
    assert len(attacks)==len(actual),(len(attacks),len(actual))
    assert all(r==rr and abs(q-qq)<.01 and p==pp for (r,q,p),(rr,qq,pp) in zip(attacks,actual))
    bpms=[v for q,v in playback['tempos']]
    assert all(any(abs(v-target)<.02 for v in bpms) for target in [55,53.143,51.286,45.714,44.786,43.857,42,90,70,65,160]),bpms
    report=dict(parts=summary,expandedBars=110,quarterUnits=411,roundTripIdentical=True,playbackAttacks=len(actual),playbackMatchesScore=True,tempos=playback['tempos'],cantaiTested=False)
    (OUT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__':run()
