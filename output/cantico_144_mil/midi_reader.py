import collections
def read(path):
    raw=path.read_bytes();ppq=int.from_bytes(raw[12:14],'big');pos=14;tracks=[];tempos=[];meters=[]
    def vlq(b,k):
        v=0
        while True:
            c=b[k];k+=1;v=v*128+(c&127)
            if c<128:return v,k
    while pos<len(raw):
        tag=raw[pos:pos+4];size=int.from_bytes(raw[pos+4:pos+8],'big');b=raw[pos+8:pos+8+size];pos+=8+size
        if tag!=b'MTrk':continue
        k=0;t=0;run=None;notes=[];active=collections.defaultdict(list);name=''
        while k<len(b):
            delta,k=vlq(b,k);t+=delta;s=b[k]
            if s>=128:k+=1
            else:s=run
            if s==255:
                typ=b[k];k+=1;n,k=vlq(b,k);v=b[k:k+n];k+=n
                if typ==3:name=v.decode('latin1',errors='replace')
                elif typ==81:tempos.append([t/ppq,60000000/int.from_bytes(v,'big')])
                elif typ==88:meters.append([t/ppq,list(v)])
            elif s in [240,247]:n,k=vlq(b,k);k+=n
            else:
                run=s;typ=s>>4;n=1 if typ in [12,13] else 2;v=b[k:k+n];k+=n
                if typ==9 and v[1]:active[(s&15,v[0])].append((t,v[1]))
                elif typ==8 or (typ==9 and not v[1]):
                    starts=active[(s&15,v[0])]
                    if starts:
                        st,vel=starts.pop(0);notes.append(dict(onset=st/ppq,duration=(t-st)/ppq,pitch=v[0],velocity=vel))
        tracks.append(dict(name=name,notes=sorted(notes,key=lambda n:(n['onset'],n['pitch'])),end=t/ppq))
    return dict(ppq=ppq,tempos=tempos,meters=meters,tracks=tracks)
