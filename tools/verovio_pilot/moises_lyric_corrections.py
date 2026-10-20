"""Explicit underlay corrections checked against the source, kept auditable."""
import json
from moises_model import OUT
def run():
    es=json.loads((OUT/'positioned-events.json').read_text());ls=json.loads((OUT/'lyric-atoms.json').read_text(encoding='utf-8'));changes=[]
    def event(role,measure,onset,passage=1):return next(e for e in es if e['role']==role and e['measure']==measure and abs(e['onset']-onset)<.0001 and e['passage']==passage and not e.get('rest'))
    for role in [0,1]:
        for passage in [1,2]:
            a=event(role,1,1/3,passage);b=event(role,1,0,passage);ls[b['id']]=ls.pop(a['id']);changes.append([role,1,'Can on first triplet note',passage])
    # The digital source misses the n in "Grande" in the bass, bar 32.
    e=event(3,32,2);assert ls[e['id']][0]['text']=='Gra';ls[e['id']][0]['text']='Gran';changes.append([3,32,'Grade -> Grande'])
    # A PDF kerning boundary assigned the final e of pre to the next onset.
    a=event(1,99,2);b=event(1,99,3);c=event(1,99,2.75)
    assert ls[a['id']][0]['text']=='siempr' and ls[b['id']][0]['text']=='e'
    ls[a['id']][0]['text']='siem';atom=ls[b['id']].pop(0);atom['text']='pre';ls[c['id']]=[atom];changes.append([1,99,'siem-pre restored at dotted-eighth/sixteenth'])
    # Source prints "e es" over a two-note melisma. Sing es once and extend.
    for role in [0,1]:
        a=event(role,73,1.5);b=event(role,73,1.75);ls[a['id']][0].update(text='es',syllabic='single');ls.pop(b['id']);changes.append([role,73,'es over two-note melisma'])
    (OUT/'lyric-atoms.json').write_text(json.dumps(ls,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'lyric-corrections.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2),encoding='utf-8');print(changes)
if __name__=='__main__':run()
