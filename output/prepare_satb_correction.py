from pathlib import Path
import ast,json,hashlib,base64
OUT=Path('output/satb_correction/2026-10-12');OUT.mkdir(parents=True,exist_ok=True)
r=next(r for r in json.loads(Path('docs/repertorio/2026-10-12/incorporados_30.json').read_text(encoding='utf-8'))['records'] if r['name']=='A la Sombra de Tus Alas')
tree=ast.parse(Path('output/repertoire_import/2026-10-10/prepare_import.py').read_text(encoding='utf-8'));scope={}
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['vlq','encoded_vlq','track_info','replace_names']],type_ignores=[]),'<helpers>','exec'),scope)
raw=Path(r['sourceMidi']).read_bytes();pos=8+int.from_bytes(raw[4:8],'big');new=bytearray(raw[:pos]);labels=['Soprano','Alto','Parte adicional 1','Tenor','Bajo','Parte adicional 2'];active=0
for _ in range(int.from_bytes(raw[10:12],'big')):
 assert raw[pos:pos+4]==b'MTrk';size=int.from_bytes(raw[pos+4:pos+8],'big');data=raw[pos+8:pos+8+size];pos+=8+size
 count,spans=scope['track_info'](data)
 if count:
  assert spans
  updated=scope['replace_names'](data,spans,labels[active]);_,newspans=scope['track_info'](updated)
  assert scope['replace_names'](data,spans,'')==scope['replace_names'](updated,newspans,'')
  data=updated;active+=1
 new.extend(b'MTrk'+len(data).to_bytes(4,'big')+data)
assert active==6 and pos==len(raw)
new=bytes(new);sha=hashlib.sha256(new).hexdigest()
(OUT/'sombra-etiquetas-corregidas.mid').write_bytes(new)
p={'localId':r['id'],'remoteId':r['remoteId'],'name':r['name'],'oldMidiKey':r['midiKey'],'midiKey':'global/assets/midi/'+sha+'.enc','midiHash':sha,'midiData':'data:audio/midi;base64,'+base64.b64encode(new).decode(),'labels':labels,'oldMidiHash':hashlib.sha256(raw).hexdigest(),'sourceMidi':r['sourceMidi'],'onlyTrackLabelsChanged':True}
(OUT/'sombra_patch.json').write_text(json.dumps(p,ensure_ascii=False),encoding='utf-8')
Path('E:/proyectos/CoroLLDM/public/__satb_correction.json').write_text(json.dumps(p,ensure_ascii=False),encoding='utf-8')
print(json.dumps({k:p[k] for k in ['localId','remoteId','onlyTrackLabelsChanged','midiHash']}))
