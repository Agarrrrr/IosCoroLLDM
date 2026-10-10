# Revisión de integridad del catálogo — 2026-09-30

## Error confirmado y corregido en el proyecto

El commit `6093c8d` eliminó una obra distinta y acortó el título de otra por una identificación incorrecta basada en títulos similares.

| Obra | ID original | Versión de origen | Audio |
| --- | --- | --- | --- |
| La Vida se va Como el Viento | eaeafa56-1d25-4517-b13f-1b3f7f6beced | 4 | 215.998 s, cuatro voces |
| La Vida Se Va Como El Viento y Pronto en Las Nubes Vendrá | f034d95c-6ae5-45ad-9d7c-c0ea51075a58 | 6 | 158.999 s, cuatro voces |

Se restituyeron las dos entradas y los títulos originales en los catálogos de la app, offline y del sitio. Se recuperó el PDF offline que faltaba. Se actualizaron los metadatos derivados del catálogo del sitio. Cloudflare y el catálogo público de origen ya tenían asignaciones diferentes y correctas.

Los cuatro recursos descargados se descifraron y validaron: cabeceras PDF/MIDI, hashes y análisis de voces. Los cuatro recursos empaquetados tienen exactamente el mismo hash del contenido descifrado que los originales descargados. Diferencias del cifrado no implican diferencias del contenido.

Hashes SHA-256 del contenido descifrado:

- PDF corto: `19d61581a345a7e453defcd819750e481c66c3abef671d7733e653a7dc3f149e`.
- MIDI corto: `7c5d03657ae81557310c610e626d2c2f2cbae102cbd36a839b0fd8f7a176ad02`.
- PDF largo: `0d63e82724212947869feb409ee8fce25ab8858b1d2cceebaa3fbcd025470818`.
- MIDI largo: `354d3ed82b163a02fe3cd06a59a4179df8b568e5ba068cdf062a102db24066f2`.

Esta corrección es local. No se compiló ni publicó una versión nueva durante esta revisión.

## Revisión adicional de cambios desde 5d79960

Se compararon los catálogos español e inglés anteriores con los actuales. Tras restaurar la obra corta, todos los demás 39 IDs retirados tienen una correspondencia explícita mediante `external_id` en el catálogo actual. No se detectaron más títulos renombrados para IDs conservados ni IDs duplicados. No se usó la similitud del título como prueba de identidad.

Se contrastaron 51 entradas modificadas o migradas con el catálogo público de origen: todas existen y sus nombres coinciden. Los MIDI coinciden por clave, excepto Pecador, Ven al Dulce Jesús, que conserva una ruta antigua. Ocho cantos conservan rutas PDF antiguas. Esas diferencias de ruta no prueban una obra incorrecta; queda pendiente comparar el contenido de esos recursos con las versiones actuales del origen.

### Otro defecto confirmado en el código: falta de migración de datos del usuario

Los 39 cambios de ID no tienen una migración implementada para favoritos y anotaciones. El modelo de la app no lee `external_id`; FavoritosNotifier conserva IDs literales y las tarjetas consultan `contains(canto.id)`. AnnotationStore carga y guarda en Hive con el ID recibido. Por tanto, los datos asociados al ID anterior no se recuperan al abrir la entrada con el ID nuevo.

Impacto condicional: usuarios que ya tenían favoritos o anotaciones en alguno de esos 39 cantos pueden dejar de verlos. Esto no demuestra que se hayan borrado: las claves antiguas pueden seguir en Hive. No se inspeccionaron dispositivos de usuarios ni se cuantificó el alcance real. Este defecto se documenta pendiente; no se modificó su almacenamiento durante esta revisión.

## Límites

Esta revisión cubre identidad y referencias de catálogo de esa etapa, más los cuatro recursos de las dos obras restauradas. No constituye una revisión completa de todos los cambios de código, ni una comprobación musical de todos los audios, ni una validación en dispositivos. El informe original de rendimiento se conserva sin modificaciones.
