# El Cántico de Moisés — preparación SATB para MuseScore / Cantai

## Fuentes y alcance

- PDF digital de la aplicación: `64b5f67921b21cae02606966_el_cantico_de_moises.pdf`, 12 páginas, Miguel Franco.
- MIDI de referencia asignado al mismo registro `usmc_64b5f67921b21cae02606966`, cuatro pistas.
- Se conservan las cuatro partes abiertas: Soprano, Alto, Tenor (clave de sol octavada) y Bajo.
- 118 compases originales, desarrollados a 122 al escribir la repetición inicial: 1–5, 1–4, 6–118. Duración escrita total: 484 negras.
- Letra silabeada independiente por pentagrama, sinalefas y extensiones vocales. Separación mínima de letra de 1 sp en el estilo de MuseScore; margen entre notas y barras de compás.
- Se mantienen armaduras, compases de 2/4 intercalados, tresillos, divisi final, ligaduras, calderones e indicaciones de carácter. El PDF no contiene matices p/f o reguladores: no se han inventado.

## Criterios y diferencias encontradas

Se ha dado prioridad a la notación del PDF cuando contradice el MIDI, sin asumir que el MIDI esté libre de errores.

| Lugar del PDF | Diferencia | Decisión |
| --- | --- | --- |
| Inicio | El PDF indica negra = 90; el MIDI empieza a 70. | Se mantiene 90. |
| Soprano, compás 33 | La blanca tiene dos puntillos y termina con corchea; el MIDI anticipa esa corchea media negra. | Se conserva el ritmo impreso. |
| Tenor, compases 60–62 | El MIDI sostiene Re durante doce negras; el PDF cambia Re–Do natural–Si. | Se conservan las tres alturas y la ligadura de frase. |
| Tenor, compases 65–66 | El MIDI añade un Re durante siete negras donde el PDF contiene silencios, antes de la entrada escrita. | Se conservan los silencios y la entrada del PDF. |
| Alto, compás 100 | El MIDI usa dos corcheas Sol♯–Si en el último tiempo; el PDF muestra semicorcheas La–Sol♯–La–Si, con ligadura desde el La anterior. | Se conserva el pasaje del PDF. |
| Bajo, compás 95 | El Fa♯ ligado pasa sobre un Mi intermedio. El MIDI sostiene Fa♯ mientras suena Mi. | Se representa Mi en una segunda voz temporal dentro del mismo pentagrama de Bajo, para que la ligadura sostenga el intervalo completo sin reataque. |

Las velocidades de Andante, Marciale y Vivace se apoyan en el MIDI. Son cambios reales de reproducción, no únicamente rótulos. Se conserva el 40 final impreso; los calderones tienen la interpretación automática de MuseScore, que puede diferir de la duración expresiva del MIDI original.

Correcciones locales de letra documentadas en `lyric-corrections.json`: entrada de «Can» en la primera nota de los tresillos, «Grade» → «Grande» en Bajo, separación «siem-pre» de Alto y «es» sobre melisma de dos notas.

## Verificación

Los registros reproducibles están en `output/verovio_pilot_support/cantico_moises/`:

- `pdf-reading.json`, `positioned-events.json`: lectura geométrica de notas y asignación a compases.
- `expressions-reading.json`: ligaduras, frases y calderones.
- `lyric-rows.json`, `word-diagnostics.json`, `lyric-atoms.json`: extracción, silabificación y alineación de letra.
- `validation.json`: comprobación de duración de todos los compases, alturas, ataques, ligaduras, letra y reproducción MIDI generada por MuseScore.
- `render/`: MSCZ, exportación/reimportación MusicXML y vistas de las 14 páginas para revisión visual.

La validación comprueba 2.214 notas escritas, 43 enlaces de prolongación, 62 ligaduras de frase, 24 calderones y 51 notas de tresillo. Se contrasta que la reproducción nativa no reataque las notas ligadas y que existan los siete cambios de velocidad explícitos del archivo entregado.

### Limitación de MuseScore 4.7.5

MuseScore conserva los cambios de velocidad invisibles en el MSCZ y en su reproducción, pero omite algunos al volver a exportar MusicXML. **Para Cantai debe utilizarse directamente el MusicXML entregado**, no una nueva exportación de MuseScore. Las notas, letra, ligaduras y calderones sí se comprueban después de exportar y reimportar.

No se han sustituido recursos del repertorio de la app ni modificado los originales. La comprobación realizada es estructural y visual en MuseScore; no equivale a una prueba de importación en Cantai ni a una revisión musical humana de toda la obra.
