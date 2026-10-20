# Aleluya al Rey — SATB con letra por pentagrama

## Entrega

MusicXML y MuseScore editables en `C:/Users/Huri_/Downloads/musescore/`, con nombre `Aleluya al Rey - SATB con letra - Cantai`.

- Obra completa: 70 compases, 280 negras, nueve páginas en MuseScore.
- SATB abierto como la partitura, con clave de sol octavada para Tenor. Los pentagramas superiores se ocultan cuando están completamente en silencio; las voces no se fusionan.
- Letra independiente en Soprano, Alto, Tenor y Bajo, respetando los pasajes en que cantan textos diferentes.
- Sílabas con guiones, sinalefas, melismas y prolongaciones. Una sola línea de letra por pentagrama para el flujo de Cantai.
- Compás de 4/4, tempo real ♩ = 90, secciones A–E, dinámicas y reguladores del original.
- Tresillos del compás 17 en las cuatro voces, ligaduras de expresión y ligaduras de prolongación.

Autor: Noé Ovando Rodríguez. Arreglos: Armonía Coral.

## Fuentes y método

Canto `be1d8013-b5ba-4aed-b8f7-ae754e6e21a9` del catálogo local: `aleluya-al-rey.pdf` y `aleluya-al-rey-1779828232782.mid`.

El PDF contiene imágenes, sin texto musical digital extraíble. Se revisaron sus nueve páginas y se realizó una lectura OMR auxiliar; sus errores de notas, ritmos, letra y clave del tenor no se aceptaron automáticamente. La letra se transcribió por voz y compás y se cotejó visualmente. El MIDI de la app se usó como referencia para alturas y entradas.

El MIDI acorta normalmente las duraciones al 95 % y resta un tick, para articular la reproducción. Se recuperaron los valores escritos, incluidos los tresillos y los sonidos ligados que cruzan compases, sin convertir los pequeños espacios de articulación en silencios musicales.

### Corrección respecto al MIDI

La última nota de Soprano en el compás 54 se superpone a la entrada siguiente en el MIDI. Se escribe como corchea, tal como aparece en el PDF, sin añadir una ligadura ni una nota superpuesta en el compás 55. Se conserva su altura y su momento de entrada.

## Validación

El archivo generado, la exportación de MuseScore y una segunda importación/exportación cumplen:

- 70 compases completos por voz.
- Coincidencia de todas las alturas y entradas con los cuatro canales del MIDI: 398 ataques de Soprano, 286 de Alto, 363 de Tenor y 321 de Bajo.
- Duraciones escritas conservadas, con la corrección documentada del compás 54.
- 1.375 figuras de nota, 7 continuaciones ligadas, 34 ligaduras de expresión y 12 notas de tresillo.
- 1.253 entradas de letra conservadas, con el mismo texto y posición tras el ciclo de importación/exportación; ninguna sílaba nueva sobre una continuación ligada.
- Tempo 90 aplicado en la reproducción MIDI exportada.
- Revisión visual de las nueve páginas finales, con separación mínima de letra configurada en 1 sp.

Evidencias y scripts en `output/verovio_pilot_support/aleluya_al_rey/` y `tools/verovio_pilot/`. Validación resumida en `validation.json`; renderizados y registros en `render/`.

La validación de apertura se realizó en MuseScore; no se ejecutó Cantai en esta tarea. Los originales y el repertorio de la app no se modificaron. No se hizo push a GitHub.
