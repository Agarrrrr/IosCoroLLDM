import json,collections,copy
from cuando_model import OUT,plan
from cuando_underlay import VOCAB,norm
def run():
    rows=json.loads((OUT/'lyric-rows.json').read_text(encoding='utf-8'));events=json.loads((OUT/'positioned-events.json').read_text());streams=collections.defaultdict(list)
    actual={(e['role'],e['bar'],e['onset']):e for e in sorted(events,key=lambda n:-n.get('pitch',0)) if not e.get('rest')}
    def raw(role,m,variant):return [c for row in rows if row['role']==role and row['variant']==variant for c in row['chars'] if c['measure']==m]
    missing=[]
    for bar in plan():
        m=bar['source'];v=bar['passage']
        for role in [0,2]:
            if role==0:
                if m<27:cs=raw(0,m,v)
                elif m==27:cs=[c for c in raw(0,m,v) if c['onset']<3]+[c for c in raw(0,m,1) if c['onset']>=3]
                elif m==28:cs=raw(0,m,1)
                elif m<=42:cs=raw(0,m,0)
                elif m==43:cs=[c for c in raw(0,m,1) if c['onset']<3]+[c for c in raw(0,m,1 if v==1 else 2) if c['onset']>=3]
                else:cs=raw(0,m,1)
            else:
                if m<=19:cs=raw(2,m,v)
                elif m<27:cs=raw(2,m,0)
                elif m==27:cs=raw(2,m,0)+[c for c in raw(0,m,1) if c['onset']>=3]
                elif m==28:cs=raw(0,m,1)
                elif m<=42:cs=raw(0,m,0)+(raw(2,m,0) if m in [35,36] else [])
                elif m==43:cs=[c for c in raw(0,m,1) if c['onset']<3]
                else:cs=raw(0,m,1)
            cs=sorted(cs,key=lambda c:(c['measure'],c['onset'],c['left']))
            for c in cs:
                target=actual.get((role,bar['number'],c['onset']))
                if target is None:missing.append((role,m,c['onset'],c['text']));continue
                cc=copy.deepcopy(c);cc.update(role=role,bar=bar['number'],id=target['id'],tieStop=target.get('tieStop',False));streams[role].append(cc)
    assert not missing,missing
    result=collections.defaultdict(list);words=[];unknown=[];repairs=[]
    vocabulary=list(set(norm(w) for w in '''le cual noche parecía hoy recorde recordé aquel momento cuando por primera vez creí quedarme solo me sentí a perecer clamaba dios sin la paz de cruel ansiedad acabar con mi vivir señor ten compasión no dejes librame líbrame orfandad y que es tan bueno un nuevo amanecer consoló ya tristeza se ha ido reina felicidad luz alumbra mayor intensidad su gran bondad amor gratitud ensalzando muy grande fue el dolor separación del amigo los cielos ascendio pero consuelo otro apóstol levantó plan esposa amada mira florecer apostol santo adornando esta majestad firme va prosperidad presteza cumplio te doy gracias bendicion permitirme contemplar tu gloriosa eleccion desde aquel feliz soy al escuchar hermosa voz afliccion yo senti sentir morir solos protección en era tan densa oscuridad dad gloria dios elecion autoridad haz transformado aflicción lamento alegría eso gozo canto alta perfumada está siervo poder triunfo lleva promesa diera embajador uh oí decir naasón alto corazón saltó quedó ligado usted ese instante amé ser estremeció porque reconoció mismo intante tocó tante comenzó dignan digan hoy'''.split()))
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
            # Correct two evident text defects without moving their syllables.
            if word=='intante' and groups[0]['text']=='in':groups[0]['text']='ins'
            for g in groups:g['text']=g['text'].replace('Di.os','Dios')
            for gi,g in enumerate(groups):
                if g['tieStop']:repairs.append(dict(role=role,word=word,kind='lyric-on-tie',bar=g['bar'],onset=g['onset']))
                result[g['id']].append(dict(text=g['text'],syllabic='single' if len(groups)==1 else 'begin' if gi==0 else 'end' if gi==len(groups)-1 else 'middle',join=gi==0 and a>0 and characters[a-1]['text']=='_'))
            words.append(dict(role=role,word=word,groups=groups))
    print('unknown',unknown);print('repairs',repairs)
    (OUT/'word-diagnostics.json').write_text(json.dumps(dict(unknown=unknown,repairs=repairs,words=words),ensure_ascii=False,indent=2),encoding='utf-8')
    if unknown:return
    # Both closed staves share their printed underlay. Copy exact syllable
    # positions where the lower voice sings; retain its actual rests.
    mapped=copy.deepcopy(result);byid={e['id']:e for e in events};copies=[]
    for role in [1,3]:
        source_role=role-1
        for key,atoms in result.items():
            e=byid[key]
            if e['role']!=source_role:continue
            target=actual.get((role,e['bar'],e['onset']))
            if target is not None and not target.get('cue'):mapped[target['id']]=copy.deepcopy(atoms)
        # A new entry after an independent rest resumes the shared vowel or
        # syllable at that time. This does not insert notes into silent bars.
        previous_rest=True
        for e in sorted([e for e in events if e['role']==role],key=lambda e:(e['bar'],e['onset'],e.get('pitch',0))):
            if e.get('rest'):previous_rest=True;continue
            if e.get('cue'):continue
            if previous_rest and not e.get('tieStop') and e['id'] not in mapped:
                candidates=[byid[k] for k in result if byid[k]['role']==source_role and byid[k]['absolute']<=e['absolute']]
                if candidates:
                    earlier=max(candidates,key=lambda x:x['absolute']);mapped[e['id']]=copy.deepcopy(result[earlier['id']]);copies.append([role,e['bar'],e['onset'],earlier['id']])
            previous_rest=False
    result=mapped
    (OUT/'shared-underlay-entries.json').write_text(json.dumps(copies,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'lyric-atoms.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print('lyric notes',len(result),'words',len(words))
if __name__=='__main__':run()
