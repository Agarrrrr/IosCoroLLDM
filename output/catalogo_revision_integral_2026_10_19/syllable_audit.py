from pathlib import Path
import json,ast,re,unicodedata,collections,copy,xml.etree.ElementTree as E
import sys
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
OUT=Path(__file__).resolve().parent
def norm(s):return ''.join(c for c in unicodedata.normalize('NFD',s.casefold()) if c.isalpha() and not unicodedata.combining(c))
def text(ly):return ''.join(t.text or '' for t in ly.findall('text'))
def words_from_chains(root):
 result=[]
 for p in root.findall('part'):
  word=''
  for ly in p.findall('.//lyric'):
   value=text(ly);kind=ly.findtext('syllabic','single')
   if not value:continue
   if kind in ['begin','single']:word=value
   else:word+=value
   if kind in ['end','single']:
    if not any(c in word for c in '_‿\ue550\ue551\ue552 ') and norm(word):result.append(norm(word))
 return result
def load_vocab(rows):
 vocab=set('a al algo ante aquí así aun aunque ay bajo bien con cual cuando de del desde donde dos el ella ellas ello ellos en entre era es esa ese eso esta fue ha hay he hoy la las le les lo los me mi mis muy ni no nos o oh os para pero por pues que quien qué se si sin so soy su sus te ti tu tus un una uno unos va ve ven ves vi ya yo uh ah mm amén'.split());vocab={norm(w) for w in vocab}
 for f in Path('tools/verovio_pilot').glob('*.py'):
  if not any(s in f.name for s in ['words','underlay']):continue
  try:tree=ast.parse(f.read_text(encoding='utf-8'))
  except SyntaxError:continue
  for n in ast.walk(tree):
   if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and n.func.attr=='split' and isinstance(n.func.value,ast.Constant) and isinstance(n.func.value.value,str) and len(n.func.value.value.split())>8:
    vocab.update(norm(w) for w in n.func.value.value.split() if w.isalpha())
 for f in Path('output/verovio_pilot_support').glob('*/word-diagnostics.json'):
  data=json.loads(f.read_text(encoding='utf-8'));vocab.update(norm(w['word']) for w in data.get('words',[]) if w.get('word'))
 for r in rows:
  if r['index'] in [2,3,4,6,12,20,21,22,24,25,27,29,32,34,37]:continue
  vocab.update(w for w in words_from_chains(E.parse(Path(r['work'])/'source.musicxml').getroot()) if len(w)>2)
 if (OUT/'extra-vocabulary.txt').exists():vocab.update(norm(w) for w in (OUT/'extra-vocabulary.txt').read_text(encoding='utf-8').split())
 vocab.difference_update({'lavoz','todoser','alque','algran','dame','have','lavida','ala','dela','mora','cantenmos','dioses'})
 return vocab
def atoms_for(part,number=None):
 atoms=[]
 container=E.Element('score-partwise');container.append(part);model=parse(container)[0]
 for mi,m in enumerate(part.findall('measure'),1):
  ordered=sorted(zip(model[mi-1]['events'],m.findall('note')),key=lambda pair:(pair[0]['onset'],int(pair[0]['voice'])))
  for event,n in ordered:
   if n.find('chord') is not None:continue
   ly=next((l for l in n.findall('lyric') if number is None or l.get('number','1')==number),None)
   if ly is None or not text(ly):continue
   raw=text(ly).strip()
   raw=re.sub(r'\b(lavoz|todoser|Alque|algran)\b',lambda m:{'lavoz':'la voz','todoser':'todo ser','Alque':'Al que','algran':'al gran'}[m[0]],raw)
   raw=raw.replace('\ue550','‿').replace('\ue551','‿').replace('\ue552','‿').replace('_','‿')
   raw=re.sub(r'(?<=[a-záéíóúñü])(?=[A-ZÁÉÍÓÚÑÜ])',' ',raw)
   raw=re.sub(r'([,;:.!?])(?=[A-Za-zÁÉÍÓÚÑÜáéíóúñü])',r'\1 ',raw)
   segments=re.split(r'([\s‿]+)',raw);previous_boundary=False;separator=''
   for seg in segments:
    if not seg:continue
    if re.fullmatch(r'[\s‿]+',seg):previous_boundary='‿' in seg;separator=seg;continue
    if not norm(seg):continue
    atoms.append(dict(raw=seg,key=norm(seg),node=n,lyric=ly,bar=mi,onset=str(event['onset']),hardBefore=previous_boundary,separator=separator))
    previous_boundary=False;separator=''
 return atoms
PHRASES=['Dios de dioses','grandes','a la','de la','amor a','ha venido','vida me','nos ama','mi vivir','nueva vida','Dios es','Ángel es','todo ser','al gran','al que','siempre alabad','los mares','nuestro gran Rey','guía','a su','de Dios','para dar','puede imaginar','y el deseo']
def segment(atoms,vocab):
 count=len(atoms);states={count:(0,[])}
 for i in range(count-1,-1,-1):
  best=(18+states[i+1][0],[(i,i+1,False)])
  word=''
  for j in range(i,min(count,i+9)):
   if j>i:
    if atoms[j]['hardBefore'] or re.search(r'[,;:.!?)]$',atoms[j-1]['raw']):break
    if atoms[j]['raw'].lstrip('¿¡(')[:1].isupper() and not (atoms[j-1]['raw'].isupper() and atoms[j]['raw'].isupper()):break
   word+=atoms[j]['key']
   if word in vocab:
    cost=1+states[j+1][0]
    if cost<best[0]:best=(cost,[(i,j+1,True)])
  # Reference phrases settle ambiguous short Spanish words without changing
  # their printed syllables or their allocation to notes.
  for phrase in PHRASES:
   desired=[norm(w) for w in phrase.split()];groups=[];a=i;okay=True
   for w in desired:
    value='';b=a
    while b<count and len(value)<len(w):value+=atoms[b]['key'];b+=1
    if value!=w:okay=False;break
    groups.append((a,b,True));a=b
   if okay and a>i and 0.1*len(groups)+states[a][0]<best[0]:best=(0.1*len(groups)+states[a][0],groups)
  states[i]=best
 groups=[];i=0
 while i<count:
  selected=states[i][1];groups.extend(selected);i=selected[-1][1]
 return groups

def run():
 rows=json.loads((OUT/'inventory.json').read_text(encoding='utf-8'));vocab=load_vocab(rows);targets={2,3,4,6,12,20,21,22,24,25,27,29,30,31,32,34,37};reports=[];review=[];unknown=[]
 for r in rows:
  p=Path(r['work']);file=p/'corrected.musicxml' if (p/'corrected.musicxml').exists() else p/'source.musicxml';root=E.parse(file).getroot()
  if r['index'] not in targets:
   reports.append(dict(index=r['index'],name=r['name'],action='Existing syllabic markers retained',words=len(words_from_chains(root))));continue
  changed=0;words=[]
  for pi,part in enumerate(root.findall('part')):
   atoms=[];groups=[]
   for number in sorted({l.get('number','1') for l in part.findall('.//lyric') if text(l)}):
    aa=atoms_for(part,number);offset=len(atoms);groups.extend((i+offset,j+offset,k) for i,j,k in segment(aa,vocab));atoms.extend(aa)
   kinds=collections.defaultdict(list);partwords=[]
   for groupid,(i,j,known) in enumerate(groups):
    group=atoms[i:j];word=''.join(a['raw'] for a in group);partwords.append(word)
    for a in group:a['wordGroup']=groupid
    if not known:
     context=' '.join(a['raw'] for a in atoms[max(0,i-5):min(len(atoms),j+7)])
     unknown.append(dict(index=r['index'],part=pi,bar=group[0]['bar'],token=word,context=context))
    nodeids=[]
    for a in group:
     if not nodeids or nodeids[-1] is not a['lyric']:nodeids.append(a['lyric'])
    for ni,ly in enumerate(nodeids):
     kinds[ly].append((ni>0,ni<len(nodeids)-1))
   for ly,flags in kinds.items():
    before=flags[0][0];after=flags[-1][1];value='middle' if before and after else 'end' if before else 'begin' if after else 'single';old=ly.find('syllabic')
    if old is None:old=E.Element('syllabic');ly.insert(0,old)
    if old.text!=value:changed+=1;old.text=value
   # Some source lyrics contain spaces inside a word on the same note.
   # Replace only those internal spaces with written hyphens. Keep real
   # word boundaries and explicit sinalefas as spaces and elisions.
   byl=collections.defaultdict(list)
   for atom in atoms:byl[atom['lyric']].append(atom)
   for ly,aa in byl.items():
    value=''
    for j,a in enumerate(aa):
     if j:value+=('-' if aa[j-1]['wordGroup']==a['wordGroup'] else '‿' if a['hardBefore'] else ' ')
     value+=a['raw']
    oldvalue=text(ly)
    if value!=oldvalue:
     for child in list(ly):
      if child.tag in ['text','elision']:ly.remove(child)
     E.SubElement(ly,'text').text=value;changed+=1
   words.append(partwords)
  if changed or r.get('structural'):
   E.ElementTree(root).write(p/'corrected.musicxml',encoding='utf-8',xml_declaration=True);r['changed']=True;r['syllabicEdits']=changed
  reports.append(dict(index=r['index'],name=r['name'],markersChanged=changed,partsWords=words));review.append('\n### '+str(r['index'])+' '+r['name']+'\n'+'\n'.join(f'VOICE {i}: '+ ' '.join(w) for i,w in enumerate(words)))
 (OUT/'inventory.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8');(OUT/'syllable-audit.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8');(OUT/'unknown-words.json').write_text(json.dumps(unknown,ensure_ascii=False,indent=2),encoding='utf-8');(OUT/'word-review.txt').write_text('\n'.join(review),encoding='utf-8')
 print('Vocabulary',len(vocab),'unresolved',len(unknown),'unique',len({norm(u['token']) for u in unknown}))
 counts=collections.Counter(norm(u['token']) for u in unknown);print(counts)
 for r in reports:
  if 'markersChanged' in r:print(r['index'],r['name'],r['markersChanged'])
if __name__=='__main__':run()
