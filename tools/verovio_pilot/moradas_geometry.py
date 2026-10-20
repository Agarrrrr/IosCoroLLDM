import json
from moradas_model import OUT
def run():
    events=json.loads((OUT/'source-events.json').read_text());heads=json.loads((OUT/'pdf-heads.json').read_text());layout=json.loads((OUT/'pdf-layout.json').read_text());issues=[];pitchIssues=[];unrepresented=[];glyphIssues=[]
    for sy in layout['systems']:
        for role in sy['roles']:
            for measure in range(sy['first'],sy['last']+1):
                row=[e for e in events if e['role']==role and e['measure']==measure and not e.get('rest')];hs=[h for h in heads if h['role']==role and h['measure']==measure];xs=[]
                for x in sorted(h['x'] for h in hs):
                    if not xs or x-xs[-1]>6.6:xs.append(x)
                times=sorted({e['onset'] for e in row})
                if len(xs)!=len(times):issues.append(dict(role=role,measure=measure,times=times,xs=xs));continue
                represented=set()
                for e in row:
                    x=xs[times.index(e['onset'])];match=[h for h in hs if 0<=h['x']-x<6.6 and h['pitch']==e['pitch']]
                    if not match:pitchIssues.append(dict(role=role,measure=measure,onset=e['onset'],midi=e['pitch'],pdf=[h['pitch'] for h in hs if 0<=h['x']-x<6.6]));continue
                    h=match[0];represented.add((h['x'],h['pitch']));e.update({k:h[k] for k in ['x','y','diatonic','alter','page','system','staff','glyph']});e['pdfPitchVerified']=True
                    if h['glyph']=='˙' and e['duration'] not in [2,3] or h['glyph']=='w' and e['duration']!=4:glyphIssues.append(dict(role=role,measure=measure,onset=e['onset'],duration=e['duration'],glyph=h['glyph']))
                unrepresented += [h for h in hs if (h['x'],h['pitch']) not in represented]
    layout.update(issues=issues,pitchIssues=pitchIssues,unrepresentedHeads=unrepresented,glyphMismatches=glyphIssues)
    (OUT/'pdf-layout.json').write_text(json.dumps(layout,indent=2));(OUT/'positioned-events.json').write_text(json.dumps(events,indent=2))
    for key in ['issues','pitchIssues','unrepresentedHeads','glyphMismatches']:print(key,json.dumps(layout[key],indent=2))
if __name__=='__main__':run()
