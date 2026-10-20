from pathlib import Path
import json,hashlib,unicodedata,subprocess
D=Path('docs/repertorio/2026-10-12')
rect=json.loads((D/'rectificacion_satb.json').read_text(encoding='utf-8'))
rows=json.loads((D/'incorporacion_actual.json').read_text(encoding='utf-8'))
baseline=json.loads(Path('output/remaining_midis/2026-10-12/baseline.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256(Path(f).read_bytes()).hexdigest()==h for f,h in baseline['assets'].items())
assert len(rows['records'])==29
for f in baseline['catalogs']:
 if Path(f).name=='catalogo_en.json':assert hashlib.sha256(Path(f).read_bytes()).hexdigest()==baseline['catalogs'][f]['sha256']
rect.update(originalAssetsUnchanged=4278,testsPassed=109,previousAabStatus='NO PUBLICAR - requiere revision SATB y nueva compilacion',retainedMidiNotMusicallyCertified=True)
(D/'rectificacion_satb.json').write_text(json.dumps(rect,ensure_ascii=False,indent=2),encoding='utf-8')
a=json.loads(Path('docs/repertorio/2026-10-10/incorporacion_seleccionada.json').read_text(encoding='utf-8'))['records'];b=json.loads(Path('docs/repertorio/2026-10-11/midis_confirmados.json').read_text(encoding='utf-8'))['records']
new={r['id']:r for r in a+rows['records'] if r.get('newWork')};old={r['id']:r for r in a if not r.get('newWork')};old.update({r['id']:r for r in b if not r.get('existingAppAudioPreserved')});old.update({r['id']:r for r in rows['records'] if not r.get('newWork')})
assert len(new)==8 and len(old)==43
p=Path('docs/PATCH_NOTES_OCTUBRE_2026.md');s=p.read_text(encoding='utf-8').replace('44 cantos','43 cantos')
start=s.index('| Canto | Canto |');end=s.index('## Cambios de mantenimiento',start)
alias={'El Cantico de Los 144 Mil':'El C\u00e1ntico de los 144 Mil','HEME AQU\u00cd':'Heme Aqu\u00ed'}
names=sorted([alias.get(r['name'],r['name']) for r in old.values()],key=lambda v:unicodedata.normalize('NFKD',v).encode('ascii','ignore').decode().lower())
half=22;table='| Canto | Canto |\n|---|---|\n'
for i in range(half):table+='| '+names[i]+' | '+(names[i+half] if i+half<len(names) else '')+' |\n'
s=s[:start]+table+'\n'+s[end:]
s+='\n## Rectificaci\u00f3n del 12 de octubre\n\nNo Puedo Imaginar vuelve a quedar pendiente: su MIDI no ofrece cuatro pistas vocales completas. A la Sombra de Tus Alas conserva todas sus notas y tiempos y corrige las etiquetas de sus cuatro partes principales contra el editable MuseScore. El AAB anterior queda pendiente de revisi\u00f3n y recompilaci\u00f3n. Los conteos describen recursos asignados, no certifican la correspondencia musical de todos los arreglos.\n'
p.write_text(s,encoding='utf-8',newline='\n')
report='''# Rectificaci\u00f3n de la validaci\u00f3n SATB \u2014 2026-10-12

## Error

La importaci\u00f3n de la \u00faltima tanda comprob\u00f3 cantidad de pistas, \u00faltimas notas, integridad de archivos y aislamiento de pistas. No complet\u00f3 la identificaci\u00f3n Soprano/Alto/Tenor/Bajo contra cada partitura. El normalizador del reproductor asigna etiquetas a cuatro o cinco pistas gen\u00e9ricas por cantidad; esas etiquetas generadas no constituyen evidencia musical.

## No Puedo Imaginar

Dos pistas largas agrupadas, y tres pistas con 4, 20 y 21 notas que terminan antes. No ofrece cuatro pistas vocales completas conforme al criterio solicitado. Se retir\u00f3 \u00fanicamente midi_archivo, aumentando versi\u00f3n a 5, en nube, app, PWA y repertorio_bc. ID, t\u00edtulo y PDF se conservan. No se borraron el MIDI original ni el objeto cifrado de respaldo.

## A la Sombra de Tus Alas

El editable MuseScore tiene cuatro partes expl\u00edcitas Soprano, Alto, Tenor, Bajo. La exportaci\u00f3n de diagn\u00f3stico tiene 205, 242, 236 y 232 notas; sus alturas y entradas coinciden exactamente con las pistas principales 0, 1, 3 y 4 del MIDI de origen. Las duraciones de esa exportaci\u00f3n difieren hasta 49 ms, por lo que NO se reemplaz\u00f3 el contenido musical con la exportaci\u00f3n.

En una copia del MIDI original se cambiaron solo los eventos de nombre de pista. Las principales se llaman Soprano, Alto, Tenor, Bajo; las dos fragmentarias se identifican como Parte adicional 1/2. Todos los eventos restantes quedaron byte a byte iguales tras eliminar los eventos de nombre en la comparaci\u00f3n. El original no se modific\u00f3. La nube y los cat\u00e1logos usan la nueva copia, versi\u00f3n 6; el PDF se conserva.

## Otros archivos de m\u00e1s de cuatro pistas

- Ha Triunfado mi Se\u00f1or: solista m\u00e1s Soprano, Contralto, Tenor, Bajo; las cuatro cuerdas llegan al final.
- Nadie Como T\u00fa: solista m\u00e1s Soprano, Contralto, Tenor, Bajo; las cuatro cuerdas llegan al final.
- Somos La Luz del Mundo: solista y dos juegos de Soprano, Contralto, Tenor, Bajo; las ocho pistas corales llegan al final.

Estos hallazgos verifican identificaci\u00f3n y alcance estructural. No equivalen a comprobar cada nota contra el PDF.

## Estado

- \u00daltima tanda: 29 asignaciones conservadas; una retirada.
- Recuento mensual: ocho cantos con PDF/MIDI nuevos, 43 cantos existentes con MIDI a\u00f1adido.
- Los dem\u00e1s arreglos con etiquetas gen\u00e9ricas siguen sin certificaci\u00f3n musical expl\u00edcita. Tener cuatro pistas o un rango grave/agudo no basta para concluir su identidad vocal.
- Se mantienen las observaciones previas de diferencias de comp\u00e1s/arreglo.
- AAB anterior renombrado a app-release-revision-pendiente.aab. No publicar ni anunciarlo como corregido; no se recompil\u00f3 en esta rectificaci\u00f3n.
- 109 pruebas aprobadas, incluyendo retirada de la asignaci\u00f3n incompleta, conservaci\u00f3n de su PDF y etiquetas/cantidad de notas de las partes principales verificadas del editable.
- 4.278 assets anteriores intactos; cat\u00e1logos ingleses sin cambios.

Los informes originales se conservan como registro hist\u00f3rico. La prueba de incorporaci\u00f3n utiliza incorporacion_actual.json y esta rectificaci\u00f3n.
'''
(D/'rectificacion_satb.md').write_text(report,encoding='utf-8',newline='\n')
(D/'pruebas_rectificacion_satb.txt').write_bytes(Path('output/satb_correction/2026-10-12/tests.log').read_bytes())
f=Path('E:/proyectos/CoroLLDM/public/__satb_correction.json')
if f.exists():f.unlink()
paths=['assets/catalogo.json','assets/offline_assets/catalogo.json','docs/PATCH_NOTES_OCTUBRE_2026.md','docs/repertorio/2026-10-12/incorporacion_actual.json','docs/repertorio/2026-10-12/rectificacion_satb.json','docs/repertorio/2026-10-12/rectificacion_satb.md','docs/repertorio/2026-10-12/pruebas_rectificacion_satb.txt','test/remaining_repertoire_import_test.dart','assets/offline_assets/midis/'+rect['labelCorrections'][0]['midiKey']]
subprocess.run(['git','add','--']+paths,check=True,capture_output=True)
subprocess.run(['git','add','--','public/offline_assets/catalogo.json','public/offline_assets/midis/'+rect['labelCorrections'][0]['midiKey']],cwd='E:/proyectos/CoroLLDM',check=True,capture_output=True)
print('Rectification documented and staged; original assets intact')
