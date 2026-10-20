from pathlib import Path
import pdfplumber,json,sys,collections
sys.path.insert(0,'output/salmo_135')
from read_pdf import beam_y
OUT=Path('output/amado_salvador')
LAYOUT=[[1,5,9],[13,18,22,26]]
events=[];systems=[]
with pdfplumber.open(OUT/'original.pdf') as pdf:
 for pi,page in enumerate(pdf.pages,1):
  page=page.dedupe_chars(tolerance=.1);H=page.height
  ys=sorted({round(e['top'],3) for e in page.lines if e['height']<.1 and e['width']>150})
  staves=[]
  for y in ys:
   if staves and y<=staves[-1][-1]+1:continue
   g=[min(ys,key=lambda v:abs(v-y-4.46433*j)) for j in range(5)]
   if all(abs(v-y-4.46433*j)<.15 for j,v in enumerate(g)):staves.append(g)
  assert len(staves)==2*len(LAYOUT[pi-1])
  for si,first in enumerate(LAYOUT[pi-1]):
   pair=staves[si*2:si*2+2];last=LAYOUT[pi-1][si+1]-1 if si+1<len(LAYOUT[pi-1]) else 12 if pi==1 else 30
   bars=sorted({round(l['x0'],3) for l in page.lines if l['width']<.01 and abs(l['top']-pair[0][0])<.1 and abs(l['bottom']-pair[0][-1])<.1})
   hs=[l for l in page.lines if l['width']>150 and abs(l['top']-pair[0][0])<.1]
   bars=sorted({min(l['x0'] for l in hs),*bars,max(l['x1'] for l in hs)})
   bars=[x for i,x in enumerate(bars) if i==0 or x-bars[i-1]>4]
   # Page 2 begins the chorus with an extra repeat bar at the system margin.
   if pi==2 and si==1:bars.pop(0)
   assert len(bars)-1==last-first+1,(pi,si,bars,first,last)
   systems.append(dict(page=pi,system=si,first=first,last=last,bars=bars,staves=pair))
   for staffi,staff in enumerate(pair):
    music=[c for c in page.chars if c['fontname'].endswith('+OpusStd') and c['text'] in ['œ','˙','w','Œ','‰','∑'] and min(range(len(staves)),key=lambda k:abs(H-c['matrix'][5]-sum(staves[k])/5))==si*2+staffi]
    beams=[s for s in page.curves if s['fill'] and not any(p[0]=='c' for p in s['path'])]
    beams += [dict(x0=s['x0'],x1=s['x1'],pts=[(s['x0'],s['top']),(s['x1'],s['top']),(s['x1'],s['bottom']),(s['x0'],s['bottom'])]) for s in page.rects if 1.5<s['height']<3.1]
    for c in music:
     x=c['x0'];y=H-c['matrix'][5];m=first+sum(b<x+1 for b in bars)-1
     if not first<=m<=last:continue
     e=dict(page=pi,system=si,staff=staffi,measure=m,x=x,y=y,glyph=c['text'])
     if c['text'] in ['Œ','‰','∑']:
      e['rest']=True;e['duration']={'Œ':1,'‰':.5,'∑':4}[c['text']]
      e['direction']='up' if y<sum(staff)/5-3 else 'down' if y>sum(staff)/5+3 else 'both'
      evs=[e]
     else:
      e['rest']=False;e['diatonic']=(30 if staffi==0 else 18)+round((staff[-1]-y)/2.232165)
      e['alter']=-1 if 'CDEFGAB'[e['diatonic']%7]=='B' else 0
      stems=[l for l in page.lines if l['width']<.01 and l['height']>8 and ((abs(l['x0']-x-6)<.5 and abs(l['bottom']-y)<1.1) or (abs(l['x0']-x-.14)<.5 and abs(l['top']-y)<1.1))]
      stems=list({(round(l['x0'],2),round(l['top'],2),round(l['bottom'],2)):l for l in stems}.values())
      evs=[]
      if c['text']=='w':evs=[dict(e,duration=4,direction='whole')]
      else:
       assert stems,(e,'no stem')
       for stem in stems:
        up=abs(stem['bottom']-y)<1.1;tip=stem['top'] if up else stem['bottom']
        levels=sum((v:=beam_y(s,stem['x0'])) is not None and abs(v-tip)<6 for s in beams)
        flags=[cc for cc in page.chars if cc['text'] in ['j','J'] and cc['fontname'].endswith('+OpusStd') and abs(cc['x0']-stem['x0'])<.7 and abs(H-cc['matrix'][5]-y)<20]
        if flags:levels=max(levels,1)
        d=2 if c['text']=='˙' else 1/2**levels
        evs.append(dict(e,duration=d,direction='up' if up else 'down'))
     for e in evs:
      dots=[cc for cc in page.chars if cc['text'] in ['™','.'] and 'Opus' in cc['fontname'] and 6<cc['x0']-x<14 and abs(H-cc['matrix'][5]-y)<2.4]
      if dots and e['duration']!=4:e['duration']*=1.5;e['dot']=True
      events.append(e)
(OUT/'raw-reading.json').write_text(json.dumps(dict(events=events,systems=systems),ensure_ascii=False,indent=2),encoding='utf-8')
for m in range(1,31):
 print('\nBAR',m)
 for staff in range(2):
  row=sorted([e for e in events if e['measure']==m and e['staff']==staff],key=lambda e:(e['x'],e['y']))
  print('SA' if staff==0 else 'TB', ' | '.join(f"{e['x']:.1f} {'r' if e['rest'] else 'CDEFGAB'[e['diatonic']%7]+str(e['diatonic']//7)}:{e['duration']:g}:{e['direction']}" for e in row))

