# Recuerda — SATB extendido con letra por pentagrama

## Entrega

`Recuerda - SATB extendido - Cantai.musicxml` y `.mscz`, en `C:/Users/Huri_/Downloads/musescore/`.

- 88 compases escritos, sin saltos de repetición, con las dos estrofas, sus coros, el pasaje intermedio de voces independientes y el final completo.
- Cuatro pentagramas: Soprano, Alto, Tenor y Bajo. Se conserva la división interna donde la partitura contiene acordes en una cuerda; no se eliminan esas notas al abrir el SATB.
- Letra propia en cada pentagrama, también en los pasajes de «Uh/Mm» y «Ah». Una sola línea por pasada, con sílabas, sinalefas y prolongaciones.
- Re mayor y 4/4, con anacrusa de una negra; 349 negras en total.
- Dinámicas, reguladores, acentos, tenutos y ligaduras del original.
- Tempo inicial ♩ = 63. Los ritardandos y acelerandos usan los valores reales del MIDI, entre aproximadamente 47,13 y 63 BPM; no son solo instrucciones de texto.

Autor: Benjamín Rangel Valerio. La fuente está fechada el 7 de mayo de 2024, Guadalajara, Jalisco, México.

## Fuentes y reconstrucción

Canto `95053cdd-2883-4f3f-adc0-68e952460082` del catálogo local: `recuerda.pdf` y `recuerda-1780776578735.mid`.

Se cotejaron las cinco páginas digitales del PDF con las cuatro pistas del MIDI. Las columnas de notas y sus alturas se comprobaron geométricamente, incluyendo la armadura, las alteraciones y los desplazamientos de cabezas de nota cuando forman una segunda.

La secuencia desarrollada sigue el MIDI: compases impresos 1–29, repetición de 2–28 con la segunda letra y continuación de 30–61. No se superponen las dos estrofas.

Se recuperaron las duraciones escritas a partir de la articulación del MIDI (95 % menos un tick). Las subdivisiones ligadas se escribieron como aparecen en el PDF, manteniendo el sonido continuo. Las ligaduras de expresión entre notas distintas se conservaron como frases, sin convertirlas en prolongaciones de una misma altura.

La distribución de letra del final, originalmente situada encima y debajo de dos pentagramas cerrados, se revisó por cuerda. Se corrigió en esta transcripción la errata evidente «nuca» por «nunca» en «nunca dudes de Él»; no cambia la cantidad de sílabas. El PDF original se conserva.

## Validación realizada

- Apertura en MuseScore Studio 4.7.5 y renderizado de 13 páginas, revisadas visualmente.
- Alturas, entradas y duraciones escritas comparadas con el MIDI completo en los cuatro pentagramas: 513 ataques de Soprano, 537 de Alto, 508 de Tenor y 527 de Bajo.
- 2.248 figuras de nota, incluidas 163 continuaciones ligadas; 29 ligaduras de expresión, 171 articulaciones y 96 marcas dinámicas en la versión desarrollada.
- 2.014 entradas de letra conservadas, con el mismo texto y posición después de exportar y reabrir en MuseScore. No hay sílabas nuevas sobre continuaciones ligadas ni letra duplicada dentro de un acorde.
- Los 66 eventos de tempo efectivos del MIDI coinciden en posición y velocidad con el MIDI reproducido desde el archivo nativo de MuseScore.
- La comparación del MIDI reproducido también conserva todas las alturas y entradas de las cuatro pistas originales.

### Limitación comprobada de reexportación en MuseScore

MuseScore 4.7.5 omite en su propia exportación a MusicXML parte de los eventos de tempo invisibles entre notas. Una prueba mínima aislada confirmó el comportamiento. **El MusicXML entregado y el MSCZ entregado sí conservan los 66 eventos**, comprobados mediante su reproducción MIDI.

Para importar en Cantai debe usarse el MusicXML entregado directamente. Una reexportación posterior desde MuseScore puede reducir la suavidad de los cambios de tempo. La apertura en Cantai no se ejecutó en esta tarea.

Los cambios entre notas se posicionan mediante elementos MusicXML `forward`/`backup` equilibrados: no agregan notas, silencios o subdivisiones visibles a la música.

## Evidencias

Directorio `output/verovio_pilot_support/recuerda/`: `validation.json`, `preparation.json`, `pdf-layout.json`, `duration-recovery.json`, `word-diagnostics.json`, `expressions-reading.json`, renderizados, MIDI de comprobación y prueba mínima de tempo. Scripts en `tools/verovio_pilot/`.

Los originales y el repertorio de la app no se modificaron. No se hizo push a GitHub.
