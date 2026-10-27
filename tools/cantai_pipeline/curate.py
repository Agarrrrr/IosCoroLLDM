"""Apply reviewed scope and expression decisions stored in per-score data."""
from fractions import Fraction as F
from pathlib import Path
import json
from common import WORK,read_json,save_json

def curate(job_id,folder=None):
 p=Path(folder) if folder is not None else WORK/'scores'/job_id;c=read_json(p/'config.json');r=read_json(p/'base-model.json') if (p/'base-model.json').exists() else read_json(p/'model.json');es=r['events'];byid={e['id']:e for e in es}
 for d in r['directions']:d['onset']=str(F(str(d['onset'])))
 if c.get('global_dynamics'):
  source_roles=c.get('global_source_roles',[0,1]);unique={(d['bar'],d['onset'],d['value']):d for d in r['directions'] if d['kind']=='dynamic' and d['role'] in source_roles and (c.get('global_four_staff') or len(next(s for s in r['systems'] if s['first']<=d['bar']<=s['last'])['staves'])<4)}
  for (b,q,value),d in unique.items():
   for ro in range(4):
    clone=dict(d,role=ro)
    if not any(x['kind']=='dynamic' and x['role']==ro and x['bar']==b and x['onset']==q for x in r['directions']):r['directions'].append(clone)
  unique={}
  if c.get('normalize_global_hairpins'):
   r['hairpins']=[h for h in r['hairpins'] if h['role'] in source_roles]
  for h in r['hairpins']:
   if h['role'] not in source_roles:continue
   a,z=byid[h['start']],byid[h['stop']];unique.setdefault((a['measure'],a['onset'],z['measure'],z['onset'],h['kind']),h)
  for (ab,aq,zb,zq,kind),h in unique.items():
   for ro in range(4):
    if any(x['role']==ro and byid[x['start']]['measure']==ab and byid[x['stop']]['measure']==zb and x['kind']==kind for x in r['hairpins']):continue
    pool=[e for e in es if e['role']==ro and not e['rest']];aa=[e for e in pool if e['measure']==ab];zz=[e for e in pool if e['measure']==zb]
    if aa and zz:
     a=min(aa,key=lambda e:abs(F(e['onset'])-F(aq)));z=min(zz,key=lambda e:abs(F(e['onset'])-F(zq)));r['hairpins'].append(dict(role=ro,kind=kind,start=a['id'],stop=z['id'],start_onset=aq,stop_onset=zq))
 for d in c.get('expressions',[]):
  item=dict(role=d.get('role',0),bar=d['bar'],onset=str(F(str(d.get('onset',0)))),kind='words',value=d['text'])
  if item not in r['directions']:r['directions'].append(item)
 for d in c.get('dynamic_additions',[]):
  item=dict(role=d['role'],bar=d['bar'],onset=str(F(str(d.get('onset',0)))),kind='dynamic',value=d['value'])
  if item not in r['directions']:r['directions'].append(item)
 for correction in c.get('direction_overrides',[]):
  for d in list(r['directions']):
   if all((k in d and F(str(d[k]))==F(str(v))) if k=='onset' else d.get(k)==v for k,v in correction['match'].items()):
    if correction.get('remove'):r['directions'].remove(d)
    else:d.update(correction['values'])
 unique=[];seen=set()
 for d in r['directions']:
  d['onset']=str(F(str(d['onset'])));signature=json.dumps(d,sort_keys=True,ensure_ascii=False)
  if signature not in seen:seen.add(signature);unique.append(d)
 r['directions']=unique
 save_json(p/'model.json',r)
