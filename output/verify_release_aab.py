from pathlib import Path
import json,zipfile,hashlib,subprocess,datetime
from urllib.parse import unquote
root=Path('E:/proyectos/IosCoroLLDM');aab=root/'build/app/outputs/bundle/release/app-release.aab'
out=root/'output/aab-2026-10-12-build37';out.mkdir(parents=True,exist_ok=True)
log=(root/'output/aab-release-2026-10-12-build37.log').read_text(encoding='utf-8',errors='replace')
if 'Built build' not in log or '.aab' not in log:raise RuntimeError('La compilacion no confirmo finalizacion')
with zipfile.ZipFile(aab) as z:
 if z.testzip() is not None:raise RuntimeError('AAB ZIP corrupto')
 names={unquote(n) for n in z.namelist()};prefix='base/assets/flutter_assets/'
 for f in ['assets/catalogo.json','assets/catalogo_en.json']:
  if z.read(prefix+f)!= (root/f).read_bytes():raise RuntimeError('Catalogo empaquetado distinto')
 cat=json.loads(z.read(prefix+'assets/catalogo.json'));assert not next(r for r in cat if r['id']=='usmc_b44ea5087d4ed58cc6').get('midi_archivo');assert next(r for r in cat if r['id']=='usmc_64b5943621b21cae026063ce')['midi_archivo']=='global/assets/midi/39f5dbda19be3b0ab5e06e63bdfabe4d6cdd4db466525ee10e0cf3b0c43fcb57.enc';encat=json.loads(z.read(prefix+'assets/catalogo_en.json'))
 for row in cat+encat:
  for field,folder in [('archivo','pdfs'),('midi_archivo','midis')]:
   key=row.get(field)
   if key and prefix+'assets/offline_assets/'+folder+'/'+key not in names:raise RuntimeError('Recurso ausente '+row['nombre']+' '+field)
 records=[]
 for f in ['docs/repertorio/2026-10-10/incorporacion_seleccionada.json','docs/repertorio/2026-10-11/midis_confirmados.json','docs/repertorio/2026-10-12/incorporacion_actual.json']:records+=json.loads((root/f).read_text(encoding='utf-8'))['records']
 unique={r['id']:r for r in records}
 for r in unique.values():
  key='assets/offline_assets/midis/'+r['midiKey']
  if z.read(prefix+key)!=(root/key).read_bytes():raise RuntimeError('MIDI distinto '+r['name'])
 manifest=z.read('base/manifest/AndroidManifest.xml')
 if b'com.lldm.coro' not in manifest or b'3.1.1' not in manifest:raise RuntimeError('Identidad/version no coincide')
 signed=[n for n in names if n.startswith('META-INF/') and n.endswith(('.RSA','.EC','.DSA'))]
 if not signed:raise RuntimeError('AAB sin firma')
p=subprocess.run([r'C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe','-verify',str(aab)],capture_output=True,text=True,timeout=180)
(out/'signature.txt').write_text(p.stdout+p.stderr,encoding='utf-8')
if p.returncode or 'jar verified' not in p.stdout.lower():raise RuntimeError('Firma invalida: '+p.stdout[:500])
h=hashlib.sha256()
with aab.open('rb') as f:
 for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
report={'file':str(aab),'version':'3.1.1','versionCode':37,'package':'com.lldm.coro','sizeBytes':aab.stat().st_size,'sha256':h.hexdigest(),'signatureVerified':True,'zipIntegrityVerified':True,'spanishCatalogSongs':len(cat),'englishCatalogSongs':len(encat),'octoberSongsWithMidiVerified':len(unique),'catalogFilesMatchWorkspace':True}
(out/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
