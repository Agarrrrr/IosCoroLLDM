import json,unicodedata
from digital_text_runs import page_runs
from torre_model import OUT

def norm(s):return ''.join(c.casefold() for c in unicodedata.normalize('NFKC',s) if c.isalpha())

def align(cs,row):
    cs.sort(key=lambda c:c['x0']);states={0:(0,[])}
    for e in row:
        nxt={}
        def update(j,cost,path):
            if j not in nxt or cost<nxt[j][0]:nxt[j]=(cost,path)
        for j,(cost,path) in states.items():
            update(j,cost+(0 if e.get('tieStop') else 5),path+[None])
            for k in range(j+1,min(j+22,len(cs))+1):
                chunk=cs[j:k];dx=abs((chunk[0]['x0']+chunk[-1]['x1'])/2-e['x']-3)
                if dx>20:continue
                gaps=[max(0,b['x0']-a['x1']) for a,b in zip(chunk,chunk[1:])]
                if gaps and max(gaps)>7:break
                update(k,cost+dx*dx/5+sum(max(0,g-1)*4 for g in gaps)+.2+(45 if e.get('tieStop') else 0),path+[(j,k)])
        states=nxt
    assert len(cs) in states,('unassigned',''.join(c['text'] for c in cs))
    cost,path=states[len(cs)];assigned=[]
    for e,span in zip(row,path):
        if span:
            for c in cs[span[0]:span[1]]:assigned.append(dict(text=unicodedata.normalize('NFKC',c['text']),role=e['role'],measure=e['measure'],onset=e['onset'],x=e['x'],left=c['x0'],right=c['x1'],tieStop=e.get('tieStop',False)))
    return assigned,cost

def run():
    events=json.loads((OUT/'positioned-events.json').read_text());systems=json.loads((OUT/'pdf-layout.json').read_text())['systems'];pages=page_runs(OUT/'original.pdf');rows=[]
    for system in systems:
        pi=system['page']-1
        for si,role in enumerate(system['roles']):
            staff=system['staves'][si]
            next_system=next((s for s in systems if s['page']==system['page'] and s['system']==system['system']+1),None)
            lo=staff[-1]+2;hi=system['staves'][si+1][0]-5 if si<3 else next_system['staves'][0][0]-12 if next_system else 835
            chars=[c for c in pages[pi] if lo<c['top']<hi and not c['text'].isspace() and ('AGaramondPro-Regular' in c['fontname'] and abs(c['size']-12.09)<.08 or 'TimesNewRomanPSMT' in c['fontname'] and abs(c['size']-11.08)<.08)]
            chars += [c for c in pages[pi] if c['text'] in ['_','.'] and lo<c['top']<hi and abs(c['size']-12.09)<.08 and c not in chars]
            digits=[c for c in chars if c['text'].isdigit()]
            chars=[c for c in chars if c['text']!='-' and not c['text'].isdigit() and not(c['text']=='.' and any(abs(c['top']-d['top'])<2 and 0<=c['x0']-d['x1']<3 for d in digits))]
            if not chars:continue
            row=sorted([e for e in events if e['role']==role and system['first']<=e['measure']<=system['last'] and not e.get('rest')],key=lambda e:(e['measure'],e['onset'],e['pitch']))
            row=list({(e['measure'],e['onset']):e for e in reversed(row)}.values());row.sort(key=lambda e:(e['measure'],e['onset']))
            assigned,cost=align(chars,row)
            rows.append(dict(page=system['page'],system=system['system'],role=role,variant=1,cost=cost,chars=assigned))
    (OUT/'lyric-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    for r in rows:print(r['page'],r['system'],r['role'],r['variant'],round(r['cost'],1),''.join(c['text'] for c in r['chars']))

if __name__=='__main__':run()
