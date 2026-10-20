import json
from extract_salmo150 import OUT
import alabad_arcs
def pitch(e):return 12*(e['diatonic']//7+1)+[0,2,4,5,7,9,11][e['diatonic']%7]+e['alter']
def compare(prefix='salmo150'):
    alabad_arcs.OUT=OUT;arcs=alabad_arcs.read(prefix)
    data=json.loads((OUT/'pdf-reading.json').read_text(encoding='utf-8'))
    midi=json.loads((OUT/'midi-reading.json').read_text());ppq=midi['ppq'];matches=[];ties=[];different=[];missing=[]
    for e in arcs['notes']:
        onset=(e['measure']-1)*4+e['onset'];value=pitch(e)
        track=midi['tracks'][e['role']]['notes']
        attack=[n for n in track if abs(n['ticks']/ppq-onset)<.008]
        if attack:
            n=min(attack,key=lambda n:abs(n['pitch']-value))
            if n['pitch']!=value:different.append(dict(id=e['id'],role=e['role'],measure=e['measure'],onset=e['onset'],pdf=value,midi=n['pitch']))
            else:matches.append(e['id'])
        else:
            held=[n for n in track if n['pitch']==value and n['ticks']/ppq<onset and (n['ticks']+n['duration'])/ppq>onset+.01]
            if held:ties.append(dict(id=e['id'],role=e['role'],measure=e['measure'],onset=e['onset']))
            else:missing.append(dict(id=e['id'],role=e['role'],measure=e['measure'],onset=e['onset'],pdf=value))
    report=dict(matchedAttacks=len(matches),heldContinuations=ties,pitchDifferences=different,unmatched=missing)
    (OUT/'midi-comparison.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=='__main__':compare()
