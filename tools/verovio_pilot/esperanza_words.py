import json,collections,copy
from esperanza_model import OUT,plan
from esperanza_underlay import norm

def run():
    rows=json.loads((OUT/'lyric-rows.json').read_text(encoding='utf-8'));events=json.loads((OUT/'positioned-events.json').read_text());streams=collections.defaultdict(list)
    actual={(e['role'],e['bar'],e['onset']):e for e in sorted(events,key=lambda e:-e.get('pitch',0)) if not e.get('rest')}
    missing=[]
    for bar in plan():
        m=bar['source'];v=bar['passage'] if m<=11 else (bar['passage']+1 if m==23 else bar['passage'] if m==12 else 0)
        for role in range(4):
            cs=[c for row in rows if row['role']==role and row['variant'] in ([0,v] if m in [12,23] else [v]) for c in row['chars'] if c['measure']==m]
            for c in sorted(cs,key=lambda c:(c['measure'],c['onset'],c['left'])):
                target=actual.get((role,bar['number'],c['onset']))
                if target is None:missing.append((role,m,c['onset'],c['text']));continue
                cc=copy.deepcopy(c);cc.update(role=role,bar=bar['number'],id=target['id'],tieStop=target.get('tieStop',False));streams[role].append(cc)
    assert not missing,missing
    result=collections.defaultdict(list);words=[];unknown=[];repairs=[]
    vocabulary=list(set(norm(w) for w in 'señor jesús tú eres mi esperanza no hay nada mejor que vivir bajo tu amparo y protección porque le das paz a vivir el camino da salvación salud en alma seguridad ti perdón libertad de anhela una hermosa bendición dicha siente poderte cantar decir por gracia yo soy feliz fue amor tan inmenso sin igual bendito gloriosa es cerca cómo puedo pagar gran bondad para mí sólo quiero serte fiel hasta la muerte así junto toda eternidad amigo'.split()))
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
            for g in groups:
                if word=='mi' and '?' in g['text']:g['text']=g['text'].replace('mi','mí').replace('?;','?')
            for gi,g in enumerate(groups):
                if g['tieStop']:repairs.append(dict(role=role,word=word,kind='lyric-on-tie',bar=g['bar'],onset=g['onset']))
                result[g['id']].append(dict(text=g['text'],syllabic='single' if len(groups)==1 else 'begin' if gi==0 else 'end' if gi==len(groups)-1 else 'middle',join=gi==0 and a>0 and characters[a-1]['text']=='_'))
            words.append(dict(role=role,word=word,groups=groups))
    print('unknown',unknown);print('repairs',repairs)
    (OUT/'word-diagnostics.json').write_text(json.dumps(dict(unknown=unknown,repairs=repairs,words=words),ensure_ascii=False,indent=2),encoding='utf-8')
    assert not unknown and not repairs
    (OUT/'lyric-atoms.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print('lyric notes',len(result),'words',len(words))
if __name__=='__main__':run()
