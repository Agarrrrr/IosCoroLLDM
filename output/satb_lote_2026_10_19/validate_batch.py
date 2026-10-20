from pathlib import Path
import json,xml.etree.ElementTree as E,collections,sys,zipfile
from inventory import OUT
from score_model import parse
sys.path.insert(0,str(Path('output/cantico_144_mil').resolve()))
from midi_reader import read

def lyric(s):return s.replace('\ue550','‿').replace('\ue551','‿').replace('\ue552','‿')

def data(root):
    parts=parse(root);result=[]
    for r,p in enumerate(parts):
        notes=[];q=0
        for mi,m in enumerate(p):
            for e in m['events']:
                if e['pitch'] is not None:notes.append(dict(bar=mi,onset=float(e['onset']),duration=float(e['duration']),pitch=e['pitch'],lyric=lyric(''.join(t.text or '' for t in e['node'].findall('lyric/text'))),ties=sorted(t.get('type') for t in e['node'].findall('tie'))))
        result.append(sorted(notes,key=lambda n:(n['bar'],n['onset'],n['pitch'])))
    return result

def run():
    rows=json.loads((OUT/'prepared-index.json').read_text(encoding='utf8'));report=[]
    for record in rows:
        i=record['index'];w=OUT/f'{i:02d}'
        if not (w/'reopened.musicxml').exists():continue
        source=E.parse(w/'prepared.musicxml').getroot();again=E.parse(w/'reopened.musicxml').getroot();a=data(source);b=data(again);issues=[]
        if len(a)!=record['parts'] or len(b)!=record['parts']:issues.append(('parts',len(a),len(b),record['parts']))
        for r,(aa,bb) in enumerate(zip(a,b)):
            if len(aa)!=len(bb):issues.append(('note count',r,len(aa),len(bb)))
            else:
                for n,v in zip(aa,bb):
                    if n['bar']!=v['bar'] or n['pitch']!=v['pitch'] or abs(n['onset']-v['onset'])>.012 or abs(n['duration']-v['duration'])>.012 or n['lyric']!=v['lyric'] or n['ties']!=v['ties']:issues.append(('note mismatch',r,n,v))
        da=collections.Counter(c.tag for d in source.findall('.//dynamics') for c in d);db=collections.Counter(c.tag for d in again.findall('.//dynamics') for c in d)
        if da!=db:issues.append(('dynamics',dict(da),dict(db)))
        bars=[len(p.findall('measure')) for p in again.findall('part')]
        if any(n!=record['expandedMeasures'] for n in bars):issues.append(('bars',bars,record['expandedMeasures']))
        midi=read(w/'playback.mid');summary=dict(index=i,title=record['title'],parts=len(b),bars=bars,notes=[len(p) for p in b],lyrics=len(again.findall('.//lyric/text')),dynamics=dict(db),hairpins=len(again.findall('.//wedge')),tempos=midi['tempos'],issues=issues)
        report.append(summary);print(i,'PASS' if not issues else 'FAIL', 'notes',summary['notes'],'dyn',summary['dynamics'],'issues',str(issues[:3])[:800],flush=True)
    (OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
if __name__=='__main__':run()
