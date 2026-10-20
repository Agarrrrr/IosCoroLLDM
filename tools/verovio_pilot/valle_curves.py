"""Match genuine PDF Bezier arcs, excluding straight beam polygons."""
from pathlib import Path
import pdfplumber,json
OUT=Path('output/verovio_pilot_support/valle')
def extract():
    voices=json.loads((OUT/'pdf-note-lyrics.json').read_text(encoding='utf-8'))
    result=[]
    with pdfplumber.open(OUT/'original-2.pdf') as pdf:
        for pi,page in enumerate(pdf.pages,1):
            for curve in page.curves:
                if not curve['stroke'] or not any(p[0]=='c' for p in curve['path']):continue
                path=curve['path'];start=path[0][1];end=next(p[-1] for p in reversed(path) if p[0]=='c')
                matches=[]
                for point in [start,end]:
                    choices=[(abs(n['x']-point[0])+abs(n['y']-point[1])*.5,role,i,n) for role,notes in enumerate(voices) for i,n in enumerate(notes) if n['page']==pi]
                    score,role,index,n=min(choices,key=lambda r:r[0])
                    matches.append(dict(role=role,index=index,dx=abs(n['x']-point[0]),dy=abs(n['y']-point[1]),staff=n['staff']))
                a,b=matches
                valid=a['role']==b['role'] and a['staff']==b['staff'] and a['index']<b['index'] and max(a['dx'],b['dx'])<8 and max(a['dy'],b['dy'])<13
                result.append(dict(page=pi,start=a,end=b,valid=valid))
    (OUT/'pdf-arcs.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print('Arcs',len(result),'within-system matched',sum(c['valid'] for c in result),'partial/unmatched',sum(not c['valid'] for c in result))
    return result
if __name__=='__main__':extract()
