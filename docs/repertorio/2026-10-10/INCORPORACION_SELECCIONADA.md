# Incorporación seleccionada del repertorio

## Alcance

Se incorporaron seis MIDI y dos PDF en los recursos offline de la aplicación.

| Canto | Cambio |
| --- | --- |
| El Cántico de los 144 Mil | MIDI añadido al ID existente; PDF conservado. |
| Hay Apóstol | MIDI añadido al ID existente; PDF conservado. |
| A Dónde Iré | MIDI exportado desde su archivo MuseScore; PDF conservado. |
| Tiempo de Agradecer | MIDI exportado desde su archivo MuseScore; PDF conservado. |
| Al Gran Señor | Obra nueva, con el PDF proporcionado por el usuario y el MIDI local. |
| Salmo 23 - Jehová es mi Pastor | Obra nueva independiente, confirmada por el usuario, con PDF y MIDI del mismo archivo MuseScore. |

Los primeros cuatro mantienen su ID, título, clasificación y referencia de PDF.
Su versión de recursos se incrementa a 2. Las dos obras nuevas usan UUID independientes.
El catálogo español pasa de 1343 a 1345 entradas; el inglés conserva sus 308 entradas.

## Fuentes y preparación

Los originales proceden de `C:/Users/Huri_/Downloads/musescore` y del PDF adjunto
`Al Gran Señor.pdf`. Los archivos originales no se modificaron.

Se normalizaron exclusivamente los nombres de las cuatro pistas activas a
Soprano, Alto, Tenor y Bajo. La preparación comprueba que todos los eventos MIDI
restantes conservan sus bytes, incluidos notas, canales, dinámica, tempos y compases.
Los MIDI exportados conservan el resultado de reproducción de MuseScore.

La versión nueva de Salmo 23 es distinta tanto de `Jehova es mi Pastor` como de
`Salmo 23`, ya presentes en la app. El archivo editable comienza con un bemol y 6/8;
las versiones existentes comienzan con cuatro sostenidos y 4/4, y un sostenido y 4/4,
respectivamente. No se infirió identidad por coincidencia de título.

El PDF nuevo se preparó en A4 vertical, con cuatro páginas. La modificación de
formato y título se realizó sobre una copia y conserva todos los compases del original.
El PDF de Al Gran Señor conserva exactamente las ocho páginas del archivo adjunto.
Se revisaron visualmente todas las páginas de ambos PDF.

## Protección y preservación

Los ocho recursos nuevos se empaquetan con el formato AES-GCM ya utilizado por la app,
con una sola capa de cifrado y rutas basadas en el hash del contenido claro.
No requieren descargar archivos para abrirse.

`preservacion.json` registra la comparación de 2164 archivos anteriores en `assets`:
solo cambian los dos catálogos españoles y se añaden ocho recursos.
Todos los archivos PDF y MIDI anteriores mantienen sus bytes.
El manifiesto conserva los hashes e identidades de las obras seleccionadas y de
las dos versiones anteriores de Salmo 23 / Jehová es mi Pastor.

## Validación

Resultado: **21 pruebas aprobadas**, cero intentos HTTP para los seis cantos y
24 voces preparadas sin pérdida de notas ni cambios de tiempo. El registro de
ejecución se conserva en `pruebas_flutter.txt`.

Las pruebas específicas usan la carga real de recursos de Flutter y
`OfflineFiles.ensurePdf` / `ensureMidi`, con caché nueva y acceso HTTP bloqueado.
También verifican la preparación de las 24 voces individuales, comparando cada nota,
su velocidad, inicio y duración con el ensamble.
Esta validación no es una prueba de escucha ni un render MP3 en un dispositivo físico.

Se revisan además los catálogos offline y la identidad de las dos obras de
La Vida se va Como el Viento.

Las modificaciones son locales al proyecto de la aplicación. No se publicaron en
Cloudflare, no se modificó el catálogo del gestor ni se ejecutó un push a GitHub.
