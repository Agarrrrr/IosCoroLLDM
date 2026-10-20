import json,collections,copy
from torre_model import OUT,plan
from torre_underlay import norm

def run():
    rows=json.loads((OUT/'lyric-rows.json').read_text(encoding='utf-8'));events=json.loads((OUT/'positioned-events.json').read_text());streams=collections.defaultdict(list)
    actual={(e['role'],e['bar'],e['onset']):e for e in sorted(events,key=lambda e:-e.get('pitch',0)) if not e.get('rest')}
    def raw(role,m):return [c for row in rows if row['role']==role for c in row['chars'] if c['measure']==m]
    manual={(23,0):'der',(23,1):'Naa',(23,2):'són',(23,3):'Joa',(24,0):'quín;',(24,2):'su',(25,0):'vi',(25,2):'da,',(25,3):'nues',(26,0):'tra',(26,2):'vi',(26,3):'da',(27,0):'es.',(47,0):'són',(47,5.5):'Naa'}
    missing=[]
    for bar in plan():
        m=bar['source']
        for role in range(4):
            cs=raw(role,m)
            if role==0 and m==2:cs=raw(2,m)
            if role==0 and m in [7,8,52]:cs=raw(1,m)
            if role==1 and m in [13,40]:cs=[c for c in cs if c['onset']<4]+[c for c in raw(3,m) if c['onset']>=4]
            if role==2 and m==3:cs=[c for c in cs if c['onset']>=1.5]+[c for c in raw(0,m) if c['onset']<1.5]
            if role==3:
                if m in [7,8]:cs=raw(2,m)
                elif 23<=m<=27:cs=[]
                elif m==33:cs=raw(0,m)
                elif m==34:cs=[c for c in raw(0,m) if c['onset']==0]
                elif m==48 or m>=59:
                    cs=copy.deepcopy(raw(0,m))
                    if m==64:
                        for c in cs:
                            if c['onset']==2.5:c['onset']=1.5
                for (mm,onset),value in manual.items():
                    if mm==m:
                        for i,ch in enumerate(value):cs.append(dict(text=ch,role=role,measure=m,onset=onset,left=actual[(role,m,onset)]['x']+i*.01))
            for c in sorted(cs,key=lambda c:(c['measure'],c['onset'],c['left'])):
                target=actual.get((role,m,c['onset']))
                if target is None:missing.append((role,m,c['onset'],c['text']));continue
                cc=copy.deepcopy(c);cc.update(role=role,bar=m,id=target['id'],tieStop=target.get('tieStop',False));streams[role].append(cc)
    assert not missing,missing
    result=collections.defaultdict(list);words=[];unknown=[];repairs=[]
    vocabulary=list(set(norm(w) for w in 'de le contemplo más hermoso hemoso que cuando conocí hoy miro tan glorioso ha sido tanto lo hecho en mí me dio la vida esperanza espeanza paz y por mi cristo salvación cuánto cuando triste encontraba llegó usted sus brazos tomó con todo es gran apóstol bendición dicha ser ya no hay temor torre fuerte lucha grande ni prueba pueda vencer poder naasón joaquín su nuestra uh fe bendita oración camino una senda ternura enseñó bendito bendio padre trabajado sin descansar santa nos entregó amor paciencia todas las guerras vence pues alma mora dios eres gózate pueblo rejuvenece amada el tiempo aceptable día porque guerrero oh'.split()))
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
                if word=='hemoso' and g['text']=='he':g['text']='her'
                if word=='espeanza' and g['text']=='an':g['text']='ran'
                if word=='bendio' and g['text']=='o':g['text']='to'
            for gi,g in enumerate(groups):
                if g['tieStop']:repairs.append(dict(role=role,word=word,kind='lyric-on-tie',bar=g['bar'],onset=g['onset']))
                result[g['id']].append(dict(text=g['text'],syllabic='single' if len(groups)==1 else 'begin' if gi==0 else 'end' if gi==len(groups)-1 else 'middle',join=gi==0 and a>0 and characters[a-1]['text']=='_'))
            words.append(dict(role=role,word=word,groups=groups))
    print('unknown',unknown);print('repairs',repairs)
    (OUT/'word-diagnostics.json').write_text(json.dumps(dict(unknown=unknown,repairs=repairs,words=words),ensure_ascii=False,indent=2),encoding='utf-8')
    assert not unknown and not repairs
    (OUT/'lyric-atoms.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print('lyric notes',len(result),'words',len(words))
if __name__=='__main__':run()
