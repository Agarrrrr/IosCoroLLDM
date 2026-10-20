"""Preserve digital PDF underlay; fill omitted parallel voices explicitly."""
import json,copy,re,unicodedata
from model import OUT,plan

def normalized(s):
    return ''.join(c for c in unicodedata.normalize('NFD',s.casefold()) if c.isalpha())

def run():
    src=json.loads((OUT/'source-events.json').read_text(encoding='utf8'))
    def row(role,m):return sorted([e for e in src if e['role']==role and e['measure']==m and not e['rest']],key=lambda e:e['onset'])
    def setrow(role,m,string,verse=1):
        es=row(role,m);tokens=string.split('|');assert len(es)==len(tokens),(role,m,len(es),tokens)
        for e,t in zip(es,tokens):
            e['lyrics']=[l for l in e['lyrics'] if l['verse']!=verse]
            if t!='_':e['lyrics'].append(dict(verse=verse,text=t))
    def parallel(target,source,measures):
        for m in measures:
            for e in row(target,m):
                matches=[a for a in row(source,m) if abs(a['onset']-e['onset'])<1e-5]
                if matches:e['lyrics']=copy.deepcopy(matches[0]['lyrics'])
    # Overlapping PDF words are separated at the engraved note positions.
    setrow(0,72,'tial,|sin|i|gual,|que|ja')
    for r in [1,2]:
        es=row(r,22);es[0]['lyrics']=es[1]['lyrics'];es[1]['lyrics']=[]
    setrow(2,42,'Glo|ria_a|Dios,')
    setrow(0,60,'ter|no|y|Om|nis',2)
    setrow(1,59,'glo|ria_a|Dios,')
    setrow(1,63,'glo|ria_al|Ex')
    parallel(2,0,range(5,11))
    parallel(3,2,list(range(28,33))+list(range(35,42)))
    parallel(2,1,range(46,50))
    parallel(1,0,[70,72,73,74,75,76])
    setrow(1,68,'cu|cha_un|can|to|nue|_|vo|_')
    setrow(1,69,'_|de|a|mor,|u')
    setrow(1,71,'dor;|ce|les')
    setrow(3,65,'so')
    setrow(3,66,'Rey.')
    (OUT/'source-underlay.json').write_text(json.dumps(src,ensure_ascii=False,indent=2),encoding='utf8')
    expanded=[]
    for bar in plan():
        for r in range(4):
            es=[e for e in src if e['role']==r and e['measure']==bar['source']]
            for e in es:
                n=copy.deepcopy(e);verse=bar['passage'] if 54<=bar['source']<=61 and r==0 else 1
                n.update(bar=bar['number'],passage=bar['passage'],absolute=bar['start']+e['onset'],id=f"n-{r}-{bar['number']}-{e['onset']:.5f}")
                n['lyric']=next((l['text'] for l in e['lyrics'] if l['verse']==verse),None);expanded.append(n)
    # Determine word boundaries independently in each voice, including elisions.
    words='''después miré y vi al cordero que estaba en pie sobre el monte de sión a su lado los sellados tenían nombre ciento cuarenta cuatro mil aleluyas llenan todo cielo con bello sonido voz gloria dios eterno dad hoy la tierra creador adoración suprema alabanza sea por siglos amén aleluya cantad cielos omnipotente potencia toda honra oí una cual gran estruendo muchas aguas correr cantaban un canto nuevo ante trono del melodía dada celestial inmortal rey celso excelso siempre para loor padre omnisciente escucha amor nueva sin igual jamás escuchó entonada nuestro hacedor ah'''
    lex={normalized(w) for w in (words+' le sabiduría sean se eternidad').split()}
    issues=[]
    for r in range(4):
        atoms=[]
        for e in [e for e in expanded if e['role']==r and e.get('lyric')]:
            e['atoms']=[]
            for i,t in enumerate(e['lyric'].split('_')):
                a=dict(text=t,join=i>0,event=e['id']);atoms.append(a);e['atoms'].append(a)
        i=0
        while i<len(atoms):
            matches=[]
            for j in range(i,min(len(atoms),i+10)):
                w=normalized(''.join(a['text'] for a in atoms[i:j+1]))
                if w in lex:matches.append(j+1)
                if re.search(r'[,.;?]',atoms[j]['text']):break
            if not matches:
                issues.append((r,i,[a['text'] for a in atoms[i:i+5]]));stop=i+1
            else:stop=max(matches)
            for k in range(i,stop):atoms[k]['syllabic']='single' if stop==i+1 else 'begin' if k==i else 'end' if k==stop-1 else 'middle'
            i=stop
    assert not issues,issues[:20]
    (OUT/'events.json').write_text(json.dumps(expanded,ensure_ascii=False,indent=2),encoding='utf8')
    print('Expanded notes',sum(not e['rest'] for e in expanded),'lyric notes',sum(bool(e.get('lyric')) for e in expanded))

if __name__=='__main__':run()
