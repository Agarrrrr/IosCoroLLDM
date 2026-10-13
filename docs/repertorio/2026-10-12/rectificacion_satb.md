# Rectificación de la validación SATB — 2026-10-12

## Error

La importación de la última tanda comprobó cantidad de pistas, últimas notas, integridad de archivos y aislamiento de pistas. No completó la identificación Soprano/Alto/Tenor/Bajo contra cada partitura. El normalizador del reproductor asigna etiquetas a cuatro o cinco pistas genéricas por cantidad; esas etiquetas generadas no constituyen evidencia musical.

## No Puedo Imaginar

Dos pistas largas agrupadas, y tres pistas con 4, 20 y 21 notas que terminan antes. No ofrece cuatro pistas vocales completas conforme al criterio solicitado. Se retiró únicamente midi_archivo, aumentando versión a 5, en nube, app, PWA y repertorio_bc. ID, título y PDF se conservan. No se borraron el MIDI original ni el objeto cifrado de respaldo.

## A la Sombra de Tus Alas

El editable MuseScore tiene cuatro partes explícitas Soprano, Alto, Tenor, Bajo. La exportación de diagnóstico tiene 205, 242, 236 y 232 notas; sus alturas y entradas coinciden exactamente con las pistas principales 0, 1, 3 y 4 del MIDI de origen. Las duraciones de esa exportación difieren hasta 49 ms, por lo que NO se reemplazó el contenido musical con la exportación.

En una copia del MIDI original se cambiaron solo los eventos de nombre de pista. Las principales se llaman Soprano, Alto, Tenor, Bajo; las dos fragmentarias se identifican como Parte adicional 1/2. Todos los eventos restantes quedaron byte a byte iguales tras eliminar los eventos de nombre en la comparación. El original no se modificó. La nube y los catálogos usan la nueva copia, versión 6; el PDF se conserva.

## Otros archivos de más de cuatro pistas

- Ha Triunfado mi Señor: solista más Soprano, Contralto, Tenor, Bajo; las cuatro cuerdas llegan al final.
- Nadie Como Tú: solista más Soprano, Contralto, Tenor, Bajo; las cuatro cuerdas llegan al final.
- Somos La Luz del Mundo: solista y dos juegos de Soprano, Contralto, Tenor, Bajo; las ocho pistas corales llegan al final.

Estos hallazgos verifican identificación y alcance estructural. No equivalen a comprobar cada nota contra el PDF.

## Estado

- Última tanda: 29 asignaciones conservadas; una retirada.
- Recuento mensual: ocho cantos con PDF/MIDI nuevos, 43 cantos existentes con MIDI añadido.
- Los demás arreglos con etiquetas genéricas siguen sin certificación musical explícita. Tener cuatro pistas o un rango grave/agudo no basta para concluir su identidad vocal.
- Se mantienen las observaciones previas de diferencias de compás/arreglo.
- AAB anterior renombrado a app-release-revision-pendiente.aab. No publicar ni anunciarlo como corregido; no se recompiló en esta rectificación.
- 109 pruebas aprobadas, incluyendo retirada de la asignación incompleta, conservación de su PDF y etiquetas/cantidad de notas de las partes principales verificadas del editable.
- 4.278 assets anteriores intactos; catálogos ingleses sin cambios.

Los informes originales se conservan como registro histórico. La prueba de incorporación utiliza incorporacion_actual.json y esta rectificación.
