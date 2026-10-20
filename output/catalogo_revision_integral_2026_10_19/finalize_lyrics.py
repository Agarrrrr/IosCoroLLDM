from pathlib import Path
import json,xml.etree.ElementTree as E,copy,sys
from fractions import Fraction as F
sys.path.insert(0,'output/satb_lote_2026_10_19')
from score_model import parse
OUT=Path(__file__).resolve().parent
def txt(n):return n.findtext('lyric/text','')
def put(n,value):
 for ly in list(n.findall('lyric')):n.remove(ly)
 if value is not None:E.SubElement(E.SubElement(n,'lyric',number='1'),'text').text=value
def nodemap(r):return [{(b+1,e['onset'],e['voice']):n for b,m in enumerate(p) for e,n in zip(m['events'],r.findall('part')[pi].findall('measure')[b].findall('note')) if e['pitch'] is not None and n.find('chord') is None} for pi,p in enumerate(parse(r))]
for i in [2,4,6,12,20,21,22,24,25,29,30,32,34]:
 p=OUT/f'{i:02}/corrected.musicxml';r=E.parse(p).getroot();mm=nodemap(r)
 def at(pi,b,o,v):
  key=(b,F(o),'1');assert key in mm[pi],(i,pi,b,o);put(mm[pi][key],v)
 if i==2:
  for t in r.findall('.//lyric/text'):
   if t.text:t.text=t.text.replace('al-gran','al gran')
  at(0,78,F(5,2),'ria‿e')
 if i==4:
  at(2,43,1,None)
  # In the PDF these two syllables start under the preceding held Jehová.
  # The soprano has no new attack there: sing the text on the available
  # note rather than dropping the beginning of "Poderoso".
  at(0,100,0,'vá, Po-de')
 if i==6:
  at(0,104,F(11,4),'des-cen')
 if i==12:
  for t in r.findall('.//lyric/text'):
   if t.text:t.text=t.text.replace('tu‿eE','tu‿E').replace('tu‿e‿E','tu‿E')
  # Source has both "e" and "E" on the same attack; preserve one.
  for pi in range(4):
   for key,n in mm[pi].items():
    t=n.find('lyric/text')
    if t is not None and t.text in ['e‿E','e E','e-E']:t.text='E'
 if i==20:
  # Bass closing "mares" precedes its own "cruzando".
  at(3,26,0,'ma');at(3,26,F(1,2),'res')
 if i in [21,22]:
  for pi in range(4):
   for rep in range(3):
    for b,o in [(16,2),(82, F(1,2))] if False else []:pass
   at(pi,16,2,'zo')
   at(pi,82,F(1,2),'zo')
   at(pi,45,2,'so‿en')
 if i==24:
  for pi in range(4):
   # "her" begins at the second pickup note; the long following
   # note carries it over a tie before "mo-sa".
   for b in [14,34,54,85]:
    for key,n in mm[pi].items():
     if key[0]==b and key[1]==F(9,2):put(n,'la her')
   for b in [15,35,55,86]:
    at(pi,b,0,None);at(pi,b,3,'mo')
 if i==25 or i==34:
  # Native source has a typo in "amanecer" (a-ma-na-cer).
  for t in r.findall('.//lyric/text'):
   if t.text=='ma-na':t.text='ma-ne'
  # The source spells the final responses across alternating rests.
  # Hyphens are explicit where a word is interrupted by another voice.
  for b,o,v in [(141,1,'da'),(141,3,'crea'),(142,1,'a'),(142,3,'ren')]:at(0,b,o,v)
 if i==29:
  at(0,154,0,None);at(2,154,0,None)
  at(2,153,F(3,2),'són')
  # Bass has a sustained common "miró", with no separate reply here.
  at(3,18,0,None)
 if i==30:
  for key,n in mm[3].items():
   if key[0]==17 and txt(n)=='cris-is':put(n,'cris')
 p.write_bytes(E.tostring(r,encoding='utf-8',xml_declaration=True))
print('Final text corrections saved')
