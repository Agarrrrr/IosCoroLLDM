import json,collections,copy
from apostol_model import OUT,plan
from apostol_underlay import VOCAB,norm
def run():
    rows=json.loads((OUT/'lyric-rows.json').read_text(encoding='utf-8'));events=json.loads((OUT/'positioned-events.json').read_text());streams=collections.defaultdict(list)
    actual={(e['role'],e['bar'],e['onset']):e for e in sorted(events,key=lambda n:-n.get('pitch',0)) if not e.get('rest')}
    for bar in plan():
        for role in range(4):
            source=bar['source'];owner=0 if role==1 and source<=4 else 2 if role==3 and 5<=source<=14 else role
            variant=bar['passage'] if 63<=source<=65 else 1 if source==66 else 0
            raw=[c for row in rows if row['role']==owner and row['variant']==variant for c in row['chars'] if c['measure']==source]
            for c in sorted(raw,key=lambda c:c['x']):
                target=actual[(role,bar['number'],c['onset'])];cc=copy.deepcopy(c);cc.update(role=role,bar=bar['number'],id=target['id']);streams[role].append(cc)
    result=collections.defaultdict(list);words=[];unknown=[];repairs=[]
    vocabulary=list(set(norm(w) for w in '''envío los hermosa al pelead inundad el gran apóstol que cristo envió ved él es jesús ha mandado un maestro enseña hoy evangelio eterno pregonando a voz por todo mundo entero las almas en esta nueva dispensación y darnos vida su elección qué señor nos para salvación luchar con toda alma valor pelear devoción vamos todos tomad apresto sin temor salió diciendo hombre temed dios nuestro la promesa conforme aquella diciembre le dió dio ni razón mente imaginarlo podran podrá diera multiplicar iglesia dío vemos se cumple cun anunciad tierra hay varón dá dar alvación salvacián amor pueblo da consolación ejemplo servir labor loable hermoso admirable pasión esfuerzo frutos santa paz corazón queremos decirle usted amamos cada día más siempre mucho decirlo manifestar somos llevamos así nosotros sello padre sus sabios consejos dicen oid oíd tiempo ya llego anunciemos hasta último alieneento son palabras ungido santo alcanzar final nuestra redención alabad naasón joaquín si del de lo do en a tu '''.split()))
    for role,characters in streams.items():
        letters=[(i,ch) for i,c in enumerate(characters) for ch in norm(c['text'])];stream=''.join(ch for _,ch in letters);states={0:(0,[])}
        for i in range(len(stream)):
            if i not in states:continue
            cost,path=states[i]
            for word in vocabulary:
                if stream.startswith(word,i):
                    j=i+len(word)
                    if j not in states or cost+1<states[j][0]:states[j]=(cost+1,path+[(i,j,word)])
        if len(stream) not in states:
            reached=max(states);unknown.append(dict(role=role,position=reached,next=stream[reached:reached+120],tail=stream[-100:]));continue
        pending=''.join(c['text'] for c in characters[:letters[0][0]])
        for wi,(i,j,word) in enumerate(states[len(stream)][1]):
            a=letters[i][0];b=letters[j-1][0]+1
            while b<len(characters) and not norm(characters[b]['text']) and characters[b]['text']!='_':b+=1
            segment=copy.deepcopy(characters[a:b]);groups=[]
            for c in segment:
                if c['text']=='_':continue
                if not groups or groups[-1]['id']!=c['id']:groups.append(dict(id=c['id'],text='',bar=c['bar'],onset=c['onset'],tieStop=c['tieStop']))
                groups[-1]['text']+=c['text']
            if pending:groups[0]['text']=pending+groups[0]['text'];pending=''
            while len(groups)>1 and not norm(groups[-1]['text']):
                punct=groups.pop()['text']
                if punct in ['¡','¿','(']:pending=punct+pending
                else:groups[-1]['text']+=punct
            for _ in range(10):
                bad=next((i for i,g in enumerate(groups) if norm(g['text']) and not any(c in 'aeiouáéíóúüy' for c in norm(g['text']))),None)
                if bad is None or len(groups)==1:break
                dest=bad+1 if bad==0 else bad-1
                if dest<bad:groups[dest]['text']+=groups[bad]['text']
                else:groups[dest]['text']=groups[bad]['text']+groups[dest]['text']
                groups.pop(bad);repairs.append(dict(role=role,word=word,kind='consonant-fragment'))
            for gi,g in enumerate(groups):
                if g['tieStop']:repairs.append(dict(role=role,word=word,kind='lyric-on-tie',bar=g['bar'],onset=g['onset']))
                result[g['id']].append(dict(text=g['text'],syllabic='single' if len(groups)==1 else 'begin' if gi==0 else 'end' if gi==len(groups)-1 else 'middle',join=gi==0 and a>0 and characters[a-1]['text']=='_'))
            words.append(dict(role=role,word=word,groups=groups))
    print('unknown',unknown);print('repairs',repairs)
    (OUT/'word-diagnostics.json').write_text(json.dumps(dict(unknown=unknown,repairs=repairs,words=words),ensure_ascii=False,indent=2),encoding='utf-8')
    if unknown:return
    (OUT/'lyric-atoms.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print('lyric notes',len(result),'words',len(words))
if __name__=='__main__':run()
