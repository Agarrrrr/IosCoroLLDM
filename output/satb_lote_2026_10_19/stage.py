from pathlib import Path
import json,hashlib,re,subprocess,os,unicodedata,collections
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import pdfplumber
from inventory import OUT,load

NAMES=['A Dónde Iré','Al Gran Señor','Ángel Poderoso','Apocalipsis 10','En su Corazón','Firmes y Adelante','Glory Unto Jesus Christ','Guerrero Celestial','Jehova es mi Pastor','La Restauración','Para Siempre es su Misericordia','Restauración','Santo Varón','Al Huerto Van','El Aliento de mi Ser','Es Dios','Imaginate tu','Imaginate tu','La Fiesta Universal','La Vida se va Como el Viento','Mi Padre en la fe','Nardo, Justicia y Gloria']
def run():
    rows=json.loads((OUT/'inventory.json').read_text(encoding='utf8'));cats=[]
    for f in ['catalogo.json','catalogo_en.json']:cats+=json.loads((Path('assets')/f).read_text(encoding='utf8'))
    source=Path('lib/core/security/file_crypto.dart').read_text(encoding='utf8');cipher=AESGCM(hashlib.sha256(re.search("_rawKey = '([^']+)'",source)[1].encode()).digest())
    env=os.environ.copy();env['QT_QUICK_BACKEND']='software'
    for r,name in zip(rows,NAMES):
        work=OUT/f"{r['index']:02d}";cat=next(c for c in cats if c['nombre']==name);r['catalog']=cat
        for field,folder,filename in [('archivo','pdfs','partitura.pdf'),('midi_archivo','midis','referencia.mid')]:
            if not cat.get(field):continue
            raw=(Path('assets/offline_assets')/folder/cat[field]).read_bytes();clear=raw if raw[:4] in [b'%PDF',b'MThd'] else cipher.decrypt(raw[:12],raw[12:],None);(work/filename).write_bytes(clear)
        if Path(r['source']).suffix=='.mscz':
            res=subprocess.run(['C:/Program Files/MuseScore 4/bin/MuseScore4.exe','-o',str(work/'source.musicxml'),r['source']],env=env,capture_output=True,timeout=120);assert res.returncode==0,(r['index'],res.stderr)
        else:
            import xml.etree.ElementTree as E
            E.ElementTree(load(Path(r['source']))).write(work/'source.musicxml',encoding='utf-8',xml_declaration=True)
        with pdfplumber.open(work/'partitura.pdf') as pdf:
            texts=[p.extract_text() or '' for p in pdf.pages];(work/'pdf-text.txt').write_text('\n\n'.join(texts),encoding='utf8')
            pdf.pages[0].to_image(resolution=75).save(work/'pdf-first.png')
            words=[w for p in pdf.pages for w in p.extract_words(extra_attrs=['fontname']) if w['text'] in ['ppp','pp','p','mp','mf','f','ff','fff','sfz','fp']]
            r['pdfReview']=dict(pages=len(pdf.pages),dynamics=[dict(text=w['text'],font=w['fontname']) for w in words])
        print(r['index'],name,'PDF pages',r['pdfReview']['pages'],'marks',collections.Counter(w['text'] for w in r['pdfReview']['dynamics']),flush=True)
    (OUT/'sources.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
if __name__=='__main__':run()
