import json,collections,copy
from eleccion_model import OUT,plan
from eleccion_underlay import norm

def run():
    rows=json.loads((OUT/'lyric-rows.json').read_text(encoding='utf-8'));events=json.loads((OUT/'positioned-events.json').read_text());streams=collections.defaultdict(list)
    actual={(e['role'],e['bar'],e['onset']):e for e in sorted(events,key=lambda e:-e.get('pitch',0)) if not e.get('rest')}
    missing=[]
    for bar in plan():
        m=bar['source'];v=bar['passage'] if 78<=m<=84 else 1
        for role in range(4):
            cs=[c for row in rows if row['role']==role and row['variant']==v for c in row['chars'] if c['measure']==m]
            for c in sorted(cs,key=lambda c:(c['measure'],c['onset'],c['left'])):
                target=actual.get((role,bar['number'],c['onset']))
                if target is None:missing.append((role,m,c['onset'],c['text']));continue
                cc=copy.deepcopy(c);cc.update(role=role,bar=bar['number'],id=target['id'],tieStop=target.get('tieStop',False));streams[role].append(cc)
    assert not missing,missing
    result=collections.defaultdict(list);words=[];unknown=[];repairs=[]
    vocabulary=list(set(norm(w) for w in 'marchan poder divino mucho dado oró varón o cuan naasón joaquín el ángel que señor envió apóstol dios lo eligió día dia ocho de diciembre un hombre en gran grande dolor a cristo suplicaba dame tu consolación y su ruego él una voz oyó escucho escuchó desconcertado estaba no sabia sabía plan nombre es quien oraba con fervor rey tú consolarás dijo alabemos alabemoos al vivo gloria demos bondad nos ha visto ojos amor vió vio sus digamos todos enviado muy alto alcemos hoy tenemos aquí nuestro redentor creador marchando fe fé hasta haste cielo unidos mismo sentir triunfaremos triunfareemos seguro se halla aprisco mano empuñada seguridad segurida fuerte por la eternidad capitán frente va derrotando toda maldad está victoria pueblo le da dará'.split()))
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
            if word=='alabemoos':
                groups[-2]['text']='mos';groups.pop()
            if word=='triunfareemos':groups=[g for g in groups if not(g['text']=='e' and g['bar']==83)]
            if role==2 and word=='o' and groups[0]['bar']==21:groups=[]
            for g in groups:
                if word=='haste' and g['text']=='te':g['text']='ta'
                if word=='segurida':g['text']=g['text'].replace('da;','dad;')
                if word=='dia':g['text']=g['text'].replace('Di','Dí')
                if word=='sabia' and g['text']=='bi':g['text']='bí'
                if word=='escucho' and g['text']=='cho':g['text']='chó'
                g['text']=g['text'].replace('fé','fe').replace('vió','vio')
            for gi,g in enumerate(groups):
                if g['tieStop']:repairs.append(dict(role=role,word=word,kind='lyric-on-tie',bar=g['bar'],onset=g['onset']))
                result[g['id']].append(dict(text=g['text'],syllabic='single' if len(groups)==1 else 'begin' if gi==0 else 'end' if gi==len(groups)-1 else 'middle',join=gi==0 and a>0 and characters[a-1]['text']=='_'))
            words.append(dict(role=role,word=word,groups=groups))
    print('unknown',unknown);print('repairs',repairs)
    (OUT/'word-diagnostics.json').write_text(json.dumps(dict(unknown=unknown,repairs=repairs,words=words),ensure_ascii=False,indent=2),encoding='utf-8')
    assert not unknown and not repairs
    (OUT/'lyric-atoms.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print('lyric notes',len(result),'words',len(words))
if __name__=='__main__':run()
