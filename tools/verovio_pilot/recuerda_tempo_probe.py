from pathlib import Path
import os,subprocess,json
from recuerda_model import OUT
from inspect_sources import NODE
def run():
    work=OUT/'tempo-probe';work.mkdir(exist_ok=True);binary='C:/Program Files/MuseScore 4/bin/MuseScore4.exe';env=os.environ.copy();env.pop('QT_QPA_PLATFORM',None);env['QT_QUICK_BACKEND']='software'
    body='''<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Test</part-name></score-part></part-list><part id="P1"><measure number="1"><attributes><divisions>960</divisions><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes><direction><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>63</per-minute></metronome></direction-type><sound tempo="63"/></direction>{change}<note><pitch><step>C</step><octave>4</octave></pitch><duration>3840</duration><type>whole</type></note></measure></part></score-partwise>'''
    options={'offset':'<direction><direction-type><metronome print-object="no"><beat-unit>quarter</beat-unit><per-minute>50</per-minute></metronome></direction-type><offset sound="yes">2400</offset><sound tempo="50"/></direction>',
      'forward':'<forward><duration>2400</duration></forward><direction><direction-type><metronome print-object="no"><beat-unit>quarter</beat-unit><per-minute>50</per-minute></metronome></direction-type><sound tempo="50"/></direction><backup><duration>2400</duration></backup>'}
    for name,change in options.items():
        source=work/(name+'.musicxml');source.write_text(body.replace('{change}',change),encoding='utf-8');target=work/(name+'.mid');p=subprocess.run([binary,'-o',str(target.resolve()),str(source.resolve())],env=env,capture_output=True,timeout=120);assert p.returncode==0,p.stderr
        midi=json.loads(subprocess.run(['node','-e',NODE,str(target.resolve())],check=True,capture_output=True,text=True).stdout);print(name,midi['tempos'],flush=True)
        if name=='forward':
            exported=work/'exported.musicxml';p=subprocess.run([binary,'-o',str(exported.resolve()),str(source.resolve())],env=env,capture_output=True,timeout=120);assert p.returncode==0
            target=work/'reimport.mid';p=subprocess.run([binary,'-o',str(target.resolve()),str(exported.resolve())],env=env,capture_output=True,timeout=120);assert p.returncode==0
            midi=json.loads(subprocess.run(['node','-e',NODE,str(target.resolve())],check=True,capture_output=True,text=True).stdout);print('roundtrip',midi['tempos'],flush=True)
if __name__=='__main__':run()
