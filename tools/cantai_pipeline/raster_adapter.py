"""Convert a locally reviewed two-staff OMR proposal into the common score model.

No OMR correction is inferred from MIDI. Reviewed pitch/rhythm replacements and
lyrics are explicit data, so the same engine can be reused for another scan.
"""
import sys,copy,xml.etree.ElementTree as E
from fractions import Fraction as F
from common import REPO,WORK,read_json,save_json
sys.path.insert(0,str(REPO/'output/satb_lote_2026_10_19'))
from score_model import parse

def adapt(job_id):
 p=WORK/'scores'/job_id;c=read_json(p/'config.json');review=read_json(p/'raster-review.json')
 assert review.get('reviewed_against_pdf') is True
 parts=parse(E.parse(p/'omr.musicxml').getroot());assert len(parts)==2
 systems=read_json(p/'raster-systems.json');events=[];directions=[];links=[];slurs=[];fermatas=[];pending_ties={};pending_slurs={}
 for staff,part in enumerate(parts):
  for mi,measure in enumerate(part):
   b=mi+1;sy=next(s for s in systems if s['first']<=b<=s['last']);groups={}
   for e in measure['events']:
    if e['pitch'] is not None:groups.setdefault(e['onset'],[]).append(e)
   for q,group in sorted(groups.items()):
    group=list({(e['pitch'],e['duration']):e for e in group}.values());group.sort(key=lambda e:-e['pitch']);assert len(group)<=2
    for lane in [0,1]:
     src=group[min(lane,len(group)-1)];node=src['node'];pitch=node.find('pitch');ro=staff*2+lane
     e=dict(role=ro,staff=staff,page=sy['page'],system=sy['system'],measure=b,onset=str(q),duration=str(src['duration']),absolute=str((b-1)*4+q),pitch=src['pitch'],rest=False,diatonic=int(pitch.findtext('octave'))*7+'CDEFGAB'.index(pitch.findtext('step')),alter=int(pitch.findtext('alter','0')),dots=len(node.findall('dot')),x=float(node.get('default-x','0')),clef='G' if staff==0 else 'F',ties=[])
     e['_ties']=[x.get('type') for x in node.findall('tie')];e['_slurs']=[x.attrib for x in node.findall('notations/slur')];events.append(e)
   for d in measure['directions']:
    for dyn in d['node'].findall('direction-type/dynamics/*'):
     for ro in [staff*2,staff*2+1]:directions.append(dict(role=ro,bar=b,onset=str(d['onset']),kind='dynamic',value=dyn.tag))
 for patch in review['patches']:
  assert patch.get('reason');ro,b=patch['role'],patch['bar'];source=[e for e in events if e['role']==ro and e['measure']==b]
  if 'notes' in patch:
   template=copy.deepcopy(source[0]);events=[e for e in events if e not in source]
   for q,d,pitch in patch['notes']:
    e=copy.deepcopy(template);e.update(onset=str(F(str(q))),duration=str(F(str(d))),pitch=pitch,_ties=[],_slurs=[]);events.append(e)
  else:
   e=next(e for e in source if F(e['onset'])==F(str(patch['onset'])));e['pitch']=patch['pitch']
 # Recompute spelling and IDs after all reviewed replacements.
 spelling={0:('C',0),1:('C',1),2:('D',0),3:('E',-1),4:('E',0),5:('F',0),6:('F',1),7:('G',0),8:('G',1),9:('A',0),10:('B',-1),11:('B',0)}
 for e in events:
  step,alter=spelling[e['pitch']%12];e.update(diatonic=(e['pitch']//12-1)*7+'CDEFGAB'.index(step),alter=alter,dots=1 if F(e['duration']) in [F(3,2),F(3),F(3,4)] else 0,absolute=str((e['measure']-1)*4+F(e['onset'])),id=f"r{e['role']}-b{e['measure']}-q{e['onset']}-p{e['pitch']}")
 for e in sorted(events,key=lambda e:(e['role'],F(e['absolute']))):
  key=(e['role'],e['pitch'])
  if 'stop' in e['_ties'] and key in pending_ties:links.append((pending_ties[key],e['id']))
  if 'start' in e['_ties']:pending_ties[key]=e['id']
  else:pending_ties.pop(key,None)
  for s in e['_slurs']:
   key=(e['role'],s.get('number','1'))
   if s['type']=='start':pending_slurs[key]=e['id']
   elif s['type']=='stop' and key in pending_slurs:slurs.append((pending_slurs.pop(key),e['id']))
  e.pop('_ties');e.pop('_slurs')
 for s in review.get('slurs',[]):
  aa=[next(e['id'] for e in events if e['role']==s['role'] and e['measure']==s['bar'] and F(e['onset'])==F(str(q))) for q in s['onsets']];slurs.append(aa)
 for ro in range(4):
  for b in range(1,len(parts[0])+1):
   row=sorted([e for e in events if e['role']==ro and e['measure']==b],key=lambda e:F(e['onset']));q=F(0);sy=next(s for s in systems if s['first']<=b<=s['last'])
   for e in row+[dict(onset='4',duration='0')]:
    assert F(e['onset'])>=q,(ro,b,q,e)
    while q<F(e['onset']):
     d=max(x for x in [F(4),F(3),F(2),F(3,2),F(1),F(3,4),F(1,2),F(1,4)] if x<=F(e['onset'])-q);events.append(dict(role=ro,staff=ro//2,page=sy['page'],system=sy['system'],measure=b,rest=True,onset=str(q),duration=str(d),absolute=str((b-1)*4+q),id=f'r{ro}-b{b}-q{q}-rest',ties=[]));q+=d
    q=F(e['onset'])+F(e['duration']);assert q<=4
 lyrics=[];previous={}
 for line,item in enumerate(review['lyrics']):
  ro,b,v,phrase=item[:4];shared=item[4] if len(item)>4 else True;atoms=[]
  for word in phrase.split():
   chunks=word.split('-')
   for j,ch in enumerate(chunks):
    if ch:atoms.append(dict(text=ch,state='single' if len(chunks)==1 else 'begin' if j==0 else 'end' if j==len(chunks)-1 else 'middle'))
  row=sorted([e for e in events if not e['rest'] and e['role']==ro and e['measure']==b],key=lambda e:F(e['onset']));assert len(row)==len(atoms),(ro,b,v,len(row),phrase)
  for e,a in zip(row,atoms):
   series=(ro,v)
   if previous.get(series) in ['begin','middle'] and a['state'] in ['single','begin']:a['state']='end' if a['state']=='single' else 'middle'
   previous[series]=a['state'];lyrics.append(dict(role=ro,bar=b,onset=e['onset'],verse=v,shared=shared,line=line,mirrors=[3] if ro==2 else [],**a))
 model=dict(events=events,heads=[e for e in events if not e['rest']],systems=systems,arcs=[],chars=[],issues=[],connections=links,slurs=slurs,fermatas=fermatas,fermata_types={},hairpins=[],directions=directions,starts={str(b):str((b-1)*4) for b in range(1,29)},refmap={})
 if 'directions' in review:model['directions']=review['directions']
 save_json(p/'base-model.json',model);save_json(p/'reading.json',model);save_json(p/'lyric-review.json',dict(lyrics=lyrics,geometry=[]));print(job_id,'REVIEWED RASTER',len(events),'events',len(lyrics),'syllables')

if __name__=='__main__':adapt(sys.argv[1])
