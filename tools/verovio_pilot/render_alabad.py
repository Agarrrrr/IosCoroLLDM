from pathlib import Path
import os,subprocess,json,xml.etree.ElementTree as E
OUT=Path('output/verovio_pilot_support/alabad').resolve()
env=os.environ.copy();env.pop('QT_QPA_PLATFORM',None);env['QT_QUICK_BACKEND']='software'
binary='C:/Program Files/MuseScore 4/bin/MuseScore4.exe'
source=OUT/'Alabad a Jehová - SATB revisado contra PDF.musicxml';render=OUT/'render';render.mkdir(exist_ok=True)
for stale in render.glob('preview-*.png'):stale.unlink()
jobs=[([binary,'-S',str(OUT/'choral-spacing.mss'),'-o',str(render/'score.mscz'),str(source)],'styled'),
      ([binary,'-o',str(render/'exported.musicxml'),str(render/'score.mscz')],'export'),
      ([binary,'-o',str(render/'reimport.musicxml'),str(render/'exported.musicxml')],'reimport'),
      ([binary,'-r','110','-o',str(render/'preview.png'),str(render/'score.mscz')],'preview')]
for command,name in jobs:
    p=subprocess.run(command,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
    (render/(name+'.log')).write_text(p.stdout+'\n'+p.stderr,encoding='utf-8')
    print(name,p.returncode,flush=True);assert p.returncode==0
def metrics(file):
    root=E.parse(file).getroot();starts=[];ends=[]
    for p in root.findall('part'):
        for m in p.findall('measure'):
            ns=m.findall('note');width=float(m.get('width','0'))
            if not ns:continue
            if ns[0].find('pitch') is not None and ns[0].get('default-x'):starts.append((p.get('id'),m.get('number'),float(ns[0].get('default-x'))))
            if ns[-1].find('pitch') is not None and ns[-1].get('default-x') and width:ends.append((p.get('id'),m.get('number'),width-float(ns[-1].get('default-x'))-10))
    return dict(notes=len(root.findall('.//pitch')),parts=len(root.findall('part')),measures=[len(p.findall('measure')) for p in root.findall('part')],minimumStartTenths=min(x[2] for x in starts),minimumEndTenths=min(x[2] for x in ends),smallStarts=sorted(starts,key=lambda a:a[2])[:5],smallEnds=sorted(ends,key=lambda a:a[2])[:5])
report={name:metrics(render/(name+'.musicxml')) for name in ['exported','reimport']}
(render/'layout-validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2))
