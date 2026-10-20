# Como la Aurora — cuatro pentagramas SATB

## Entrega

MusicXML canónico y proyecto MuseScore: `C:/Users/Huri_/Downloads/musescore/Como la Aurora - SATB extendido - Cantai`.

- Soprano, Alto, Tenor y Bajo independientes; letra silabeada en cada pentagrama.
- Autor: José Pérez. Arreglo: Calep. Transcripción original: Job Ruiz P.
- Las tres estrofas se desarrollan con sus respectivos coros y el cierre en Fine. Las entradas de las estrofas segunda y tercera se conservan en la anacrusa después del calderón del coro precedente.
- Se conservan las respuestas distintas de tenor y bajo, las elisiones, prolongaciones, figuras, alteraciones y cambios entre 6/8, 9/8 y 12/8.
- 47 compases fuente —incluida la anacrusa inicial— se desarrollan en 89 compases y 320,5 negras. Ocho páginas renderizadas, con cuatro pentagramas por sistema y separación mínima de letra de 1 sp.

## Fuentes y criterio

Se usan exclusivamente el PDF digital de dos páginas y el MIDI de «Como la Aurora» del catálogo de la aplicación. Se descifran copias en `output/verovio_pilot_support/como_la_aurora`; no se modifican los recursos originales ni el catálogo.

La separación de las cuatro voces y sus posiciones se contrasta con el PDF, usando el MIDI como guía. Las alturas coinciden en todas las voces. Se recupera la duración escrita de los eventos del MIDI: las líneas de soprano y tenor tienen un recorte de articulación del 5 %, y todos los eventos tienen un tick final de separación. Ese recorte no se convierte en silencios escritos.

El tenor reataca en el MIDI el Re4 de la segunda mitad del compás fuente 29. El PDF liga las dos notas iguales; se conserva la prolongación en las tres pasadas del coro. Son las únicas tres diferencias de ataques frente al MIDI de referencia. El bajo tiene su propia ligadura en ese mismo lugar y se conserva de manera independiente.

Se conserva **negra = 90** y el calderón de cada coro. MuseScore reproduce esos calderones con el mismo mapa temporal del MIDI: tempo 45 en las posiciones 106,5, 213 y 319,5, con recuperación posterior a 90. No se añaden esos valores como indicaciones impresas de metrónomo: corresponden a la interpretación del calderón.

## Verificaciones

- Lectura geométrica del PDF: sin discrepancias de columnas, alturas, figuras ni cabezas de nota omitidas en `pdf-layout.json`.
- 89 compases completos según su duración real en las cuatro partes, incluida la anacrusa inicial y el cierre parcial en Fine.
- 1.532 notas escritas, 24 enlaces de prolongación, 12 signos de calderón y 1.508 notas con letra. Los calderones aparecen en las cuatro voces de cada uno de los tres coros.
- Importación en MuseScore 4.7.5, exportación MusicXML y segunda importación: notas, alturas, duraciones, letra, ligaduras, calderones y tempo conservados.
- Dos exportaciones MIDI de MuseScore: 377 ataques por voz, sin reatacar las prolongaciones, con posiciones y alturas coincidentes con el MusicXML.
- Revisión visual de las ocho páginas, con comprobación ampliada del coro, de la tercera estrofa y del cierre.
- Resultado estructurado y diferencias frente al MIDI guardados en `output/verovio_pilot_support/como_la_aurora/validation.json`.

No se ha probado una importación en Cantai ni realizado una revisión cantada. La entrega permite esa revisión en MuseScore y Cantai sin modificar el repertorio de la aplicación.
