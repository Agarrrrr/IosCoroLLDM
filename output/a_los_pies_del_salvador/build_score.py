from pathlib import Path
from copy import deepcopy
from fractions import Fraction as F
import json,collections,sys,xml.etree.ElementTree as E
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
OUT=Path(__file__).resolve().parent
root=E.parse(OUT/'source.musicxml').getroot();parts=parse(root);notes={}
for role,part in enumerate(root.findall('part')):
 for bar,m in enumerate(part.findall('measure'),1):
  for n,e in zip(m.findall('note'),parts[role][bar-1]['events']):
   if n.find('chord') is None:notes[role,bar,float(e['onset'])]=n
def text(p,k,v,**attrs):e=E.SubElement(p,k,attrs);e.text=str(v);return e
def notation(n):
 e=n.find('notations')
 return e if e is not None else E.SubElement(n,'notations')
def atoms(s):
 result=[]
 for word in s.split():
  chunks=word.split('-')
  for i,ch in enumerate(chunks):
   if not ch:continue
   result.append(dict(text=ch.replace('_','‿'),syllabic='single' if len(chunks)==1 else 'begin' if i==0 else 'end' if i==len(chunks)-1 else 'middle'))
 return result
assigned={}
def put(role,first,last,phrase,omit=(),only=None):
 omit=set(omit)
 row=[(m['index']+1,e) for m in parts[role][first-1:last] for e in m['events'] if e['pitch'] is not None and e['node'].find('chord') is None and e['node'].find('tie[@type="stop"]') is None and (m['index']+1,float(e['onset'])) not in omit]
 if only is not None:row=[(b,e) for b,e in row if (b,float(e['onset'])) in set(only)]
 aa=atoms(phrase);assert len(row)==len(aa),(role,first,last,len(row),len(aa),phrase,[(b,float(e['onset'])) for b,e in row])
 for (b,e),a in zip(row,aa):
  key=role,b,float(e['onset']);assert key not in assigned,key;assigned[key]=a

put(0,1,5,'A los pies del Sal-va-dor de-se-o siem-pre_es-tar, en sus bra-zos des-can-sar,')
put(0,6,8,'su dul-ce voz o-ír; gran con-sue-lo en-con-tré')
put(0,9,13,'en bra-zos de Je-sús, pues me lle-va más y más al Pa-dre Ce-les-tial. ¡A-')
put(1,2,13,'Mi Sal-va-dor mi de-se-o es, ah sí dul-ce es; yo en-con-tré con Je-sús, más y más al Pa-dre Ce-les-tial. ¡A-',omit=[(3,2),(3,3),(6,2.5),(8,3.5),(10,1.5)])
put(2,2,13,'Mi Se-ñor mi de-se-o es, ah sí dul-ce es; en-con-tré con Je-sús, más y más al Pa-dre Ce-les-tial. ¡A-',omit=[(3,0),(3,2),(5,3),(6,0),(7,1.5),(8,3.5),(10,1)])
put(3,2,13,'Mi Se-ñor (oh, sí es), ah sí dul-ce es; en-con-tré con Je-sús, más y más al Pa-dre Ce-les-tial. ¡A-',omit=[(3,2),(4,2),(4,3),(6,0),(10,1.5)])

# Common chorus text is present before each separate answer.
put(0,14,17,'ma-do mí-o quie-ro siem-pre cer-ca_es-tar de ti! En tus')
put(0,18,20,'bra-zos des-can-sar, oh Cris-to con-fí-o en ti; ¡te')
put(0,21,24,'a-mo tan-to mi ben-di-to Sal-va-dor Je-sús! Sé que')
put(0,25,27,'Tú me a-mas más, y nun-ca me has de_ol-vi-dar.',omit=[(27,2),(27,2.5),(27,3),(27,3.5)])
for key,a in list(assigned.items()):
 role,b,onset=key
 if role==0 and 14<=b<=27:
  for other in [1,2,3]:
   if (other,b,onset) in notes:assigned[other,b,onset]=deepcopy(a)
put(3,15,15,'(sí)',only=[(15,1)])
put(1,17,17,'(de ti)',only=[(17,1),(17,2)])
for r in [1,2,3]:put(r,20,20,'(en ti)',only=[(20,1),(20,2)])
put(1,24,24,'(mi Rey)',only=[(24,1),(24,2)])

VERSE2='A su la-do soy fe-liz, ol-vi-do mi do-lor, la tris-te-za ter-mi-nó, mi sue-ño se cum-plió; cual Ma-rí-a es-ta-ré en pie de mi Je-sús de-rra-man-do an-te Él per-fu-me de_o-ra-ción. ¡A-'
put(0,27,39,VERSE2,omit=[(27,0),(35,0)])
put(1,27,39,VERSE2,omit=[(27,0),(28,3),(29,0),(31,3),(32,0),(34,3),(35,0),(37,3),(38,0)])
put(2,27,39,VERSE2,omit=[(27,0),(28,3),(29,0),(31,3),(32,0),(34,3),(35,0)])
put(3,27,39,VERSE2,omit=[(27,0),(37,3),(38,0)])

for role in range(4):
 for b in [40,54]:
  for (r,bar,onset),a in list(assigned.items()):
   if r==role and bar==26:assigned[role,b,onset]=deepcopy(a)
 # Final dar belongs to the chorus; third-strophe pickup follows in tenor.
 put(role,41,41,'dar.',only=[(41,0)])

SHORT='Más a-llá, mi Je-sús pue-do ver, le ve-ré; he de ver, de mi Rey pron-to_es-ta-ré en pie de mi Se-ñor. ¡A-'
put(0,42,53,SHORT)
put(1,42,53,SHORT.replace('pron-to_es-ta-ré','es-ta-ré'),omit=[(52,0)])
put(3,42,46,'Más a-llá mi Je-sús pue-do ver, le ve-')
put(2,41,53,'Más a-llá del cie-lo_a-zul ha-bi-ta mi Je-sús, por la fe yo pue-do ver muy pron-to le ve-ré; ca-ra_a ca-ra he de ver el ros-tro de mi Rey, ya muy pron-to es-ta-ré en pie de mi Se-ñor. ¡A-',omit=[(41,0),(52,0)])
put(3,47,53,'ré; ca-ra_a ca-ra he de ver el ros-tro de mi Rey, ya muy pron-to es-ta-ré en pie de mi Se-ñor. ¡A-',omit=[(52,0)])

put(0,55,58,'dar. Sé que Tú me a-mas más, y nun-ca me has de_ol-vi-dar.')
put(1,55,58,'dar. (Se-ñor). Me_a-mas más, y nun-ca me has de_ol-vi-dar. (Se-ñor).')
put(2,55,58,'dar. (Se-ñor.) Tú me_a-mas más, y no me has de_ol-vi-dar.')
put(3,55,58,'dar. Me_a-mas más, y no me has de_ol-vi-dar.')

for key,a in assigned.items():
 n=notes[key];ly=E.SubElement(n,'lyric',number='1',placement='below');text(ly,'syllabic',a['syllabic']);text(ly,'text',a['text'])
(OUT/'assigned-lyrics.json').write_text(json.dumps([dict(role=k[0],measure=k[1],onset=k[2],**v) for k,v in sorted(assigned.items())],ensure_ascii=False,indent=2),encoding='utf-8')
E.indent(root);E.ElementTree(root).write(OUT/'underlaid.musicxml',encoding='utf-8',xml_declaration=True)
print('lyrics',len(assigned))

