import json,xml.etree.ElementTree as E
import pdfplumber
from extract_dios_poderoso import OUT
from prepare_salmo150 import text,notation
from extract_alabad import staff_groups
# The source MIDI is fixed at 98. These ending values interpret the PDF's
# qualitative dim tempo / Perdendosi / Adagio, with an explicitly chosen 60.
TEMPOS=[(0,98),(357.5,94),(360,88),(361.5,82),(363,78),(364,74),(367.5,72),
        (368,70),(369.5,68),(371,66),(372,64),(376,60)]
WORDS=[(1,0,'Animato'),(13,0,'Appassionato'),(40,0,'Dolcesimo legato'),(49,0,'Mistico'),
       (71,0,'Attacca Maestoso'),(77,0,'cresc.'),(90,1.5,'dim. tempo'),(92,3.5,'Decresc.'),
       (94,0,'Perdendosi'),(95,0,'Adagio')]
def insert_direction(measure,direction,onset):
    q=0
    for n in measure.findall('note'):
        if abs(q-onset)<.0001:measure.insert(list(measure).index(n),direction);return
        q+=int(n.findtext('duration'))/960
    assert abs(q-onset)<.0001,(measure.get('number'),onset,q)
    measure.append(direction)
def apply_expressions(root,events,notes):
    for number,q,word in WORDS:
        m=root.find('part').findall('measure')[number-1];d=E.Element('direction',placement='above');dt=E.SubElement(d,'direction-type');text(dt,'words',word);insert_direction(m,d,q)
    import alabad_dynamics
    alabad_dynamics.OUT=OUT
    from extract_salmo150 import STARTS
    starts=[[1,4,7],[10,13,15],[17,19,21],[23,25,28],[31,34,37],[40,45,50],[54,58,61],[65,68,71],[73,75,77],[79,81,83],[85,89,93],[96,99,101]]
    alabad_dynamics.LAYOUT=[[(first,[0,1,2,3]) for first in page] for page in starts]
    dynamics=alabad_dynamics.read();dynamic_values={'p':49,'mp':57,'mf':69,'f':88,'ff':100,'sfz':90}
    for mark in dynamics:
        candidates=[e for e in events if e['page']==mark['page'] and e['staff']==mark['staff'] and e['role']==mark['role']]
        e=min(candidates,key=lambda e:abs(e['x']-mark['x']));m=root.findall('part')[e['role']].findall('measure')[e['measure']-1]
        d=E.Element('direction',placement='above');dt=E.SubElement(d,'direction-type');dyn=E.SubElement(dt,'dynamics');E.SubElement(dyn,mark['value'])
        E.SubElement(d,'sound',dynamics=str(dynamic_values.get(mark['value'],69)));insert_direction(m,d,e['onset'])
    counts={'dynamics':len(dynamics),'fermatas':0,'accents':0,'tenutos':0,'upBows':0,'wedges':0}
    with pdfplumber.open(OUT/'original.pdf') as pdf:
        for pi,page in enumerate(pdf.pages,1):
            staves=staff_groups(page)
            for c in page.chars:
                if not c['fontname'].endswith('+OpusStd') or c['text'] not in ['U','>','-','≤']:continue
                x=c['x0'];y=842-c['matrix'][5]
                candidates=[e for e in events if e['page']==pi and not e['rest'] and abs(e['x']-x)<5 and abs(e['y']-y)<35]
                if not candidates:continue
                e=min(candidates,key=lambda e:abs(e['x']-x)+abs(e['y']-y)*.7);n=notes[e['id']];block=notation(n)
                if c['text']=='U':text(block,'fermata','normal',type='upright');counts['fermatas']+=1
                elif c['text']=='≤':technical=block.find('technical');technical=technical if technical is not None else E.SubElement(block,'technical');E.SubElement(technical,'up-bow');counts['upBows']+=1
                else:
                    articulation=block.find('articulations');articulation=articulation if articulation is not None else E.SubElement(block,'articulations')
                    E.SubElement(articulation,'accent' if c['text']=='>' else 'tenuto');counts['accents' if c['text']=='>' else 'tenutos']+=1
            # Straight hairpins: a converging/diverging pair with matching x range.
            lines=[l for l in page.lines if 12<l['width']<250 and .4<l['height']<12]
            for i,a in enumerate(lines):
                for b in lines[i+1:]:
                    if abs(a['x0']-b['x0'])>.5 or abs(a['x1']-b['x1'])>.5:continue
                    def ends(line):
                        pts=line['pts'];return sorted(pts,key=lambda p:p[0])
                    aa=ends(a);bb=ends(b);left=abs(aa[0][1]-bb[0][1]);right=abs(aa[-1][1]-bb[-1][1])
                    if not(min(left,right)<.5 and 2<max(left,right)<15):continue
                    y=sum([aa[0][1],aa[-1][1],bb[0][1],bb[-1][1]])/4
                    si=min(range(len(staves)),key=lambda s:abs(staves[s][0]-(y+12)))
                    row=[e for e in events if e['page']==pi and e['staff']==si]
                    start=min(row,key=lambda e:abs(e['x']-a['x0']));end=min(row,key=lambda e:abs(e['x']-a['x1']))
                    if (start['measure'],start['onset'])>=(end['measure'],end['onset']):continue
                    for e,kind in [(start,'crescendo' if left<right else 'diminuendo'),(end,'stop')]:
                        m=root.findall('part')[e['role']].findall('measure')[e['measure']-1];d=E.Element('direction',placement='above');dt=E.SubElement(d,'direction-type');E.SubElement(dt,'wedge',type=kind,number='1');insert_direction(m,d,e['onset'])
                    counts['wedges']+=1
    (OUT/'expression-validation.json').write_text(json.dumps(counts,indent=2),encoding='utf-8');return counts
