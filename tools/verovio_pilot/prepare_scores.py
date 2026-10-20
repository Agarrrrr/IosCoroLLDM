"""Prepare explicitly limited, traceable eight-measure MusicXML pilot scores.

Original catalogues, PDF, MIDI, MSCZ and MusicXML sources are never modified.
"""
from pathlib import Path
import collections,copy,hashlib,json,shutil
import xml.etree.ElementTree as ET
from inspect_sources import SOURCE, OUT, source_files, xml_events

ASSETS=Path('output/verovio_pilot/assets')
NAMES=['Soprano','Alto','Tenor','Bajo']

# First verse, manually transcribed from the application's PDF, page 1.
# Keys are musical quarter positions, not an assumed sequential word list.
COMMON={0:'Quie|begin',2:'ro|end',3:'Se|begin',4:'ñor,|end',7.5:'es|begin',8:'tar|end',10:'jun|begin',11:'to a|end',12:'Ti,',15.5:'Tu',16:'ma|begin',18:'no|end',19:'so|begin',19.5:'bre|end',20:'mí,',23.5:'de',24:'nue|begin',27:'vo|end',27.5:'sen|begin',28:'tir.|end'}
LYRICS=[COMMON,COMMON|{13:'(mi',13.5:'Se|begin',14:'ñor,|end',15:'Tu)',15.5:'Tu'},
 {0:'Quie|begin',2:'ro|end',3:'Se|begin',4:'ñor,|end',5:'(Quie|begin',5.5:'ro es|middle',6:'tar|end',7:'jun|begin',7.5:'to a|end',8:'Ti)',15.5:'Tu',16:'ma|begin',18:'no|end',19:'so|begin',19.5:'bre|end',20:'mí,',23.5:'de',24:'nue|begin',27:'vo|end',27.5:'sen|begin',28:'tir.|end'},
 {0:'Quie|begin',2:'ro|end',3:'Se|begin',4:'ñor,|end',7.5:'es|begin',8:'tar|end',11:'jun|begin',11.5:'to a|end',12:'Ti,',13:'mi',13.5:'Se|begin',14:'ñor,|end',15:'Tu',16:'ma|begin',18:'no|end',19:'so|begin',19.5:'bre|end',20:'mí,',23.5:'de',24:'nue|begin',27:'vo|end',27.5:'sen|begin',28:'tir.|end'}]

def text(parent,tag,value,**attrs):
    e=ET.SubElement(parent,tag,attrs);e.text=str(value);return e

def rest(parent,ticks,staff,voice):
    if ticks<=0:return
    values=[(1920,'whole',False),(1440,'half',True),(960,'half',False),(720,'quarter',True),(480,'quarter',False),(360,'eighth',True),(240,'eighth',False),(120,'16th',False),(60,'32nd',False)]
    while ticks:
        size,kind,dotted=next(v for v in values if v[0]<=ticks)
        n=ET.SubElement(parent,'note');ET.SubElement(n,'rest');text(n,'duration',size);text(n,'voice',voice);text(n,'type',kind)
        if dotted:ET.SubElement(n,'dot')
        if staff:text(n,'staff',staff)
        ticks-=size

def prepare(key,path):
    original=ET.parse(path).getroot();midi=json.loads((OUT/(key+'-midi.json')).read_text())
    events=[e for e in xml_events(original) if e['measure']<8]
    lookup=collections.defaultdict(list)
    for ti,t in enumerate(midi['tracks']):
        for n in t['notes']:lookup[(round(n['ticks']/midi['ppq'],8),n['pitch'])].append((ti,n))
    assigned=[]
    for e in events:
        candidates=[(ti,n) for ti,n in lookup[(e['onset'],e['pitch'])] if (ti==e['part'] if key!='acercame' else ti//2==e['part'])]
        # Coincident unisons on separate source staves are distinguished by part.
        if len(candidates)!=1:raise ValueError(('ambiguous',key,{k:v for k,v in e.items() if k!='element'},len(candidates)))
        ti,n=candidates[0];assigned.append(e|dict(role=ti,midi=n))
    summary={}
    for layout in ['closed','open']:
        root=ET.Element('score-partwise',version='4.0')
        work=ET.SubElement(root,'work');text(work,'work-title',('Acércame a Ti' if key=='acercame' else 'Al Gran Señor'))
        text(root,'movement-title','Prueba · compases 1–8'+(' · estrofa 1' if key=='acercame' else ''))
        ident=ET.SubElement(root,'identification')
        for field in original.findall('identification/creator')+original.findall('identification/rights'):ident.append(copy.deepcopy(field))
        if key=='acercame' and ident.find('creator') is None:
            text(ident,'creator','Á. Fabián Linares Ruiz',type='composer')
            text(ident,'creator','Gerson / Fabián Linares',type='arranger')
        enc=ET.SubElement(ident,'encoding');text(enc,'software','Coro LLDM — piloto local, fuentes propias')
        pl=ET.SubElement(root,'part-list')
        for pi in range(1 if layout=='closed' else 4):
            part=ET.SubElement(pl,'score-part',id='P'+str(pi+1));text(part,'part-name','SATB' if layout=='closed' else ['S','A','T','B'][pi])
        for pi in range(1 if layout=='closed' else 4):
            part=ET.SubElement(root,'part',id='P'+str(pi+1))
            roles=range(4) if layout=='closed' else [pi]
            for mi in range(8):
                measure=ET.SubElement(part,'measure',number=str(mi+1))
                a=ET.SubElement(measure,'attributes');text(a,'divisions',480)
                if mi==0:
                    src=original.findall('part')[0].find('measure/attributes')
                    for name in ['key','time']:
                        v=src.find(name)
                        if v is not None:a.append(copy.deepcopy(v))
                    if layout=='closed':text(a,'staves',2)
                    for sn in range(1,3) if layout=='closed' else [1]:
                        c=ET.SubElement(a,'clef',number=str(sn));bass=sn==2 if layout=='closed' else pi==3
                        text(c,'sign','F' if bass else 'G');text(c,'line',4 if bass else 2)
                        if layout=='open' and pi==2:text(c,'clef-octave-change',-1)
                    d=ET.SubElement(measure,'direction',placement='above');dt=ET.SubElement(d,'direction-type');met=ET.SubElement(dt,'metronome');text(met,'beat-unit','quarter');text(met,'per-minute',90);ET.SubElement(d,'sound',tempo='90')
                for ri,role in enumerate(roles):
                    if ri:back=ET.SubElement(measure,'backup');text(back,'duration',1920)
                    cursor=0
                    staff=role//2+1 if layout=='closed' else None
                    voice=role%2+1 if layout=='closed' else 1
                    rows=sorted([e for e in assigned if e['role']==role and e['measure']==mi],key=lambda e:e['local'])
                    for ni,e in enumerate(rows):
                        start=round(e['local']*480);rest(measure,start-cursor,staff,voice)
                        n=copy.deepcopy(e['element']);n.set('id',f'{key}-{layout}-{role}-{mi}-{ni}')
                        for tag in ['chord','voice','staff','beam','stem']:
                            for child in n.findall(tag):n.remove(child)
                        n.find('duration').text=str(round(e['duration']*480));text(n,'voice',voice)
                        text(n,'stem','up' if role%2==0 else 'down')
                        if staff:text(n,'staff',staff)
                        if key=='acercame':
                            for child in n.findall('lyric'):n.remove(child)
                            value=LYRICS[role].get(e['onset'])
                            if value:
                                bits=value.split('|');ly=ET.SubElement(n,'lyric',number='1');text(ly,'syllabic',bits[1] if len(bits)>1 else 'single')
                                # Spaces inside a sung syllable use MusicXML elision.
                                for wi,word in enumerate(bits[0].split(' ')):
                                    if wi:text(ly,'elision',' ')
                                    text(ly,'text',word)
                        else:
                            # Explicit word boundary visible in the user's PDF;
                            # the editable source incorrectly joins these words.
                            for lyric_text in n.findall('lyric/text'):
                                if lyric_text.text=='granSe':lyric_text.text='gran Se'
                        if layout=='closed':
                            for lyric in n.findall('lyric'):lyric.set('number',str(role%2+1))
                        order=['grace','cue','chord','pitch','unpitched','rest','duration','tie','instrument','footnote','level','voice','type','dot','accidental','time-modification','stem','notehead','notehead-text','staff','beam','notations','lyric','play','listen']
                        n[:]=sorted(n,key=lambda child:order.index(child.tag) if child.tag in order else 999)
                        measure.append(n);cursor=start+round(e['duration']*480)
                    if cursor>1920:raise ValueError(('measure overflow',key,mi,role,cursor))
                    rest(measure,1920-cursor,staff,voice)
                if mi==7:b=ET.SubElement(measure,'barline',location='right');text(b,'bar-style','light-heavy')
        pathout=ASSETS/'scores'/f'{key}-{layout}.musicxml';pathout.parent.mkdir(parents=True,exist_ok=True)
        ET.indent(root);ET.ElementTree(root).write(pathout,encoding='utf-8',xml_declaration=True)
        summary[layout]=dict(notes=len(root.findall('.//pitch')),lyrics=len(root.findall('.//lyric')))
    # Playback uses precisely the MIDI events matched above, not the browser's synth.
    note_times=[dict(role=e['role'],pitch=e['pitch'],q=e['onset'],time=e['midi']['time'],duration=e['midi']['seconds']) for e in assigned]
    (ASSETS/'scores'/f'{key}-events.json').write_text(json.dumps(note_times),encoding='utf-8')
    shutil.copy2(path.with_suffix('.mid'),ASSETS/'scores'/f'{key}.mid')
    print(key,summary)
    return dict(key=key,sourceXml=str(path),sourceXmlSha256=hashlib.sha256(path.read_bytes()).hexdigest(),sourceMidiSha256=hashlib.sha256(path.with_suffix('.mid').read_bytes()).hexdigest(),measures=8,matchedNotes=len(assigned),layouts=summary,lyricsSource='PDF propio, página 1; transcripción manual de estrofa 1' if key=='acercame' else 'MusicXML propio; conserva sílabas originales',status='piloto: no equivale a revisión musical completa')

def main():
    ASSETS.mkdir(parents=True,exist_ok=True)
    manifest=[prepare(key,path) for key,path in source_files()]
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    for f in ['midi_engine.dart','native_midi_parser.dart']:
        dest=Path('output/verovio_pilot/lib/core/midi')/f;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(Path('lib/core/midi')/f,dest)
    shutil.copy2('assets/Piano.sf2',ASSETS/'Piano.sf2')
    dest=ASSETS/'audio/metro';dest.mkdir(parents=True,exist_ok=True)
    for f in Path('assets/audio/metro').iterdir():
        if f.is_file():shutil.copy2(f,dest/f.name)

if __name__=='__main__':main()
