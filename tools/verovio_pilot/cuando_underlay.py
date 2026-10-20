"""Digital lyric characters aligned with the correct printed staff/verse."""
import collections,json,unicodedata
from digital_text_runs import page_runs
from cuando_model import OUT
def norm(s):return ''.join(c.casefold() for c in unicodedata.normalize('NFKC',s) if c.isalpha())
VOCAB='recuerdas a moisés cuando dios le dijo él ve egipto liberar israel con poder abrió las aguas para librarlos de la vejación ese mismo que adoramos hoy es el ayer nos salvará y librará no será excepción recuerda está job cuánto sufrió gran tribulación sus labios salió imprecación cuán fue probada fe abraham lo amaba duro pero obedeció como centurión fío en señor esperemos fervor cuidará bendecirá maravilloso fuerte grande hay otro todo creó sólo sonido su voz potencia gigante dudes nunca nuca venció faraón derrotó los filisteos potestad detuvo sol vencer amorreos pueblo vencedor muy poderoso maravillo aleluya ha creado formado aarón joaquín apóstol tu camina por donde te indique guarda ternura del samuel permitas sentimiento malo ti naasón vehemente sea corazón sé valiente confía confia siempre amén uh mm ah por que'.split()
def run():
    events=json.loads((OUT/'positioned-events.json').read_text());systems=json.loads((OUT/'pdf-layout.json').read_text())['systems'];pages=page_runs(OUT/'original.pdf');rows=[]
    for system in systems:
        pi=system['page']-1
        for si,role in enumerate(system['roles']):
            next_system=next((s for s in systems if s['page']==system['page'] and s['system']==system['system']+1),None)
            staff=system['staves'][si];bottom=system['staves'][si+1][0]-4 if si+1<len(system['staves']) else next_system['staves'][0][0]-12 if next_system else 835
            # Coda underlay has independent text above/below the closed staves;
            # it is supplied explicitly, not guessed from a common baseline.
            row=sorted([e for e in events if (e['passage']==1 or e['measure']>=44) and e['role']==role and system['first']<=e['measure']<=system['last'] and not e.get('rest') and not e.get('cue')],key=lambda e:(e['measure'],e['onset']))
            row=list({(e['measure'],e['onset']):e for e in reversed(row)}.values());row.sort(key=lambda e:(e['measure'],e['onset']))
            if not row:continue
            chars=[c for c in pages[pi] if ('TimesNewRomanPSMT' in c['fontname'] or 'TimesNewRomanPS-ItalicMT' in c['fontname'] or 'OpusTextStd' in c['fontname'] and c['text']=='_') and (abs(c['size']-13.02)<.08 or role==2 and abs(c['size']-11.01)<.08 or 'OpusTextStd' in c['fontname'] and abs(c['size']-10.08)<.08) and staff[-1]+1<c['top']<bottom and not c['text'].isspace()]
            digits=[c for c in chars if c['text'].isdigit()]
            chars=[c for c in chars if not c['text'].isdigit() and not(c['text']=='.' and any(abs(c['top']-d['top'])<2 and 0<=c['x0']-d['x1']<3 for d in digits))]
            lines=[]
            for c in sorted(chars,key=lambda c:c['top']):
                match=next((r for r in lines if abs(c['top']-r[0]['top'])<6),None)
                if match is None:lines.append([c])
                else:match.append(c)
            text_lines=[r for r in lines if any(norm(c['text']) for c in r)]
            for extra in [r for r in lines if not any(norm(c['text']) for c in r)]:
                if text_lines:min(text_lines,key=lambda r:abs(r[0]['top']-extra[0]['top'])).extend(extra)
            lines=sorted(text_lines,key=lambda r:min(c['top'] for c in r if norm(c['text'])))
            for vi,cs in enumerate(lines):
                cs.sort(key=lambda c:c['x0']);states={0:(0,[])}
                for e in row:
                    nxt={}
                    def update(j,cost,path):
                        if j not in nxt or cost<nxt[j][0]:nxt[j]=(cost,path)
                    for j,(cost,path) in states.items():
                        update(j,cost+(0 if e.get('tieStop') else 5),path+[None])
                        for k in range(j+1,min(j+22,len(cs))+1):
                            chunk=cs[j:k];dx=abs((chunk[0]['x0']+chunk[-1]['x1'])/2-e['x']-3.2)
                            if dx>19:continue
                            gaps=[max(0,b['x0']-a['x1']) for a,b in zip(chunk,chunk[1:])]
                            if gaps and max(gaps)>5:break
                            update(k,cost+dx*dx/8+sum(max(0,g-1.5)*4 for g in gaps)+.2+(45 if e.get('tieStop') else 0),path+[(j,k)])
                    states=nxt
                assert len(cs) in states,(system['page'],system['first'],role,vi,'unassigned',''.join(c['text'] for c in cs))
                cost,path=states[len(cs)];assigned=[]
                for e,span in zip(row,path):
                    if span:
                        for c in cs[span[0]:span[1]]:assigned.append(dict(text=unicodedata.normalize('NFKC',c['text']),role=role,measure=e['measure'],onset=e['onset'],x=e['x'],left=c['x0'],right=c['x1'],tieStop=e.get('tieStop',False)))
                rows.append(dict(page=system['page'],system=system['system'],role=role,variant=vi+1 if role==0 and (system['first']<28 or system['first']==43) or role==2 and system['first']<=15 else 0,cost=cost,chars=assigned))
    (OUT/'lyric-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    for r in rows:print(r['page'],r['system'],r['role'],r['variant'],round(r['cost'],1),''.join(c['text'] for c in r['chars']))
if __name__=='__main__':run()
