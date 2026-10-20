import json,collections,copy
from recuerda_model import OUT,plan
from recuerda_underlay import VOCAB,norm
CODA=[{56:'dor. Por',57:'siem- pre A-',58:'mén, A- .',59:'mén,',60:'A-',61:'mén.'},
 {56:'dor. Por',57:'siem- pre,',58:'por siem- pre A- mén .',59:'A- mén,',60:'A-',61:'mén.'},
 {56:'dor. Por',57:'siem- pre,',58:'A- . . . .',59:'mén,',60:'A-',61:'mén.'},
 {56:'dor. Por',57:'siem-',58:'pre,',59:'A- mén por siem- pre, A- .',60:'mén, A-',61:'mén.'}]
def run():
    rows=json.loads((OUT/'lyric-rows.json').read_text(encoding='utf-8'));events=json.loads((OUT/'positioned-events.json').read_text());by_raw=collections.defaultdict(list)
    for r in rows:
        for c in r['chars']:by_raw[(r['role'],r['variant'],c['measure'])].append(c)
    actual={(e['role'],e['bar'],e['onset']):e for e in reversed(events) if not e.get('rest')};streams=collections.defaultdict(list);missing=[]
    for bar in plan():
        m=bar['source'];variant=bar['passage']
        if m>=56:continue
        for role in range(4):
            if m<=15:
                raw=by_raw[(0,variant,m)]
                if m==15:raw=[c for c in raw if c['onset']<3.5]+[c for c in by_raw[(0,2,m)] if c['onset']>=3.5]
            elif m==16:raw=by_raw[(0,2,m)]
            elif m==17:
                raw=[c for c in by_raw[(0,2,m)] if c['onset']==0]
                raw+=by_raw[(0,1,m)] if role<2 else by_raw[(2,0,m)]
            elif m<=27:
                owner=0 if role<2 or m>=26 else 2
                raw=by_raw[(owner,1 if m==18 and owner==0 else 0,m)]
            elif m<=42:raw=by_raw[(role,0,m)]
            else:raw=by_raw[(0 if role<2 or m>=51 else 2,0,m)]
            for c in sorted(raw,key=lambda c:c['x']):
                target=actual.get((role,bar['number'],c['onset']))
                if target is None:missing.append((role,m,c['onset'],c['text']));continue
                cc=copy.deepcopy(c);cc.update(role=role,bar=bar['number'],id=target['id']);streams[role].append(cc)
    assert not missing,missing
    for role in range(4):
        for m in range(56,62):
            row=sorted([e for e in events if e['role']==role and e['measure']==m and not e.get('rest')],key=lambda e:e['onset']);row=list({e['onset']:e for e in reversed(row)}.values());row.sort(key=lambda e:e['onset']);tokens=CODA[role][m].split();assert len(tokens)==len(row),(role,m,row,tokens)
            for e,token in zip(row,tokens):
                if token=='.':continue
                for char in token.rstrip('-'):
                    streams[role].append(dict(text=char,role=role,measure=m,onset=e['onset'],bar=e['bar'],id=e['id'],tieStop=e.get('tieStop',False),x=e.get('x',0),left=0,right=0))
    result=collections.defaultdict(list);words=[];unknown=[];repairs=[]
    vocabulary=list(set(norm(w) for w in VOCAB+['se','envió','plagas','cuán','cuándo','cuánto','cuando','uhmm','como','vehemente','librarlos','abrio','maravilloso','bendecirá']))
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
                if word=='nuca' and gi==0 and norm(g['text'])=='nu':
                    g['text']=g['text'].replace('nu','nun');repairs.append(dict(role=role,word=word,kind='PDF spelling: nuca -> nunca',bar=g['bar'],onset=g['onset']))
                if g['tieStop']:repairs.append(dict(role=role,word=word,kind='lyric-on-tie',bar=g['bar'],onset=g['onset']))
                result[g['id']].append(dict(text=g['text'],syllabic='single' if len(groups)==1 else 'begin' if gi==0 else 'end' if gi==len(groups)-1 else 'middle',join=gi==0 and a>0 and characters[a-1]['text']=='_'))
            words.append(dict(role=role,word=word,groups=groups))
    print('unknown',unknown);print('repairs',repairs)
    (OUT/'word-diagnostics.json').write_text(json.dumps(dict(unknown=unknown,repairs=repairs,words=words),ensure_ascii=False,indent=2),encoding='utf-8')
    if unknown:return
    (OUT/'lyric-atoms.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print('lyric notes',len(result),'words',len(words))
if __name__=='__main__':run()
