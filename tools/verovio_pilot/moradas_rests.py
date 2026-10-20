"""Retain the PDF's separate rest figures instead of merging every gap."""
import json,pdfplumber,collections
from moradas_model import OUT
def run():
    events=json.loads((OUT/'positioned-events.json').read_text());layout=json.loads((OUT/'pdf-layout.json').read_text());plans={}
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for sy in layout['systems']:
            page=pdf.pages[sy['page']-1]
            for si,role in enumerate(sy['roles']):
                for measure in range(sy['first'],sy['last']+1):
                    a,b=sy['bars'][measure-sy['first']:measure-sy['first']+2]
                    chars=[c for c in page.chars if 'Opus' in c['fontname'] and c['text'] in ['∑','Ó','Œ','‰'] and a<c['x0']<b and abs(842-c['matrix'][5]-sum(sy['staves'][si])/5)<15 and min(range(len(sy['staves'])),key=lambda i:abs(842-c['matrix'][5]-sum(sy['staves'][i])/5))==si]
                    chars=list({(round(c['x0'],3),round(c['matrix'][5],3),c['text']):c for c in chars}.values())
                    row=[]
                    for c in sorted(chars,key=lambda c:c['x0']):
                        d={'∑':4,'Ó':2,'Œ':1,'‰':.5}[c['text']]
                        dots=[cc for cc in page.chars if 'OpusStd' in cc['fontname'] and cc['text']=='.' and 3<cc['x0']-c['x0']<13 and abs(cc['matrix'][5]-c['matrix'][5])<6]
                        if dots:d*=1.5
                        row.append((d,c['text']))
                    plans[(role,measure)]=row
    changed=[];unresolved=[]
    for (role,measure),row in plans.items():
        rests=sorted([e for e in events if e['role']==role and e['measure']==measure and e.get('rest')],key=lambda e:e['onset'])
        if not row:continue
        # The printed figures and silence budget must agree before replacing.
        if abs(sum(d for d,_ in row)-sum(e['duration'] for e in rests))>.001:
            unresolved.append(dict(role=role,measure=measure,printed=row,gaps=[(e['onset'],e['duration']) for e in rests]));continue
        gaps=[]
        for e in rests:
            if gaps and abs(gaps[-1][0]+gaps[-1][1]-e['onset'])<.001:gaps[-1][1]+=e['duration']
            else:gaps.append([e['onset'],e['duration']])
        added=[];i=0
        for start,left in gaps:
            q=start
            while left>0:
                d,glyph=row[i];assert d<=left,(role,measure,gaps,row);i+=1
                added.append(dict(id=f'moradas-rest-pdf-{role}-{measure}-{q}',role=role,bar=measure,measure=measure,passage=1,onset=q,absolute=(measure-1)*4+q,duration=d,rest=True,pdfRest=glyph));q+=d;left-=d
        events=[e for e in events if e not in rests]+added
        if [e['duration'] for e in rests]!=[e['duration'] for e in added]:changed.append(dict(role=role,measure=measure,before=[e['duration'] for e in rests],after=[e['duration'] for e in added]))
    (OUT/'positioned-events.json').write_text(json.dumps(events,indent=2));(OUT/'rest-validation.json').write_text(json.dumps(dict(changed=changed,unresolved=unresolved),indent=2));print('rest figures corrected',len(changed),'unresolved',unresolved)
if __name__=='__main__':run()
