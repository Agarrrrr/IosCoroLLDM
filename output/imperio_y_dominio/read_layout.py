from pathlib import Path
import pdfplumber,json,collections,sys,xml.etree.ElementTree as E
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
OUT=Path(__file__).resolve().parent
LAYOUT=[[1,4,7],[10,13,15],[17,19,21],[25,28,34],[38,42,46],[50,52,54],[56,59,66],[70,73,76]]
systems=[];heads=[];chars=[];curves=[]
with pdfplumber.open(OUT/'original.pdf') as pdf:
 for pi,page in enumerate(pdf.pages,1):
  page=page.dedupe_chars(tolerance=.1);H=page.height
  ys=sorted({round(e['top'],3) for e in page.lines if e['height']<.1 and e['width']>150});staves=[]
  for y in ys:
   if staves and y<=staves[-1][-1]+1:continue
   g=[min(ys,key=lambda v:abs(v-y-4.9603*j)) for j in range(5)]
   if all(abs(v-y-4.9603*j)<.15 for j,v in enumerate(g)):staves.append(g)
  assert len(staves)==12,(pi,staves)
  for si,first in enumerate(LAYOUT[pi-1]):
   pair=staves[si*4:si*4+4];last=LAYOUT[pi-1][si+1]-1 if si<2 else LAYOUT[pi][0]-1 if pi<8 else 79
   bars=sorted({round(l['x0'],3) for l in page.lines if l['width']<.1 and abs(l['top']-pair[0][0])<.3 and abs(l['bottom']-pair[0][-1])<.3})
   hs=[l for l in page.lines if l['width']>150 and abs(l['top']-pair[0][0])<.3]
   bars=sorted({min(l['x0'] for l in hs),*bars,max(l['x1'] for l in hs)});bars=[x for i,x in enumerate(bars) if i==0 or x-bars[i-1]>4]
   assert len(bars)-1==last-first+1,(pi,si,first,last,bars)
   systems.append(dict(page=pi,system=si,first=first,last=last,bars=bars,staves=pair))
   for role,staff in enumerate(pair):
    musical=[c for c in page.chars if c['fontname'].endswith('+OpusStd') and c['text'] in ['œ','˙','w'] and min(range(len(staves)),key=lambda k:abs(H-c['matrix'][5]-sum(staves[k])/5))==si*4+role]
    scopes=collections.defaultdict(dict)
    for c in sorted(musical,key=lambda c:c['x0']):
     x=c['x0'];y=H-c['matrix'][5];bar=first+sum(b<x+1 for b in bars)-1
     dia=([30,30,23,18][role])+round((staff[-1]-y)/2.48015);step='CDEFGAB'[dia%7];alter=-1 if step in 'BE' else 0
     acc=[cc for cc in page.chars if cc['fontname'].endswith('+OpusStd') and cc['text'] in ['#','b','n'] and 1<x-cc['x0']<13 and abs(H-cc['matrix'][5]-y)<.4]
     if acc:
      a=min(acc,key=lambda cc:x-cc['x0']);alter={'#':1,'b':-1,'n':0}[a['text']];scopes[bar][dia]=alter
     else:alter=scopes[bar].get(dia,alter)
     pitch=(dia//7+1)*12+[0,2,4,5,7,9,11][dia%7]+alter
     heads.append(dict(page=pi,system=si,role=role,measure=bar,x=x,y=y,pitch=pitch,step=step,alter=alter,octave=dia//7,glyph=c['text']))
    lo=staff[-1]+4;hi=staves[si*4+role+1][0]-5 if si*4+role+1<len(staves) else 817
    for c in page.chars:
     if 'TimesNewRomanPSMT' in c['fontname'] and lo<c['top']<hi:chars.append(dict(page=pi,system=si,role=role,text=c['text'],x0=c['x0'],x1=c['x1'],top=c['top'],size=c['size']))
  for c in page.curves:
   if any(pt[0]=='c' for pt in c['path']) and c['x1']-c['x0']>3:curves.append(dict(page=pi,path=c['path']))
data=dict(systems=systems,heads=heads,chars=chars,curves=curves)
(OUT/'layout.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
parts=parse(E.parse(OUT/'source.musicxml').getroot())
for role in range(4):
 for bar in range(1,80):
  expected=collections.Counter(e['pitch'] for e in parts[role][bar-1]['events'] if e['pitch'] is not None)
  actual=collections.Counter(h['pitch'] for h in heads if h['role']==role and h['measure']==bar)
  if actual!=expected:print('mismatch',role,bar,'missingPDF',dict(expected-actual),'extraPDF',dict(actual-expected))
print('heads',len(heads),'lyricchars',len(chars),'fontsizes',collections.Counter(round(c['size'],2) for c in chars))
