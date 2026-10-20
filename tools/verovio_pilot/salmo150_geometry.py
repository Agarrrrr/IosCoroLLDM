from pathlib import Path
import json,collections,pdfplumber
from extract_alabad import staff_groups
OUT=Path('output/verovio_pilot_support/salmo150')
def inspect():
    d=json.loads((OUT/'midi-reading.json').read_text());ppq=d['ppq']
    for i,t in enumerate(d['tracks']):
        print('MIDI',i,'first',[(n['ticks']/ppq,n['pitch'],n['duration']/ppq) for n in t['notes'][:16]],'end',max((n['ticks']+n['duration'])/ppq for n in t['notes']))
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,p in enumerate(pdf.pages,1):
            print('PAGE',pi,'size',p.width,p.height,'fonts',collections.Counter((c['fontname'],round(c['size'],2)) for c in p.chars).most_common(12))
            print('staves',staff_groups(p))
            print('heads',[(c['text'],c['x0'],c['top'],c['matrix']) for c in p.chars if c['text']=='œ'][:2])
if __name__=='__main__':inspect()
