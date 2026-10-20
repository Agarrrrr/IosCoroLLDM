"""Check raw note-on events, including overlapping notes of the same pitch."""
from extract_salmo150 import OUT
import struct,json
def read():
    data=(OUT/'original.mid').read_bytes();offset=8+struct.unpack('>I',data[4:8])[0];tracks=[]
    while offset<len(data):
        assert data[offset:offset+4]==b'MTrk';size=struct.unpack('>I',data[offset+4:offset+8])[0];buf=data[offset+8:offset+8+size];offset+=8+size
        i=0;ticks=0;running=None;events=[]
        def vlq():
            nonlocal i
            value=0
            while True:
                b=buf[i];i+=1;value=(value<<7)|(b&127)
                if b<128:return value
        while i<len(buf):
            ticks+=vlq();status=buf[i]
            if status>=128:i+=1
            else:status=running
            if status==255:
                kind=buf[i];i+=1;length=vlq();i+=length;continue
            if status in [240,247]:length=vlq();i+=length;continue
            running=status;kind=status&240;length=1 if kind in [192,208] else 2;args=list(buf[i:i+length]);i+=length
            if kind in [128,144]:events.append(dict(ticks=ticks,type='on' if kind==144 and args[1]>0 else 'off',pitch=args[0],velocity=args[1]))
        if events:tracks.append(events)
    (OUT/'raw-midi-events.json').write_text(json.dumps(tracks),encoding='utf-8')
    print('RAW note-ons',[sum(e['type']=='on' for e in t) for t in tracks])
    for r,lo,hi in [(1,188,190),(3,240,244),(0,284,290)]:print(r,[(e['ticks']/960,e['type'],e['pitch']) for e in tracks[r] if lo<=e['ticks']/960<hi])
    return tracks
if __name__=='__main__':read()
