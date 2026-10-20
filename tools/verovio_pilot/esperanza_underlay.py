import json,unicodedata
from esperanza_model import OUT
from digital_text_runs import page_runs
from torre_underlay import align,norm
def run():
    events=json.loads((OUT/'positioned-events.json').read_text());systems=json.loads((OUT/'pdf-layout.json').read_text())['systems'];pages=page_runs(OUT/'original.pdf');rows=[]
    for sy in systems:
        pi=sy['page']-1;cs=[c for c in pages[pi] if abs(c['size']-11.94)<.08 and ('TimesNewRoman' in c['fontname'] or c['text']=='_') and not c['text'].isspace()]
        specs=[]
        if pi==0:
            baselines={1:[137.8,150.8,163.2],4:[319.3,333,347],7:[509,523,537],10:[701.2,714,727.9]}[sy['first']]
            for v,y in enumerate(baselines,1):
                specs.append((list(range(4)),v,[c for c in cs if abs(c['top']-y)<5 and (sy['first']!=10 or c['x0']<440)]))
            if sy['first']==10:
                specs.append(([0,1],0,[c for c in cs if abs(c['top']-714)<5 and c['x0']>440]))
                specs.append(([3],0,[c for c in cs if abs(c['top']-791)<3]))
        elif sy['first']==13:
            for roles,y in [([0,1],137.8),([2],164.3),([3],233.3)]:specs.append((roles,0,[c for c in cs if abs(c['top']-y)<3]))
        elif sy['first']==16:
            for roles,y in [([0,1],334.6),([2],364.3),([3],432.6)]:specs.append((roles,0,[c for c in cs if abs(c['top']-y)<3]))
            specs.append((list(range(4)),0,[c for c in cs if abs(c['top']-352)<3]))
        elif sy['first']==20:
            boundary=sy['bars'][3]
            specs.append((list(range(4)),0,[c for c in cs if abs(c['top']-542)<3 and c['x0']<460]))
            for v,y in [(2,541),(3,554)]:specs.append((list(range(4)),v,[c for c in cs if abs(c['top']-y)<3 and c['x0']>460]))
        else:specs.append((list(range(4)),0,[c for c in cs if abs(c['top']-724.2)<3]))
        for owners,v,chars in specs:
            digits=[c for c in chars if c['text'].isdigit()];chars=[c for c in chars if not c['text'].isdigit() and not(c['text']=='.' and any(abs(c['top']-d['top'])<2 and 0<=c['x0']-d['x1']<3 for d in digits))]
            for role in owners:
                row=sorted([e for e in events if e['passage']==(3 if e['measure']>=24 else 1) and e['role']==role and sy['first']<=e['measure']<=sy['last'] and not e.get('rest')],key=lambda e:(e['measure'],e['onset']))
                assigned,cost=align(chars.copy(),row)
                rows.append(dict(page=sy['page'],system=sy['system'],role=role,variant=v,cost=cost,chars=assigned))
    (OUT/'lyric-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    for r in rows:print(r['page'],r['system'],r['role'],r['variant'],round(r['cost'],1),''.join(c['text'] for c in r['chars']))
if __name__=='__main__':run()
