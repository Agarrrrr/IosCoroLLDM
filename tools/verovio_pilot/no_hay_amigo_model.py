"""Source measure plan and exact MIDI-based four-voice notation."""
from pathlib import Path
from fractions import Fraction
import json,math
OUT=Path('output/verovio_pilot_support/no_hay_amigo_mejor')
LAYOUT=[[1,5,9],[13,16,20],[24,28,31,34]]
def plan():
    result=[];q=Fraction(0)
    for number in range(1,38):
        duration=Fraction(1 if number==1 else 2 if number in [15,30,37] else 3)
        result.append(dict(number=number,start=float(q),duration=float(duration)));q+=duration
    assert q==106
    return result
def source_events():
    midi=json.loads((OUT/'midi-reading.json').read_text());ppq=midi['ppq'];bars=plan();events=[]
    for role,track in enumerate(midi['tracks']):
        first=[n for n in track['notes'] if n['ticks']/ppq<106]
        for index,n in enumerate(first):
            start=Fraction(n['ticks'],ppq);duration=Fraction(n['duration'],ppq)
            # Match the source's quarter tied to dotted eighth, rather than
            # replacing that notation by a double-dotted quarter.
            values=[Fraction(1),Fraction(3,4)] if duration==Fraction(7,4) else [duration]
            cursor=start
            for i,value in enumerate(values):
                bar=next(b for b in bars if b['start']<=float(cursor)<b['start']+b['duration'])
                assert float(cursor+value)<=bar['start']+bar['duration']+.0001,(role,index,cursor,value,bar)
                events.append(dict(id=f'amigo-{role}-{index}-{i}',role=role,measure=bar['number'],onset=float(cursor)-bar['start'],absolute=float(cursor),duration=float(value),pitch=n['pitch'],tieStart=i<len(values)-1,tieStop=i>0,sourceAttack=index))
                cursor+=value
        for bar in bars:
            row=sorted([e for e in events if e['role']==role and e['measure']==bar['number']],key=lambda e:e['onset']);cursor=0
            for e in row:
                if e['onset']>cursor+.0001:events.append(dict(id=f'rest-{role}-{bar["number"]}-{cursor}',role=role,measure=bar['number'],onset=cursor,absolute=bar['start']+cursor,duration=e['onset']-cursor,rest=True))
                cursor=e['onset']+e['duration']
            if cursor<bar['duration']-.0001:events.append(dict(id=f'rest-{role}-{bar["number"]}-{cursor}',role=role,measure=bar['number'],onset=cursor,absolute=bar['start']+cursor,duration=bar['duration']-cursor,rest=True))
    (OUT/'source-events.json').write_text(json.dumps(events,indent=2),encoding='utf-8');return events
if __name__=='__main__':
    ev=source_events();print('bars',plan());print('events',[sum(e['role']==r and not e.get('rest') for e in ev) for r in range(4)])
