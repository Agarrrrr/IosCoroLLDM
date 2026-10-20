import copy,xml.etree.ElementTree as E
from fractions import Fraction as F

def pitch(n):
    p=n.find('pitch')
    return None if p is None else (int(p.findtext('octave'))+1)*12+{'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[p.findtext('step')]+int(p.findtext('alter','0'))

def parse(root):
    parts=[]
    for pi,p in enumerate(root.findall('part')):
        div=1;meter=F(4);measures=[];absolute=F(0)
        for mi,m in enumerate(p.findall('measure')):
            q=F(0);last=F(0);end=F(0);events=[];dirs=[];attrs=[];durations=[];lastvoice='1';lastdur=None
            for item in m:
                if item.tag=='attributes':
                    div=int(item.findtext('divisions',str(div)));t=item.find('time')
                    if t is not None:
                        beats=sum(int(v) for v in t.findtext('beats','4').split('+'));meter=F(beats*4,int(t.findtext('beat-type','4')))
                    attrs.append(copy.deepcopy(item))
                elif item.tag in ['backup','forward']:q+=F(int(item.findtext('duration')),div)*(-1 if item.tag=='backup' else 1)
                elif item.tag=='note':
                    d=F(int(item.findtext('duration','0')),div);chord=item.find('chord') is not None;voice=item.findtext('voice',lastvoice if chord else '1');onset=last if chord else q
                    if chord and lastdur is not None and item.findtext('type')==events[-1]['node'].findtext('type') and len(item.findall('dot'))==len(events[-1]['node'].findall('dot')):d=lastdur
                    if not chord:lastvoice=voice;lastdur=d
                    if item.find('chord') is None:last=q;q+=d
                    end=max(end,q);events.append(dict(part=pi,measure=mi,onset=onset,duration=d,voice=voice,staff=item.findtext('staff','1'),node=copy.deepcopy(item),pitch=pitch(item),div=div,absolute=absolute+onset))
                elif item.tag in ['direction','harmony']:
                    onset=q+F(int(item.findtext('offset','0')),div);dirs.append(dict(onset=onset,node=copy.deepcopy(item)))
            duration=end if m.get('implicit')=='yes' and end else max(end,meter)
            measures.append(dict(index=mi,source=m,events=events,directions=dirs,attributes=attrs,div=div,meter=meter,duration=duration,absolute=absolute));absolute+=duration
        parts.append(measures)
    if parts:
        for mi in range(min(len(p) for p in parts)):
            ends=[max((e['onset']+e['duration'] for e in p[mi]['events']),default=F(0)) for p in parts]
            if ends[0]>0 and len(set(ends))==1 and ends[0]<parts[0][mi]['meter']:
                for p in parts:p[mi]['duration']=ends[0]
        for p in parts:
            absolute=F(0)
            for m in p:
                m['absolute']=absolute
                for e in m['events']:e['absolute']=absolute+e['onset']
                absolute+=m['duration']
    return parts

def overlaps(events):
    seq=[]
    for e in events:
        if e['pitch'] is not None:seq.extend([(e['onset'],1),(e['onset']+e['duration'],-1)])
    active=0;maximum=0
    for q,v in sorted(seq,key=lambda x:(x[0],x[1])):active+=v;maximum=max(maximum,active)
    return maximum

def semantic(root):
    return [[[(str(e['onset']),str(e['duration']),e['pitch'],e['voice'],tuple(n.text for n in e['node'].findall('lyric/text')),tuple(t.get('type') for t in e['node'].findall('tie'))) for e in m['events']] for m in p] for p in parse(root)]
