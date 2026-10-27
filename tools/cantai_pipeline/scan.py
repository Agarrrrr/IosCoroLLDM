"""Locate vector staves and measures; topology is reviewed source data."""
import json,sys,collections
from pathlib import Path
from common import WORK,save_json,read_json
from pdf_cache import open_geometry

GROUPS={
 'yo_te_seguire':[[2]*4]*3,
 'viene_de_dios':[[1]*8]+[[2]*5]*3,
 'un_grande_honor':[[1,1,2,2,2]],
 'un_banquete_de_amor':[[2]*4]*2,
 'te_alabare':[[2]*3,[2]*4],
 'rey_del_universo':[[2]*3,[2]*4,[2]*3,[4]*2,[4,2,2]],
 'rey_eterno':[[2]*4]*2,
}

def staves(page):
 coverage=collections.defaultdict(float)
 for e in page.lines:
  if abs(e['top']-e['bottom'])<.1 and e['x1']-e['x0']>20:coverage[round(e['top'],3)]+=e['x1']-e['x0']
 ys=sorted(y for y,w in coverage.items() if w>150);out=[]
 for i,y in enumerate(ys):
  if out and y<=out[-1][-1]+1:continue
  g=ys[i:i+5]
  if len(g)==5 and 2<g[1]-g[0]<12 and max(g[j+1]-g[j] for j in range(4))-min(g[j+1]-g[j] for j in range(4))<.25:out.append(g)
 return out

def scan(job_id):
 folder=WORK/'scores'/job_id;groups=GROUPS[job_id];systems=[];bar=1
 with open_geometry(folder/'original.pdf') as pdf:
  for pi,p in enumerate(pdf.pages,1):
   ss=staves(p)
   if len(ss)!=sum(groups[pi-1]):raise ValueError((job_id,pi,'Review topology',len(ss),groups[pi-1]))
   idx=0
   for sy,count in enumerate(groups[pi-1]):
    pair=ss[idx:idx+count];idx+=count;staff=pair[0]
    hs=[e for e in p.lines if abs(e['top']-staff[0])<.15 and e['x1']-e['x0']>20 and abs(e['top']-e['bottom'])<.15];left=min(e['x0'] for e in hs);right=max(e['x1'] for e in hs)
    def full_bar(e):
     if abs(e['x1']-e['x0'])>=.05 or abs(e['top']-staff[0])>=.4:return False
     if abs(e['bottom']-pair[-1][-1])<.4:return True
     if abs(e['bottom']-staff[-1])>=.4:return False
     # A chord stem can span exactly five lines. Require the same divider on
     # every physical staff before treating it as a measure boundary.
     return all(any(abs(z['x0']-e['x0'])<.35 and abs(z['x1']-z['x0'])<.05 and abs(z['top']-st[0])<.4 and abs(z['bottom']-st[-1])<.4 for z in p.lines) for st in pair[1:])
    bb=sorted({left,right,*[round(e['x0'],3) for e in p.lines if full_bar(e)]});bb=[x for j,x in enumerate(bb) if j==0 or x-bb[j-1]>(staff[1]-staff[0])*1.3]
    music=[c for c in p.chars if ('Opus' in c['fontname'] and c['text'] in ['œ','˙','w','Œ','‰','∑','Ó','\uf0cf','\uf0fa','\uf077','\uf0ce','\uf0e4','\uf0b7'] or 'Leland' in c['fontname'] and c['text'] in ['\ue0a4','\ue0a3','\ue0a2','\ue4e3','\ue4e4','\ue4e5','\ue4e6']) and min(ss,key=lambda st:abs(p.height-c['matrix'][5]-sum(st)/5)) in pair]
    while len(bb)>2 and not any(bb[0]<c['x0']<bb[1] for c in music):bb.pop(0)
    while len(bb)>2 and not any(bb[-2]<c['x0']<bb[-1] for c in music):bb.pop()
    systems.append(dict(page=pi,system=sy,first=bar,last=bar+len(bb)-2,bars=bb,staves=pair));bar+=len(bb)-1
 save_json(folder/'systems.json',systems);print(job_id,'MEASURES',bar-1,'SYSTEMS',[(s['page'],s['first'],s['last'],len(s['staves'])) for s in systems])
 return systems
