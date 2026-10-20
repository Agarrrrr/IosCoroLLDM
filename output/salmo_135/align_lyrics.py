import sys,json,collections,unicodedata
from pathlib import Path
import pdfplumber
sys.path.insert(0,'tools/verovio_pilot')
from extract_cantico_moises import staff_groups
OUT=Path('output/salmo_135')
def norm(s):return ''.join(c for c in unicodedata.normalize('NFD',s.casefold()) if c.isalpha() and not unicodedata.combining(c))
def run():
 reading=json.loads((OUT/'pdf-reading.json').read_text(encoding='utf-8'));events=reading['events'];logs=[]
 # The final Bass chord has two heads at the same time, not two whole measures.
 last=None
 for e in events:
  if e['role']==3 and e['measure']==45:e['onset']=0;e['chord']=last is not None;last=e
  e['lyrics']=[]
 with pdfplumber.open(OUT/'original.pdf') as pdf:
  for pi,page in enumerate(pdf.pages,1):
   staves=staff_groups(page)
   for system in [s for s in reading['systems'] if s['page']==pi]:
    for role in range(4):
     si=system['system']*4+role;staff=staves[si];bottom=staves[si+1][0]-5 if si+1<len(staves) else 835
     cs=sorted([c for c in page.chars if ('TimesNewRomanPSMT' in c['fontname'] or 'OpusTextStd' in c['fontname'] and c['text']=='_') and abs(c['size']-13.02)<.1 and staff[-1]+4<c['top']<bottom and not c['text'].isspace()],key=lambda c:c['x0'])
     row=sorted([e for e in events if e['page']==pi and e['system']==system['system'] and e['role']==role and not e['rest'] and not e.get('chord')],key=lambda e:(e['measure'],e['onset']))
     if not cs:continue
     states={0:(0,[])}
     for e in row:
      nxt={}
      def update(j,cost,path):
       if j not in nxt or cost<nxt[j][0]:nxt[j]=(cost,path)
      for j,(cost,path) in states.items():
       update(j,cost+4,path+[None])
       for k in range(j+1,min(j+25,len(cs))+1):
        chunk=cs[j:k];dx=abs((chunk[0]['x0']+chunk[-1]['x1'])/2-e['x']-3.2)
        if dx>20:continue
        gaps=[max(0,b['x0']-a['x1']) for a,b in zip(chunk,chunk[1:])]
        if gaps and max(gaps)>6:break
        update(k,cost+dx*dx/8+sum(max(0,g-1.5)*4 for g in gaps)+.2,path+[(j,k)])
      states=nxt
     assert len(cs) in states,(pi,role,system['first'],max(states),len(cs))
     cost,path=states[len(cs)]
     for e,span in zip(row,path):
      if span:e['rawLyric']=''.join(unicodedata.normalize('NFKC',c['text']) for c in cs[span[0]:span[1]])
     logs.append(dict(page=pi,role=role,first=system['first'],cost=cost,text=' '.join(e.get('rawLyric','.') for e in row)))
 (OUT/'lyric-debug.json').write_text(json.dumps(reading,ensure_ascii=False,indent=2),encoding='utf-8')
 # The printed syllable is left aligned at the beginning of each long run.
 for role,bar,start in [(0,28,2),(1,22,0),(2,26,0)]:
  row=[e for e in events if e['role']==role and e['measure']==bar and not e['rest']]
  src=next((e for e in row if 'bad' in e.get('rawLyric','').lower()),None);dst=next(e for e in row if e['onset']==start)
  if src is None:continue
  if src is not dst:dst['rawLyric']=src.pop('rawLyric')
 vocab='por alabad a nuestro dios los redimidos del señor le con júbilo cantemos al nueva canción todo el corazón para siempre porque grande es la inmensa muchedumbre cante gran cantad fuerte voz viva jehova y bendita roca de mi salvación su santo nombre'.split()
 vocab=sorted({norm(w) for w in vocab},key=lambda w:-len(w))
 syllables={norm(w.replace('-','')):w.split('-') for w in 'A-la-bad nues-tro re-di-mi-dos Se-ñor jú-bi-lo can-te-mos nue-va can-ción to-do co-ra-zón pa-ra siem-pre por-que gran-de in-men-sa mu-che-dum-bre can-te can-tad fuer-te Vi-va Jeho-va ben-di-ta Ro-ca sal-va-ción San-to nom-bre'.split()}
 for role in range(4):
  row=[e for e in events if e['role']==role and e.get('rawLyric')]
  chars=[(e,c) for e in row for c in e['rawLyric']];letters=[(i,c) for i,(_,c) in enumerate(chars) if norm(c)];stream=''.join(norm(c) for _,c in letters);states={0:(0,[])}
  for i in range(len(stream)):
   if i not in states:continue
   cost,path=states[i]
   for word in vocab:
    if stream.startswith(word,i):
     j=i+len(word)
     if j not in states or cost+1<states[j][0]:states[j]=(cost+1,path+[(i,j,word)])
  assert len(stream) in states,(role,max(states),stream[max(states):max(states)+100])
  for start,end,word in states[len(stream)][1]:
   a=letters[start][0];b=letters[end-1][0]+1
   while b<len(chars) and not norm(chars[b][1]) and chars[b][1]!='_':b+=1
   # Printed hyphens are vector rules, so reconstruct word syllables from
   # their actual letters. This keeps consonants with their sung vowel and
   # prevents splitting "bad" among the first notes of a long melisma.
   pieces=syllables.get(word,[word]);cursor=start
   for gi,piece in enumerate(pieces):
    count=len(norm(piece));sa=letters[cursor][0];sb=letters[cursor+count-1][0]+1
    if gi==len(pieces)-1:sb=b
    e=chars[sa][0];value=''.join(c for _,c in chars[sa:sb] if c!='_')
    e['lyrics'].append(dict(text=value,syllabic='single' if len(pieces)==1 else 'begin' if gi==0 else 'end' if gi==len(pieces)-1 else 'middle',join=cursor>0 and chars[sa-1][1]=='_',word=word))
    cursor+=count
 # Keep the source's contracted "Jeho" on its original single note.
 # Hyphens join the written syllables of each word; spaces separate words.
 (OUT/'lyric-alignment.json').write_text(json.dumps(logs,ensure_ascii=False,indent=2),encoding='utf-8')
 (OUT/'aligned-reading.json').write_text(json.dumps(reading,ensure_ascii=False,indent=2),encoding='utf-8')
 print('Lyrics',sum(bool(e['lyrics']) for e in events))
 for l in logs:print(l['page'],l['role'],l['first'],round(l['cost'],1),l['text'])
if __name__=='__main__':run()
