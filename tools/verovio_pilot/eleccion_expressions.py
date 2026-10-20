"""Read printed dynamics, articulations, hairpins and phrase arcs."""
import json,collections,pdfplumber
from eleccion_model import OUT
def run():
    events=[e for e in json.loads((OUT/'positioned-events.json').read_text()) if e['passage']==(2 if e['measure']>=86 else 1) and not e.get('rest')];systems=json.loads((OUT/'pdf-layout.json').read_text())['systems'];marks=[];arcs=[];partial=[];articulations=[];wedges=[];words=[]
    def owner(page,y):
        options=[(abs(staff[0]-y-16),system,i,role) for system in systems if system['page']==page for i,(staff,role) in enumerate(zip(system['staves'],system['roles']))]
        _,system,i,role=min(options,key=lambda x:x[0]);return system,i,role
    def near_note(page,system,role,x,art_y=None):
        row=[e for e in events if e['page']==page and e['system']==system['system'] and e['role']==role]
        return min(row,key=lambda e:abs(e['x']-x)+(abs(e['y']-art_y)*.6 if art_y is not None else 0))
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,raw in enumerate(pdf.pages,1):
            page=raw.dedupe_chars(tolerance=.1)
            for w in page.extract_words(extra_attrs=['fontname','size'],x_tolerance=1,y_tolerance=3):
                if w['text'] not in ['p','mp','mf','f','ff','fp'] or abs(w['size']-8.48)>.1 or 'OpusText' not in w['fontname']:continue
                system,i,role=owner(pi,w['top']);e=near_note(pi,system,role,w['x0']);roles=[role] if len(system['roles'])==4 else [role,role+1]
                for r in roles:marks.append(dict(role=r,measure=e['measure'],onset=e['onset'],value=w['text'],page=pi))
            for c in page.chars:
                if 'OpusStd' not in c['fontname'] or c['text'] not in ['U','u','>','-','Æ','.']:continue
                if c['text']=='.' and c['size']<15:continue
                x=c['x0'];y=raw.height-c['matrix'][5]
                limit=32 if c['text'] in ['.','Æ'] else 22
                row=[e for e in events if e['page']==pi and abs(e['x']-x)<6 and abs(e['y']-y)<limit]
                if not row:continue
                e=min(row,key=lambda e:abs(e['x']-x)+abs(e['y']-y)*.6)
                system=next(s for s in systems if s['page']==pi and s['system']==e['system']);i=next(i for i,index in enumerate(system['staffIndexes']) if index==e['staff']);staff=system['staves'][i]
                if c['text']=='-' and y>staff[-1]+17:continue
                articulations.append(dict(id=e['id'],role=e['role'],measure=e['measure'],onset=e['onset'],kind={'U':'fermata','u':'fermata','>':'accent','-':'tenuto','Æ':'staccatissimo','.':'staccato'}[c['text']]))
            for curve in raw.curves:
                if not any(p[0]=='c' for p in curve['path']) or curve['x1']-curve['x0']<3:continue
                a=curve['path'][0][1];b=next(p[-1] for p in curve['path'] if p[0]=='c')
                pair=[]
                for x,y in [a,b]:
                    row=[e for e in events if e['page']==pi and abs(e['x']+3.2-x)<11 and abs(e['y']-y)<30]
                    pair.append(sorted([(abs(e['x']+3.2-x)+abs(e['y']-y)*.5,e) for e in row],key=lambda v:v[0])[:8])
                options=[]
                for ca,na in pair[0]:
                    for cb,nb in pair[1]:
                        if na['role']!=nb['role'] or na['staff']!=nb['staff'] or (na['measure'],na['onset'])>=(nb['measure'],nb['onset']):continue
                        same_attack=na['pitch']==nb['pitch'] and (na['sourceAttack']==nb['sourceAttack'] or na.get('tieStart') and nb.get('tieStop'));options.append((ca+cb-(4 if same_attack else 0),na,nb,same_attack))
                if options:
                    cost,na,nb,tie=min(options,key=lambda v:v[0]);arcs.append(dict(start=na['id'],end=nb['id'],role=na['role'],measure=na['measure'],onset=na['onset'],toMeasure=nb['measure'],toOnset=nb['onset'],kind='tie' if tie else 'slur',cost=cost))
                else:partial.append(dict(page=pi,start=a,end=b,nearest=[[dict(id=e['id'],cost=cost) for cost,e in pp[:2]] for pp in pair]))
            lines=[l for l in raw.lines if 12<l['width']<250 and .3<l['height']<12]
            for li,a in enumerate(lines):
                for b in lines[li+1:]:
                    if abs(a['x0']-b['x0'])>.5 or abs(a['x1']-b['x1'])>.5:continue
                    aa=sorted(a['pts'],key=lambda p:p[0]);bb=sorted(b['pts'],key=lambda p:p[0]);left=abs(aa[0][1]-bb[0][1]);right=abs(aa[-1][1]-bb[-1][1])
                    if not(min(left,right)<.5 and 2<max(left,right)<15):continue
                    y=sum([aa[0][1],aa[-1][1],bb[0][1],bb[-1][1]])/4;system,i,role=owner(pi,y)
                    n1=near_note(pi,system,role,a['x0']);n2=near_note(pi,system,role,a['x1'])
                    if (n1['measure'],n1['onset'])>=(n2['measure'],n2['onset']):continue
                    for r in ([role] if len(system['roles'])==4 else [role,role+1]):wedges.append(dict(role=r,measure=n1['measure'],onset=n1['onset'],toMeasure=n2['measure'],toOnset=n2['onset'],kind='crescendo' if left<right else 'diminuendo'))
    # Remove repeated PDF draws without erasing genuine divisi.
    def unique(rows,keys):return list({tuple(r[k] for k in keys):r for r in rows}.values())
    arcs=unique(arcs,['start','end']);articulations=unique(articulations,['id','kind']);marks=unique(marks,['role','measure','onset','value']);wedges=unique(wedges,['role','measure','onset','toMeasure','toOnset','kind'])
    result=dict(dynamics=marks,arcs=arcs,partial=partial,articulations=articulations,wedges=wedges)
    (OUT/'expressions-reading.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print('dynamics',len(marks),'arcs',len(arcs),collections.Counter(a['kind'] for a in arcs),'partial',len(partial),'articulations',collections.Counter(a['kind'] for a in articulations),'wedges',len(wedges));print('partial',json.dumps(partial,indent=2)[:6500])
if __name__=='__main__':run()
