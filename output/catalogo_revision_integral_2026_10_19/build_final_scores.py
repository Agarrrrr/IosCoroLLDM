from pathlib import Path
from fractions import Fraction as F
import xml.etree.ElementTree as E,zipfile,copy,json,subprocess,os,hashlib,sys,time
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
OUT=Path(__file__).resolve().parent
MS='C:/Program Files/MuseScore 4/bin/MuseScore4.exe'
ENV=dict(os.environ,QT_QUICK_BACKEND='software');ENV.pop('QT_QPA_PLATFORM',None)
def run(args):
 p=subprocess.run([MS]+list(map(str,args)),env=ENV,capture_output=True,timeout=180)
 if p.returncode:raise RuntimeError((p.returncode,p.stdout.decode(errors='replace')[-1000:],p.stderr.decode(errors='replace')[-1000:]))
def pitch(n):
 p=n.find('pitch');return (int(p.findtext('octave'))+1)*12+{'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[p.findtext('step')]+int(p.findtext('alter','0'))
def chords(m):
 result=[]
 for n in m.findall('note'):
  if n.find('pitch') is None:continue
  if n.find('chord') is None:result.append([n])
  else:result[-1].append(n)
 return result
def music_signature(root):
 result=[]
 for p in root.findall('part'):
  for m in p.findall('measure'):
   for n in m.findall('note'):
    x=copy.deepcopy(n)
    for ly in x.findall('lyric'):x.remove(ly)
    result.append(E.tostring(x))
 return result
def native_patch(r):
 folder=Path(r['work']);source=E.parse(folder/'source.musicxml').getroot();target=E.parse(folder/'corrected.musicxml').getroot()
 assert music_signature(source)==music_signature(target),f"Music changed in lyric-only revision {r['index']}"
 with zipfile.ZipFile(folder/'original.mscz') as z:files={n:z.read(n) for n in z.namelist()}
 main=next(n for n in files if n.endswith('.mscx'));native=E.fromstring(files[main]);before=copy.deepcopy(native)
 staff=native.find('Score').findall('Staff');model=parse(target);total=0
 assert len(staff)==len(target.findall('part'))
 for pi,(s,p) in enumerate(zip(staff,target.findall('part'))):
  measures=s.findall('Measure');assert len(measures)==len(p.findall('measure'))
  timeline=[]
  for bi,(nm,xm) in enumerate(zip(measures,p.findall('measure'))):
   nc=nm.findall('./voice/Chord');xc=chords(xm);assert len(nc)==len(xc),(r['index'],pi,bi,len(nc),len(xc))
   events=[e for e in model[pi][bi]['events'] if e['pitch'] is not None and e['node'].find('chord') is None]
   assert len(events)==len(nc)
   for c,ns,e in zip(nc,xc,events):
    assert sorted(int(n.findtext('pitch')) for n in c.findall('Note'))==sorted(pitch(n) for n in ns),(r['index'],pi,bi)
    old=c.findall('Lyrics');by_no={int(l.findtext('no','0')):l for l in old}
    for l in old:c.remove(l)
    for ly in ns[0].findall('lyric'):
     value=''.join(t.text or '' for t in ly.findall('text'))
     if not value:continue
     no=int(ly.get('number','1'))-1;new=copy.deepcopy(by_no.get(no,old[0] if old else E.Element('Lyrics')))
     for child in list(new):
      if child.tag in ['eid','text','syllabic','ticks','ticks_f','no']:new.remove(child)
     if no:E.SubElement(new,'no').text=str(no)
     kind=ly.findtext('syllabic','single')
     if kind!='single':E.SubElement(new,'syllabic').text=kind
     E.SubElement(new,'text').text=value.replace('‿','\ue550')
     c.insert(next((j for j,v in enumerate(c) if v.tag=='Note'),len(c)),new);total+=1
    timeline.append((e['absolute'],e['duration'],c,e['voice']))
  # Rebuild melismas from actual later attacks, stopping at a rest or a new
  # lyric. Never retain an extender across an inserted syllable.
  for j,(on,dur,c,voice) in enumerate(timeline):
   for ly in c.findall('Lyrics'):
    no=ly.findtext('no','0');end=on+dur;more=False
    for on2,dur2,c2,v2 in timeline[j+1:]:
     if v2!=voice:continue
     if on2>end or any(l.findtext('no','0')==no for l in c2.findall('Lyrics')):break
     if on2<end:continue
     more=True;end=on2+dur2
    if more:E.SubElement(ly,'ticks_f').text=str((end-on)/4)
 populated=E.tostring(native,encoding='utf-8',xml_declaration=True)
 # Proof: every non-lyric element in the saved native score is identical.
 for doc in [native,before]:
  for c in doc.findall('.//Chord'):
   for l in list(c.findall('Lyrics')):c.remove(l)
 assert E.tostring(native)==E.tostring(before)
 files[main]=populated
 with zipfile.ZipFile(folder/'final.mscz','w',zipfile.ZIP_DEFLATED) as z:
  for n,data in files.items():z.writestr(n,data)
 return total

def patch_file(r):
 # Keep verification copies separate from the populated tree.
 pass

if __name__=='__main__':
 rows=json.loads((OUT/'inventory.json').read_text(encoding='utf8'))
 selected=set(map(int,sys.argv[1:])) if len(sys.argv)>1 else {r['index'] for r in rows if r.get('changed')}
 for r in rows:
  if r['index'] not in selected:continue
  p=Path(r['work']);print('BUILD',r['index'],r['name'],flush=True)
  if r.get('structural'):
   style=p/'original.mss'
   if r['index'] in [30,31]:style=Path('output/satb_lote_2026_10_19/choral.mss')
   run(['-S',style,'-o',p/'final.mscz',p/'corrected.musicxml'])
  else:native_patch(r)
  print('SAVED',r['index'],flush=True)
