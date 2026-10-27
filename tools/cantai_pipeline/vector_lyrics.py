"""Map literal vector lyric runs to printed notes, preserving an audit trail.

No language model text or reference MIDI supplies the words. Explicit row/verse
ownership is reviewed separately; close runs on one note retain their elision.
"""
from fractions import Fraction as F
import unicodedata,collections

def normalized(s):
 return ''.join(c.casefold() for c in unicodedata.normalize('NFKD',s) if c.isalpha() and not unicodedata.combining(c))

def align(reading,lines,specs):
 lyrics=[];audit=[];previous={};ownership={}
 for spec in specs:
  index=spec['line'];line=lines[index];sy=next(s for s in reading['systems'] if s['page']==line['page'] and s['system']==line['system']);scale=(sy['staves'][0][-1]-sy['staves'][0][0])/4/4.9603
  cs=[dict(c,text=unicodedata.normalize('NFKC',c['text'])) for c in line['chars']];runs=[];dashes=[];last=None;current=[]
  def flush():
   if current:runs.append(dict(text=''.join(c['text'] for c in current),left=current[0]['x0'],right=current[-1]['x1']));current.clear()
  for ch in cs:
   if ch['text'] in ['-','–','—']:
    flush();dashes.append((ch['x0']+ch['x1'])/2);last=None;continue
   if ch['text'].isspace():flush();last=None;continue
   if last is not None and ch['x0']-last>spec.get('run_gap',.8)*scale:flush()
   current.append(ch);last=ch['x1']
  flush();runs=[a for a in runs if any(ch.isalpha() for ch in a['text'])]
  forced=spec.get('role');pool=spec.get('pool',list(range(4)))
  candidates=[e for e in reading['events'] if not e['rest'] and line['first']<=e['measure']<=line['last'] and (e['role']==forced if forced is not None else e['role'] in pool)]
  assert candidates,(index,'no lyric notes')
  selected=[];parenthetical=False
  for run in runs:
   centre=(run['left']+run['right'])/2
   if '(' in run['text']:parenthetical=True
   active=candidates
   if forced is None and len(sy['staves'])==2:
    upper=[e for e in active if e['role'] in [0,1]]
    if upper and min(abs(e['x']+3.3*scale-centre)/scale for e in upper)<7:active=upper
   if forced is None and parenthetical and len(sy['staves'])==2:
    alto=[e for e in active if e['role']==1]
    if alto and min(abs(e['x']+3.3*scale-centre)/scale for e in alto)<7:active=alto
   e=min(active,key=lambda e:(round(abs(e['x']+3.3*scale-centre)/scale,2),e['role']))
   distance=abs(e['x']+3.3*scale-centre)/scale
   same_note=selected and (selected[-1]['id']==e['id'] or forced is None and selected[-1]['event']['measure']==e['measure'] and selected[-1]['event']['onset']==e['onset'] and selected[-1]['event'].get('staff')==e.get('staff') and selected[-1]['parenthetical']==parenthetical)
   if same_note:
    old=selected[-1];dash=any(old['right']<x<run['left'] for x in dashes);old['text']+=('-' if dash else '_')+run['text'];old['right']=run['right'];old['distance']=max(old['distance'],distance)
   else:selected.append(dict(run,id=e['id'],event=e,distance=distance,parenthetical=parenthetical))
   if ')' in run['text']:parenthetical=False
  series=(spec.get('series',forced if forced is not None else 'main'),spec['verse'])
  for pos,a in enumerate(selected):
   e=a['event'];verse=spec['verse']
   a['distance']=abs(e['x']+3.3*scale-(a['left']+a['right'])/2)/scale
   assert a['distance']<21,(index,a['text'],a['distance'],e['id'])
   for change in spec.get('verse_regions',[]):
    if e['measure']>change['first'] or e['measure']==change['first'] and F(e['onset'])>=F(str(change.get('from_onset',0))):verse=change['verse']
   left=selected[pos-1]['right'] if pos else -float('inf');right=selected[pos+1]['left'] if pos+1<len(selected) else float('inf')
   before=any(left<x<a['left'] for x in dashes) if pos else previous.get(series,False)
   after=any(a['right']<x<right for x in dashes)
   state='middle' if before and after else 'end' if before else 'begin' if after else 'single'
   shared=spec.get('shared',forced is None) and not a['parenthetical']
   if index in ownership:assert ownership[index]==series
   ownership[index]=series
   mirrors=list(spec.get('mirrors',[]))
   if spec.get('physical_pair'):
    other=e['role']^1
    if any(z['role']==other and z['measure']==e['measure'] and z['onset']==e['onset'] and z['duration']==e['duration'] for z in candidates):mirrors.append(other)
   if forced is None and (a['parenthetical'] or spec.get('physical_pair')) and e['role']==2 and any(z['role']==3 and z['measure']==e['measure'] and z['onset']==e['onset'] and z['duration']==e['duration'] for z in candidates):mirrors.append(3)
   record=dict(role=e['role'],bar=e['measure'],onset=e['onset'],verse=verse,text=a['text'],state=state,shared=shared,line=index,mirrors=mirrors)
   lyrics.append(record)
   if e['measure']>spec.get('copy_first_bar',0) or e['measure']==spec.get('copy_first_bar',0) and F(e['onset'])>=F(str(spec.get('copy_first_onset',0))):
    for otherverse in spec.get('copy_to_verses',[]):lyrics.append(dict(record,verse=otherverse,printed=False))
   audit.append(dict(line=index,event=e['id'],literal=a['text'],x0=a['left'],x1=a['right'],distance=a['distance'],role=e['role'],verse=verse))
  previous[series]=after if selected else previous.get(series,False)
  # This independently checks every source letter, including elided words.
  assert normalized(line['text'])==normalized(''.join(a['text'] for a in selected)),(index,'source letters changed')
 return dict(lyrics=lyrics,geometry=audit)
