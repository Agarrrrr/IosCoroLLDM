"""Keep independent written words and vocalises over their printed melismas."""
from fractions import Fraction as F
def protections(model,lyrics):
 events=[e for e in model['events'] if not e['rest']];byid={e['id']:e for e in events};edges={}
 for a,z in model['connections']+model['slurs']:edges.setdefault(a,[]).append(z)
 out={}
 for lyric in lyrics:
  starts=[e for e in events if e['role']==lyric['role'] and e['measure']==lyric['bar'] and F(e['onset'])==F(lyric['onset'])]
  for start in starts:
   siblings=[e for e in events if e['measure']==start['measure'] and F(e['onset'])==F(start['onset']) and e['duration']==start['duration'] and e.get('staff')==start.get('staff')]
   for sibling in siblings:
    stack=[sibling['id']];seen=set();end=F(sibling['absolute'])
    while stack:
     key=stack.pop()
     if key in seen:continue
     seen.add(key);end=max(end,F(byid[key]['absolute']));stack.extend(edges.get(key,[]))
    out.setdefault(sibling['role'],[]).append((F(sibling['absolute']),end,lyric['verse'],lyric['role']))
 return out
def blocked(protected,target_role,absolute,verse,source_role):
 return any(a<=F(absolute)<=z and v in [0,verse] and origin!=source_role for a,z,v,origin in protected.get(target_role,[]))
