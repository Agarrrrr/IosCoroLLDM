# Dios Poderoso: reconstrucción SATB con referencia MIDI

17 de octubre de 2026.

## Fuentes y método

PDF del catálogo `dios-poderoso.pdf` (12 páginas digitales), MIDI
`dios-poderoso-1779998759229.mid`. Autor indicado en el PDF:
Benjamin Rangel Valerio.

Se reconstruyeron los 103 compases desde las coordenadas de los símbolos y
letras digitales del PDF, sin OMR. El MIDI sirve como referencia de alturas,
entradas y prolongaciones, según la instrucción del usuario. Sus cuatro
pistas, denominadas Piano, coinciden con el orden Soprano, Alto, Tenor y Bajo
del PDF; el tenor conserva la clave de sol octavada.

## Resultado y controles musicales

- Cuatro partes separadas: SATB abierto; no se fusionaron voces en un pentagrama.
- 103 compases completos de 4/4 por parte; 1.946 cabezas de nota escritas.
- 1.906 ataques, coincidentes con el MIDI en altura y posición musical:
  Soprano 395, Alto 496, Tenor 520 y Bajo 495.
- 40 enlaces de prolongación con continuidad sonora y 52 arcos de frase.
  Se conectaron ocho arcos partidos por cambios de sistema. Se contrastó
  cada prolongación con el MIDI para distinguirla de una frase de notas
  repetidas de la misma altura.
- Se mantienen semicorcheas, fusas y silencios cortos. Los cuatro dobles
  puntillos del compás 92 se representan como tales y completan el compás.
  Los números pequeños de la sección inicial no se interpretaron como
  tresillos: las duraciones escritas y el MIDI completan el 4/4 sin tuplets.
- Se incorporan 84 indicaciones dinámicas, 13 calderones, 42 acentos,
  12 tenutos, los 16 signos en V del original y tres reguladores rectos.

### Dos ajustes según el MIDI

1. Tenor, compás 42: el PDF cambia de Si♭3 a Sol3 mientras el MIDI prolonga
   Si♭3 desde el compás 41. Se conserva Si♭3 ligado en el 42; el Sol3 entra
   en el 43 como en el MIDI.
2. Bajo, compás 74: las tres sílabas de «corazón» se alinean en las posiciones
   2,25 / 2,50 / 2,75 negras del compás, según el MIDI. Sigue un silencio de
   negra. El PDF separa las dos últimas entradas y las coloca algo después.

## Letra y presentación

Se recupera la letra de cada voz, con 906 grupos de palabra. Se repartieron
conjuntamente los caracteres entre las notas para resolver etiquetas apretadas
como «podero», «miReyEterno» y «miDios». Se conservan las letras del PDF y
se añade metadato silábico para generar guiones musicales entre las notas
de una palabra, además de los enlaces de las sinalefas.

Se incluyen tanto los caracteres de 13,02 puntos como los de 11,47 puntos
usados para comprimir la letra en algunas secciones. Se verifica que la
secuencia de letras de cada voz coincide íntegramente con los caracteres
digitales del PDF, para detectar omisiones por cambio de tamaño tipográfico.

No se duplicaron estrofas ni se inventó letra para notas de prolongación.
Se conserva incluso la escritura poco habitual de algunas palabras del PDF;
la recuperación de caracteres no constituye una corrección editorial del texto.
Las evidencias de reparto y ajustes de etiquetas están en
`underlay-validation.json` y `lyric-words.json`.

Se amplió la separación respecto a las barras de compás en el archivo nativo.
La maqueta reorganiza los sistemas y páginas para acomodar la letra con guiones;
no se promete una copia exacta de la maquetación original. MSCZ conserva los
ajustes de espaciado; al importar MusicXML, MuseScore puede aplicar su estilo.

## Tempo que afecta a la reproducción

El MIDI solo contiene negra = 98. El PDF también indica 98 al comienzo y añade
`dim tempo`, `Perdendosi` y `Adagio`, sin cifras para esos cambios finales.

Se mantiene 98 durante el cuerpo de la obra. Desde el compás 90, a partir de
su segunda entrada, se aplica una reducción escalonada: 94, 88, 82, 78, 74,
72, 70, 68, 66 y 64 BPM. El Adagio del compás 95 se fija en 60 BPM.
Estas cifras finales son una interpretación elegida para dar efecto audible
a las indicaciones cualitativas del PDF; no proceden del MIDI original.

Los cambios se anclan a notas concretas con `sound tempo`. Se comprueba su
efecto en el MIDI exportado desde MSCZ y tras reimportar el MusicXML.
MuseScore reduce adicionalmente el tempo efectivo durante los calderones y
lo restablece al terminar cada uno. Esos eventos adicionales no se confunden
con cambios de tempo originales del MIDI.

## Validación y alcance

Se comprueban compases completos, prolongaciones dentro de la misma voz,
coincidencia de ataques con el MIDI original y conservación de alturas,
duraciones, letra y silabificación al exportar y reimportar en MuseScore 4.7.5.
También se comprueban las notas y los cambios de tempo de las dos exportaciones
MIDI resultantes. La revisión visual usa las páginas renderizadas y una hoja
de contacto. No sustituye una audición editorial completa de las cuatro voces.

Evidencias: `output/verovio_pilot_support/dios_poderoso/`, en particular
`notation-validation.json`, `preparation.json`, `expression-validation.json`,
`render/playback.json`, `render/playback-reimport.json` y `delivery.json`.

## Entrega

En `C:/Users/Huri_/Downloads/musescore/`:

- `Dios Poderoso - SATB con letra.musicxml`
- `Dios Poderoso - SATB con letra.mscz`

Los archivos originales del repertorio no se modificaron. No se integró esta
prueba en la aplicación ni se publicó en GitHub.
