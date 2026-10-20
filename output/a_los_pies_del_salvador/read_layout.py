from pathlib import Path
import pdfplumber,json,collections
OUT=Path(__file__).resolve().parent
ROLES=[[[0],[1],[2,3]]*3,[[0,1],[2,3]]*4,[[0,1],[2,3]]*4,[[0,1],[2],[3]]+[[0,1],[2,3]]*3]
SIZES=[[3,3,3],[2,2,2,2],[2,2,2,2],[3,2,2,2]]
systems=[];heads=[];chars=[];curves=[];first=1
with pdfplumber.open(OUT/'original.pdf') as pdf:
 for pi,page in enumerate(pdf.pages,1):
  page=page.dedupe_chars(tolerance=.1);H=page.height
  ys=sorted({round(e['top'],3) for e in page.lines if e['height']<.1 and e['width']>150});staves=[]
  for y in ys:
   if staves and y<=staves[-1][-1]+1:continue
   g=[min(ys,key=lambda v:abs(v-y-4.6065*j)) for j in range(5)]
   if all(abs(v-y-4.6065*j)<.15 for j,v in enumerate(g)):staves.append(g)
  assert len(staves)==sum(SIZES[pi-1]),(pi,staves)
  offset=0
  for si,size in enumerate(SIZES[pi-1]):
   pair=staves[offset:offset+size];roles=ROLES[pi-1][offset:offset+size]
   bars=sorted({round(l['x0'],3) for l in page.lines if l['width']<.1 and abs(l['top']-pair[0][0])<.3 and abs(l['bottom']-pair[0][-1])<.3})
   hs=[l for l in page.lines if l['width']>150 and abs(l['top']-pair[0][0])<.3]
   bars=sorted({min(l['x0'] for l in hs),*bars,max(l['x1'] for l in hs)});bars=[x for i,x in enumerate(bars) if i==0 or x-bars[i-1]>4]
   if pi==2 and si==0:bars.pop(0)
   last=first+len(bars)-2
   systems.append(dict(page=pi,system=si,first=first,last=last,bars=bars,staves=pair,roles=roles))
   print(pi,si,first,last,bars)
   for staffi,staff in enumerate(pair):
    musical=[c for c in page.chars if c['fontname'].endswith('+OpusStd') and c['text'] in ['œ','˙','w'] and min(range(len(staves)),key=lambda k:abs(H-c['matrix'][5]-sum(staves[k])/5))==offset+staffi]
    scopes=collections.defaultdict(dict)
    for c in sorted(musical,key=lambda c:c['x0']):
     x=c['x0'];y=H-c['matrix'][5];m=first+sum(b<x+1 for b in bars)-1
     base=18 if roles[staffi] in [[2,3],[3]] else 23 if roles[staffi]==[2] else 30
     dia=base+round((staff[-1]-y)/2.30325);step='CDEFGAB'[dia%7];alter=-1 if step in 'BEADGC' else 0
     acc=[cc for cc in page.chars if cc['fontname'].endswith('+OpusStd') and cc['text'] in ['#','b','n'] and 1<x-cc['x0']<13 and abs(H-cc['matrix'][5]-y)<.4]
     if acc:
      a=min(acc,key=lambda cc:x-cc['x0']);alter={'#':1,'b':-1,'n':0}[a['text']];scopes[m][dia]=alter
     else:alter=scopes[m].get(dia,alter)
     pitch=(dia//7+1)*12+[0,2,4,5,7,9,11][dia%7]+alter
     heads.append(dict(page=pi,system=si,staff=staffi,roles=roles[staffi],measure=m,x=x,y=y,pitch=pitch,glyph=c['text']))
    lo=staff[-1]+3;hi=(staves[offset+staffi+1][0]-5 if offset+staffi+1<len(staves) else 813)
    for c in page.chars:
     if 'AGaramondPro' in c['fontname'] and c['size']>9 and lo<c['top']<hi:chars.append(dict(page=pi,system=si,staff=staffi,text=c['text'],x0=c['x0'],x1=c['x1'],top=c['top'],font=c['fontname'],size=c['size']))
   offset+=size;first=last+1
  for c in page.curves:
   if any(pt[0]=='c' for pt in c['path']) and c['x1']-c['x0']>3:
    curves.append(dict(page=pi,path=c['path']))
(OUT/'layout.json').write_text(json.dumps(dict(systems=systems,heads=heads,chars=chars,curves=curves),ensure_ascii=False,indent=2),encoding='utf-8')
print('bars',first-1,'heads',len(heads))

