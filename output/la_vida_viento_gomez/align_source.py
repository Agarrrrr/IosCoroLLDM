from pathlib import Path
import json,sys,xml.etree.ElementTree as E,collections
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
OUT=Path(__file__).resolve().parent
root=E.parse(OUT/'source.musicxml').getroot();parts=parse(root)
fixes=[]
def fix(role,bar,onset,pitch,step,alter,octave):
 e=next(e for e in parts[role][bar-1]['events'] if float(e['onset'])==onset)
 fixes.append(dict(role=role,bar=bar,onset=onset,old=e['pitch'],new=pitch))
 p=root.findall('part')[role].findall('measure')[bar-1].findall('note')[parts[role][bar-1]['events'].index(e)].find('pitch');p.find('step').text=step
 if p.find('alter') is None:E.SubElement(p,'alter')
 p.find('alter').text=str(alter);p.find('octave').text=str(octave)
for bar in [25,73]:
 fix(1,bar,0,64,'E',0,4)
 for onset in [0,.5,1,1.5,2,2.5]:fix(3,bar,onset,52,'E',0,3)
fix(2,45,0,61,'D',-1,4)
E.ElementTree(root).write(OUT/'corrected.musicxml',encoding='utf-8',xml_declaration=True)
parts=parse(root);data=json.loads((OUT/'layout.json').read_text(encoding='utf-8'));mapped=[];issues=[]
for bar in range(1,104):
 hs=[h for h in data['heads'] if h['measure']==bar]
 hs=list({(h['staff'],round(h['x'],2),round(h['y'],2)):h for h in hs}.values())
 groups=[]
 for h in sorted(hs,key=lambda h:h['x']):
  if not groups or abs(h['x']-groups[-1][0]['x'])>.7:groups.append([])
  groups[-1].append(h)
 onsets=sorted({e['onset'] for r in range(4) for e in parts[r][bar-1]['events'] if e['pitch'] is not None})
 if len(groups)!=len(onsets):issues.append(('columns',bar,len(groups),len(onsets)));continue
 for onset,group in zip(onsets,groups):
  for role in range(4):
   for ei,e in enumerate(parts[role][bar-1]['events']):
    if e['onset']!=onset or e['pitch'] is None:continue
    hh=[h for h in group if h['staff']==role//2 and h['pitch']==e['pitch']]
    if not hh:issues.append(('head',bar,role,float(onset),e['pitch'],[(h['staff'],h['pitch']) for h in group]));continue
    h=hh[0];mapped.append(dict(role=role,measure=bar,index=ei,onset=float(onset),duration=float(e['duration']),pitch=e['pitch'],**{k:h[k] for k in ['page','system','x','y']}))
(OUT/'mapped.json').write_text(json.dumps(dict(events=mapped,fixes=fixes,issues=issues),ensure_ascii=False,indent=2),encoding='utf-8')
print('matched',len(mapped),'fixes',len(fixes),'issues',issues)

