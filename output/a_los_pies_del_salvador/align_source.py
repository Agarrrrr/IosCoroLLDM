from pathlib import Path
import json,sys,xml.etree.ElementTree as E,functools
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
OUT=Path(__file__).resolve().parent
root=E.parse(OUT/'source.musicxml').getroot();parts=parse(root);data=json.loads((OUT/'layout.json').read_text(encoding='utf-8'));mapped=[];issues=[]
for bar in range(1,59):
 hs=[h for h in data['heads'] if h['measure']==bar]
 hs=list({(h['staff'],round(h['x'],2),round(h['y'],2)):h for h in hs}.values());groups=[]
 for h in sorted(hs,key=lambda h:h['x']):
  if not groups or abs(h['x']-groups[-1][0]['x'])>.7:groups.append([])
  groups[-1].append(h)
 onsets=sorted({e['onset'] for r in range(4) for e in parts[r][bar-1]['events'] if e['pitch'] is not None})
 sy=next(s for s in data['systems'] if s['first']<=bar<=s['last'])
 targets=[{(next(i for i,roles in enumerate(sy['roles']) if r in roles),e['pitch']) for r in range(4) for e in parts[r][bar-1]['events'] if e['onset']==o and e['pitch'] is not None} for o in onsets]
 @functools.lru_cache(None)
 def partition(i,j):
  if i==len(onsets):return [] if j==len(groups) else None
  for take in range(1,4):
   if j+take>len(groups):break
   group=sum(groups[j:j+take],[])
   if {(h['staff'],h['pitch']) for h in group}!=targets[i]:continue
   tail=partition(i+1,j+take)
   if tail is not None:return [take]+tail
  return None
 plan=partition(0,0)
 if plan is None:issues.append(('columns',bar,len(groups),len(onsets)));continue
 combined=[];gi=0
 for take in plan:combined.append(sum(groups[gi:gi+take],[]));gi+=take
 for onset,group in zip(onsets,combined):
  for role in range(4):
   for ei,e in enumerate(parts[role][bar-1]['events']):
    if e['onset']!=onset or e['pitch'] is None:continue
    hh=[h for h in group if role in h['roles'] and h['pitch']==e['pitch']]
    if not hh:issues.append(('head',bar,role,float(onset),e['pitch'],[(h['roles'],h['pitch']) for h in group]));continue
    h=hh[0];mapped.append(dict(role=role,measure=bar,index=ei,onset=float(onset),duration=float(e['duration']),pitch=e['pitch'],**{k:h[k] for k in ['page','system','x','y','staff']}))
(OUT/'mapped.json').write_text(json.dumps(dict(events=mapped,issues=issues),ensure_ascii=False,indent=2),encoding='utf-8')
print('matched',len(mapped),'issues',issues)
