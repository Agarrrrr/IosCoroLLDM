import copy,json
from extract_dios_poderoso import OUT
def run():
    data=json.loads((OUT/'pdf-reading.json').read_text(encoding='utf-8'));events=data['events']
    e=next(e for e in events if e['role']==2 and e['measure']==42 and not e['rest'])
    assert e['diatonic']==25 and e['alter']==0
    e['diatonic']=27;e['alter']=-1;e.pop('accidental',None)
    ra=next(e for e in events if e['role']==3 and e['measure']==74 and not e['rest'] and e['onset']==2.75)
    zon=next(e for e in events if e['role']==3 and e['measure']==74 and not e['rest'] and e['onset']==3)
    co=next(e for e in events if e['role']==3 and e['measure']==74 and not e['rest'] and e['onset']==2.25)
    ra['onset']=2.5;zon['onset']=2.75
    for e in [co,ra,zon]:e['beamGroup']=['midi-reference',3,74];e['beams']=2
    trailing=copy.deepcopy(next(e for e in events if e['role']==3 and e['measure']==74 and e['rest'] and e['onset']==3.25))
    trailing.update(onset=3,duration=1,writtenDuration=1,glyph='Œ');trailing.pop('dot',None);trailing.pop('dotCount',None)
    events=[e for e in events if not (e['role']==3 and e['measure']==74 and e['rest'] and e['onset'] in [2.5,3.25])]+[trailing]
    events.sort(key=lambda e:(e['page'],e['staff'],e['measure'],e['onset']));data['events']=events
    (OUT/'notation-reading.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    adjustments=[dict(role='Tenor',measure=42,pdfPitch=55,midiPitch=58),dict(role='Bajo',measure=74,word='corazón',pdfOnsets=[2.25,2.75,3],midiOnsets=[2.25,2.5,2.75])]
    (OUT/'reference-adjustments.json').write_text(json.dumps(adjustments,ensure_ascii=False,indent=2),encoding='utf-8')
    print('MIDI reference applied: Tenor 42 G3 -> Bb3; Bass 74 final syllables at 2.25,2.5,2.75; final rest at 3.')
if __name__=='__main__':run()
