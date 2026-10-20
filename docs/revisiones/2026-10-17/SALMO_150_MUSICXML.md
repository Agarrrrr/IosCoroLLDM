# Salmo 150: MusicXML SATB con letra y tempo activo

17 de octubre de 2026.

## Fuentes

PDF digital del catálogo: `salmo-150.pdf`, cinco páginas, 73 compases en 4/4.
MIDI del mismo canto: `salmo-150-1779912523535.mid`, cuatro pistas nombradas
SOPRANO, ALTO, TENOR y BASS. El usuario indica usarlo como referencia musical.

Se leyeron directamente las coordenadas de los símbolos y caracteres del PDF.
No se usó OMR para decidir los tresillos. Se contrastaron alturas y ataques con
el MIDI; sus tiempos permiten distinguir las corcheas de tresillo de las
corcheas y semicorcheas normales. Se conservan cuatro pentagramas independientes.

## Resultado

- 1.118 notas escritas y 73 compases completos en cada parte.
- 106 tresillos, 318 notas: corcheas con duración de 1/3 de negra, relación
  explícita 3:2, agrupación y cifra visibles. Los ataques de los 318 eventos
  se comprobaron en el MIDI exportado por MuseScore.
- 25 ligaduras de prolongación y 31 de frase. Se conectaron siete arcos
  partidos por saltos de sistema. Las prolongaciones no pasan entre voces.
- Letra separada en 424 grupos de palabra, con metadatos silábicos que producen
  guiones musicales. Ejemplos: `a-le-lu-ya`, `a-la-bad-le`, `en-gran-de-ced`.
  Se mantienen sinalefas, repeticiones, texto distinto por voz y sílabas sobre
  varias notas; no se inventan estrofas ni se añade una nota por cada sílaba.
- Se mantienen los valores escritos, las articulaciones detectadas y los
  calderones finales. La maqueta reorganiza los saltos respecto al PDF.
- Se conserva el margen de las notas respecto a las barras en el archivo
  nativo. Al abrir MusicXML, MuseScore puede aplicar sus propios ajustes de
  espaciado; para revisar el diseño completo se entrega también MSCZ.

## Tempo: datos y comprobación sonora

El PDF indica negra = 95, pero el MIDI contiene estos dos eventos reales:

| Posición | Tempo |
| --- | --- |
| Inicio | Negra = 100 |
| Tras dos negras, dentro del compás 1 | Negra = 112 |

Se adoptó el mapa del MIDI por instrucción del usuario. Los cambios están
anclados en su posición temporal, con metadatos `sound tempo`, además del
metrónomo visible. No son simples rótulos. Durante la prueba se detectó que
MuseScore ignoraba el cambio situado mediante `offset`; se corrigió colocando
la indicación antes de la nota correspondiente.

Se verificaron ambos tempos y su posición en dos exportaciones MIDI: desde
el MSCZ y después de volver a abrir el MusicXML. Ambas conservan 100 → 112.
MuseScore añade su propio alargamiento de calderón al final (tempo efectivo
56); no procede del mapa de tempo del MIDI original.

La interpretación original también desplaza medio pulso las dos últimas
entradas y prolonga la nota final. Se conserva aquí la escritura de 4/4 y
calderón del PDF; no se promete una copia exacta de esa temporización final.

## Diferencias entre PDF y MIDI

Se siguieron las alturas del MIDI en cinco puntos, registrados en
`preparation.json`:

| Voz / compás | PDF | Entrega según MIDI |
| --- | --- | --- |
| Bajo 35 | Mi3 | La3 |
| Bajo 37 | Mi3 | La3 |
| Soprano 44 | Mi5 | Do♯5 |
| Alto 65 | Sol4 | Fa♯4 |
| Bajo 73 | Re3 | Re4 |

Tres casos se conservaron según el PDF para evitar perder una sílaba o
introducir una superposición que no aparece escrita:

- Alto 48: falta el ataque de Fa♯4 en el segundo pulso. La ausencia se
  comprobó en los eventos MIDI originales, no solo en una librería de lectura.
- Bajo 61 y 62: La3 sigue sonando desde el principio del compás hasta casi
  el final y se solapa con Re4. No existe el nuevo ataque de La3 en la
  segunda corchea del tresillo final. Se conserva la línea monódica escrita
  del PDF, con su ataque y su sílaba.

Por estas diferencias, la entrega combina la referencia MIDI con la escritura
del PDF y no debe describirse como una conversión literal del MIDI.

## Validación y entrega

MuseScore 4.7.5 abre, exporta y reimporta la partitura. Las comprobaciones
comparan alturas, duraciones racionales, prolongaciones, relaciones de tresillo
y texto/silabificación antes y después de esas operaciones. No quedaron errores
en estas comprobaciones. La revisión visual incluye todas las páginas en una
hoja de contacto y detalles de letra, tresillos y final. Esto no sustituye una
audición editorial completa de las cuatro voces.

Archivos nuevos en `C:/Users/Huri_/Downloads/musescore/`:

- `Salmo 150 - SATB con letra.musicxml`
- `Salmo 150 - SATB con letra.mscz`

Evidencias y hashes: `output/verovio_pilot_support/salmo150/`, especialmente
`notation-validation.json`, `raw-midi-events.json`, `render/playback.json`,
`render/playback-reimport.json`, `render/preview-*.png` y `delivery.json`.

Los assets originales del catálogo no se modificaron. No se integró esta
prueba en la app ni se publicó en GitHub.
