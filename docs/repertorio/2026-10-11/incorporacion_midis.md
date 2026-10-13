# Incorporación de MIDI confirmados — 2026-10-11

## Resultado

- 18 asignaciones verificadas en Cloudflare y en el catálogo autenticado del gestor.
- 16 audios nuevos en la app; 2 audios existentes sincronizados conservando sus bytes.
- Los 18 PDF de la nube coinciden byte por byte con los de la app. No se reemplazó ninguna partitura.
- No se cambiaron IDs, títulos, temas, vínculos de idioma ni el orden de los catálogos locales.
- En la nube solo cambiaron midi_archivo, version y updated_at. Se usaron actualizaciones condicionadas al ID, versión y ausencia previa de MIDI.
- Las copias offline se escribieron con validateAsset, encodeDataUrl y writeTransaction del gestor, con reversión ante fallo.
- Los 4226 archivos anteriores comprobados conservaron exactamente su SHA-256; no hubo eliminaciones.
- Los catálogos ingleses no cambiaron. El catálogo de la app conserva 1345 cantos españoles y 308 ingleses.

## Cantos incorporados

| Canto | Voces | Estado |
| --- | --- | --- |
| Canten los Ángeles | 4 | Audio añadido |
| Como mi Padre | 4 | Audio añadido |
| Cosas Maravillosas | 4 | Audio añadido |
| Cuando Escucho su Nombre | 4 | Audio añadido |
| Cuerdas de Amor | 4 | Audio añadido |
| Divino Mandamiento | 4 | Audio añadido |
| El Cántico de los 144 Mil | 4 | Audio existente sincronizado |
| El Santo Llamamiento | 4 | Audio añadido |
| El Ángel de Cristo | 4 | Audio añadido |
| Firme Estoy | 4 | Audio añadido |
| Ha Triunfado mi Señor | 5 | Audio añadido |
| Hasta el Final | 4 | Audio añadido |
| Hay Apóstol | 4 | Audio existente sincronizado |
| Mi Plegaria | 4 | Audio añadido |
| Mi Siervo Amado | 4 | Audio añadido |
| Nadie Como Tú | 5 | Audio añadido |
| HEME AQUÍ | 4 | Audio añadido |
| Él Vive | 4 | Audio añadido |

Los MIDI de Ha Triunfado mi Señor y Nadie Como Tú incluyen solista además de SATB.

## Comprobación musical

Se verificaron pistas activas y nombres de voces, tonalidad/compás declarado, notas iniciales y la correspondencia visual con la partitura. Las diferencias no confirmadas quedaron pendientes. Esta comprobación no equivale a revisar de oído cada nota de toda la obra.

## Pendientes nuevos

| Canto | Motivo |
| --- | --- |
| A lo Largo de la Vida | El PDF indica 12/8; el MIDI comienza en 3/4 y después pasa a 6/8. Requiere confirmar y preparar el compás antes de incorporarlo. |
| Fue por Mí | El PDF actual y la transcripción de origen tienen diferencias de edición, tempo y colocación de cambios de compás. No se asignó este audio. |
| Linaje de Bendición | Las entradas y distribución de las voces requieren confirmar equivalencia con el arreglo actual. |
| Recordando la Muerte de Cristo | No quedó confirmada la equivalencia de las notas entre el MIDI y el arreglo cerrado actual. No se asignó este audio. |
| Ven a la Fiesta | El PDF indica 6/8 y el MIDI declara 3/8. Requiere revisión del compás. |

## Verificación de la app

Resultado: **49 pruebas aprobadas** (36 de esta incorporación y 13 de las seis incorporaciones anteriores).

Prueba: test/priority_repertoire_import_test.dart. Comprueba apertura de PDF y MIDI desde el bundle con la red bloqueada y exportación individual de cada voz conservando notas, velocidades, tiempos y duraciones.
Se ejecuta también test/selected_repertoire_import_test.dart para comprobar las seis incorporaciones anteriores.
Registro de ejecución: output/priority_midis/2026-10-11/flutter-tests.log.
No se compiló un AAB ni se probó reproducción física en un dispositivo durante esta incorporación.

## Preservación y trazabilidad

El registro previo y los recibos remotos están en output/priority_midis/2026-10-11. Los catálogos se actualizaron por ID y solo en los campos de MIDI y versión.
Los originales de E:/MIDIS REVISAR TODOS y las copias de E:/Audios Octubre permanecen intactos.
No se realizó commit ni push.
