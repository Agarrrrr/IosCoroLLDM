from pathlib import Path
import xml.etree.ElementTree as E,json,collections
OUT=Path('output/verovio_pilot_support/valle')
ROOT=E.parse(next(Path('C:/Users/Huri_/Downloads/musescore').glob('D__*Huesos*musicxml'))).getroot()
MIDI=json.loads((OUT/'midi.json').read_text())
TYPES={'whole':4,'half':2,'quarter':1,'eighth':.5,'16th':.25,'32nd':.125,'64th':.0625}
def duration(note):
    result=TYPES[note.findtext('type')]
    result*=sum(.5**i for i in range(len(note.findall('dot'))+1))
    tm=note.find('time-modification')
    if tm is not None:result*=int(tm.findtext('normal-notes'))/int(tm.findtext('actual-notes'))
    return result
def check():
    for role,part in enumerate(ROOT.findall('part')):
        div=1;attacks=[];invalid=[];repairs=[]
        for mi,m in enumerate(part.findall('measure')):
            cursor=0;div=int(m.findtext('attributes/divisions',str(div)))
            for item in m:
                if item.tag in ['forward','backup']:cursor+=int(item.findtext('duration'))/div*(1 if item.tag=='forward' else -1)
                if item.tag!='note':continue
                d=duration(item)
                if abs(d-int(item.findtext('duration'))/div)>.00001:repairs.append((mi+1,item.find('rest') is not None,int(item.findtext('duration'))/div,d))
                if item.find('pitch') is not None and item.find("tie[@type='stop']") is None:attacks.append((mi*4+cursor,item))
                cursor+=d
            if abs(cursor-4)>.001:invalid.append((mi+1,cursor))
        diffs=[(i,q,n['ticks']/MIDI['ppq']) for i,((q,_),n) in enumerate(zip(attacks,MIDI['tracks'][role]['notes'])) if abs(q-n['ticks']/MIDI['ppq'])>.0021]
        print('ROLE',role,'duration corrections',repairs,'invalid',invalid,'timingDiffs',len(diffs),diffs[:12])
if __name__=='__main__':check()
