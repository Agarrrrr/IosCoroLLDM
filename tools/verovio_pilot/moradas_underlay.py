import json,unicodedata
from digital_text_runs import page_runs
from torre_underlay import align,norm
from moradas_model import OUT

def run():
    events=json.loads((OUT/'positioned-events.json').read_text());systems=json.loads((OUT/'pdf-layout.json').read_text())['systems'];pages=page_runs(OUT/'original.pdf');rows=[]
    for system in systems:
        pi=system['page']-1
        for si,role in enumerate(system['roles']):
            staff=system['staves'][si];next_system=next((s for s in systems if s['page']==system['page'] and s['system']==system['system']+1),None)
            lo=staff[-1]+2;hi=system['staves'][si+1][0]-5 if si<len(system['staves'])-1 else next_system['staves'][0][0]-12 if next_system else 810
            chars=[c for c in pages[pi] if lo<c['top']<hi and not c['text'].isspace() and 'AGaramondPro-Regular' in c['fontname'] and abs(c['size']-11.94)<.08]
            chars += [c for c in pages[pi] if c['text'] in ['_','.'] and lo<c['top']<hi and abs(c['size']-11.94)<.08 and c not in chars]
            digits=[c for c in chars if c['text'].isdigit()]
            chars=[c for c in chars if c['text']!='-' and not c['text'].isdigit() and not(c['text']=='.' and any(abs(c['top']-d['top'])<2 and 0<=c['x0']-d['x1']<3 for d in digits))]
            if not chars:continue
            lines=[]
            for c in sorted(chars,key=lambda c:c['top']):
                match=next((r for r in lines if abs(c['top']-r[0]['top'])<5),None)
                if match is None:lines.append([c])
                else:match.append(c)
            text_lines=[r for r in lines if any(norm(c['text']) for c in r)]
            for extra in [r for r in lines if not any(norm(c['text']) for c in r)]:
                if text_lines:min(text_lines,key=lambda r:abs(r[0]['top']-extra[0]['top'])).extend(extra)
            lines=sorted(text_lines,key=lambda r:min(c['top'] for c in r if norm(c['text'])))
            row=sorted([e for e in events if e['passage']==1 and e['role']==role and system['first']<=e['measure']<=system['last'] and not e.get('rest')],key=lambda e:(e['measure'],e['onset'],e['pitch']))
            row=list({(e['measure'],e['onset']):e for e in reversed(row)}.values());row.sort(key=lambda e:(e['measure'],e['onset']))
            for vi,cs in enumerate(lines):
                assigned,cost=align(cs,row);rows.append(dict(page=system['page'],system=system['system'],role=role,variant=vi+1,cost=cost,chars=assigned))
    # The alto print omits the vowel "a" in de-se-a. Its second phrase arc
    # starts on A4 at beat 2, separate from the "se" melisma.
    row=next(r for r in rows if r['page']==2 and r['system']==1 and r['role']==2)
    event=next(e for e in events if e['role']==2 and e['measure']==31 and e['onset']==2)
    row['chars'].append(dict(text='a',role=2,measure=31,onset=2,x=event['x'],left=event['x'],right=event['x']+4,tieStop=False,editorial=True))
    for r in rows:
        for c in r['chars']:c['text']=c['text'].replace('ì','í')
    # Keep consonants and sinalefas on their sung onset, not on the
    # following note of the printed melisma.
    moves=[(0,81,3.5,3),(1,41,3.5,3),(2,40,3.5,3),(3,40,3.5,3),(4,40,3.5,3),(2,32,.5,0),(3,32,.5,0),(2,71,2.5,2),(3,30,2.5,2),(3,71,2.5,2),(2,90,1,0)]
    for role,measure,old,new in moves:
        e=next(e for e in events if e['role']==role and e['measure']==measure and e['onset']==new and not e.get('rest'))
        for r in rows:
            if r['role']!=role:continue
            for c in r['chars']:
                if c['measure']==measure and c['onset']==old:c.update(onset=new,x=e['x'],tieStop=e.get('tieStop',False))
    (OUT/'lyric-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    for r in rows:print(r['page'],r['system'],r['role'],r['variant'],round(r['cost'],1),''.join(c['text'] for c in r['chars']))
if __name__=='__main__':run()
