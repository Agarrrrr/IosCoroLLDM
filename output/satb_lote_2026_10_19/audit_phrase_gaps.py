import json,xml.etree.ElementTree as E
from pathlib import Path
from score_model import parse
base=Path('output/underlay_revision_2026_10_19');rows=json.loads((base/'audit.json').read_text(encoding='utf-8'));lines=[]
for r in rows:
 parts=parse(E.parse(r['xml']).getroot());lines.append('\n### '+r['name'])
 for ri,p in enumerate(parts):
  seq=[e for m in p for e in m['events'] if e['pitch'] is not None and e['node'].find('chord') is None]
  def txt(e):return ''.join(t.text or '' for t in e['node'].findall('lyric/text'))
  groups=[];group=[];prev=''
  for e in seq+[None]:
   if e is not None and not txt(e) and not any(t.get('type')=='stop' for t in e['node'].findall('tie')) and not any(txt(a) for a in p[e['measure']]['events'] if a['onset']==e['onset']):group.append(e);continue
   if len(group)>=3:
    donors=[]
    for si,sp in enumerate(parts):
     if si==ri:continue
     matched=[]
     for a in group:
      b=next((b for b in sp[a['measure']]['events'] if b['pitch'] is not None and b['onset']==a['onset'] and txt(b)),None)
      if b:matched.append((a,b))
     if len(matched)>=3:donors.append((si,matched))
    if donors:
     si,matched=max(donors,key=lambda z:len(z[1]));text=' '.join(txt(b) for a,b in matched)
     lines.append(f"role{ri} bars{group[0]['measure']+1}-{group[-1]['measure']+1} before=[{prev}] after=[{txt(e) if e else ''}] donor{si} ({len(matched)}/{len(group)}): {text}")
   group=[]
   if e is not None and txt(e):prev=txt(e)
(base/'phrase-gaps.txt').write_text('\n'.join(lines),encoding='utf-8')
print('\n'.join(lines))
