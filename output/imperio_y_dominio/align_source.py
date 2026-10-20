from pathlib import Path
import json,sys,xml.etree.ElementTree as E,functools,collections,pdfplumber
sys.path.insert(0,'output/satb_lote_2026_10_19');from score_model import parse
sys.path.insert(0,'output/salmo_135');from read_pdf import beam_y
OUT=Path(__file__).resolve().parent
root=E.parse(OUT/'source.musicxml').getroot();parts=parse(root);data=json.loads((OUT/'layout.json').read_text(encoding='utf-8'));mapped=[];issues=[]
for bar in range(1,80):
 hs=[h for h in data['heads'] if h['measure']==bar];hs=list({(h['role'],round(h['x'],2),round(h['y'],2)):h for h in hs}.values());groups=[]
 for h in sorted(hs,key=lambda h:h['x']):
  if not groups or abs(h['x']-groups[-1][0]['x'])>.7:groups.append([])
  groups[-1].append(h)
 onsets=sorted({e['onset'] for r in range(4) for e in parts[r][bar-1]['events'] if e['pitch'] is not None})
 targets=[{(r,e['pitch']) for r in range(4) for e in parts[r][bar-1]['events'] if e['onset']==o and e['pitch'] is not None} for o in onsets]
 @functools.lru_cache(None)
 def partition(i,j):
  if i==len(onsets):return [] if j==len(groups) else None
  for take in range(1,4):
   if j+take>len(groups):break
   group=sum(groups[j:j+take],[])
   if {(h['role'],h['pitch']) for h in group}!=targets[i]:continue
   tail=partition(i+1,j+take)
   if tail is not None:return [take]+tail
  return None
 plan=partition(0,0)
 if plan is None:issues.append(('columns',bar,len(groups),len(onsets)));continue
 gi=0
 for onset,take in zip(onsets,plan):
  group=sum(groups[gi:gi+take],[]);gi+=take
  for role in range(4):
   for ei,e in enumerate(parts[role][bar-1]['events']):
    if e['onset']!=onset or e['pitch'] is None:continue
    h=next(h for h in group if h['role']==role and h['pitch']==e['pitch'])
    n=root.findall('part')[role].findall('measure')[bar-1].findall('note')[ei];p=n.find('pitch')
    p.find('step').text=h['step'];p.find('alter').text=str(h['alter']);p.find('octave').text=str(h['octave'])
    mapped.append(dict(index=ei,onset=float(onset),absolute=float(e['absolute']),duration=float(e['duration']),chord=e['node'].find('chord') is not None,**h))
assert not issues,issues
beamed=collections.defaultdict(list);beam_issues=[]
with pdfplumber.open(OUT/'original.pdf') as pdf:
 for pi,page in enumerate(pdf.pages,1):
  shapes=[s for s in page.curves if s['fill'] and not any(p[0]=='c' for p in s['path'])]
  shapes += [dict(x0=s['x0'],x1=s['x1'],pts=[(s['x0'],s['top']),(s['x1'],s['top']),(s['x1'],s['bottom']),(s['x0'],s['bottom'])]) for s in page.rects if 1.5<s['height']<3.1]
  for e in mapped:
   if e['page']!=pi:continue
   n=root.findall('part')[e['role']].findall('measure')[e['measure']-1].findall('note')[e['index']]
   if n.findtext('type') not in ['eighth','16th'] or e['chord']:continue
   stem_candidates=[l for l in page.lines if l['width']<.1 and l['height']>8 and l['top']-1<e['y']<l['bottom']+1 and (abs(l['x0']-e['x']-.15)<.5 or abs(l['x0']-e['x']-6.65)<.5)]
   if not stem_candidates:beam_issues.append(('stem',e['role'],e['measure'],e['onset']));continue
   stem=min(stem_candidates,key=lambda l:abs(l['x0']-e['x']-.15) if l['x0']<e['x']+3 else abs(l['x0']-e['x']-6.65));up=stem['x0']>e['x']+3;tip=stem['top'] if up else stem['bottom']
   hits=[(abs(v-tip),i,v) for i,s in enumerate(shapes) if (v:=beam_y(s,stem['x0'])) is not None and abs(v-tip)<10]
   hits.sort();limit=2 if n.findtext('type')=='16th' else 1
   for level,(_,sid,v) in enumerate(hits[:limit],1):beamed[pi,e['role'],level,sid].append(e)
  for (page_number,role,level,sid),row in list(beamed.items()):
   if page_number!=pi:continue
   row.sort(key=lambda e:e['absolute'])
   for i,e in enumerate(row):
    n=root.findall('part')[role].findall('measure')[e['measure']-1].findall('note')[e['index']]
    if len(row)>1:value='begin' if i==0 else 'end' if i==len(row)-1 else 'continue'
    else:value='forward hook' if shapes[sid]['x1']-e['x']>e['x']-shapes[sid]['x0'] else 'backward hook'
    text=E.SubElement(n,'beam',number=str(level));text.text=value
E.indent(root);E.ElementTree(root).write(OUT/'aligned.musicxml',encoding='utf-8',xml_declaration=True)
(OUT/'mapped.json').write_text(json.dumps(dict(events=mapped,issues=issues,beamIssues=beam_issues),ensure_ascii=False,indent=2),encoding='utf-8')
print('matched',len(mapped),'beam issues',beam_issues)
