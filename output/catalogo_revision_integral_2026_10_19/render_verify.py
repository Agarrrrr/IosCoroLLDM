from pathlib import Path
import json,sys,collections,xml.etree.ElementTree as E,zipfile,hashlib
from PIL import Image,ImageDraw
from build_final_scores import run,OUT
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
rows=json.loads((OUT/'inventory.json').read_text(encoding='utf8'))
selected=set(map(int,sys.argv[1:])) if len(sys.argv)>1 else {r['index'] for r in rows if r.get('changed')}
report=[]
def canonical(root):
 return [[(b+1,round(float(e['onset']),4),round(float(e['duration']),4),e['pitch'],tuple(t.get('type') for t in e['node'].findall('tie'))) for b,m in enumerate(p) for e in m['events'] if e['pitch'] is not None] for p in parse(root)]
def lyrics(root):
 result=[]
 for pi,p in enumerate(parse(root)):
  for b,m in enumerate(p,1):
   for e in m['events']:
    for ly in e['node'].findall('lyric'):
     value=''.join(t.text or '' for t in ly.findall('text')).replace('\ue550','‿').replace('\ue551','‿').replace('\ue552','‿')
     if value:result.append((pi,b,round(float(e['onset']),4),int(ly.get('number','1')),value))
 return sorted(result)
for r in rows:
 if r['index'] not in selected:continue
 p=Path(r['work']);print('VERIFY',r['index'],flush=True)
 final=p/'final.mscz';assert final.exists()
 run(['-o',p/'reopened.musicxml',final]);run(['-o',p/'playback.mid',final]);run(['-r','90','-o',p/'preview.png',final])
 expected=E.parse(p/'corrected.musicxml').getroot();actual=E.parse(p/'reopened.musicxml').getroot();issues=[]
 if canonical(expected)!=canonical(actual):issues.append('Music XML round trip changed note events')
 if lyrics(expected)!=lyrics(actual):
  ee=collections.Counter(lyrics(expected));aa=collections.Counter(lyrics(actual));issues.append(dict(lyricMissing=list((ee-aa).elements())[:10],lyricExtra=list((aa-ee).elements())[:10]))
 if collections.Counter(c.tag for d in expected.findall('.//dynamics') for c in d)!=collections.Counter(c.tag for d in actual.findall('.//dynamics') for c in d):issues.append('Dynamics changed')
 if len(actual.findall('part'))!= (5 if r['index'] in [6,10] else 4):issues.append('Staff count')
 with zipfile.ZipFile(final) as z:assert z.testzip() is None
 images=sorted(p.glob('preview-*.png'),key=lambda f:int(f.stem.split('-')[-1]));sheet=Image.new('RGB',(1200,580*((len(images)+2)//3)),'#ddd');draw=ImageDraw.Draw(sheet)
 for j,f in enumerate(images):
  im=Image.open(f).convert('RGB');im.thumbnail((390,550));x=j%3*400;y=j//3*580;sheet.paste(im,(x,y+25));draw.text((x+5,y+5),str(j+1),fill='black')
 sheet.save(p/'contact-final.png')
 record=dict(index=r['index'],name=r['name'],issues=issues,pages=len(images),sha256=hashlib.sha256(final.read_bytes()).hexdigest(),staves=len(actual.findall('part')),bars=len(actual.findall('part')[0].findall('measure')),lyrics=len(lyrics(actual)))
 report.append(record);(OUT/'final-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
 print('PASS' if not issues else 'FAIL',r['index'],len(images),'pages',str(issues)[:1200],flush=True)
