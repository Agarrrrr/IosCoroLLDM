import json,hashlib,zipfile,xml.etree.ElementTree as E
from inventory import OUT

names={1:'A Dónde Iré - SATB - Cantai',2:'Al Gran Señor (Adoración) - SATB - Cantai',3:'Ángel Poderoso - SATB - Cantai',4:'Apocalipsis 10 - SATB y Barítono - Cantai',5:'En su Corazón - SATB - Cantai',6:'Firmes y Adelante - SATB desarrollado - Cantai',7:'Glory Unto Jesus Christ - SATB - Cantai',8:'Guerrero Celestial - SATB - Cantai',9:'Jehová es mi Pastor - SATB - Cantai',10:'La Restauración - SATB - Cantai',11:'Para Siempre Es Su Misericordia - SATB - Cantai',12:'Restauración - SATB - Cantai',13:'Santo Varón - SATB - Cantai',14:'Al Huerto Van a Visitar - SATB - Cantai',15:'El Aliento de mi Ser - SATB - Cantai',16:'Es Dios - SATB - Cantai',17:'Imagínate Tú - SATB - Cantai',18:'Imagínate Tú (variante SATB) - Cantai',19:'La Fiesta Universal - SATB desarrollado - Cantai',20:'La Vida Se Va Como El Viento (reducción) - SATB - Cantai',21:'Mi Padre en la Fe - SATB - Cantai',22:'Nardo, Justicia y Gloria - SATB - Cantai'}
rows=json.loads((OUT/'prepared-index.json').read_text(encoding='utf-8'))
for report in ['validation.json','playback-validation.json']:
    checks=json.loads((OUT/report).read_text(encoding='utf-8'))
    assert len(checks)==22 and not any(r['issues'] for r in checks),report
manifest=[]
for row in rows:
    old=OUT/'final'/(row['finalName']+'.mscz');new=old.with_name(names[row['index']]+'.mscz')
    if new!=old:
        assert not new.exists(),new
        old.rename(new)
    with zipfile.ZipFile(new) as z:
        assert z.testzip() is None
        mscx=[n for n in z.namelist() if n.endswith('.mscx') and '/' not in n]
        assert len(mscx)==1
        root=E.fromstring(z.read(mscx[0]));score=root.find('Score')
        assert len(score.findall('Staff'))==row['parts']
    row['finalName']=names[row['index']]
    manifest.append(dict(index=row['index'],source=str(new),destination=str(__import__('pathlib').Path('E:/MusescoreCantai')/new.name),sha256=hashlib.sha256(new.read_bytes()).hexdigest(),staves=row['parts']))
(OUT/'prepared-index.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'delivery-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('Validated and packaged',len(manifest),'MSCZ files')
