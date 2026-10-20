from pathlib import Path
import json,hashlib
APP=Path('E:/proyectos/IosCoroLLDM');OUT=APP/'output/priority_midis/2026-10-11'
DOC=APP/'docs/repertorio/2026-10-11';DOC.mkdir(parents=True,exist_ok=True)
baseline=json.loads((OUT/'baseline.json').read_text(encoding='utf-8'))
payload=json.loads((OUT/'payload.json').read_text(encoding='utf-8'))
receipt=json.loads((OUT/'remote_receipt.json').read_text(encoding='utf-8'))
accepted={r['localId']:r for r in receipt['results']}
assert len(accepted)==18
for name,h in baseline['assets'].items():
 p=Path(name);assert p.exists(), 'Falta archivo anterior: '+name
 assert hashlib.sha256(p.read_bytes()).hexdigest()==h,'Archivo anterior alterado: '+name
catalog_checks=[]
for name,before in baseline['catalogs'].items():
 p=Path(name);rows=json.loads(p.read_text(encoding='utf-8'));old=before['rows']
 assert [r['id'] for r in rows]==[r['id'] for r in old],'IDs u orden alterados'
 changed=0
 for oldrow,row in zip(old,rows):
  fields={k for k in set(oldrow)|set(row) if oldrow.get(k)!=row.get(k)}
  if fields:
   assert row['id'] in accepted,'Canto ajeno modificado'
   assert fields<={'midi_archivo','version'},'Otro campo alterado'
   assert row['archivo']==oldrow['archivo']
   if oldrow.get('midi_archivo'):assert row['midi_archivo']==oldrow['midi_archivo']
   changed+=1
 if p.name=='catalogo_en.json':assert hashlib.sha256(p.read_bytes()).hexdigest()==before['sha256']
 catalog_checks.append({'path':name,'rows':len(rows),'changedRows':changed})
records=[]
for p in payload:
 r=accepted[p['localId']]
 records.append({'id':p['localId'],'name':p['title'],'remoteId':r['remoteId'],'existingPdf':p['appRow']['archivo'],'pdfHash':p['pdfHash'],'midiKey':r['midiKey'],'midiHash':p['midiHash'],'activeTracks':len(p['tracks']),'existingAppAudioPreserved':bool(p['appRow'].get('midi_archivo')),'version':r['version']})
summary={'date':'2026-10-11','cloudMidiValidated':18,'newAppAudio':16,'existingAppAudioSynced':2,'oldAssetFilesUnchanged':len(baseline['assets']),'catalogs':catalog_checks,'records':records}
(DOC/'midis_confirmados.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'preservation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
source=(APP/'test/selected_repertoire_import_test.dart').read_text(encoding='utf-8')
source=source[:source.index("  test('las versiones anteriores de Salmo 23")]+ '}\n'
source=source.replace('2026-10-10/incorporacion_seleccionada.json','2026-10-11/midis_confirmados.json')
source=source.replace('selected_repertoire_validation','priority_repertoire_validation')
source=source.replace("if (record['newWork'] == false)",'if (true)')
source=source.replace("expect(song.tracks.map((track) => track.name).toList(),\n          ['Soprano', 'Alto', 'Tenor', 'Bajo']);","expect(song.tracks, hasLength(record['activeTracks']));\n      final voices = song.tracks.skip(song.tracks.length - 4).map((t) => t.name.toLowerCase()).toList();\n      expect(voices[0], contains('soprano'));\n      expect(voices[1], contains('alto'));\n      expect(voices[2], contains('tenor'));\n      expect(voices[3], contains('bajo'));")
(APP/'test/priority_repertoire_import_test.dart').write_text(source,encoding='utf-8')
print(json.dumps({k:summary[k] for k in ['cloudMidiValidated','newAppAudio','existingAppAudioSynced','oldAssetFilesUnchanged','catalogs']},ensure_ascii=False))
