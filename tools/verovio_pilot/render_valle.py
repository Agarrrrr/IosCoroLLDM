from pathlib import Path
import os,subprocess,json,sys,xml.etree.ElementTree as E

base=Path('output/verovio_pilot_support/valle').resolve()
source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else base/'Valle de los Huesos Secos - SATB con letra.musicxml'
render=base/('render-pdf-reviewed' if len(sys.argv)>1 else 'render');render.mkdir(exist_ok=True)
env=os.environ.copy();env.pop('QT_QPA_PLATFORM',None)
env['QT_QUICK_BACKEND']='software'
binary='C:/Program Files/MuseScore 4/bin/MuseScore4.exe'
for target in [render/'check.musicxml',render/'preview.png']:
    result=subprocess.run([binary,'-r','96','-o',str(target),str(source)],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
    (render/(target.stem+'-log.txt')).write_text(result.stdout+'\n'+result.stderr,encoding='utf-8')
    print(target.name,result.returncode,result.stderr[-1000:])
    assert result.returncode==0
root=E.parse(render/'check.musicxml').getroot()
original=E.parse(source).getroot()
report=dict(parts=len(root.findall('part')),measures=[len(p.findall('measure')) for p in root.findall('part')],notes=len(root.findall('.//pitch')),lyrics=len(root.findall('.//lyric')),ties=len(root.findall('.//tie')),slurs=len(root.findall('.//slur')),pngPages=len(list(render.glob('preview-*.png'))))
assert report['parts']==4 and report['measures']==[148]*4
assert report['notes']==2451 and report['ties']==108 and report['slurs']==2,report
assert report['lyrics']==len(original.findall('.//lyric'))
def bass_rhythm(score):
    result={};div=1
    for i,m in enumerate(score.findall('part')[3].findall('measure'),1):
        div=int(m.findtext('attributes/divisions',str(div)))
        result[i]=[('N' if n.find('pitch') is not None else 'R',int(n.findtext('duration'))/div) for n in m.findall('note')]
    return result
assert bass_rhythm(root)==bass_rhythm(original),'Bass rhythm must survive MuseScore import/export'
(render/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
