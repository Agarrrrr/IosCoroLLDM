# Valle de los Huesos Secos: muestra MusicXML

Se utiliza la entrada **Valle de Los Huesos Secos**, ID `21a57ea9-9696-5dd0-8e8a-2c14708b2ca1`, con PDF abierto de 13 páginas. Es la entrada confirmada por el usuario, sin «El».

## Procedencia y método

- Notación del MusicXML local existente, procedente del archivo Sibelius y exportado por Sheet Music Scanner. Ese editable no tenía letra.
- Letra del PDF digital empaquetado en la app. Se recuperaron las coordenadas de los caracteres, las separaciones originales de objetos de texto y las cabezas de nota. No se utilizó reconocimiento de letra del MIDI.
- Cuatro partes conservadas abiertas: Soprano, Alto, Tenor y Bajo. 148 compases por parte.
- Los 2.398 ataques del MIDI original coinciden en altura y posición musical con la notación base después de corregir las duraciones inconsistentes del editable. El cotejo precede a las restauraciones indicadas abajo.
- Cada una de las 2.451 cabezas de nota finales se cotejó con su altura diatónica y clase de figura del PDF. La letra se asigna por proximidad horizontal dentro de cada pentagrama; esto no certifica una corrección editorial de cada sílaba.

## Correcciones de la copia

- Inconsistencias de duración en compases 14 y 15. Todas las partes terminan con exactamente cuatro negras por compás.
- Nota La bemol 2, blanca con puntillo, de tenor en el compás 100: aparece en el PDF y falta en el editable y en el MIDI. Se restaura en el MusicXML nuevo.
- Dos prolongaciones de tenor y bajo entre compases 65 y 66, cortadas en el editable y rearticuladas por el MIDI. Se restauran según los arcos del PDF entre páginas 7 y 8.
- Una ligadura de expresión en soprano, compás 87, entre Mi natural y Mi bemol. Se distingue de una prolongación porque cambia la altura.
- Errata «lglo» de bajo normalizada a «glo».
- Tempo inicial impreso 100 según este PDF. El MIDI original inicia aproximadamente a 63 y el editable indicaba 80; son diferencias de las fuentes, no se ha cambiado el MIDI.
- Líneas ordinarias de compás ocultas; barra final conservada.

## Validación y entrega

- MuseScore Studio 4.7.5 importó y reexportó correctamente el archivo completo: cuatro partes, 148 compases por parte, 2.451 notas, 2.388 notas con letra, 54 prolongaciones y una ligadura de expresión.
- Verovio validó los 54 enlaces entre notas distintas. Se corrigió el orden de los finales e inicios de ligadura en las notas intermedias para evitar enlaces de una nota consigo misma.
- Renderización de las doce páginas finales, revisión del conjunto y muestras de detalle.
- Archivo nuevo: `C:/Users/Huri_/Downloads/musescore/Valle de los Huesos Secos - SATB con letra.musicxml`.
- Fuentes, informes numéricos y vistas de revisión en `output/verovio_pilot_support/valle/`.

Esta muestra aprovecha un editable local preexistente. No demuestra todavía una conversión general de cualquier PDF y MIDI sin editable. No se ha incorporado este canto al piloto instalado ni cambiado los originales del repertorio.
