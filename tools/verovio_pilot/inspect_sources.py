"""Read-only musical comparison for the isolated Verovio pilot."""
from pathlib import Path
import collections
import json
import subprocess
import xml.etree.ElementTree as ET

SOURCE = Path('C:/Users/Huri_/Downloads/musescore')
OUT = Path('output/verovio_pilot_support')
OUT.mkdir(parents=True, exist_ok=True)
NODE = """
const {Midi}=require('E:/proyectos/CoroLLDM/node_modules/@tonejs/midi');
const fs=require('fs');const m=new Midi(fs.readFileSync(process.argv[1]));
console.log(JSON.stringify({ppq:m.header.ppq,tempos:m.header.tempos,
tracks:m.tracks.filter(t=>t.notes.length).map(t=>({name:t.name,notes:t.notes.map(n=>({
ticks:n.ticks,pitch:n.midi,duration:n.durationTicks,time:n.time,seconds:n.duration
}))}))}));
"""

def source_files():
    return [
        ('acercame', next((SOURCE/'AudiosJulio').glob('Ac*ti.musicxml'))),
        ('al-gran-senor', next(SOURCE.glob('Al Gran*.musicxml'))),
    ]

def xml_events(root):
    result=[]
    for pi,part in enumerate(root.findall('part')):
        absolute=0.; div=1
        for mi,m in enumerate(part.findall('measure')):
            cursor=0.; last=0.; end=0.
            for item in m:
                if item.tag=='attributes': div=int(item.findtext('divisions',str(div)))
                elif item.tag in ('backup','forward'):
                    cursor+=(-1 if item.tag=='backup' else 1)*int(item.findtext('duration','0'))/div
                elif item.tag=='note':
                    dur=int(item.findtext('duration','0'))/div
                    start=last if item.find('chord') is not None else cursor
                    if item.find('chord') is None: last=start;cursor+=dur
                    end=max(end,cursor)
                    p=item.find('pitch')
                    if p is not None:
                        pitch=12*(int(p.findtext('octave'))+1)+{'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[p.findtext('step')]+int(p.findtext('alter','0'))
                        result.append(dict(part=pi,measure=mi,onset=round(absolute+start,8),local=start,duration=dur,pitch=pitch,element=item))
            absolute+=end
    return result

def main():
    for key,xml in source_files():
        midi=json.loads(subprocess.run(['node','-e',NODE,str(xml.with_suffix('.mid'))],check=True,capture_output=True,text=True,encoding='utf-8').stdout)
        (OUT/(key+'-midi.json')).write_text(json.dumps(midi),encoding='utf-8')
        root=ET.parse(xml).getroot();ev=xml_events(root)
        lookup=collections.defaultdict(list)
        for ti,t in enumerate(midi['tracks']):
            for n in t['notes']:lookup[(round(n['ticks']/midi['ppq'],8),n['pitch'])].append(ti)
        rows=[]
        for e in ev:
            if e['measure']<8:
                rows.append({k:v for k,v in e.items() if k!='element'}|{'tracks':lookup[(e['onset'],e['pitch'])]})
        (OUT/(key+'-comparison.json')).write_text(json.dumps(rows,indent=2),encoding='utf-8')
        print(key,'first8 events',len(rows),'matched',sum(bool(e['tracks']) for e in rows),'unmatched',[e for e in rows if not e['tracks']][:15])
        if key=='acercame':
            for ti,t in enumerate(midi['tracks']):
                print('voice',ti,[(n['ticks']/midi['ppq'],n['pitch']) for n in t['notes'] if n['ticks']/midi['ppq']<32])

if __name__=='__main__':main()
