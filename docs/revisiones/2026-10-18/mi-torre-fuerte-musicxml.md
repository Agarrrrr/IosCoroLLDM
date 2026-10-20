# Mi Torre Fuerte — MusicXML SATB

## Entrega

`Mi Torre Fuerte - SATB extendido - Cantai.musicxml` y su proyecto `.mscz` en `C:/Users/Huri_/Downloads/musescore`.

Partitura completa de Isidro Amaya H., con cuatro pentagramas independientes. Se mantienen los 65 compases escritos, las dos estrofas ya desarrolladas en el original, las respuestas distintas de cada voz y los divisi de soprano dentro de su propio pentagrama. El tenor conserva su clave de sol a la octava baja; el bajo, su clave de fa.

## Fuentes y decisiones musicales

Se consultan el PDF digital de siete páginas y el MIDI de la aplicación. Las copias descifradas y los resultados de análisis se guardan en `output/verovio_pilot_support/mi_torre_fuerte`. No se modifican los archivos originales ni el catálogo.

- Se cotejan las cabezas de nota y las alturas del PDF con las cuatro pistas del MIDI. Se recuperan las divisiones gráficas de notas ligadas que el MIDI almacena como un único evento, sin añadir ataques en su reproducción.
- El acompañamiento «Uh» de Alto, Tenor y Bajo está ligado del compás 28 al 29. El MIDI reataca esas tres notas al cambiar de página; se conservan las prolongaciones del PDF.
- El alto del compás 64 lleva Si bemol en el PDF. El MIDI prolonga un Si natural desde el compás anterior. Se conserva la alteración escrita y se interpreta la curva como fraseo entre dos alturas distintas, en lugar de una ligadura de prolongación inválida.
- Se conservan 154 enlaces de prolongación, diez arcos de frase y seis signos de calderón. Los fragmentos de curvas que cruzan de página se resuelven con las prolongaciones 28–29.
- El MIDI recorta un 5 % las duraciones y deja un tick de separación. Ese recorte de articulación no se convierte en silencios de la partitura escrita.

## Letra

La letra se extrae del texto digital del PDF y se alinea por voz. Se conservan guiones, elisiones y prolongaciones. Las sílabas de un divisi se escriben una vez dentro de ese pentagrama.

El PDF deja sin texto diversos pasajes del Bajo. Se completa editorialmente su letra a partir de las otras voces, conservando sus notas y silencios: compases 7–8, 23–27, 33–34, 47–48 y 59–65. Los compases 24–26 y la entrada «oh» del 47 se adaptan al ritmo propio del Bajo.

Se normalizan erratas evidentes del original: «hemoso» → «hermoso», «espeanza» → «esperanza» y «bendio» → «bendito». Se resuelve el texto superpuesto de «cuando» del tenor y se ajustan fragmentos de letras que la extracción geométrica separaba incorrectamente. Estas decisiones afectan la letra, sin cambiar las notas.

## Tempo y expresión

- Inicio: negra = 75, tomado del MIDI al no existir una indicación inicial en el PDF.
- Compás 20: blanca = 50, equivalente a negra = 100.
- Compás 28: negra con puntillo = 50, equivalente a negra = 75; «Tempo Primo». Se aplica desde la indicación impresa, antes de la entrada de soprano. El MIDI retrasa este cambio hasta las dos últimas corcheas del compás.
- Compás 49: negra con puntillo = 60, equivalente a negra = 90.
- Los tres «rit.» llevan cambios audibles, con valores intermedios guiados por el MIDI. El MusicXML canónico contiene 30 eventos explícitos de tempo.
- Se conserva el `ff` final y los calderones impresos. MuseScore aplica su propia prolongación temporal de los calderones, incluida la del Alto en el compás 19, que el MIDI no interpreta de esa misma manera. Su duración exacta puede variar entre reproductores.

## Validación y límites

- Cuatro partes, 65 compases y 323 negras. Cada compás conserva su duración en todas las voces, con los cambios entre 6/8, 12/8, 15/8, 2/2 y 9/8.
- 1.492 notas escritas y 1.251 notas con texto de letra.
- Lectura geométrica del PDF sin discrepancias pendientes de alturas, columnas, figuras ni cabezas omitidas.
- Importación en MuseScore 4.7.5, exportación MusicXML y segunda importación: notas, alturas, duraciones, letra, prolongaciones, fraseo, calderones y los cuatro tempos principales conservados.
- Dos exportaciones MIDI de MuseScore coinciden en ataques y alturas con la interpretación del MusicXML: 381 ataques de soprano, 338 de alto, 302 de tenor y 317 de bajo. Las diferencias frente al MIDI fuente son únicamente las tres prolongaciones 28–29 y la entrada del Si bemol del Alto en el 64.
- Se revisan las nueve páginas renderizadas, con separación mínima de letra de 1 sp y espacio lateral respecto de las barras.
- Los 30 eventos de tempo canónicos se comprueban también en el MIDI generado directamente desde el proyecto MuseScore, incluidos los valores intermedios de los ritardandos.

**Para Cantai debe usarse el MusicXML entregado directamente.** MuseScore conserva los cambios intermedios de tempo en el proyecto y su reproducción, pero al volver a exportar MusicXML omite los metrónomos invisibles de las rampas de ritardando. El archivo canónico conserva esos 30 eventos; el proyecto `.mscz` también contiene su reproducción. Este límite está registrado en `validation.json` y no afecta a las notas ni a los cuatro tempos principales.

No se ha probado una importación en Cantai ni realizado una revisión cantada. Las letras completadas editorialmente del Bajo pueden ajustarse en ensayo.
