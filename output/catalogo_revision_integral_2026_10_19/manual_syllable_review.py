from pathlib import Path
import xml.etree.ElementTree as E,json
OUT=Path(__file__).resolve().parent
exceptions=[]
def kind(ly,value):
 e=ly.find('syllabic')
 if e is None:e=E.SubElement(ly,'syllabic')
 e.text=value
for i in [21,22]:
 f=OUT/f'{i:02}/corrected.musicxml';r=E.parse(f).getroot()
 for pi in [0,2]:
  for b in [1,34,67]:
   ls=r.findall('part')[pi].findall('measure')[b-1].findall('.//lyric')
   assert [l.findtext('text') for l in ls]==['I','ma']
   kind(ls[0],'begin');kind(ls[1],'end')
   exceptions.append(dict(index=i,part=pi,bar=b,reason='The main word is passed to the lower voice while this voice begins the parenthetical response; I-ma is the printed fragment.'))
 f.write_bytes(E.tostring(r,encoding='utf-8',xml_declaration=True))
for i in [25,34]:
 f=OUT/f'{i:02}/corrected.musicxml';r=E.parse(f).getroot()
 for pi,p in enumerate(r.findall('part')):
  for b in [141,142]:
   for l in p.findall('measure')[b-1].findall('.//lyric'):
    t=l.find('text')
    if t is None:continue
    if pi==0:t.text={'da':'-da','crea':'crea-','a':'a-','ren':'-ren-'}.get(t.text,t.text)
    else:t.text={'To':'To-','ción':'-ción','dó':'-dó-'}.get(t.text,t.text)
    kind(l,'single')
  exceptions.append(dict(index=i,part=pi,bars=[141,142],reason='The PDF divides Toda la creación adórenle between alternating voices. Written edge hyphens retain those fragments without joining different words.'))
 f.write_bytes(E.tostring(r,encoding='utf-8',xml_declaration=True))
(OUT/'manual-reviewed-fragments.json').write_text(json.dumps(exceptions,ensure_ascii=False,indent=2),encoding='utf8')
print('PDF antiphonal fragments reviewed:',len(exceptions))
