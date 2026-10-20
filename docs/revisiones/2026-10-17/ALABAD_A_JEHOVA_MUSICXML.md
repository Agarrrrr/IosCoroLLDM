# Alabad a Jehová: reconstrucción y reparto de voces

Fecha: 17 de octubre de 2026.

## Fuentes y alcance

PDF del catálogo: `alabad-a-jehova-1780291784813.pdf` (7 páginas digitales).
MIDI del mismo canto: `alabad-a-jehova-1779147790894.mid`.
El usuario confirma que este MIDI tiene bien escritas las voces y autoriza usarlo
para resolver el reparto y la participación ampliada del Alto.

Se reconstruyeron notas, silencios, valores, alteraciones, letra y arcos desde
los símbolos y coordenadas del PDF. El resultado de reconocimiento OMR se
descartó como fuente de notas: confundía el reparto de los sistemas reducidos.
El MIDI se usó para las dos decisiones de voces descritas a continuación.

## Reparto confirmado

- Cuatro partes independientes: Soprano, Alto, Tenor y Bajo. Se ocultan los
  pentagramas vacíos cuando el sistema completo lo permite.
- Compases 18–32: dúo Soprano / Tenor. La clave de fa de la línea inferior
  no la convierte en Bajo: el MIDI confirma actividad en Tenor y silencio en Bajo.
- Entrada del compás 33: la continuación ligada de Re3 pertenece al Tenor.
  En el PDF está dibujada en Bajo mientras Tenor tiene silencio. Se trasladó
  esa continuación a Tenor y el silencio inicial a Bajo, siguiendo el MIDI.
- Compases 80–93: el MIDI añade Alto doblando la línea de Tenor una octava
  arriba. Se incorporaron 30 notas escritas, con el ritmo, letra y arcos de
  la línea del PDF. Los 28 ataques resultantes, descontando las continuaciones
  ligadas, coinciden en posición y altura con el MIDI.

## Presentación

Se conserva la disposición abierta de las voces, las dos líneas de texto del
Tenor en la sección repetida, los cambios de compás y armadura, las repeticiones
y las casillas. Se incorporan 85 indicaciones dinámicas digitales, 4 calderones,
70 enlaces de prolongación y 44 ligaduras de frase. Las prolongaciones usan
`tie` y `tied`, para conservar tanto el sonido como el arco visible.

Se añadió espacio a ambos lados de las barras y se ajustaron los saltos de
sistema para evitar un compás final aislado. La maqueta nativa tiene 9 páginas;
no reproduce exactamente los saltos del PDF. Se revisaron las nueve páginas
en una hoja de contacto y en detalle las entradas de voces, versos y final.
Esta comprobación no equivale a una revisión editorial musical independiente
de cada símbolo ni a una audición completa de las cuatro voces.

## Comprobaciones automáticas

- 138 compases por parte; duración completa en todos los compases.
- Se conservan las alturas de las 973 notas del PDF y su voz, salvo la
  continuación de Tenor expresamente corregida en el compás 33.
- 1.003 notas totales al incorporar las 30 de Alto.
- No hay prolongaciones sin inicio, sin cierre, interrumpidas por silencios
  ni que pasen de una voz a otra.
- Apertura, exportación y reimportación correctas en MuseScore 4.7.5.
- La exportación de MuseScore conserva alturas, duraciones, prolongaciones y
  textos de letra respecto al archivo reconstruido.

Evidencias: `output/verovio_pilot_support/alabad/notation-validation.json`,
`render/layout-validation.json`, `render/preview-*.png` y `delivery.json`.

## Archivos entregados y límite de MusicXML

Destino: `C:/Users/Huri_/Downloads/musescore/`.

- `Alabad a Jehová - SATB revisado contra PDF.musicxml`
- `Alabad a Jehová - SATB revisado contra PDF.mscz`

El archivo nativo conserva los ajustes de espaciado: mínimo de 2 espacios
de pentagrama antes de una primera nota de compás. MuseScore restablece ese
ajuste al importar MusicXML: en la reimportación medida el mínimo es 1,25
espacios. Por eso se entrega también MSCZ para revisar la maqueta con su
espaciado completo. No se promete identidad visual entre programas.

Los originales del repertorio no se modificaron. Esta entrega es una partitura
de prueba independiente; no se integró en la aplicación ni se publicó en GitHub.
