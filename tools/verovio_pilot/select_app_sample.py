"""Select a reproducible sample exclusively from our bundled app assets."""
from pathlib import Path
import hashlib,io,json,random,re
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from pypdf import PdfReader

OUT=Path('output/verovio_pilot_support/complete');OUT.mkdir(parents=True,exist_ok=True)
raw=re.search(r"_rawKey = '([^']+)'",Path('lib/core/security/file_crypto.dart').read_text()).group(1)
cipher=AESGCM(hashlib.sha256(raw.encode()).digest())
def read_asset(kind,name):
    p=Path('assets/offline_assets')/kind/name
    if not p.exists():return None
    b=p.read_bytes()
    return b if b.startswith((b'%PDF',b'MThd')) else cipher.decrypt(b[:12],b[12:],None)
def vlq(b,p):
    v=0
    while True:
        x=b[p];p+=1;v=(v<<7)|(x&127)
        if x<128:return v,p
def midi_info(b):
    pos=8+int.from_bytes(b[4:8],'big');lyrics=0;counts=[];end=0
    for _ in range(int.from_bytes(b[10:12],'big')):
        size=int.from_bytes(b[pos+4:pos+8],'big');d=b[pos+8:pos+8+size];pos+=8+size;p=0;tick=0;running=None;notes=0
        while p<len(d):
            dt,p=vlq(d,p);tick+=dt;status=d[p]
            if status<128:status=running
            else:p+=1
            if status==255:
                tag=d[p];p+=1;n,p=vlq(d,p)
                if tag==5 and n:lyrics+=1
                p+=n
            elif status in [240,247]:n,p=vlq(d,p);p+=n;running=None
            else:
                running=status;n=1 if status>>4 in [12,13] else 2;v=d[p:p+n];p+=n
                if status>>4==9 and v[1]:notes+=1
        if notes:counts.append(notes)
        end=max(end,tick)
    return dict(lyrics=lyrics,notes=counts,total=sum(counts),quarters=end/int.from_bytes(b[12:14],'big'))

catalog=json.loads(Path('assets/catalogo.json').read_text(encoding='utf-8'));candidates=[]
for row in catalog:
    if not row.get('midi_archivo'):continue
    try:
        midi=read_asset('midis',row['midi_archivo'])
        if midi is None:continue
        info=midi_info(midi)
        if info['lyrics'] or len(info['notes'])!=4 or info['total']>500 or info['quarters']>180:continue
        pdf=read_asset('pdfs',row['archivo'])
        if pdf is None:continue
        pages=len(PdfReader(io.BytesIO(pdf)).pages)
        if pages<=2:candidates.append(dict(row=row,info=info,pages=pages))
    except Exception:continue
assert candidates,'No valid bundled candidates'
selected=random.Random(20261017).choice(sorted(candidates,key=lambda x:x['row']['id']))
row=selected['row'];selected['candidateCount']=len(candidates);selected['seed']=20261017
for kind,field,ext in [('pdfs','archivo','pdf'),('midis','midi_archivo','mid')]:
    data=read_asset(kind,row[field]);(OUT/('app-sample.'+ext)).write_bytes(data);selected[ext+'Sha256']=hashlib.sha256(data).hexdigest()
(OUT/'app-sample-selection.json').write_text(json.dumps(selected,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(selected,ensure_ascii=False))
# Our other two explicitly requested examples also use the bundled originals.
for key,canto_id in [('acercame','usmc_'),('al-gran-senor','3ad4f5e6-ca67-4792-8747-4a86fd4e4633')]:
    matches=[r for r in catalog if r['id']==canto_id] if key!='acercame' else [r for r in catalog if r['nombre'].lower() in ['acércame a ti','acercame a ti']]
    assert len(matches)==1,(key,[r['nombre'] for r in matches])
    r=matches[0]
    for kind,field,ext in [('pdfs','archivo','pdf'),('midis','midi_archivo','mid')]:
        (OUT/(key+'.'+ext)).write_bytes(read_asset(kind,r[field]))
    (OUT/(key+'-catalog.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
