from pathlib import Path
p=Path('tools/verovio_pilot/moises_words.py').read_text(encoding='utf-8').replace('from moises_model','from cuando_model').replace('from moises_underlay','from cuando_underlay')
a=p.index('    for bar in plan():');b=p.index('    result=collections.defaultdict',a)
p=p[:a]+"""    def raw(role,m,variant):return [c for row in rows if row['role']==role and row['variant']==variant for c in row['chars'] if c['measure']==m]
    missing=[]
    for bar in plan():
        m=bar['source'];v=bar['passage']
        for role in [0,2]:
            if role==0:
                if m<=27:cs=raw(0,m,v)
                elif m==28:cs=raw(0,m,1)
                elif m<=42:cs=raw(0,m,0)
                elif m==43:cs=[c for c in raw(0,m,1) if c['onset']<3]+[c for c in raw(0,m,1 if v==1 else 2) if c['onset']>=3]
                else:cs=raw(0,m,1)
            else:
                if m<=19:cs=raw(2,m,v)
                elif m<=27:cs=raw(2,m,0)
                elif m==28:cs=raw(0,m,1)
                elif m<=42:cs=raw(0,m,0)+(raw(2,m,0) if m in [35,36] else [])
                elif m==43:cs=[c for c in raw(0,m,1) if c['onset']<3]
                else:cs=raw(0,m,1)
            cs=sorted(cs,key=lambda c:(c['measure'],c['onset'],c['left']))
            for c in cs:
                target=actual.get((role,bar['number'],c['onset']))
                if target is None:missing.append((role,m,c['onset'],c['text']));continue
                cc=copy.deepcopy(c);cc.update(role=role,bar=bar['number'],id=target['id']);streams[role].append(cc)
    assert not missing,missing
"""+p[b:]
a=p.index('    vocabulary=');b=p.index('    for role,characters',a)
p=p[:a]+"""    vocabulary=list(set(norm(w) for w in '''hoy recorde recordé aquel momento cuando por primera vez creí quedarme solo me sentí a perecer clamaba dios sin la paz de cruel ansiedad acabar con mi vivir señor ten compasión no dejes librame líbrame orfandad y que es tan bueno un nuevo amanecer consoló ya tristeza se ha ido reina felicidad luz alumbra mayor intensidad su gran bondad amor gratitud ensalzando muy grande fue el dolor separación del amigo los cielos ascendio pero consuelo otro apóstol levantó plan esposa amada mira florecer apostol santo adornando esta majestad firme va prosperidad presteza cumplio te doy gracias bendicion permitirme contemplar tu gloriosa eleccion desde aquel feliz soy al escuchar hermosa voz afliccion yo senti sentir morir solos protección en era tan densa oscuridad dad gloria dios elecion autoridad haz transformado aflicción lamento alegría eso gozo canto alta perfumada está siervo poder triunfo lleva promesa diera embajador uh oí decir naasón alto corazón saltó quedó ligado usted ese instante amé ser estremeció porque reconoció mismo intante tocó tante comenzó dignan digan hoy'''.split()))
"""+p[b:]
# Write helper after segmentation, keeping original spelling diagnostics.
needle="    (OUT/'lyric-atoms.json').write_text"
at=p.index(needle)
p=p[:at]+"""    # Both closed staves share their printed underlay. Copy exact syllable
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
"""+p[at:]
Path('tools/verovio_pilot/cuando_words.py').write_text(p,encoding='utf-8')
