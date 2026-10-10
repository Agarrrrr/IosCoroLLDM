# Registro de picos residuales: borrador y reapertura

Continuación del [registro de correcciones](REGISTRO_CORRECCIONES_RENDIMIENTO_2026-09-30.md). La [auditoría original](AUDITORIA_RENDIMIENTO_ANDROID_2026-09-29.md), sus evidencias y los registros anteriores se conservan sin modificaciones.

## Diagnóstico en el Samsung SM-G986U

Se añadió una variante de diagnóstico del recorrido completo con traza del motor durante borrado y reapertura, y un control que reabre el mismo PDF después de retirar las anotaciones. Las trazas son instrumentación adicional: se usan para atribuir costes, no para sustituir la medición final sin instrumentación.

El primer intento de traza falló al conectar el servicio VM con DDS. Se descartó esa ejecución; la misma compilación pasó al ejecutar `flutter drive --no-dds`.

| Control antes del cambio | Raster p95 | Máximo | Cuadros sobre 16,67 ms |
|---|---:|---:|---:|
| Borrador, 500 trazos | 4,20 ms | 40,36 ms | 3/410 |
| Reabrir con anotaciones | 105,18 ms | 169,06 ms | 10/78 |
| Reabrir el mismo PDF sin anotaciones | 3,23 ms | 7,47 ms | 0/155 |

En la reapertura anotada, `LayerTree::Paint` alcanza 164 ms y `DoMakeRasterSnapshot` 162 ms. En el borrador aparecen snapshots de hasta 27 ms y `DeviceHostTransfer` de hasta 22 ms en el hilo de raster. El control sin notas sitúa el coste principal de esta reapertura en la capa de anotaciones, no en aumentar el presupuesto de la caché PDF.

## Candidato: imágenes residentes en GPU

La caché usaba `Picture.toImage`, que en la traza generaba snapshots y transferencias hacia memoria del host. Se cambia a `Picture.toImageSync`: crea el handle inmediatamente y rasteriza de forma asíncrona, manteniendo la imagen residente en GPU cuando existe un contexto compatible. [Documentación de Flutter](https://api.flutter.dev/flutter/dart-ui/Picture/toImageSync.html).

También se evita solicitar una segunda caché automática del motor para una capa que ya tiene una imagen propia. Se mantienen el límite de tres snapshots y los 24 MiB por capa. Si Flutter informa un error de rasterización al dibujar la imagen, se vuelve al dibujo vectorial para conservar el contenido.

Validación visual local: cuatro pruebas aprobadas. Incluyen transparencia, borrador, texto, desplazamientos fraccionarios, cambios de recorte y 20 commits consecutivos sobre la misma caché comparados con capas nuevas sin caché. Se mantiene el máximo de dos niveles por canal de 8 bits. La tolerancia media se cambia de 0,02 a 0,05 niveles por canal para el redondeo observado al cambiar la representación de imagen (primera comparación: 0,025). No se afirma identidad exacta de todos los píxeles. Análisis de tres archivos: sin incidencias.

La traza del candidato ya no contiene eventos `DeviceHostTransfer` ni `DoMakeRasterSnapshot` en los intervalos capturados de los dos escenarios examinados. Es una mejora de transferencia, pero no cierra el problema de reapertura: raster p95 de 116,08 ms, máximo de 151,49 ms y 8/74 cuadros sobre presupuesto. El borrador mantiene un máximo de 41,10 ms y 2/414 cuadros sobre presupuesto. Estas mediciones tienen traza activada; la decisión final debe apoyarse también en medición sin ella.

Limitación del recolector: el buffer circular de la traza del borrador conserva los últimos 3,8–3,9 segundos de un recorrido de unos siete segundos; no permite atribuir sus primeros picos. Las trazas de reapertura sí cubren sus aproximadamente 2,5 segundos completos. Se conserva esta limitación junto a los datos.

El control breve de reapertura registra seis fallos de caché por apertura para la misma lista de 505 trazos. La anchura cambia de 591,85 a 368 y después a 373,94 puntos; también cambia el origen utilizado para alinear píxeles. Sus dos reaperturas densas tienen p95 de aproximadamente 95,9 ms, frente a 3,13 ms sin notas.

Se probó ajustar el cálculo del límite mínimo y retrasar el montaje de las anotaciones hasta completar el ajuste inicial. Eso no bastó: el control `stable_viewport` todavía registró p95 de 87–88 ms y cambios de geometría. La hipótesis del límite mínimo no era la causa principal; ese cambio de cálculo se retiró. Se conserva el montaje después del ajuste inicial.

La causa adicional está en la carga progresiva: al conocer las dimensiones reales de las páginas de fondo, pdfrx recalculaba el layout y animaba otro ajuste de la página visible durante 200 ms. Cada tamaño intermedio invalidaba su caché de anotaciones.

## Correcciones finales de esta etapa

- Si la carga progresiva cambia las dimensiones de páginas de fondo y la página visible conserva su tamaño, se conserva su zoom y su posición en pantalla. Los cambios explícitos de distribución, los redimensionamientos del visor y los cambios de tamaño de la propia página visible conservan el comportamiento anterior.
- Las anotaciones se montan después del ajuste inicial del visor. La imagen de caché resuelve su origen real después del layout, evitando preparar una imagen alineada al origen provisional cero.
- Se conserva un checkpoint de tinta opaca anterior al borrado para componer los nuevos trazos sin volver a cuantizar repetidamente los bordes borrados. Las notas translúcidas se repintan completas al cambiar, manteniendo reutilización de su imagen mientras permanecen estables y al deshacer/rehacer. Es una decisión de fidelidad que puede conservar picos de confirmación en páginas muy densas con transparencia; no se da por optimizado ese caso con este benchmark de tinta opaca.
- El prefijo se pinta directamente fuera del área modificada. Dentro de ella, prefijo y trazos nuevos comparten una capa de borrado, ajustada a los píxeles físicos. Incluye margen para el grosor y el antialias; las pruebas cubren borrados puntuales y continuos sin alterar el fondo.
- Las páginas densas usan la misma composición aislada antes y después de preparar su imagen, estabilizando el antialias al pasar de vector a caché. Los colores almacenados y las matrices de OLED permanecen iguales; no se afirma identidad con cada píxel del renderizado vectorial histórico anterior a esta capa.

La prueba de regresión de carga progresiva falla antes del parche: un zoom de 2 cambia aproximadamente a 0,649. Con el parche conserva el zoom y las coordenadas relativas de la página. Pasan ocho pruebas entre PDF, filtros y anotaciones, y la prueba visual del borrador acotado pasa por separado. Incluyen 20 commits sobre notas opacas y otros 20 sobre notas translúcidas, frente a referencias recién montadas. Máximo permitido: dos niveles por canal; media inferior a 0,05 niveles por canal. Análisis final de cinco archivos: sin incidencias.

## Resultado final sin trazas, dos ejecuciones

Compilación profile del recorrido completo, con control de reapertura sin notas, sin captura de pantalla ni traza VM. Ambas ejecuciones terminaron sin errores, recuperaron exactamente 10/100/500/2000 trazos y los diez gestos de dos dedos no añadieron trazos inesperados. Los ensayos de dibujo y borrado guardaron cinco trazos por escenario.

| Escenario | Antes de esta etapa, dos pasadas | Final 1 / final 2 |
|---|---:|---:|
| Reapertura densa, raster p95 | 105,43 / 106,09 ms | **5,62 / 5,12 ms** |
| Reapertura densa, cuadros sobre presupuesto | 9/77 / 9/78 | **2/124 / 2/123** |
| Dibujo sobre 500 trazos, raster p95 | 5,92 / 5,77 ms | 5,71 / 5,58 ms |
| Dibujo sobre 500 trazos, cuadros sobre presupuesto | 0/414 / 0/416 | 0/416 / 0/411 |
| Dibujo sobre 500 trazos, RSS | 559 / 568 MiB | **441 / 451 MiB** |
| Borrador, raster p95 | 5,37 / 5,21 ms | 5,38 / 5,34 ms |
| Borrador, cuadros sobre presupuesto | 2/405 / 2/405 | 2/405 / 3/404 |
| Deshacer/rehacer, raster p95 | 3,98 / 3,81 ms | 3,61 / 3,41 ms |
| Deshacer/rehacer, cuadros sobre presupuesto | 0/122 / 0/123 | 0/122 / 0/122 |

Referencia anterior: las dos pasadas `incremental` del [registro previo](REGISTRO_CORRECCIONES_RENDIMIENTO_2026-09-30.md). La reducción de reapertura se reproduce, pero el borrador no muestra una reducción de sus picos residuales: no se declara resuelto.

La duración total de frame p95 en dibujo es 9,51 / 9,01 ms; en borrador, 9,72 / 9,59 ms; en reapertura, 10,04 / 15,35 ms. Los máximos totales de reapertura todavía son 258 / 264 ms, con máximos de raster de 153 / 151 ms. Las pausas de apertura del recorrido incluyen 2,5 segundos de espera explícita y no equivalen a tiempo de carga.

Guardado de 2000 trazos: 435 / 411 ms de latencia total, máximo retraso de temporizador de 32,17 / 25,11 ms y cero frames con UI o raster sobre presupuesto. Los cambios de página vertical y carrusel no excedieron el presupuesto en la primera pasada. La muestra térmica de la primera ejecución indica estado 0, AP 28 °C; las temperaturas de referencia eran distintas y parte de la diferencia de rendimiento o memoria puede incluir variación del dispositivo.

## Pendientes delimitados

1. **Preparación inicial de anotaciones densas.** Quedan dos frames lentos de reapertura, aproximadamente a 66–83 ms y 349–365 ms desde el primer frame del escenario. Se evitó la sucesión de escalas intermedias, pero todavía existe el trabajo inicial de pintar vectores y preparar su imagen. El siguiente experimento debe intentar prepararla una sola vez y comparar también la duración total del frame; mover trabajo fuera de `rasterDuration` por sí solo no demostraría que desapareció la pausa visual.
2. **Primeros picos del borrador.** Los dos picos principales aparecen hacia los 200 ms y 2,5 segundos del escenario, con máximos de 46–47 ms. El primero sucede durante el movimiento, antes de confirmar el primer trazo; por tanto, no se atribuyen ambos a la confirmación. La traza larga perdió el comienzo por el buffer circular. Se necesita una traza corta del primer gesto para atribuirlos antes de otra corrección.
3. **Transparencia y densidad mayor.** La política de checkpoint prioriza fidelidad de alpha. No se certifica el rendimiento de confirmación con 500 notas translúcidas ni el de densidades superiores mediante el recorrido de tinta opaca actual. Las pruebas visuales sí cubren ambos tipos de tinta.
4. **Otros equipos.** Resultados de Android SM-G986U a 60 Hz; no certifican iOS, 120 Hz ni equipos con menor memoria.

Se conservan las correcciones que reducen transferencias y reconstrucciones de geometría, manteniendo los límites de memoria y los controles de fidelidad. Esta etapa mejora la reapertura sostenida y la memoria; no representa el cierre de todos los picos.

Evidencia final: [primera pasada](auditorias/2026-09-30/residuales/final/results_summary.json), [repetición](auditorias/2026-09-30/residuales/final_repeat/results_summary.json), [regresión y pruebas](auditorias/2026-09-30/residuales/regression_tests.log), [calidad del borrador](auditorias/2026-09-30/residuales/bounded_eraser_quality.log), [análisis](auditorias/2026-09-30/residuales/final_analyze.log) y [SHA-256](auditorias/2026-09-30/residuales/SHA256.json).

Evidencias de esta etapa: `docs/auditorias/2026-09-30/residuales/`. La traza completa se conserva comprimida en gzip para evitar archivos de texto de decenas de megabytes. Los resúmenes y logs quedan separados de la evidencia original.
