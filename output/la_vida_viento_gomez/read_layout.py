from pathlib import Path
import pdfplumber,json,sys,collections,xml.etree.ElementTree as E
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
OUT=Path(__file__).resolve().parent
LAYOUT=[[1,8,14,20,25],[30,36,42,47,52],[57,62,67,72],[77,82,88,93,98]]
parts=parse(E.parse(OUT/'source.musicxml').getroot())
systems=[];heads=[];chars=[]
with pdfplumber.open(OUT/'eaeafa56-1d25-4517-b13f-1b3f7f6beced.pdf') as pdf:
 for pi,page in enumerate(pdf.pages,1):
  page=page.dedupe_chars(tolerance=.1);H=page.height
  ys=sorted({round(e['top'],3) for e in page.lines if e['height']<.15 and e['width']>150})
  staves=[]
  for y in ys:
   if staves and y<=staves[-1][-1]+1:continue
   g=[min(ys,key=lambda v:abs(v-y-4.224*j)) for j in range(5)]
   if all(abs(v-y-4.224*j)<.18 for j,v in enumerate(g)):staves.append(g)
  assert len(staves)==2*len(LAYOUT[pi-1]),(pi,staves)
  for si,first in enumerate(LAYOUT[pi-1]):
   pair=staves[si*2:si*2+2];last=LAYOUT[pi-1][si+1]-1 if si+1<len(LAYOUT[pi-1]) else LAYOUT[pi][0]-1 if pi<4 else 102
   first=first+(first>=20);last=last+(last>=19)
   bars=sorted({round(l['x0'],3) for l in page.lines if l['width']<.15 and abs(l['top']-pair[0][0])<.3 and abs(l['bottom']-pair[0][-1])<.3})
   hs=[l for l in page.lines if l['width']>150 and abs(l['top']-pair[0][0])<.3]
   bars=sorted({min(l['x0'] for l in hs),*bars,max(l['x1'] for l in hs)})
   bars=[x for i,x in enumerate(bars) if i==0 or x-bars[i-1]>4]
   assert len(bars)-1==last-first+1,(pi,si,first,last,bars)
   systems.append(dict(page=pi,system=si,first=first,last=last,bars=bars,staves=pair))
   for staffi,staff in enumerate(pair):
    music=[c for c in page.chars if 'Opus' in c['fontname'] and c['text'] in ['\uf0cf','\uf0fa'] and min(range(len(staves)),key=lambda k:abs(H-c['matrix'][5]-sum(staves[k])/5))==si*2+staffi]
    scopes=collections.defaultdict(dict)
    for c in sorted(music,key=lambda c:c['x0']):
     x=c['x0'];y=H-c['matrix'][5];m=first+sum(b<x+1 for b in bars)-1
     dia=(30 if staffi==0 else 18)+round((staff[-1]-y)/2.112)
     step='CDEFGAB'[dia%7];alter=(1 if step in 'FC' else 0) if m<19 else (-1 if step in 'BEA' else 0)
     accidentals=[cc for cc in page.chars if cc['text'] in ['\uf023','\uf062','\uf06e'] and 'Opus' in cc['fontname'] and 1<x-cc['x0']<12 and abs(H-cc['matrix'][5]-y)<.4]
     if accidentals:
      a=min(accidentals,key=lambda cc:x-cc['x0']);alter={'\uf023':1,'\uf062':-1,'\uf06e':0}[a['text']];scopes[m][dia]=alter
     else:alter=scopes[m].get(dia,alter)
     pitch=(dia//7+1)*12+[0,2,4,5,7,9,11][dia%7]+alter
     heads.append(dict(page=pi,system=si,staff=staffi,measure=m,x=x,y=y,pitch=pitch,glyph=c['text']))
    lo=staff[-1]+4;hi=pair[1][0]-5 if staffi==0 else (staves[si*2+2][0]-15 if si*2+2<len(staves) else 748)
    for c in page.chars:
     if c['fontname'] in ['Times-Roman','Times-Italic'] and 9<c['size']<11 and lo<c['top']<hi:
      chars.append(dict(page=pi,system=si,staff=staffi,text=c['text'],x0=c['x0'],x1=c['x1'],top=c['top']))
(OUT/'layout.json').write_text(json.dumps(dict(systems=systems,heads=heads,chars=chars),ensure_ascii=False,indent=2),encoding='utf-8')
print('systems',len(systems),'heads',len(heads),'lyricchars',len(chars))

