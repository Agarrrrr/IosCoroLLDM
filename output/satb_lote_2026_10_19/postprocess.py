from pathlib import Path
import json,xml.etree.ElementTree as E,re
from inventory import OUT
from prepare_batch import text

def run():
    import sys
    rows=json.loads((OUT/'prepared-index.json').read_text(encoding='utf8'))
    selected={int(x) for x in sys.argv[1:]} if len(sys.argv)>1 else None
    for record in rows:
        i=record['index']
        if selected is not None and i not in selected:continue
        path=OUT/f'{i:02d}'/'prepared.musicxml';root=E.parse(path).getroot();changed=0
        # Metronome directions from Sibelius sometimes contain only engraving.
        for d in root.findall('.//direction'):
            met=d.find('direction-type/metronome')
            if met is None:continue
            bpm=met.findtext('per-minute','')
            if not re.fullmatch(r'\d+(?:\.\d+)?',bpm.strip()):continue
            unit={'whole':4,'half':2,'quarter':1,'eighth':.5,'16th':.25}.get(met.findtext('beat-unit'),1);dots=len(met.findall('beat-unit-dot'));tempo=float(bpm)*unit*(2-2**(-dots))
            sound=d.find('sound')
            if sound is None:sound=E.SubElement(d,'sound')
            if 'tempo' not in sound.attrib:sound.set('tempo',str(tempo));changed+=1
        if i==6 and not root.findall('.//sound[@tempo]'):
            m=root.findall('part')[0].find('measure');d=E.Element('direction',placement='above');met=E.SubElement(E.SubElement(d,'direction-type'),'metronome');text(met,'beat-unit','quarter');text(met,'per-minute',100);E.SubElement(d,'sound',tempo='100');anchor=next((k for k,c in enumerate(m) if c.tag=='note'),len(m));m.insert(anchor,d);changed+=1
        if i in [10,12]:
            for part in root.findall('part'):part.find('measure').set('implicit','yes')
        if i==7:
            # Read against the PDF: mp at "men" (31), then mf at the next Amen.
            for part in root.findall('part'):
                m=part.findall('measure')[30]
                for dy in m.findall('.//dynamics'):
                    for v in list(dy):
                        if v.tag=='mf':v.tag='mp';changed+=1
                for sound in m.findall('.//sound[@dynamics]'):sound.set('dynamics','54')
            # Locate the later dolce return by its printed lyric, not bar labels.
            soprano=root.findall('part')[0]
            ms=soprano.findall('measure')
            for part in root.findall('part'):
                for m in part.findall('measure')[100:]:
                    for d in list(m.findall('direction')):
                        if d.find('direction-type/dynamics/mp') is not None or any((t.text or '')=='dolce' for t in d.findall('direction-type/words')):m.remove(d)
            returns=[k for k,m in enumerate(ms) if k>100 and any('high!' in (t.text or '').casefold() for t in ms[k-1].findall('.//lyric/text')) and any((t.text or '').casefold()=='glo' for t in m.findall('.//lyric/text'))]
            if returns:
                k=returns[0]
                for part in root.findall('part'):
                    m=part.findall('measure')[k];d=E.Element('direction',placement='below');dy=E.SubElement(E.SubElement(d,'direction-type'),'dynamics');E.SubElement(dy,'mp');E.SubElement(d,'sound',dynamics='54');m.insert(next(j for j,c in enumerate(m) if c.tag=='note'),d)
                d=E.Element('direction',placement='above');text(E.SubElement(d,'direction-type'),'words','dolce');m=soprano.findall('measure')[k];m.insert(next(j for j,c in enumerate(m) if c.tag=='note'),d);changed+=4
        for t in root.findall('.//lyric/text'):
            if t.text:
                for code in ['\ue550','\ue551','\ue552']:t.text=t.text.replace(code,'‿')
        # Embedded sources/validation notes will travel with the single MSCZ.
        ident=root.find('identification')
        if ident is None:ident=E.SubElement(root,'identification')
        misc=ident.find('miscellaneous')
        if misc is None:misc=E.SubElement(ident,'miscellaneous')
        text(misc,'miscellaneous-field',record['source'],name='sourceEditable')
        text(misc,'miscellaneous-field','Partitura contrastada con PDF; voces independientes. Apocalipsis conserva baritono independiente. Es Dios se transcribe desde el PDF oficial. No probado en Cantai.',name='review')
        E.indent(root);E.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
        print(i,'playback tempo fixes',changed,flush=True)
if __name__=='__main__':run()
