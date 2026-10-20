"""Locate the source's digital dynamic marks above each printed staff."""
from collections import defaultdict
import json,pdfplumber
from digital_text_runs import page_runs
from extract_alabad import OUT,LAYOUT,staff_groups
def read():
    runs=page_runs(OUT/'original.pdf');marks=[]
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,page in enumerate(pdf.pages):
            staves=staff_groups(page);roles=[r for _,rs in LAYOUT[pi] for r in rs]
            groups=[]
            cs=[c for c in runs[pi] if 'OpusText' in c['fontname'] and abs(c['size']-9)<.1 and c['text'] in 'mpfsz']
            for c in sorted(cs,key=lambda c:(round(c['top']/3),c['x0'])):
                match=next((g for g in groups if abs(g[-1]['top']-c['top'])<3 and -.2<c['x0']-g[-1]['x1']<2),None)
                if match is None:groups.append([c])
                else:match.append(c)
            for group in groups:
                value=''.join(c['text'] for c in group)
                assert value in ['p','f','mp','mf','ff','fp','sf','sfz','sffz'],value
                x=group[0]['x0'];y=group[0]['top']
                si=min(range(len(staves)),key=lambda i:abs(staves[i][0]-(y+12)))
                marks.append(dict(page=pi+1,staff=si,role=roles[si],x=x,value=value))
    (OUT/'dynamics-reading.json').write_text(json.dumps(marks,indent=2),encoding='utf-8')
    print('source dynamics',len(marks))
    return marks
if __name__=='__main__':read()
