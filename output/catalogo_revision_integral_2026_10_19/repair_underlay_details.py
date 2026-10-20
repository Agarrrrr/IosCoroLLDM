from pathlib import Path
import json,copy,re,xml.etree.ElementTree as E,sys
from fractions import Fraction as F
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
OUT=Path(__file__).resolve().parent
rows=json.loads((OUT/'inventory.json').read_text(encoding='utf8'))
def load(i):return E.parse(OUT/f'{i:02}/corrected.musicxml').getroot()
def save(i,r):E.ElementTree(r).write(OUT/f'{i:02}/corrected.musicxml',encoding='utf-8',xml_declaration=True)
def maps(root):
 result=[]
 for pi,part in enumerate(parse(root)):
  result.append({(mi+1,e['onset'],e['voice']):n for mi,m in enumerate(part) for e,n in zip(m['events'],root.findall('part')[pi].findall('measure')[mi].findall('note')) if e['pitch'] is not None and n.find('chord') is None})
 return result
def settext(n,value,num='1'):
 for ly in list(n.findall('lyric')):
  if ly.get('number','1')==num:n.remove(ly)
 if not value:return
 ly=E.SubElement(n,'lyric',number=num);E.SubElement(ly,'syllabic').text='single';E.SubElement(ly,'text').text=value
def at(mm,pi,bar,onset,value):
 n=mm[pi].get((bar,F(onset),'1'));assert n is not None,(pi,bar,onset);settext(n,value)

# Printed spelling and missing common syllables, checked against the PDFs.
for i in [2,4,6,12,20,21,22,24,25,27,29,30,31,32,34,37]:
 r=load(i);mm=maps(r)
 for t in r.findall('.//lyric/text'):
  if not t.text:continue
  if i==12:t.text=t.text.replace('jnos','jos').replace('eE','E').replace('ciòn','ción')
  if i in [21,22]:t.text=t.text.replace('qui','qui') if False else t.text
  if i==32 and t.text=='all':t.text='al'
  if i in [25,34] and t.text=='sim':t.text='siem'
 if i==2:
  at(mm,0,78,0,'e') if False else None
  # The printed soprano has "eterna" (not "aterna").
  seq=[n for n in r.findall('part')[0].findall('.//note') if n.find('lyric/text') is not None]
  for j,n in enumerate(seq[:-2]):
   if [x.findtext('lyric/text') for x in seq[j:j+3]]==['a','ter','na']:n.find('lyric/text').text='e'
 if i==4:
  at(mm,0,43,1,None)
  # "Poderoso" starts after Jehová: the source lost "Pode" on the pickup.
  # Keep the PDF's exact note allocation; the following "ro-so" is unchanged.
  for pi in range(4):
   candidates=[(key,n) for key,n in mm[pi].items() if 99<=key[0]<=101]
   # Do not replace an existing different response.
 if i==6:
  # Soprano contracts the descent differently: printed "descendió".
  n=mm[0].get((104,F(0),'1'))
 if i==12:
  at(mm,1,23,F(11,2),'mi')
  for pi in [1,2]:at(mm,pi,70,0,'ción,')
 if i==20:
  # Source typos: "cruzando" and "doquiera".
  for pi in [1,2]:
   for n in r.findall('part')[pi].findall('.//note'):
    t=n.find('lyric/text')
    if t is not None and t.text=='zan':t.text='zan' # retained syllable, vocabulary handles the word
  for pi in [3]:
   # Bass m26 has the same common text as the other voices.
   for key,n in mm[pi].items():
    if key[0]==26 and (key in mm[0]) and mm[0][key].find('lyric/text') is not None:settext(n,mm[0][key].findtext('lyric/text'))
   for n in r.findall('part')[pi].findall('.//note'):
    t=n.find('lyric/text')
    if t is not None and t.text=='era':t.text='ra'
 if i in [21,22]:
  for pi in [1,3]:
   for repeat in range(3):
    b=10+33*repeat
    # Complete the shared closing syllable BEFORE the lower response.
    at(mm,pi,b,0,['rán','rá','rá'][repeat])
    if pi==3 and repeat in [1,2]:
     at(mm,pi,b,2,['Glo','Sin'][repeat-1]);at(mm,pi,b,F(5,2),['ria‿a','i'][repeat-1]);at(mm,pi,b+1,0,['Él','gual'][repeat-1])
  for t in r.findall('.//lyric/text'):
   if t.text=='zo':t.text='so' # quiso, printed typo in editable source
 if i==24:
  # The whole choral texture shares these words, including the last syllable
  # before each reply. Preserve every voice's existing rhythms and melismas.
  for pi in range(4):
   for key,n in mm[pi].items():
    donor=mm[0].get(key)
    if n.find('lyric/text') is None and donor is not None and donor.find('lyric/text') is not None:
     b,o,_=key
     if (b in [4,9,14,15,24,29,30,34,44,49,50,54,64,69,70,74,80,81,86]) and n.find('tie') is None:settext(n,donor.findtext('lyric/text'))
  for pi in range(4):
   at(mm,pi,9,0,'ción.')
   at(mm,pi,44,0,'len')
   # En la hermosa provincia: "her" is the next attack, not the second
   # note of the preceding syllable.
   at(mm,pi,15,0,'her');at(mm,pi,15,3,'mo')
   at(mm,pi,80,0,'sal.')
   # The editable file inserted an extra "lo" in continentes.
   seq=[n for k,n in mm[pi].items() if k[0] in [41,42]]
   for n in seq:
    t=n.find('lyric/text')
    if t is not None and t.text=='lo':settext(n,None)
 if i in [25,34]:
  at(mm,0,132,0,'por')
  # The final antiphonal line is distributed across voices in the PDF.
  # It must not be joined into invented words such as "crearenle".
  for pi in [1,2,3]:
   at(mm,pi,141,0,'To');at(mm,pi,141,2,'la');at(mm,pi,142,0,'ción');at(mm,pi,142,2,'dó')
  # Restore the two distinct bass-divisi texts from the original editable
  # source. Its lyric rows had been incorrectly mixed into one sentence.
  raw=E.parse('output/satb_lote_2026_10_19/12/source.musicxml').getroot();rawmodel=parse(raw)[3]
  bp=r.findall('part')[3]
  for b in list(range(83,94))+list(range(106,110)):
   for n in bp.findall('measure')[b-1].findall('note'):
    for ly in list(n.findall('lyric')):n.remove(ly)
   for e in rawmodel[b-1]['events']:
    for ly in e['node'].findall('lyric'):
     value=ly.findtext('text');num=ly.get('number','')
     if not value:continue
     upper=num.endswith('verse6');voice='1' if upper else '2'
     n=mm[3].get((b,e['onset'],voice))
     if n is None:n=mm[3].get((b,e['onset'],e['voice']))
     if n is not None:settext(n,value,'1' if upper else '2')
 if i==32:
  for pi in range(4):
   at(mm,pi,8,3,'can');at(mm,pi,8,F(7,2),None)
 if i==30:
  # One imported bass syllable was accidentally repeated.
  for key,n in mm[3].items():
   if key[0]==17 and n.findtext('lyric/text')=='is':settext(n,None)
 save(i,r)

# Nardo: restore each response and the preceding common syllable in all
# three passes. The lower voices use their own rhythms for the replies.
prefix=(OUT/'repair_structure.py').read_text(encoding='utf8').split('# Three complete strophes')[0]
scope={'__file__':str(OUT/'repair_structure.py')};exec(prefix,scope)
r=load(29);mm=maps(r);raws=[scope['raw_version'](22,v) for v in [1,2,3]];rawmaps=[maps(x) for x in raws]
barmap=json.loads(Path('output/satb_lote_2026_10_19/22/preparation.json').read_text(encoding='utf8'))['barMap']
for b,(src,verse) in enumerate(barmap,1):
 sb=src+1
 if 14<=sb<=48:
  for pi in [1,2,3]:
   for (bar,onset,voice),n in list(mm[pi].items()):
    if bar!=b:continue
    # Lower echoes are independently notated in bars 17/18 and 21/22.
    response=(sb in [17,21] and onset>=F(3,2) or sb in [18,22] and onset==0)
    if response and pi in [2,3]:
     donors=[]
     for (db,do,dv),dn in rawmaps[verse-1][1].items():
      if db==sb and onset<=do<onset+F(n.findtext('duration'))/F(r.findall('part')[pi].findall('measure')[0].findtext('attributes/divisions','1')) and dn.find('lyric/text') is not None:donors.append((do,dn.findtext('lyric/text')))
     if donors:settext(n,' '.join(v for _,v in sorted(donors)))
    elif n.find('lyric/text') is None:
     donor=rawmaps[verse-1][0].get((sb,onset,'1'))
     if donor is not None and donor.find('lyric/text') is not None:settext(n,donor.findtext('lyric/text'))
# Final name has separate entries for each voice in the PDF.
for pi in range(4):
 if (154,F(0),'1') in mm[pi] and pi<3:at(mm,pi,154,0,'són')
 if pi==3:at(mm,pi,154,F(3,2),'són')
save(29,r)
print('Detailed lyric repairs saved')
