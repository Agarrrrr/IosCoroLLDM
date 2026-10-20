from pathlib import Path
import json,pdfplumber,collections
OUT=Path(__file__).resolve().parent
data=json.loads((OUT/'layout.json').read_text(encoding='utf-8'));mapped=json.loads((OUT/'mapped.json').read_text(encoding='utf-8'))['events']
tokens=[]
with pdfplumber.open(OUT/'eaeafa56-1d25-4517-b13f-1b3f7f6beced.pdf') as pdf:
 for sy in data['systems']:
  for staff in range(2):
   cs=[c for c in data['chars'] if c['page']==sy['page'] and c['system']==sy['system'] and c['staff']==staff and not c['text'].isdigit()]
   # Soprano's separate high response on page three is printed above staff.
   if sy['page']==3 and sy['system']==0 and staff==0:
    for c in pdf.pages[2].chars:
     if c['fontname']=='Times-Roman' and 100<c['top']<120 and c['x0']>280:cs.append(dict(text=c['text'],x0=c['x0'],x1=c['x1'],top=c['top']))
   lines=[]
   for c in sorted(cs,key=lambda c:c['top']):
    line=next((l for l in lines if abs(l[0]['top']-c['top'])<3),None)
    if line is None:lines.append([c])
    else:line.append(c)
   for li,line in enumerate(lines):
    groups=[]
    for c in sorted(line,key=lambda c:c['x0']):
     if c['text'].isspace():continue
     if not groups or c['x0']-groups[-1][-1]['x1']>1.7:groups.append([])
     groups[-1].append(c)
    for group in groups:
     value=''.join(c['text'] for c in group);x=(group[0]['x0']+group[-1]['x1'])/2
     if value.startswith('(4') or value in ['compases)']:continue
     rows=[e for e in mapped if e['page']==sy['page'] and e['system']==sy['system'] and e['role']//2==staff]
     near=min(rows,key=lambda e:abs(e['x']+2.8-x));distance=abs(near['x']+2.8-x)
     tokens.append(dict(page=sy['page'],system=sy['system'],staff=staff,line=li,text=value,x=x,top=group[0]['top'],measure=near['measure'],onset=near['onset'],distance=distance))
(OUT/'lyric-tokens.json').write_text(json.dumps(tokens,ensure_ascii=False,indent=2),encoding='utf-8')
for sy in data['systems']:
 print('\nSYSTEM',sy['page'],sy['system'])
 for st in range(2):print(st,' | '.join(f"{t['measure']}:{t['onset']:g}={t['text']}({t['distance']:.1f})" for t in tokens if t['page']==sy['page'] and t['system']==sy['system'] and t['staff']==st))
