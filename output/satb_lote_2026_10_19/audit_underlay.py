from pathlib import Path
import sys,json,xml.etree.ElementTree as E,collections
from fractions import Fraction as F
from score_model import parse
OUT=Path('output/underlay_revision_2026_10_19');OUT.mkdir(exist_ok=True)
BATCH=Path('output/satb_lote_2026_10_19')
records=[]
for r in json.loads((BATCH/'prepared-index.json').read_text(encoding='utf-8')):
    records.append(dict(name=r['finalName'],xml=str(BATCH/f"{r['index']:02d}/prepared.musicxml"),pdf=str(BATCH/f"{r['index']:02d}/reference.pdf"),batch=r['index']))
for p in Path('output/verovio_pilot_support').glob('*/*.musicxml'):
    if (Path('E:/MusescoreCantai')/(p.stem+'.mscz')).exists():
        records.append(dict(name=p.stem,xml=str(p),pdf=str(p.parent/'original.pdf')))
p=Path('output/cantico_144_mil/El Cántico de los 144 Mil - SATB desarrollado - Cantai.musicxml')
records.append(dict(name=p.stem,xml=str(p),pdf=str(p.parent/'original.pdf')))

def txt(n):return ''.join(t.text or '' for t in n.findall('lyric/text'))
def tied(n):return any(t.get('type')=='stop' for t in n.findall('tie'))
def inspect(record):
    root=E.parse(record['xml']).getroot();parts=parse(root);gaps=[]
    for ri,part in enumerate(parts):
        for mi,m in enumerate(part):
            target=[e for e in m['events'] if e['pitch'] is not None and e['node'].find('chord') is None]
            for si,other in enumerate(parts):
                if si==ri:continue
                source=[e for e in other[mi]['events'] if e['pitch'] is not None and e['node'].find('chord') is None]
                matched=[]
                for e in target:
                    if txt(e['node']) or tied(e['node']):continue
                    a=next((a for a in source if a['onset']==e['onset'] and a['duration']==e['duration'] and txt(a['node']) and not tied(a['node'])),None)
                    if a:matched.append(dict(onset=str(e['onset']),text=txt(a['node']),syllabic=a['node'].findtext('lyric/syllabic','single')))
                if matched:
                    gaps.append(dict(role=ri,bar=mi+1,donor=si,missing=matched,existing=' '.join(txt(e['node']) for e in target if txt(e['node'])),source=' '.join(txt(e['node']) for e in source if txt(e['node']))))
    return gaps

for record in records:
    record['candidates']=inspect(record)
(OUT/'audit.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
lines=[]
for r in records:
    lines.append('\n### '+r['name'])
    groups=collections.defaultdict(list)
    for g in r['candidates']:
        if g['donor']==min(x['donor'] for x in r['candidates'] if x['role']==g['role'] and x['bar']==g['bar']):groups[g['role']].append(g)
    for role,gs in groups.items():
        lines.append('ROLE '+str(role))
        for g in gs:lines.append(f"{g['bar']}: missing=[{' '.join(x['text'] for x in g['missing'])}] own=[{g['existing']}] donor{g['donor']}=[{g['source']}]")
(OUT/'audit.txt').write_text('\n'.join(lines),encoding='utf-8')
print('scores',len(records),'candidate bars',sum(len(r['candidates']) for r in records))
