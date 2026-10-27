from fractions import Fraction as F
from common import WORK,read_json,save_json
from midi_diff import timeline

def canonical_tempos(events):
 out=[]
 for q,bpm in sorted(events,key=lambda e:e[0]):
  if not out or abs(out[-1][1]-bpm)>.0001:out.append([q,bpm])
 return out

def performance(job_id):
 p=WORK/'scores'/job_id;ma,aa=timeline(p/'original.mid');mb,bb=timeline(p/'synthesizer.mid');expected={}
 native_original_end=max(t['end'] for t in ma['tracks']);cycles=read_json(p/'config.json',{}).get('original_performance_cycles',1)
 if cycles>1:
  # The printed score shows stanza rows once; Synthesizer develops each row.
  # Compare each developed cycle with the same complete printed performance.
  aa=[(q+F(str(native_original_end))*i,pitches) for i in range(cycles) for q,pitches in aa]
  ma['tempos']=[(q+native_original_end*i,bpm) for i in range(cycles) for q,bpm in ma['tempos']]
 a=dict(aa);b=dict(bb)
 for event in read_json(p/'articulation-review.json',[]):expected.setdefault(F(event['absolute']),set()).add(event['pitch'])
 omissions={}
 for event in read_json(p/'verse-activity-review.json',[]):omissions.setdefault(F(event['absolute']),set()).add(event['pitch'])
 issues=[];accepted=[];accepted_omissions=[]
 for q in sorted(set(a)|set(b)):
  removed=set(a.get(q,()))-set(b.get(q,()));added=set(b.get(q,()))-set(a.get(q,()))
  if removed or added:
   if removed<=omissions.get(q,set()) and added<=expected.get(q,set()):
    if added:accepted.append(dict(onset=str(q),new_attacks=sorted(added),reason='new written syllable on printed tie'))
    if removed:accepted_omissions.append(dict(onset=str(q),pitches=sorted(removed),reason='printed stanza-only notes'))
   else:issues.append(dict(onset=str(q),only_original=sorted(removed),only_synthesizer=sorted(added)))
 ends=[max(t['end'] for t in m['tracks']) for m in [ma,mb]]
 ends[0]*=cycles
 if abs(ends[0]-ends[1])>.00001:issues.append(dict(duration_difference=ends))
 # MuseScore can emit a same-value tempo reset at a repeat boundary.
 # Compare the sounding tempo function, not redundant MIDI meta events.
 ta,tb=canonical_tempos(ma['tempos']),canonical_tempos(mb['tempos'])
 tick_tolerance=read_json(p/'config.json',{}).get('tempo_tick_tolerance',0)/480
 if tick_tolerance:
  ta=[x for x in ta if x[0]<ends[0]-tick_tolerance-.000001]
  tb=[x for x in tb if x[0]<ends[1]-tick_tolerance-.000001]
 tempo_offsets=[dict(original=x[0],synthesizer=y[0],quarters=y[0]-x[0]) for x,y in zip(ta,tb) if abs(x[0]-y[0])>.00001]
 if len(ta)!=len(tb) or any(abs(x[0]-y[0])>max(.00001,tick_tolerance+.000001) or abs(x[1]-y[1])>.0001 for x,y in zip(ta,tb)):issues.append(dict(tempo_difference=[ta,tb]))
 report=dict(passed=not issues,quarters=ends,accepted_rearticulations=accepted,accepted_verse_omissions=accepted_omissions,accepted_tempo_tick_offsets=tempo_offsets if not any('tempo_difference' in x for x in issues) else [],issues=issues);save_json(p/'performance-validation.json',report);print(job_id,'PERFORMANCE',report['passed'],'quarters',ends,'reviewed articulations',len(accepted))
 if issues:raise RuntimeError('Performance differs; inspect '+str(p/'performance-validation.json'))
 return report
