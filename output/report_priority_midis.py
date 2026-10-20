from pathlib import Path
import json
APP=Path('E:/proyectos/IosCoroLLDM');DOC=APP/'docs/repertorio/2026-10-11';OUT=APP/'output/priority_midis/2026-10-11'
summary=json.loads((DOC/'midis_confirmados.json').read_text(encoding='utf-8'))
inspection=json.loads((OUT/'inspection.json').read_text(encoding='utf-8'))
all_entries=json.loads(Path('E:/Audios Octubre/Candidatos revisados - 2026-10-10/registro.json').read_text(encoding='utf-8'))['records']
accepted={r['id'] for r in summary['records']}
reasons={
1:'El PDF indica 12/8; el MIDI comienza en 3/4 y despu\u00e9s pasa a 6/8. Requiere confirmar y preparar el comp\u00e1s antes de incorporarlo.',
12:'El PDF actual y la transcripci\u00f3n de origen tienen diferencias de edici\u00f3n, tempo y colocaci\u00f3n de cambios de comp\u00e1s. No se asign\u00f3 este audio.',
16:'Las entradas y distribuci\u00f3n de las voces requieren confirmar equivalencia con el arreglo actual.',
20:'No qued\u00f3 confirmada la equivalencia de las notas entre el MIDI y el arreglo cerrado actual. No se asign\u00f3 este audio.',
21:'El PDF indica 6/8 y el MIDI declara 3/8. Requiere revisi\u00f3n del comp\u00e1s.'
}
pending=[]
for i,r in enumerate(inspection,1):
 if r['id'] not in accepted:pending.append({'name':r['title'],'id':r['id'],'reason':reasons[i],'sourceMidi':r['sourceMidi']})
(DOC/'pendientes_prioritarios.json').write_text(json.dumps(pending,ensure_ascii=False,indent=2),encoding='utf-8')
lines=['# Incorporaci\u00f3n de MIDI confirmados \u2014 2026-10-11','','## Resultado','','- 18 asignaciones verificadas en Cloudflare y en el cat\u00e1logo autenticado del gestor.','- 16 audios nuevos en la app; 2 audios existentes sincronizados conservando sus bytes.','- Los 18 PDF de la nube coinciden byte por byte con los de la app. No se reemplaz\u00f3 ninguna partitura.','- No se cambiaron IDs, t\u00edtulos, temas, v\u00ednculos de idioma ni el orden de los cat\u00e1logos locales.','- En la nube solo cambiaron midi_archivo, version y updated_at. Se usaron actualizaciones condicionadas al ID, versi\u00f3n y ausencia previa de MIDI.','- Las copias offline se escribieron con validateAsset, encodeDataUrl y writeTransaction del gestor, con reversi\u00f3n ante fallo.','- Los 4226 archivos anteriores comprobados conservaron exactamente su SHA-256; no hubo eliminaciones.','- Los cat\u00e1logos ingleses no cambiaron. El cat\u00e1logo de la app conserva 1345 cantos espa\u00f1oles y 308 ingleses.','','## Cantos incorporados','','| Canto | Voces | Estado |','| --- | --- | --- |']
for r in summary['records']:lines.append('| '+r['name']+' | '+str(r['activeTracks'])+' | '+('Audio existente sincronizado' if r['existingAppAudioPreserved'] else 'Audio a\u00f1adido')+' |')
lines+=['','Los MIDI de Ha Triunfado mi Se\u00f1or y Nadie Como T\u00fa incluyen solista adem\u00e1s de SATB.','','## Comprobaci\u00f3n musical','','Se verificaron pistas activas y nombres de voces, tonalidad/comp\u00e1s declarado, notas iniciales y la correspondencia visual con la partitura. Las diferencias no confirmadas quedaron pendientes. Esta comprobaci\u00f3n no equivale a revisar de o\u00eddo cada nota de toda la obra.','','## Pendientes nuevos','','| Canto | Motivo |','| --- | --- |']
for r in pending:lines.append('| '+r['name']+' | '+r['reason']+' |')
lines+=['','## Verificaci\u00f3n de la app','','Prueba: test/priority_repertoire_import_test.dart. Comprueba apertura de PDF y MIDI desde el bundle con la red bloqueada y exportaci\u00f3n individual de cada voz conservando notas, velocidades, tiempos y duraciones.','Se ejecuta tambi\u00e9n test/selected_repertoire_import_test.dart para comprobar las seis incorporaciones anteriores.','Registro de ejecuci\u00f3n: output/priority_midis/2026-10-11/flutter-tests.log.','No se compil\u00f3 un AAB ni se prob\u00f3 reproducci\u00f3n f\u00edsica en un dispositivo durante esta incorporaci\u00f3n.','','## Preservaci\u00f3n y trazabilidad','','El registro previo y los recibos remotos est\u00e1n en output/priority_midis/2026-10-11. Los cat\u00e1logos se actualizaron por ID y solo en los campos de MIDI y versi\u00f3n.','Los originales de E:/MIDIS REVISAR TODOS y las copias de E:/Audios Octubre permanecen intactos.','No se realiz\u00f3 commit ni push.']
(DOC/'incorporacion_midis.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
review=['# MIDI pendientes de revisi\u00f3n \u2014 2026-10-11','','18 cantos confirmados: 16 MIDI a\u00f1adidos a la app y 2 audios existentes sincronizados con la nube.','','## Cinco prioritarios aplazados','']
for r in pending:review+=['- **'+r['name']+'**: '+r['reason']]
review+=['','## Revisi\u00f3n de voces o solapamientos','']
seen=set()
for e in all_entries:
 if e['category'].startswith('02') and e['title'] not in seen:
  seen.add(e['title']);review.append('- '+e['title'])
review+=['','## T\u00edtulos sin correspondencia confirmada en el cat\u00e1logo','']
seen=set()
for e in all_entries:
 if e['category'].startswith('03') and e['title'] not in seen:
  seen.add(e['title']);review.append('- '+e['title'])
review+=['','## Archivos con identidad pendiente','']
for e in all_entries:
 if e['category'].startswith('04'):review.append('- '+Path(e['source']).name+' \u2014 '+str(Path(e['source']).parent))
review+=['','No se movieron ni modificaron los MIDI originales. Las carpetas previas de candidatos se conservan. El estado actualizado es este registro.']
(DOC/'pendientes_revision.md').write_text('\n'.join(review)+'\n',encoding='utf-8')
Path('E:/Audios Octubre/Estado de incorporacion - 2026-10-11.md').write_text('\n'.join(lines+['','## Pendientes restantes','']+review)+'\n',encoding='utf-8')
print('Reports saved')
