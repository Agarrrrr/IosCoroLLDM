# Cuán Amables Son Tus Moradas [Oficial] — MusicXML

Fecha: 2026-10-18.

## Fuentes

- Registro solicitado: `usmc_64b5f64821b21cae02606946`, **Cuan Amables Son Tus Moradas [ Oficial ]**.
- PDF oficial de seis páginas: `assets/offline_assets/pdfs/64b5f64821b21cae02606946_cuan_amables_son_tus_moradas.pdf`.
- Este registro no declara MIDI. Se contrastó el MIDI existente en la otra entrada del título: `assets/offline_assets/midis/cuan-amables-son-tus-moradas-1779479451976.mid`, registro `96c780ad-8268-4dd2-b139-2e1e7fc96fba`.
- El arreglo oficial conserva cinco partes independientes: solista, soprano, alto, tenor y bajo. Se mantienen las cuatro cuerdas abiertas y el solista aparte, incluido cuando canta simultáneamente con el coro.
- Las fuentes y el catálogo de la aplicación permanecen intactos. La entrega es independiente para MuseScore/Cantai.

## Estructura y discrepancias resueltas

- 91 compases numerados como el PDF, 4/4, Re mayor. Se conservan los compases vacíos y las pausas entre secciones.
- La guía MIDI incluye una sección coral anterior al primer solo del PDF. Se descartan los ataques corales previos al tick equivalente a la negra 195. La relación temporal de la guía con el PDF es `q−96` antes de la negra 292 y `q−92` desde ahí, restaurando el compás 50 de silencio omitido en el MIDI. La parte solista se conserva en su posición del PDF.
- Soprano, compás 89, último tiempo: Do sostenido según el PDF; el MIDI tiene Si natural.
- Bajo, compás 69: La con duración de tres negras seguido del siguiente ataque en el cuarto tiempo. El MIDI reataca innecesariamente en los tiempos segundo y tercero; se sustituyen por la duración sostenida que muestra el PDF.
- Alto, compás 43: ligadura de prolongación sobre «en», con sus dos figuras escritas. No se confunde con una repetición de sílaba.
- Alto, compás 86: dos unísonos duplicados de las voces internas aparecen como notas MIDI de duración cero junto a notas válidas. Se conserva un ataque válido por unísono y su duración de negra, manteniendo los divisi reales de los compases 85–86.
- Las ligaduras que cruzan sistema/página en solista 61–62 y alto 78–79 están completas; los fragmentos gráficos del PDF corresponden a estas prolongaciones.

## Letra y expresión

- Letra silabeada por cada pentagrama, siguiendo sus propias entradas, repeticiones de palabras y melismas. Se conservan las sinalefas y las prolongaciones.
- Alto, compás 31: se restaura la vocal «a» omitida en «de-se-a», al comenzar el segundo arco de frase en el tercer tiempo. Es una corrección editorial de texto; las notas no cambian.
- Se normalizan erratas claras de letra: «mìo» → «mío», «Jeová» → «Jehová», «Ttus» → «tus» y el «sí» afirmativo. Se mantienen distintas las letras y los ritmos de cada cuerda.
- 38 indicaciones dinámicas, once acentos, cinco calderones y seis reguladores. Se conservan también las indicaciones textuales «cresc.», «Andante tranquillo», «Soprano o Tenor», «Solo» y «Con fervor».
- El PDF indica negra = 70. Se usa este valor en lugar de copiar los distintos tempos base 71/80 de la otra versión MIDI.
- Las ocho indicaciones de ritardando/rallentando/allargando modifican la reproducción y recuperan el tempo. Sus destinos numéricos no están especificados en el PDF: se documenta la decisión editorial de bajar gradualmente hasta 55 BPM y volver a 70. En la cadencia de allargando de los compases 46–49 se sostiene el valor lento hasta la entrada siguiente.
- Espaciado mínimo de letra configurado a 1 sp y margen entre notas y barras. Cada parte conserva su pentagrama propio; se ocultan pentagramas vacíos como en el original, sin juntar voces en un pentagrama cerrado.

## Validación

`tools/verovio_pilot/validate_moradas.py` comprueba:

- Importación en MuseScore 4.7.5, exportación y nueva importación.
- Cinco partes, 91 compases completos, 364 negras de duración escrita.
- 994 notas escritas, ocho continuaciones ligadas y 73 arcos de expresión.
- 882 notas con letra, sin fragmentos consonánticos ni palabras sin resolver en la alineación.
- 986 ataques efectivos: solista 183, soprano 191, alto 216, tenor 219 y bajo 177. Coinciden en altura y posición con ambos MIDI generados por MuseScore, sin ataques añadidos en las prolongaciones.
- Ataques y duraciones agregadas contrastados con el MIDI de referencia tras las diferencias documentadas arriba.
- Todas las cabezas de nota del PDF digital representadas: sin discrepancias pendientes de posición, altura, figuras de blanca/redonda o notas omitidas. Se reúnen sólo los dos unísonos exactos duplicados de alto 86.
- Figuras de silencio conservadas individualmente cuando el PDF las imprime, evitando sustituir dos silencios de negra por uno de blanca. Presupuesto total de silencio verificado, sin discrepancias pendientes.
- Notas, letras, prolongaciones, frases, acentos y calderones preservados en los tres XML.
- Los 119 puntos de tempo del XML canónico se aplican en el proyecto nativo. El calderón final añade su prolongación propia en MuseScore.
- Revisión visual de las seis páginas fuente, hoja de contacto y páginas completas representativas de la entrega. Siete páginas finales, sin recorte inferior. Se desactiva la expansión vertical automática.

## Entrega y límite de intercambio

En `C:/Users/Huri_/Downloads/musescore/`:

- `Cuán Amables Son Tus Moradas - Oficial - SATB y solista - Cantai.musicxml`
- `Cuán Amables Son Tus Moradas - Oficial - SATB y solista - Cantai.mscz`

Para Cantai utilizar directamente el XML canónico entregado. MuseScore reproduce la curva completa en el proyecto nativo, pero al reexportar/reimportar MusicXML omite o redondea puntos ocultos y puede perder cambios de tempo asociados a partes que se ocultan. Por ello se comprueban y se documentan por separado las notas/letras y los tempos del intercambio. No se ha probado esta entrega dentro de Cantai.

Evidencia: `output/verovio_pilot_support/cuan_amables_oficial/`, incluidos `validation.json`, `preparation.json`, `rest-validation.json`, vistas previas y manifiesto de hashes `delivery.json`.

## Reproducción del trabajo

Ejecutar en orden los scripts de `tools/verovio_pilot/`: `inspect_moradas.py`, `moradas_pdf.py`, `moradas_model.py`, `moradas_geometry.py`, `moradas_rests.py`, `moradas_underlay.py`, `moradas_words.py`, `moradas_expressions.py`, `prepare_moradas.py`, `render_moradas.py`, `validate_moradas.py` y `deliver_moradas.py`.

El paso de entrega comprueba hashes antes de reemplazar archivos para preservar posibles ediciones del usuario.
