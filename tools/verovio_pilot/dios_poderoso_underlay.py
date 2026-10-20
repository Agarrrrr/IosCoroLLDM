"""Assign digital lyric characters jointly to note centres, then identify words."""
from collections import defaultdict
import json,re
from digital_text_runs import page_runs
from extract_dios_poderoso import OUT
VOCAB='dios poderoso temible y majestuoso perfecto maravilloso excelso eres tú mi rey eterno por los siglos reinarás siempre amén tu nombre alabaré te amaré alma hoy canta sempiterno grande inmortal creador del cielo gloria majestad a padre grandioso eternamente se universo el de un gloria poder lo si santo isaac aarón samuel naasón naason abraham jacob justo joaquín suprema alabanza al adoración nuestro divino espíritu fuego supremo alfa omega amo aleluya amor bondad yo señor hermoso que pies ante ti cantaré maravilla maravillado estoy contemplar la hermosura crea creación con sólo solo tributamos todo corazón adoramos alabamos alabanzas honra digno disfruto alabarte adorarte gran grandes obras obra tus todopoderoso en por eso esso grade nuestro venimos nuestro dios verdadero adoraré bendito'.split()
VOCAB+=['hermosa','israel','glorioso','oh']
def clean(s):return ''.join(c.casefold() for c in s if c.isalpha())
def run():
    data=json.loads((OUT/'pdf-reading.json').read_text(encoding='utf-8'));pages=page_runs(OUT/'original.pdf');char_by_role=defaultdict(list);layout=[]
    comparison=json.loads((OUT/'midi-comparison.json').read_text(encoding='utf-8'))
    held={(n['role'],n['measure'],n['onset']) for n in comparison['heldContinuations']}
    import pdfplumber
    from extract_alabad import staff_groups
    with pdfplumber.open(OUT/'original.pdf') as pdf:all_staves=[staff_groups(p) for p in pdf.pages]
    for page in range(1,13):
        for staff in range(12):
            row=sorted([e for e in data['events'] if e['page']==page and e['staff']==staff and not e['rest']],key=lambda e:e['x'])
            if not row:continue
            # The baseline is known from the original note/lyric association;
            # use the printed staff bottom to exclude instructions above it.
            staves=all_staves[page-1]
            bottom=staves[staff+1][0]-5 if staff+1<len(staves) else 835
            cs=[c for c in pages[page-1] if ('TimesNewRomanPSMT' in c['fontname'] and 11.3<c['size']<13.3 or 'OpusTextStd' in c['fontname'] and c['text']=='_') and staves[staff][-1]+4<c['top']<bottom and not c['text'].isspace()]
            cs.sort(key=lambda c:c['x0'])
            for e in row:e['lyrics']=[];e.pop('lyricAtoms',None)
            if not cs:continue
            states={0:(0,[])}
            for e in row:
                centre=e['x']+3.3;next_states={}
                sustained=(e['role'],e['measure'],e['onset']) in held
                def update(j,cost,path):
                    if j not in next_states or cost<next_states[j][0]:next_states[j]=(cost,path)
                for j,(cost,path) in states.items():
                    update(j,cost+(0 if sustained else 5),path+[None])
                    for k in range(j+1,min(j+18,len(cs))+1):
                        chunk=cs[j:k];cx=(chunk[0]['x0']+chunk[-1]['x1'])/2;dx=abs(cx-centre)
                        if dx>16:continue
                        gaps=[max(0,b['x0']-a['x1']) for a,b in zip(chunk,chunk[1:])]
                        if gaps and max(gaps)>5:break
                        penalty=sum(max(0,g-1.5)*4 for g in gaps)
                        update(k,cost+dx*dx/8+penalty+.2+(30 if sustained else 0),path+[(j,k)])
                states=next_states
            assert len(cs) in states,('unassigned characters',page,staff,len(cs))
            cost,path=states[len(cs)];layout.append(dict(page=page,staff=staff,cost=cost,characters=len(cs)))
            for e,span in zip(row,path):
                if span is None:continue
                chunk=cs[span[0]:span[1]];value=''.join(c['text'] for c in chunk)
                e['lyrics']=[dict(verse=1,text=value,x=(chunk[0]['x0']+chunk[-1]['x1'])/2)]
                for c in chunk:char_by_role[e['role']].append(dict(text=c['text'],measure=e['measure'],onset=e['onset'],x=e['x'],page=page,staff=staff,charLeft=c['x0'],charRight=c['x1']))
    words=[];unknown=[];repairs=[]
    for role,characters in char_by_role.items():
        letters=[(i,c['text'].casefold()) for i,c in enumerate(characters) if c['text'].isalpha()];stream=''.join(c for _,c in letters)
        # Choose a complete dictionary segmentation, preferring fewer words.
        states={0:(0,[])}
        for i in range(len(stream)):
            if i not in states:continue
            cost,path=states[i]
            for word in VOCAB:
                if stream.startswith(word,i):
                    j=i+len(word);candidate=(cost+1,path+[(i,j)])
                    if j not in states or candidate[0]<states[j][0]:states[j]=candidate
        if len(stream) not in states:
            reached=max(states);unknown.append(dict(role=role,position=reached,next=stream[reached:reached+100]));continue
        for i,j in states[len(stream)][1]:
            a=letters[i][0];b=letters[j-1][0]+1
            # Preserve punctuation at the end of a word.
            while b<len(characters) and not characters[b]['text'].isalpha() and characters[b]['text']!='_':b+=1
            segment=characters[a:b]
            position_fields=['measure','onset','x','page','staff']
            last_letter=next(c for c in reversed(segment) if c['text'].isalpha())
            for c in segment:
                if not c['text'].isalpha() and c['text']!='_':
                    for k in position_fields:c[k]=last_letter[k]
            def grouped(chars):
                result=[]
                for c in chars:
                    key=(c['measure'],c['onset'])
                    if not result or result[-1][0]!=key:result.append((key,[]))
                    result[-1][1].append(c)
                return result
            # A consonant cannot be a sung syllable by itself. Resolve a
            # crowded label such as "miDios" without splitting m / i.
            for _ in range(10):
                chunks=grouped(segment)
                bad=next((i for i,(_,cs) in enumerate(chunks) if any(c['text'].isalpha() for c in cs) and not any(c['text'].casefold() in 'aeiouáéíóúüy' for c in cs)),None)
                if bad is None or len(chunks)==1:break
                choices=[]
                for neighbor in [bad-1,bad+1]:
                    if not 0<=neighbor<len(chunks):continue
                    merge=chunks[bad][1]+chunks[neighbor][1]
                    if len({(c['page'],c['staff']) for c in merge})>1:continue
                    centre=(min(c['charLeft'] for c in merge)+max(c['charRight'] for c in merge))/2
                    for target in [chunks[bad][1][0],chunks[neighbor][1][0]]:choices.append((abs(centre-target['x']-3.3),merge,target.copy()))
                if not choices:break
                _,merge,target=min(choices,key=lambda x:x[0])
                repairs.append(dict(role=role,word=stream[i:j],measure=target['measure']))
                for c in merge:
                    for k in position_fields:c[k]=target[k]
            groups=[]
            for c in segment:
                key=(c['measure'],c['onset'])
                if not groups or groups[-1]['key']!=key:groups.append(dict(key=key,text=''))
                groups[-1]['text']+=c['text']
            for gi,g in enumerate(groups):
                e=next(e for e in data['events'] if e['role']==role and (e['measure'],e['onset'])==g['key'] and not e['rest'])
                prev=characters[a-1]['text'] if a else ''
                e.setdefault('lyricAtoms',[]).append(dict(text=g['text'].replace('_',''),join=gi==0 and prev=='_',syllabic='single' if len(groups)==1 else 'begin' if gi==0 else 'end' if gi==len(groups)-1 else 'middle'))
            words.append(dict(role=role,word=stream[i:j],notes=[g['key'] for g in groups]))
    (OUT/'underlay-validation.json').write_text(json.dumps(dict(words=len(words),unknown=unknown,layout=layout,crowdedLabelRepairs=repairs),ensure_ascii=False,indent=2),encoding='utf-8')
    print('words',len(words),'unknown',unknown)
    if unknown:return
    data['invalidTotals']=[t for t in data['invalidTotals']]
    (OUT/'pdf-reading.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8');(OUT/'lyric-words.json').write_text(json.dumps(words,ensure_ascii=False,indent=2),encoding='utf-8')
    for role in range(4):print('WORDS',role,' '.join(w['word'] for w in words if w['role']==role))
if __name__=='__main__':run()
