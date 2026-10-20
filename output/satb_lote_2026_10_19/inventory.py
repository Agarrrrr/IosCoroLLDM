import sys,json,zipfile,collections,xml.etree.ElementTree as E
from pathlib import Path
sys.stdout.reconfigure(encoding='utf8')
BASE=Path('E:/Respaldo/musescoreactual');OUT=Path(__file__).resolve().parent
TARGETS=['A Dónde Iré SATB','Al Gran Señor (Adoración)','Ángel Poderoso','Apocalipsis 10_2','En su Corazón VOCES','firmes y adelante desenrrollada','glory_unto_jesus_christ','Guerrero Celestial','Jehova es mi Pastor Voces','LA RESTAURACION','PARA SIEMPRE ES SU MISERICORDIA','Restauración','Santo Varón','Al huerto van J.( santa Cena )_2','El aliento de mi ser J.','Es Dios (Ensamble)','Imaginate Tú','Imaginate Túsatb','La Fiesta Universal (closed)','La Vida Se Va Como El Viento (reducción)','Mi Padre en la Fe','Nardo, Justicia y Gloria ']
def load(path):
    if path.suffix in ['.mscz','.mxl']:
        with zipfile.ZipFile(path) as z:
            name=next(n for n in z.namelist() if n.endswith('.mscx')) if path.suffix=='.mscz' else E.fromstring(z.read('META-INF/container.xml')).find('.//rootfile').get('full-path')
            return E.fromstring(z.read(name))
    return E.parse(path).getroot()
def run():
    files=[p for p in BASE.rglob('*') if p.is_file() and p.suffix in ['.mscz','.xml','.mxl']];records=[]
    for i,title in enumerate(TARGETS,1):
        choices=[p for p in files if p.name in [title+'.mscz',title+'.musicxml.xml',title+'.mxl']];assert choices,title
        src=next((p for p in choices if p.suffix=='.mscz'),choices[0]);work=OUT/f'{i:02d}';work.mkdir(exist_ok=True)
        root=load(src)
        if src.suffix=='.mscz':
            score=root.find('Score');parts=[dict(name=p.findtext('trackName'),staffs=len(p.findall('Staff')),instruments=[x.findtext('longName') for x in p.findall('Instrument')]) for p in score.findall('Part')];st=score.findall('Staff')
            summary=dict(parts=parts,staves=len(st),bars=[len(s.findall('Measure')) for s in st],notes=len(root.findall('.//Note')),lyrics=len(root.findall('.//Lyrics')),dynamics=dict(collections.Counter(x.findtext('subtype') for x in root.findall('.//Dynamic'))),voices=dict(collections.Counter(len(m.findall('voice')) for s in st for m in s.findall('Measure'))))
        else:
            parts=[dict(id=p.get('id'),name=p.findtext('part-name')) for p in root.findall('part-list/score-part')];summary=dict(parts=parts,bars=[len(p.findall('measure')) for p in root.findall('part')],staves=[max([int(s.text) for s in p.findall('.//staves')],default=1) for p in root.findall('part')],notes=len(root.findall('.//pitch')),lyrics=len(root.findall('.//lyric/text')),dynamics=dict(collections.Counter(c.tag for d in root.findall('.//dynamics') for c in d)),voices=dict(collections.Counter(n.findtext('staff','1')+':'+n.findtext('voice','1') for n in root.findall('.//note'))))
        print(i,title,json.dumps(summary,ensure_ascii=False))
        records.append(dict(index=i,title=title,source=str(src),alternatives=[str(p) for p in choices],summary=summary))
    (OUT/'inventory.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
if __name__=='__main__':run()
