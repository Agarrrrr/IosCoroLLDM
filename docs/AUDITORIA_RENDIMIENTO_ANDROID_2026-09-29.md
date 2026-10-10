# Auditoría de rendimiento en Android físico — 29 de septiembre de 2026

## Resultado

**Sí hay problemas reproducibles de rendimiento en las anotaciones.** La conclusión anterior de que el único cuello de botella era el JSON no se sostiene en este dispositivo: el coste principal observado al dibujar con muchas anotaciones está en rasterización/composición. También hay una espera importante al preparar por primera vez un PDF cifrado grande.

Esta auditoría cubre el motor PDF y las anotaciones, con controles de arranque y catálogo. Distingue mediciones, comportamiento confirmado en código e hipótesis pendientes. No pretende garantizar que se hayan encontrado todos los fallos posibles de la aplicación.

## Dispositivo y método

- Samsung **SM-G986U**, SoC **SM8250**, Android **13**.
- Pantalla configurada a **1080 × 2400**, densidad **450 dpi**, DPR **2,8125**, **60 Hz** activos. No se midieron 120 Hz ni iOS.
- Memoria física reportada: aproximadamente **10,35 GiB**. Alimentación USB. Estado térmico Android **0**, sin limitación térmica indicada en las muestras.
- Código base: **3.1.0+35**, commit `e6a2c22d1345e8ce3e4ffde3a0ef136cb955ffd6`, con instrumentación de auditoría sin cambios al motor de producción.
- APK **profile/AOT** en el teléfono, aplicación independiente `com.lldm.coro.perfaudit`. La aplicación habitual y sus anotaciones se conservaron. El driver elimina la instalación de prueba al terminar.
- Se usa el `VisorScreen`, `AnnotationLayer`, `PdfEngineNotifier`, `OfflineFiles` y `AnnotationStore` reales. Los eventos son sintéticos, procesados y renderizados en el teléfono; no se mide latencia física desde el contacto hasta la pantalla.
- Dos recorridos generales y un recorrido de controles focalizados. La segunda ejecución y los controles evitan las marcas gráficas de los punteros del framework de pruebas. El tramo `draw_5_strokes_warm_page` de la segunda ejecución se excluye por pérdida y recuperación del primer plano. También se excluye `viewer_no_zoom_500_saved` del control final: la app perdió visibilidad durante esa fase y solo se recogieron 22 cuadros en 8,2 segundos.
- `FrameTiming` recoge tiempos de UI y raster por separado; se filtran por el intervalo de cada escenario. Se espera fuera del intervalo para recibir los lotes del motor. Presupuesto aproximado: **16,67 ms** por etapa a 60 Hz.
- «Fuera de presupuesto» significa que UI o raster superaron ese tiempo; **no equivale a contar cuadros perdidos por la pantalla**. Tampoco se suman UI y raster, porque se ejecutan en una tubería.
- Los tiempos totales de dibujo incluyen pausas entre eventos y guardados. Los de preparación de PDF, render nativo y persistencia son latencias de operación, no milisegundos de bloqueo de UI.
- La segunda ejecución añade un temporizador de 16 ms. Sus intervalos largos detectan retrasos de planificación que pueden quedar fuera de `buildDuration`; no atribuyen por sí solos la causa a una función.
- Anotaciones de estrés: 100 o 500 trazos de 60 puntos en una página; cinco trazos nuevos de 120 movimientos por escenario. Los trazos sintéticos se solapan y no representan todas las maneras de anotar.
- No se inicializan anuncios ni compras. El PDF usado para el recorrido visual, **The Holy City**, no tiene MIDI. No se midió competencia con reproducción/exportación de audio.

Metodología de referencia: [Flutter: medir rendimiento con pruebas de integración](https://docs.flutter.dev/cookbook/testing/integration/profiling) y [Flutter: rendimiento de UI](https://docs.flutter.dev/perf/ui-performance).

## Hallazgos medidos

### 1. Alta: dibujar con una página muy anotada excede sostenidamente el presupuesto gráfico

Resultados de la segunda ejecución válida, corroborados por la primera:

| Escenario | Cuadros | UI p95 | Raster p50 | Raster p95 | Raster máximo | Fuera de presupuesto |
|---|---:|---:|---:|---:|---:|---:|
| Cinco trazos, página inicialmente vacía | 371 | 3,18 ms | 5,20 ms | 7,96 ms | 491,05 ms | 3/371 |
| Dibujar con 100 trazos guardados | 384 | 1,99 ms | 11,08 ms | 13,93 ms | 42,16 ms | 15/384 |
| Dibujar con 500 trazos guardados | 258 | 1,89 ms | 22,56 ms | 87,71 ms | 93,63 ms | **258/258** |
| Borrar con 500 trazos guardados | 250 | 1,81 ms | 22,83 ms | 91,36 ms | 110,93 ms | **250/250** |
| Diez pares deshacer/rehacer, página densa | 21 | 25,83 ms | 102,25 ms | 103,31 ms | 104,70 ms | **21/21** |

En la primera ejecución, los 265 cuadros de dibujo denso y los 255 de borrado también excedieron el presupuesto. Cada secuencia de dibujo/borrado guardó los cinco trazos esperados.

**Impacto:** pérdida de fluidez al dibujar/borrar y respuesta lenta de deshacer/rehacer en páginas muy cargadas. La mediana de raster ya supera 16,67 ms antes de considerar los picos.

**Atribución:** el `setState` por evento no explica por sí solo este resultado; UI p95 se mantiene por debajo de 2 ms durante dibujo denso. El `Path` activo sí se amplía incrementalmente. Un `RepaintBoundary` conserva una lista de dibujo y puede permitir caché raster, pero no garantiza coste gráfico constante ni una textura permanentemente reutilizada.

Código relevante: [trazo incremental](../lib/features/visor/widgets/annotation_layer.dart), líneas 85–110; separación de capas, 421–439; reconstrucción de paths guardados, 595–605; `shouldRepaint`, 634–642. Cada cambio de la lista guardada invalida su pintor. El borrador añade `saveLayer` en 539–543. No se atribuye todo el coste al borrador: la página densa ya falla antes de incorporarlo.

**Acción propuesta:** perfilar la capa guardada, limitar el trabajo a regiones visibles y evaluar caché geométrica/raster por regiones con invalidación al editar. Comparar antes/después con estos mismos escenarios y con textos. Cambiar exclusivamente `setState` por otro mecanismo no resuelve el coste raster demostrado.

### 2. Alta: pico al iniciar el dibujo y presión de memoria

El primer escenario de dibujo presenta un máximo de raster de **763,06 ms** en la primera ejecución y **491,05 ms** en la segunda. En ambas, el RSS pasa de aproximadamente **440–450 MiB** tras el zoom a **1110–1122 MiB** tras los primeros cinco trazos. Es un pico de inicio dentro de ese escenario; no se ha identificado todavía el evento exacto ni demostrado una compilación de shaders.

**Condición importante:** esos dos recorridos hicieron navegación, zoom y capturas antes de dibujar. En el control focalizado, el dibujo sin visor no tuvo cuadros sobre presupuesto (máximo raster 15,15 ms). Al abrir después el visor sin zoom ni capturas previas y dibujar cinco trazos, el máximo fue **20,57 ms**, uno de 406 cuadros sobre presupuesto y RSS **467 MiB**. Ese control también tiene otra secuencia de calentamiento. Por tanto, el pico de 0,5–0,8 segundos **no debe generalizarse a todo primer trazo**; debe investigarse la combinación de zoom, cachés, captura e interacción posterior.

La muestra Android durante anotaciones densas registró **1 234 257 KiB PSS ≈ 1205 MiB** y **1 343 260 KiB RSS ≈ 1312 MiB**. Gran parte figura en `Other dev` (942 484 KiB PSS), no en el heap Dart. No debe presentarse toda esa memoria como JSON, trazos o como una fuga confirmada.

El RSS final, tras retirar el visor, bajó a **460 MiB** y **480 MiB** en las dos ejecuciones. Esto muestra liberación importante. La instrumentación y las capturas también consumen memoria; el límite PDF de 32 MiB no es un límite de memoria de toda la aplicación.

**Impacto:** pausa perceptible y presión de memoria; riesgo mayor en equipos con menos RAM, todavía sin un cierre por memoria reproducido.

**Acción propuesta:** identificar asignaciones y recursos gráficos de la primera interacción, revisar dimensiones de capas y comportamiento del caché de raster. Android tiene Impeller desactivado explícitamente en el [manifiesto](../android/app/src/main/AndroidManifest.xml), líneas 58–61; cualquier comparación con otro backend debe volver a comprobar la orientación del PDF que motivó esa configuración.

### 3. Alta: primera preparación de un PDF cifrado grande tarda alrededor de ocho segundos

| PDF | Tamaño descifrado / páginas | Preparación inicial, dos ejecuciones | Desde caché |
|---|---|---:|---:|
| Canten a Cristo Rey | 51 230 B / 1 | 63–80 ms | 1,5–2,5 ms |
| The Holy City | 12 492 044 B / 9 | 171–213 ms | 3,9–4,5 ms |
| El Llamado a mi Ser | 7 361 367 B / 2 | **7968–8069 ms** | 2,4–2,9 ms |

Se mide `OfflineFiles.ensurePdf`: obtención local, validación, posible descifrado y escritura. No es tiempo de dibujo de página. Durante la preparación lenta el indicador siguió produciendo cuadros: no hubo etapas UI/raster de más de 16,67 ms en ese escenario.

El asset de El Llamado a mi Ser tiene 7 361 395 bytes, 28 bytes más que el PDF resultante, y no tiene cabecera `%PDF`. El código usa AES-GCM de PointyCastle dentro de `Isolate.run`. Pasarlo a un isolate ya está implementado; esa separación protege la UI, pero no elimina la espera del usuario.

**Causa aislada y confirmada:** en el control final se leyó el asset antes del intervalo y se midió únicamente el descifrado en un isolate. Dos repeticiones: **7672,36 ms** y **7784,31 ms**. Ambas devolvieron un PDF válido de 7 361 367 bytes, sin etapas UI/raster sobre presupuesto en 461 y 467 cuadros respectivamente. Esto atribuye la mayor parte de la preparación de ocho segundos al descifrado y su ejecución en el worker, sin confundirla con red, escritura o render PDF.

El inventario local contiene **1663** archivos en la carpeta de PDF, de los cuales **1654** no comienzan por `%PDF` y son candidatos al formato cifrado heredado. No se descifraron todos ni se extrapola una espera de ocho segundos a todos ellos. Otros candidatos grandes: Tu Destino Soy Yo y Quién Subirá al Monte, aproximadamente 7,2 MB cada uno.

Código: [preparación offline](../lib/core/offline/offline_files.dart), líneas 57–86 y 225–244; [descifrado](../lib/core/security/file_crypto.dart).

**Acción propuesta:** medir una implementación de descifrado acelerada compatible con los assets existentes, o preparar la caché de forma controlada antes de abrir el canto. Dar progreso específico para archivos grandes. Evitar un precalentamiento masivo sin límites de espacio, batería y concurrencia.

### 4. Media: PDFs complejos tienen rasterización nativa costosa

Render de la primera página mediante `PdfPage.render`, sin cargarla en una textura Flutter:

| PDF | Lado mayor 1800 px | Lado mayor 3600 px |
|---|---:|---:|
| Canten a Cristo Rey | 19–24 ms | 57–68 ms |
| The Holy City | 71–79 ms | 127–130 ms |
| El Llamado a mi Ser | **310–312 ms** | **490–495 ms** |

Estas latencias pueden retrasar la aparición/refinamiento de una página, aunque no bloqueen UI. No son mediciones del tiempo de GPU ni del tiempo desde gesto hasta contenido visible. El tamaño del archivo, por sí solo, no predice el coste de renderizarlo.

**Acción propuesta:** optimizar los PDF más costosos conservando legibilidad y revisar la reutilización de páginas renderizadas. No aumentar indiscriminadamente la resolución y la caché.

### 5. Media: persistencia masiva conserva costes residuales

Persistencia real con cinco páginas, 60 puntos por trazo, no un `jsonEncode` aislado de escritorio:

| Total de trazos | Guardar, dos ejecuciones | Cargar, dos ejecuciones |
|---:|---:|---:|
| 10 | 6,5–7,0 ms | 0,7–1,7 ms |
| 100 | 19–26 ms | 7,7–9,0 ms |
| 500 | 116–122 ms | 34–51 ms |
| 2000 | 357–408 ms | 201–202 ms |

El JSON grande ya se procesa mediante `compute`, según umbrales en [AnnotationStore](../lib/core/pdf/annotation_store.dart), líneas 57–97. Los resultados no significan que se bloquee la UI durante todo el tiempo de guardado.

Sin embargo, en la segunda ejecución se observó un cuadro UI de **22,29 ms** al guardar 500 trazos y un intervalo del temporizador de **113,52 ms** al guardar 2000. En la primera, el guardado de 2000 tuvo un cuadro UI de **16,90 ms**. Hay costes/retrasos residuales, pero no se aisló cuánto corresponde a copia entre isolates, Hive, GC o planificación.

El debounce es de **150 ms** y las escrituras están serializadas. Si las ediciones extensas producen guardados más rápido que esos 357–408 ms, puede crecer la cola: **riesgo deducido del código, no cola creciente reproducida**. El historial tiene tope de 50 estados y comparte geometría; no se justificó culparlo de la memoria gráfica.

**Acción propuesta:** instrumentar por separado transferencia, serialización y escritura; agrupar snapshots pendientes preservando el último estado y la separación por canto; evaluar persistencia incremental. No prometer «0 ms de bloqueo» por usar `compute`.

## Hallazgo confirmado en la dependencia, impacto visual pendiente

### Media: pdfrx 1.3.5 elimina imágenes antes de comprobar si superó la caché

En la versión instalada, `lib/src/widgets/pdf_viewer.dart`, líneas 1171–1197, `_removeCacheImagesIfCacheBytesExceedsLimit` calcula el consumo y entra al bucle eliminando una imagen antes de comprobar `bytesConsumed <= acceptableBytes`. Cuando hay una página candidata cacheada, puede desalojarla aunque el consumo ya esté por debajo de los 32 MiB.

La llamada se realiza al encontrar páginas fuera de la región de precarga, alrededor de la línea 1020. Esto limita la reutilización al volver a páginas anteriores. Es un comportamiento verificable en código; **no se demostró que origine parpadeos blancos en este teléfono**.

El pintor de pdfrx dibuja blanco cuando todavía no dispone de la imagen, alrededor de la línea 984. Por tanto, la ausencia de cuadros lentos no prueba ausencia de intervalos en blanco. Para atribuirlos hay que medir contenido visible o grabar transiciones con marcas temporales.

**Acción propuesta:** validar una corrección que compruebe el presupuesto antes de desalojar, o una versión que resuelva ese comportamiento; comparar recuentos de render y tiempo hasta contenido visible. Subir de 32 a 64/128 MiB sin esa comprobación no demuestra resolver el problema.

## Qué no se confirmó y qué debe corregirse de la auditoría anterior

| Hipótesis anterior | Resultado de esta auditoría |
|---|---|
| `setState` en cada movimiento y ausencia de caché de Path hacen lento todo dibujo | El Path activo sí se conserva. Pocos trazos tienen p95 raster bajo, con picos iniciales importantes. Muchas anotaciones sí degradan raster. |
| 32 MB son insuficientes y causan parpadeo | No demostrado. Existe un problema distinto en el criterio de desalojo de la dependencia. |
| Límite de 1800 px impide nitidez al ampliar | No es un límite global: pdfrx solicita imágenes parciales a escala real cuando se supera la escala base, líneas 998–1009 y 1123–1159. |
| El pinch deja trazos fantasma | Diez gestos por ejecución, dos dedos en la misma capa: **cero trazos adicionales**, veinte gestos en total. No cubre dedos en páginas distintas, stylus o cancelaciones de sistema. |
| El único cuello de botella es JSON | Refutado por los costes gráficos y la preparación inicial del PDF cifrado. |
| El RepaintBoundary garantiza 0,08 ms con 100 trazos | El benchmark de escritorio no midió GPU del teléfono ni garantizó un repintado real en cada `pump`. Esa conclusión no era válida. |
| Invertir colores OLED es un fallo | Se mantiene como comportamiento intencional indicado por el usuario. No se clasifica como problema. El coste específico de OLED no fue medido. |

La captura con zoom de The Holy City muestra un original escaneado muy ampliado. No permite atribuir su suavidad exclusivamente al límite base de 1800 px. Las capturas del harness usan DPR **2**, inferior al DPR nativo; sirven para comprobar contenido y escenarios, no como comparación píxel a píxel de nitidez nativa.

## Controles que funcionaron

- **32 cambios de página por ejecución**, repartidos entre navegación vertical y carrusel: ninguna etapa UI/raster superó 16,67 ms en esos escenarios sin anotaciones. Raster p95 de la segunda ejecución: **5,09 ms** y **4,88 ms**.
- Documento pesado en caché: controlador listo en aproximadamente **102–103 ms** desde que se empieza a esperar tras montar el widget. **No equivale a primera página completamente visible**.
- Zoom: un pico raster de **34–38 ms** por ejecución; p95 aproximado **3,2–3,4 ms**. No es un problema sostenido en el PDF sin anotaciones.
- Catálogo frío: **185–204 ms** totales. La segunda ejecución tuvo un intervalo de temporizador de **36,63 ms**, pero ningún cuadro con UI/raster por encima del presupuesto. Parte de la decodificación/mezcla sigue en UI ([cantos_provider.dart](../lib/core/providers/cantos_provider.dart), líneas 65–82); no se atribuyó ese retraso a una función específica.
- Arranque de la aplicación instalada, `am start -W`, tres lanzamientos: **522 / 274 / 278 ms**. Es tiempo Android hasta mostrar la actividad; no el tiempo hasta catálogo/PDF listo.
- No se observaron cierres ni errores del motor en los escenarios completados. Los errores de instrumentación se detallan abajo.

### Comparación adicional de la capa de anotaciones

| Control focalizado válido | Raster p50 | Raster p95 | Raster máximo | Cuadros sobre presupuesto |
|---|---:|---:|---:|---:|
| Capa aislada, primeros cinco trazos | 2,29 ms | 5,06 ms | 15,15 ms | 0/399 |
| Capa aislada, 500 trazos guardados | 4,63 ms | 25,74 ms | 128,89 ms | 19/307 |
| Visor sin zoom previo, primeros cinco trazos | 3,49 ms | 6,28 ms | 20,57 ms | 1/406 |

Incluso aislada, la capa densa conserva picos: la complejidad de las anotaciones importa. La penalización sostenida del recorrido completo es mayor, lo que dirige la investigación a composición, transformaciones y caché además del pintor. Los controles no tienen idéntica geometría ni orden de calentamiento; no permiten asignar un porcentaje exacto del coste al PDF. La última fase densa del control dentro del visor quedó invalidada por pérdida de visibilidad y no se usa para comparar.

Las nueve páginas de The Holy City miden aproximadamente 594,81 × 841,08 unidades PDF. La memoria observada no se explica simplemente por páginas con dimensiones lógicas excepcionalmente grandes.

## Evidencias y reproducción

Evidencias de referencia preservadas: [auditorias/2026-09-29/evidencias](auditorias/2026-09-29/evidencias/). Integridad de los archivos: [SHA256.json](auditorias/2026-09-29/SHA256.json). Las nuevas ejecuciones deben guardarse aparte de esta referencia.

- [Primera ejecución](auditorias/2026-09-29/evidencias/results_run1.json) y [resumen](auditorias/2026-09-29/evidencias/results_run1_summary.json).
- [Segunda ejecución](auditorias/2026-09-29/evidencias/results.json) y [resumen](auditorias/2026-09-29/evidencias/results_summary.json).
- [Controles focalizados](auditorias/2026-09-29/evidencias/results_focused.json) y [resumen](auditorias/2026-09-29/evidencias/results_focused_summary.json).
- [Registro de la segunda ejecución](auditorias/2026-09-29/evidencias/run2.log), memoria `profile_meminfo_dense_run2.txt`, térmica `thermal_run2.txt`, inventario `pdf_asset_inventory.json` y arranques `release_start_*.txt` en esa carpeta.
- Capturas revisadas: [PDF ajustado](auditorias/2026-09-29/evidencias/pdf_fit.png), [zoom](auditorias/2026-09-29/evidencias/pdf_zoom.png), [anotaciones densas](auditorias/2026-09-29/evidencias/annotations_dense.png).
- [Harness general](../integration_test/performance_audit_test.dart), [controles focalizados](../integration_test/performance_audit_focused_test.dart), [driver](../test_driver/performance_audit.dart), [resumen reproducible](../test_driver/summarize_performance_audit.mjs).

El escenario auxiliar `decrypt_encrypted_pdf_isolated` de la segunda ejecución falló por capturar un objeto del framework no transferible al isolate. **Sus 4,8 ms son un error de la prueba y no se usan como rendimiento del descifrado**. Se corrigió limitando el alcance del closure y las dos mediciones focalizadas posteriores terminaron sin error. El primer intento de lanzar los controles perdió la conexión con el servicio antes de medir; se conservó como `run_focused_interrupted.log` y se reintentó. No hubo entrada de crash para ese proceso al consultar Android.

El driver puede indicar «All tests passed» aunque el recolector haya registrado un error: revisar siempre el campo `error` de cada escenario y el registro de visibilidad de la app. El análisis estático de los tres archivos Dart de auditoría terminó con **No issues found**. Los últimos ajustes de formato y lectura de metadatos mediante `useDocument` se verificaron con el analizador; no cambian las rutas cronometradas.

Ejemplo PowerShell, con Flutter/ADB disponibles en PATH y el teléfono desbloqueado:

```powershell
$env:ORG_GRADLE_PROJECT_PERFORMANCEAUDIT = 'true'
flutter build apk --profile --no-pub --target=integration_test/performance_audit_test.dart
# Verificar con aapt dump badging que package sea com.lldm.coro.perfaudit.
flutter drive --profile --no-pub -d <device-id> --use-application-binary=build/app/outputs/flutter-apk/app-profile.apk --driver=test_driver/performance_audit.dart --target=integration_test/performance_audit_test.dart
node test_driver/summarize_performance_audit.mjs output/performance_audit_2026-09-29/results.json
Remove-Item Env:ORG_GRADLE_PROJECT_PERFORMANCEAUDIT
```

Para los controles, usar `integration_test/performance_audit_focused_test.dart` en build y drive, y establecer `$env:AUDIT_RESULT_NAME = 'results_focused'` antes del driver. Retirar esa variable al terminar. El resumen usa ese archivo como argumento. Mantener el teléfono desbloqueado y la app de prueba visible durante toda la ejecución.

La propiedad Gradle cambia únicamente el identificador de instalación de auditoría. Se añadió `integration_test` como dependencia de desarrollo. Para builds normales, no establecer esa propiedad. No se generó un AAB de publicación ni se hizo push como parte de esta auditoría.

## Alcance pendiente

Este teléfono a 60 Hz no permite concluir rendimiento en iPad Pro/120 Hz, tablets grandes, dispositivos con poca memoria ni otros controladores gráficos. Quedan fuera sesiones de larga duración, batería, red real, textos extensos, PDFs de todo el catálogo, audio simultáneo, anuncios, exportaciones e interacciones físicas con lápiz. Las capturas estáticas tampoco descartan flashes transitorios. Estas son limitaciones de cobertura, no fallos confirmados.
