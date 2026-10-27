"""Independent staff/bar grid for scanned pages, with a visual review overlay."""
from pathlib import Path
import numpy as np,pdfplumber
from PIL import ImageDraw
from common import WORK,save_json

def clusters(values,gap=2):
 out=[]
 for v in values:
  if not out or v-out[-1][-1]>gap:out.append([int(v)])
  else:out[-1].append(int(v))
 return [sum(g)/len(g) for g in out]

def raster_grid(job_id):
 p=WORK/'scores'/job_id;result=[];bar=1
 with pdfplumber.open(p/'original.pdf') as pdf:
  for pi,page in enumerate(pdf.pages,1):
   im=page.to_image(resolution=3508*72/max(page.width,page.height)).original.convert('RGB');gray=np.array(im.convert('L'));dark=gray<170;h,w=dark.shape
   ys=clusters(np.flatnonzero(dark[:,int(w*.04):int(w*.97)].mean(axis=1)>.45));staves=[]
   for i,y in enumerate(ys):
    if staves and y<=staves[-1][-1]+2:continue
    g=ys[i:i+5]
    if len(g)==5 and 5<g[1]-g[0]<45 and max(g[j+1]-g[j] for j in range(4))-min(g[j+1]-g[j] for j in range(4))<2:staves.append(g)
   if len(staves)%2:raise ValueError((job_id,pi,'Odd raster staff count',len(staves)))
   draw=ImageDraw.Draw(im)
   for sy in range(len(staves)//2):
    pair=staves[sy*2:sy*2+2];staff=pair[0];spacing=(staff[-1]-staff[0])/4;row=dark[int(round(staff[2]))];xx=np.flatnonzero(row)
    left=max(0,int(w*.045));right=int(w*.965);candidates=[]
    for st in pair:
     coverage=dark[int(round(st[0])):int(round(st[-1]))+1,left:right].mean(axis=0);candidates.append(clusters(np.flatnonzero(coverage>.85)+left,gap=2))
    bars=clusters(sorted({round(x) for x in candidates[0] if any(abs(x-z)<3 for z in candidates[1])}),gap=spacing*.8)
    if bars:bars=[bars[0]]+[x for x in bars[1:] if x-bars[0]>12*spacing]
    if len(bars)<2:raise ValueError((job_id,pi,sy,'No reliable shared barlines'))
    result.append(dict(page=pi,system=sy,first=bar,last=bar+len(bars)-2,bars=bars,staves=pair,width=w,height=h));bar+=len(bars)-1
    for x in bars:draw.line((int(x),int(pair[0][0])-12,int(x),int(pair[-1][-1])+12),fill='red',width=2)
    draw.text((int(bars[0])+4,int(pair[0][0])-30),f"{result[-1]['first']}-{result[-1]['last']}",fill='red')
   im.save(p/f'raster-grid-{pi}.png')
 save_json(p/'raster-systems.json',result);print(job_id,'RASTER GRID',[(s['page'],s['first'],s['last']) for s in result]);return result
