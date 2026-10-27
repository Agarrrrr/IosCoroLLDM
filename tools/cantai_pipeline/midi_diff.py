from collections import defaultdict
from fractions import Fraction as F
from difflib import SequenceMatcher
from pathlib import Path
import sys
from common import REPO,save_json
sys.path.insert(0,str(REPO/'output/cantico_144_mil'))
from midi_reader import read

def timeline(path):
 m=read(Path(path));groups=defaultdict(set)
 for t in m['tracks']:
  for n in t['notes']:groups[F(n['onset']).limit_denominator(960)].add(n['pitch'])
 return m,[(q,tuple(sorted(p))) for q,p in sorted(groups.items())]

def compare(a,b,report=None):
 ma,aa=timeline(a);mb,bb=timeline(b);blocks=SequenceMatcher(None,[x[1] for x in aa],[x[1] for x in bb],autojunk=False).get_matching_blocks();shifts=[]
 for block in blocks:
  if block.size<3:continue
  for k in range(block.size):
   aq,bq=aa[block.a+k][0],bb[block.b+k][0];delta=aq-bq
   if shifts and shifts[-1]['offset']==str(delta):shifts[-1]['attacks']+=1;shifts[-1]['original_end']=str(aq);shifts[-1]['synth_end']=str(bq)
   else:shifts.append(dict(offset=str(delta),original_start=str(aq),synth_start=str(bq),original_end=str(aq),synth_end=str(bq),attacks=1))
 only_a=sorted(set(aa)-set(bb));only_b=sorted(set(bb)-set(aa))
 result=dict(same_attacks=aa==bb,quarters=[max(t['end'] for t in m['tracks']) for m in [ma,mb]],attack_counts=[len(aa),len(bb)],timing_sections=shifts,first_differences=dict(original=[(str(q),p) for q,p in only_a[:5]],synthesizer=[(str(q),p) for q,p in only_b[:5]]))
 if report:save_json(report,result)
 return result
