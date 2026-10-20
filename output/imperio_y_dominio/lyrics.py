from pathlib import Path
import json,sys,xml.etree.ElementTree as E,unicodedata,functools,collections
sys.path.insert(0,'output/satb_lote_2026_10_19');from score_model import parse
OUT=Path(__file__).resolve().parent
PHRASES=[
 ['To-do_el im-pe-rio y_el do-mi-nio y la glo-ria se-a_a nues-tro','','Uh/Mm','Uh/Mm'],
 ['Dios, se-a_a nues-tro Dios por la_e-ter-ni-dad, A-la-','Se-a a Dios, A-la-bad por la_e-ter-ni-','Y siem-pre por la e-ter-ni-dad, por la_e-ter-ni-dad, A-la-','El im-pe-rio y_el do-mi-nio se-a_a nues-tro Dios, por la_e-ter-ni-dad,'],
 ['bad a Dios. Fuer-za, Hon-ra,','dad a nues-tro Dios,','bad, a-la-bad a nues-tro Dios,','por la_e-ter-ni-dad a-la-bad a Dios Fuer-za, Hon-ra,'],
 ['Glo-ria se-a_a nues-tro Dios, Fuer-za, Hon-ra, Glo-ria, dad-le','Fuer-za, Hon-ra, Glo-ria, se-a_a nues-tro Dios,','Fuer-za, Hon-ra, Glo-ria, se-a_a nues-tro Dios,','Glo-ria se-a_a nues-tro Dios, Fuer-za, Hon-ra, Glo-ria, A-la-'],
 ['Glo-ria, Hon-ra, Glo-ria, Glo-ria, el do-','Glo-ria, Hon-ra, Glo-ria, el do-mi-nio es de','Glo-ria, Hon-ra, el do-mi-nio es de Dios, a-la-','bad, el do-mi-nio es de Dios, a-la-ban-za_y ma-jes-'],
 ['mi-nio es de Dios.','Dios, gran-de_en ma-jes-tad, a-la-ban-za_y ma-jes-','ban-za_y ma-jes-tad,','tad, a-la-ban-za_y ma-jes-'],
 ['Gran-de_es nues-tro Dios en ma-jes-tad, el do-mi-nio es de','tad Dios en ma-jes-tad','Es muy gran-de_en ma-jes-','tad el do-mi-nio es de Dios, es muy'],
 ['Dios es gran-dio-so_en ma-jes-tad','per-fec-to_en san-ti-','tad es per-fec-to_en san-ti-dad, el do-mi-nio es de','gran-de_en ma-jes-tad y el im-pe-rio y_el do-mi-nio y la'],
 ['y la glo-ria se-a a Dios. Fuer-za, Hon-ra,','dad y la Glo-ria de Dios. Fuer-za, Hon-ra,','Dios y la Glo-ria de Dios. Fuer-za, Hon-ra,','glo-ria de Dios. Fuer-za, Hon-ra,'],
 ['Glo-ria, se-a_a nues-tro Dios, Fuer-za, Hon-ra, Glo-ria, Se-a_a nues-tro Dios,']*4,
 ['A-le-lu-ya, Ah! A-le-lu-ya,','Ah! A-le-lu-ya, Ah! ah! ah!','Ah! A-le-lu-ya, ah! ah!','Ah! ah! A-le-lu-ya ah!'],
 ['','','Él es Jeho-vá, Él es el Rey, Jeho-vá Él Rey de Glo-ria,','Es Jeho-vá, Él Rey de Glo-ria,'],
 ['Es Jeho-vá el Rey de Glo-ria,','Él es Jeho-vá, Él es el Rey Jeho-vá el Rey de Glo-ria,','Po-de-ro-so, ma-jes-tuo-so, es el Rey de Glo-ria,','Fuer-za, Hon-ra, Glo-ria, Hon-ra, Fuer-za, Hon-ra, Glo-ria,'],
 ['Glo-ria, Hon-ra, Glo-ria_a Dios,']*4,
 ['Glo-ria, Hon-ra, Glo-ria_a Dios,','Glo-ria, Hon-ra, Glo-ria_a Dios,','Glo-ria, Hon-ra, Glo-ria_a Dios,','Glo-ria, Hon-ra, Glo-ria_a Dios, A-la-'],
 ['A-la-bad a Dios con el co-ra-zón por la_e-ter-ni-dad, Él, es nues-tro Dios.','Te_a-do-ra-mos, te_a-do-ra-mos, Dios e-ter-no, Dios e-ter-no,','A-la-bad, a-la-bad, a-la-bad a-la-bad,','bad a Dios, a-la-bad a Dios, a-la-bad a Dios, a-la-bad a Dios, a-la-'],
 ['A-la-bad a Dios, siem-pre por la_e-ter-ni-dad, siem-pre','E-res dig-no de a-do-ra-ción por siem-pre','A-la-bad, a-la-bad, a-la-bad a Dios, a Dios,','bad a Dios, a-la-bad de co-ra-zón, A-la-bad, a-la-'],
 ['A-la-bad a Dios con el co-ra-zón por la_e-ter-ni-dad, Él, es nues-tro Dios,','Te_a-do-ra-mos, te_a-do-ra-mos, Dios e-ter-no, Dios e-ter-no,','A-la-bad, a-la-bad, a-la-bad, a-la-bad,','bad a Dios, a-la-bad a Dios, a-la-bad a Dios, a-la-bad a Dios, a-la-'],
 ['A-la-bad a Dios, siem-pre por la_e-ter-ni-dad, A-la-bad a','E-res dig-no de a-do-ra-ción. A-la-bad a','a-la-bad, a-la-bad, a-la-bad a Dios, a-la-bad a','bad a Dios, a-la-bad de co-ra-zón, A-la-bad a'],
 ['Dios, mag-ní-fi-co Crea-dor. Po-de-ro-so, ma-jes-tuo-so e-res Tú, Se-ñor.','Dios, mag-ní-fi-co Crea-dor. Po-de-ro-so, ma-jes-tuo-so e-res Tú, Se-ñor, Jeho-vá.','Dios, mag-ní-fi-co Crea-dor. Po-de-ro-so, ma-jes-tuo-so e-res Tú, Se-ñor.','Dios, mag-ní-fi-co Crea-dor. Po-de-ro-so, ma-jes-tuo-so e-res Tú, Se-ñor,'],
 ['Te_a-do-ra-mos, te can-ta-mos por tu_a-mor y gran bon-dad.']*4,
 ['A-mén, a-','A-mén, a-mén, a-','A-mén, a-mén, a-','A-mén, a-mén, a-'],
 ['mén, a-mén, a-','mén, a-mén, a-mén, a-mén, a-mén, a-mén, a-','mén, a-mén, a-mén,','mén, a-mén, a-mén, a-mén, a-mén, a-mén, a-'],
 ['mén, a-mén, a-mén.','mén, a-mén, a-mén, a-mén.','a-mén, a-mén, a-mén.','mén, a-mén, a-mén.']
]
def norm(s):return ''.join(c.lower() for c in unicodedata.normalize('NFD',s) if c.isalnum())
def atoms(s):
 result=[]
 for word in s.split():
  chunks=word.split('-')
  for i,ch in enumerate(chunks):
   if ch:result.append(dict(text=ch.replace('_','‿'),syllabic='single' if len(chunks)==1 else 'begin' if i==0 else 'end' if i==len(chunks)-1 else 'middle'))
 return result
root=E.parse(OUT/'aligned.musicxml').getroot();parts=parse(root);data=json.loads((OUT/'layout.json').read_text(encoding='utf-8'));mapped=json.loads((OUT/'mapped.json').read_text(encoding='utf-8'))['events'];assigned=[];issues=[]
for si,sy in enumerate(data['systems']):
 for role in range(4):
  aa=atoms(PHRASES[si][role]);cs=sorted([c for c in data['chars'] if c['page']==sy['page'] and c['system']==sy['system'] and c['role']==role and abs(c['size']-13.02)<.1],key=lambda c:c['x0'])
  letters=[dict(c,text=ch) for c in cs for ch in norm(c['text'])]
  actual=''.join(c['text'] for c in letters);expected=''.join(norm(a['text']) for a in aa)
  assert actual==expected,(si,role,actual,expected)
  pos=0
  for a in aa:
   count=len(norm(a['text']));chunk=letters[pos:pos+count];pos+=count;a['x']=(chunk[0]['x0']+chunk[-1]['x1'])/2
  candidates=[e for e in mapped if e['page']==sy['page'] and e['system']==sy['system'] and e['role']==role and not e['chord']]
  candidates.sort(key=lambda e:e['absolute'])
  assert len(aa)<=len(candidates),(si,role,len(aa),len(candidates))
  @functools.lru_cache(None)
  def best(i,j):
   if i==len(aa):return 0,()
   if len(candidates)-j<len(aa)-i:return float('inf'),()
   cost,seq=best(i,j+1)
   e=candidates[j];distance=abs(e['x']+3.3-aa[i]['x']);tail,chosen=best(i+1,j+1)
   if distance**2+tail<cost:cost=distance**2+tail;seq=(j,)+chosen
   return cost,seq
  _,plan=best(0,0)
  for a,j in zip(aa,plan):
   e=candidates[j];distance=abs(e['x']+3.3-a['x']);node=root.findall('part')[role].findall('measure')[e['measure']-1].findall('note')[e['index']]
   assert node.find('lyric') is None
   ly=E.SubElement(node,'lyric',number='1',placement='below');E.SubElement(ly,'syllabic').text=a['syllabic'];E.SubElement(ly,'text').text=a['text']
   assigned.append(dict(role=role,measure=e['measure'],onset=e['onset'],index=e['index'],distance=distance,**a))
   if distance>13:issues.append(dict(system=si,role=role,bar=e['measure'],onset=e['onset'],text=a['text'],distance=round(distance,2)))
for part in root.findall('part'):
 prev=None
 for ly in part.findall('.//lyric'):
  state=ly.find('syllabic')
  if prev in ['begin','middle'] and state.text in ['single','begin']:state.text='end' if state.text=='single' else 'middle'
  prev=state.text
E.indent(root);E.ElementTree(root).write(OUT/'underlaid.musicxml',encoding='utf-8',xml_declaration=True)
(OUT/'lyric-alignment.json').write_text(json.dumps(dict(assigned=assigned,issues=issues),ensure_ascii=False,indent=2),encoding='utf-8')
print('lyric notes',len(assigned),'distant anchors',issues)
