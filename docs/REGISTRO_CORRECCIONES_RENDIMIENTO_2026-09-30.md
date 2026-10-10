# Registro separado de correcciones de rendimiento

Referencia inmutable: [auditoría original del 29 de septiembre](AUDITORIA_RENDIMIENTO_ANDROID_2026-09-29.md). Este registro no sustituye ni modifica el informe original. Sus 28 evidencias conservan los SHA-256 registrados.

## Correcciones aplicadas

- PDF: el renderizado de zoom diferido toma la escala y el área visible actuales en la misma operación. Se cancelan imágenes parciales al regresar a la escala de página completa y se liberan imágenes que terminan después de cancelarse. Evita asignaciones excesivas al combinar una escala antigua con un área visible nueva.
- PDF: la caché deja de expulsar una página cuando su consumo todavía está por debajo del presupuesto. Se mantiene el presupuesto de 32 MiB y la resolución base de 1800 px; estas cifras no se consideran por sí solas fallos demostrados.
- Anotaciones: geometría reutilizable, capas independientes para notas guardadas y trazo activo, y recorte al área visible. Las páginas densas reutilizan hasta tres imágenes recientes con un presupuesto de 24 MiB por capa. Esto acelera deshacer y rehacer; no es un límite global de memoria de la aplicación.
- Descifrado: implementación AES-GCM de `cryptography`, conservando el formato existente y la ejecución fuera del isolate de UI. Las pruebas comparan los bytes con el descifrador anterior y rechazan alteraciones del IV, contenido o etiqueta. [API utilizada](https://pub.dev/documentation/cryptography/latest/dart/DartAesGcm-class.html).
- Persistencia: las anotaciones extensas se codifican y comprimen en un isolate. El envío al worker se fragmenta para reducir las pausas en UI. Los datos pequeños continúan como JSON String; la carga admite tanto el formato anterior como los nuevos bytes comprimidos.

El parche de PDF está fijado en `third_party/pdfrx`, basado en 1.3.5; al actualizar la dependencia se deben conservar o revisar las correcciones de `LOCAL_PATCHES.md` y ejecutar las pruebas de regresión.

Compatibilidad: la versión nueva lee anotaciones anteriores. Una versión antigua que solo admita String no podrá leer las anotaciones grandes guardadas con el formato comprimido nuevo. El esquema lógico JSON no cambia.

Los filtros OLED y sus colores se conservan. Las pruebas verifican también transparencia, orden de los trazos, borrador, texto, desplazamientos fraccionarios y cambios de área visible.

## Mediciones ya confirmadas, 29 de septiembre

Samsung SM-G986U, Android 13, 60 Hz; ejecución profile, recorrido completo sin capturas de pantalla en la raíz. Referencia comparable: `memoria/full_without_capture`, anterior a estas correcciones. Dos repeticiones finales con las correcciones anteriores a la composición incremental.

| Escenario | Referencia | Final, dos ejecuciones |
|---|---:|---:|
| Dibujar sobre 500 trazos, raster p95 | 18,75 ms | 9,71 / 9,65 ms |
| Borrar sobre 500 trazos, raster p95 | 19,81 ms | 9,47 / 9,21 ms |
| Deshacer/rehacer, raster p95 | 38,63 ms | 3,74 / 4,56 ms |
| Deshacer/rehacer, cuadros sobre 16,67 ms | 78/93 | 0/122 en ambas |
| RSS al dibujar sobre 500 trazos | 1226 MiB | 577 / 559 MiB |
| Descifrar El Llamado en isolate | 7833 ms | 915 / 915 ms |
| Guardar 2000 trazos, mayor retraso del temporizador | 129,59 ms | 26,93 / 30,92 ms |

La caché de imágenes añade memoria: el candidato que solo corregía PDF medía unos 493 MiB en dibujo denso, frente a 559–577 MiB con todas las correcciones. A cambio disminuyen los tiempos de raster de anotaciones.

Guardar 2000 trazos sigue tardando aproximadamente 397–449 ms en total; latencia total y pausa de UI son métricas diferentes. Se verificó la recuperación exacta de 10, 100, 500 y 2000 trazos. Los diez gestos de dos dedos no añadieron trazos inesperados.

## Continuación del 30 de septiembre

Se añadió composición incremental: al confirmar un trazo se reutiliza el prefijo de anotaciones que ya está rasterizado y se pinta solo el contenido añadido. Si contiene borrador, prefijo y trazos nuevos comparten una capa aislada para conservar el fondo PDF.

Validación local: 13 pruebas aprobadas y análisis de nueve archivos sin incidencias. La comparación de píxeles incluye lápiz semitransparente y borrador añadidos a una página densa, contra el renderizado completo sin caché; tolerancia máxima de dos niveles por canal y media inferior a 0,02.

Primera medición en dispositivo de esta continuación:

| Escenario | Raster p95 | Raster máximo | Cuadros sobre presupuesto |
|---|---:|---:|---:|
| Dibujo, 100 trazos guardados | 5,74 ms | 8,64 ms | 0/402 |
| Dibujo, 500 trazos guardados | 5,92 ms | 15,65 ms | 0/414 |
| Borrador, 500 trazos guardados | 5,37 ms | 42,45 ms | 2/405 |
| Deshacer/rehacer | 3,98 ms | 5,12 ms | 0/122 |
| Reapertura del PDF pesado | 105,43 ms | 146,49 ms | 9/77 |

RSS durante dibujo denso: 559 MiB. Descifrado aislado: 771 ms. Guardado de 2000 trazos: 425 ms de latencia total y 24,06 ms de mayor retraso de temporizador. Ningún escenario informó errores; todos los ensayos de dibujo guardaron los cinco trazos esperados y el gesto de dos dedos agregó cero trazos inesperados. La carga recuperó exactamente los conteos solicitados.

La muestra térmica durante esta ejecución indicó estado 0 y AP 30,5 °C, frente a una muestra de 35,8 °C en las mediciones anteriores. Las comparaciones entre días pueden incluir diferencias de temperatura y carga; no se atribuye toda diferencia a una única modificación.

Segunda ejecución de la misma compilación, también sin errores y con conteos correctos:

| Escenario | Raster p95 | Raster máximo | Cuadros sobre presupuesto |
|---|---:|---:|---:|
| Dibujo, 500 trazos guardados | 5,77 ms | 14,00 ms | 0/416 |
| Borrador, 500 trazos guardados | 5,21 ms | 43,59 ms | 2/405 |
| Deshacer/rehacer | 3,81 ms | 6,34 ms | 0/123 |
| Reapertura del PDF pesado | 106,09 ms | 147,30 ms | 9/78 |

RSS durante dibujo denso: 568 MiB. Descifrado aislado: 783 ms. Guardado de 2000 trazos: 386 ms de latencia y 31,17 ms de máximo retraso de temporizador. La composición incremental se conserva tras pasar las pruebas visuales y ambas ejecuciones completas.

## Problemas pendientes y alcance

- Reabrir el PDF pesado después del recorrido de anotaciones densas conserva picos: raster p95 de aproximadamente 105 ms y máximos de 145–153 ms en las dos ejecuciones anteriores. Este escenario es distinto del ensayo de persistencia de 2000 trazos. Requiere trabajo adicional; no se declara resuelto.
- Confirmar trazos de lápiz dejó de superar el presupuesto en los dos recorridos densos nuevos. El borrador conserva dos cuadros sobre presupuesto por ejecución y máximos de 42–44 ms. Queda pendiente reducir esos picos.
- Los conteos sobre presupuesto son duraciones de UI o raster, no una medición directa de cuadros perdidos en pantalla. Los temporizadores incluyen retrasos de planificación.
- Estos resultados corresponden al Android conectado; no certifican iOS ni dispositivos de 120 Hz.

Evidencias nuevas: [primera ejecución](auditorias/2026-09-30/continuacion/incremental/results_summary.json), [repetición](auditorias/2026-09-30/continuacion/incremental_repeat/results_summary.json), [pruebas](auditorias/2026-09-30/continuacion/tests.log), [análisis](auditorias/2026-09-30/continuacion/analyze.log) y [manifest de integridad](auditorias/2026-09-30/continuacion/SHA256.json). Se conservan por separado de la evidencia original. No se ha generado una versión de publicación ni realizado push como parte de esta continuación.

Siguiente trabajo: aislar en una traza de raster los picos de reapertura y del borrador, distinguir la carga de imágenes PDF de la preparación de anotaciones y aplicar la siguiente corrección contra esta misma referencia. Este registro documenta mejoras verificadas, no el cierre de todos los problemas de rendimiento.
