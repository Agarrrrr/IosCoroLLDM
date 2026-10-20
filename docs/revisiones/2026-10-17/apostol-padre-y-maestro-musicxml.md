# Apóstol, Padre y Maestro — SATB desarrollado

## Fuentes

- Registro de la app: `usmc_64b53da621b21cae02605994`.
- PDF digital original de nueve páginas: `64b53da621b21cae02605994_apóstol_padre_y_maestro.pdf`.
- MIDI asignado: `ap-stol-padre-y-maestro-1783483201702.mid`.
- Los créditos de autor/arreglo y el aviso de derechos del PDF se conservan en los metadatos MusicXML.

## Preparación

- Cuatro partes identificadas como Soprano, Alto, Tenor y Bajo. Tenor y Bajo mantienen la clave de fa del PDF.
- 92 compases originales, desarrollados a 95: 1–66, 63–65, 67–92. Se escribe la segunda vuelta con su letra correspondiente. La primera casilla (66) sólo se ejecuta una vez.
- Se conserva el compás de 1/4 del número 15, la restitución de 4/4 y los cambios de armadura.
- El unísono de hombres (5–14) se presenta en Tenor y Bajo. El pasaje de un pentagrama de soprano (15–20) se conserva como tal; el MIDI confirma que no entra Alto. La letra compartida de Soprano/Alto en 1–4 se incluye bajo cada pentagrama.
- Letra silabeada, sinalefas y melismas independientes por voz. El estilo de MuseScore establece separación mínima de letra de 1 sp y márgenes entre notas y barras de compás.
- 1.427 notas escritas, 54 enlaces de prolongación, 21 ligaduras de frase, nueve calderones, cuatro grupos de tresillos, 74 indicaciones dinámicas originales (76 al repetir la sección) y once reguladores.
- Se conservan los acentos, puntos de staccato e indicaciones de carácter. Para reproducir «Staccato Risoluto» en el unísono de hombres se añaden articulaciones invisibles únicamente donde la duración del MIDI de referencia confirma esa articulación; se conserva el rótulo visible del PDF.

## Dudas resueltas y diferencias

### Alteración sostenida por una ligadura

En Tenor, el Re♯ del compás 74 sigue ligado durante el 75. El sostenido no se repite tras la barra de compás: se mantiene su efecto por la ligadura. El MIDI confirma un Re♯ sostenido, no un cambio a Re natural. Se representa como prolongación real.

### Ligaduras entre páginas

Se completan las ligaduras que cruzan de 72 a 73 en Soprano, Alto y Tenor. El MIDI las vuelve a atacar en 73, pero el PDF contiene las ligaduras de prolongación. Se da prioridad a la partitura y se evita ese reataque.

### Ritmo del Alto en el compás 63

La segunda mitad del compás tiene ataques breves y silencios escritos. El MIDI sostiene/redistribuye algunas notas y cambia sus entradas. Se conservan las figuras y silencios claros del PDF en las dos vueltas; las diferencias exactas se registran en `validation.json`.

### Tempo e interpretación

Se conservan negra = 90 al inicio, la reducción a 78 de «poco Rit.», la recuperación a 90, el Adagio a 78, Allegro vivace a 96 y la reducción posterior a 90, usando el MIDI para los valores numéricos no impresos.

El «rit.» del compás 54 se realiza con una transición 90 → 87 → 84 → 81 → 78, que llega al Adagio del 55. **Los tres valores intermedios son una interpolación editorial**, no cifras escritas en el PDF. Los calderones se conservan como tales y su duración expresiva automática depende del reproductor. Los textos Ad Libitum y perdondosi se conservan; no se ha impuesto una duración libre o una desaceleración final que el MIDI no especifica.

### Letra

Se documentan cuatro normalizaciones menores en `lyric-corrections.json`: «alieneento» se escribe «aliento» con melisma, «salvacián» → «salvación», la S omitida en «alvación», y el acento de «envió». No se sustituyen estrofas ni contenido de la letra. Las dos líneas de la sección repetida se desarrollan en orden de interpretación.

## Verificación y entrega

Carpeta de trabajo: `output/verovio_pilot_support/apostol_padre_maestro/`.

- Lectura geométrica directa del PDF, sin OMR: `pdf-reading.json` y `pdf-layout.json`.
- Eventos, expresión y letra: `positioned-events.json`, `expressions-reading.json`, `lyric-rows.json`, `lyric-atoms.json`.
- `validation.json` comprueba las duraciones de todos los compases, alturas frente al MIDI, ausencia de reataques en las ligaduras, articulación del unísono y los cambios reales de velocidad.
- Se abre el MusicXML en MuseScore, se genera el MSCZ y su MIDI, se exporta/reimporta y se contrastan notas, letra y notación. Las vistas de las once páginas se guardan en `render/` para revisar el diseño, incluida la agrupación del final.
- Destino: `C:/Users/Huri_/Downloads/musescore/Apóstol, Padre y Maestro - SATB extendido - Cantai.musicxml` y `.mscz`.

Para Cantai se recomienda el MusicXML entregado directamente: MuseScore 4.7.5 omite algún tempo invisible al reexportarlo (por ejemplo, el paso intermedio a 87 del ritardando). El XML entregado y el MSCZ sí conservan la transición completa, contrastada con el MIDI generado por MuseScore. La prueba realizada es estructural, visual y de reproducción MIDI en MuseScore; no incluye una importación en Cantai ni una revisión humana cantada de toda la obra. El repertorio de la app y los originales no se han sustituido.
