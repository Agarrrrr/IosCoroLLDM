# Elección Apostólica — SATB con letra desarrollada

## Entrega

MusicXML canónico y proyecto MuseScore: `C:/Users/Huri_/Downloads/musescore/Elección Apostólica - SATB extendido - Cantai`.

Autor: Zimri Y. Gutiérrez. Se mantiene la atribución de la partitura oficial del Ministerio Internacional de Cultura y Educación Cristiana, J.U.D Orfeones / Comisiones de Cantos.

Se usan el PDF digital de seis páginas y el MIDI del catálogo de la aplicación. Se consultan y descifran copias en `output/verovio_pilot_support/eleccion_apostolica`; no se modifican el repertorio ni los archivos originales.

## Estructura y voces

- Cuatro pentagramas: Soprano y Alto en clave de sol, Tenor en sol a la octava baja y Bajo en fa. Se conserva el divisi del Bajo de la primera sección dentro de su propio pentagrama.
- El PDF ya es SATB abierto. Se respetan los silencios iniciales de las mujeres y las respuestas/textos distintos de cada voz.
- Los 99 compases fuente se desarrollan en 106: 1–85, segunda letra de 78–84 y segunda casilla 86–99. La entrada «Se-» se mantiene en el final de la primera casilla antes de «-guro» en la segunda pasada.
- Duración musical: 319 negras. Cambios entre 2/4, 4/4 y 6/8 conservados.
- Letra silabeada por pentagrama, con elisiones, guiones y prolongaciones; separación mínima de letra de 1 sp. Se mantienen visibles los cuatro pentagramas, incluidos los silencios de las voces que todavía no entran.

## Diferencias resueltas

Las alturas del MIDI coinciden con todas las cabezas de nota del PDF. Se reconstruyen las divisiones gráficas de notas que el MIDI guarda como eventos largos, conservando su duración mediante prolongaciones.

En Soprano y Alto, el compás 78 prolonga «fe» en la primera letra. En la segunda letra esas mismas notas cantan «ha-lla». Se conservan sus alturas y figuras, con dos ataques y un arco de frase en la segunda pasada. Son las únicas dos diferencias de ataques frente al MIDI de referencia.

Se normalizan erratas evidentes de la letra: «haste» → «hasta», «segurida» → «seguridad» y acentuación de «Día», «sabía», «escuchó», «fe» y «vio». Las vocales duplicadas impresas como «alabemo-os», «triunfare-emos» y «oró-o» se representan como prolongaciones de la sílaba sobre su frase musical, evitando cantar una palabra o sílaba añadida. No se cambian las notas por esas correcciones.

## Expresión y tempo

- Se conservan 38 enlaces de prolongación, 13 arcos de frase y 15 calderones. Cuatro de los calderones del compás fuente 62 están sobre los silencios de negra: se colocan en los silencios, sin prolongar arbitrariamente «vo».
- Se conservan 34 marcas de dinámica, 13 reguladores y 204 marcas de staccato/staccatissimo en la versión desarrollada. La articulación se codifica para reproducción, además de verse en la partitura.
- Adagio inicial: negra = 60. «A tempo»: 70, tomado del MIDI. Cambio impreso a negra = 90. Presto: 160, tomado del MIDI, desde la entrada «Mar-».
- El ritardando final lleva cambios audibles, guiados por los valores del MIDI desde 92 hasta aproximadamente 70,21. El MIDI introduce una bajada a 46 en ese punto que no corresponde a un calderón impreso; se omite esa pausa añadida y se aplica el comienzo del ritardando a 92.
- El MusicXML canónico tiene 24 eventos explícitos de tempo. MuseScore interpreta además los calderones impresos, de manera que sus pausas no tienen por qué durar exactamente lo mismo que en el MIDI fuente.

## Validación

- Lectura geométrica del PDF: sin discrepancias pendientes de alturas, columnas, figuras ni cabezas omitidas.
- 106 compases completos en cada una de las cuatro partes; 1.086 notas escritas y 1.019 notas con texto de letra.
- Importación en MuseScore 4.7.5, exportación MusicXML y segunda importación: notas, alturas, duraciones, letra, prolongaciones, fraseo, calderones, articulaciones y cinco puntos principales de tempo conservados.
- Dos exportaciones MIDI de MuseScore coinciden en ataques y alturas con el MusicXML: 295 ataques de Soprano, 260 de Alto, 199 de Tenor y 294 de Bajo.
- Los 24 eventos de tempo canónicos se verifican en el MIDI generado directamente desde el proyecto MuseScore.
- Se comprueba el efecto audible de la articulación en dos pasajes: negra con staccato de la entrada de Presto y corchea con staccatissimo posterior; ambas exportaciones MIDI conservan sus duraciones abreviadas.
- Se revisan las ocho páginas renderizadas y los pasajes ampliados de letra, articulación y cierre. Se desactiva la expansión vertical automática en el proyecto MuseScore para mantener los pentagramas dentro de los márgenes. Resultado estructurado en `output/verovio_pilot_support/eleccion_apostolica/validation.json`.

Para Cantai se recomienda importar directamente el MusicXML entregado. MuseScore conserva los cambios intermedios de tempo en el proyecto y su reproducción, pero omite algunos metrónomos invisibles al volver a exportar MusicXML. Los cinco puntos principales sí sobreviven a esa exportación; el archivo canónico conserva los 24 eventos.

No se ha probado la importación en Cantai ni realizado una revisión cantada.
