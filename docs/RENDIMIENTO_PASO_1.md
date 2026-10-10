# Paso 1: anotaciones y composición del visor

Seguimiento: [comprobación posterior de memoria y zoom](RENDIMIENTO_MEMORIA.md), con evidencias nuevas conservadas por separado. Confirma el consumo alto sin capturas y documenta la variación de los picos; no sustituye estas mediciones.

Referencia: [auditoría original](AUDITORIA_RENDIMIENTO_ANDROID_2026-09-29.md). Las evidencias originales se conservan en su carpeta de referencia.

## Primera comparación en el Samsung SM-G986U a 60 Hz

Se indicó que la capa guardada es compleja y se separó el repintado del trazo activo mediante un RepaintBoundary. El trazo activo indica que cambia continuamente para evitar competir por caché raster con el contenido guardado.

| Escenario | Raster p95 original | Raster p95 candidato 1 | Cuadros sobre presupuesto, candidato 1 |
|---|---:|---:|---:|
| Dibujar sobre 100 trazos | 13,93 ms | 10,08 ms | 15/389 |
| Dibujar sobre 500 trazos | 87,71 ms | 84,30 ms | 286/286 |
| Borrar sobre 500 trazos | 91,36 ms | 87,50 ms | 278/278 |
| Deshacer/rehacer con 500 trazos | 103,31 ms | 100,14 ms | 22/22 |

Es una ejecución por candidato. Las diferencias pequeñas pueden incluir variación de carga y calentamiento. **Este cambio no resuelve el problema sostenido con 500 trazos.** La memoria permanece cerca de 1,2 GiB RSS durante los escenarios densos. El pico tras zoom también permanece: 441,94 ms de raster en el primer escenario de dibujo.

La captura del PDF ajustado tiene el mismo SHA-256 que la referencia: no cambió su contenido. Los diez gestos de dos dedos no agregaron trazos. Todos los escenarios de esta ejecución terminaron sin `error`. Se mantuvo temporalmente la pantalla encendida por USB y se restauró el valor previo al terminar.

Evidencias: [resultados candidato 1](auditorias/2026-09-29/paso1/candidate1/results_candidate1.json), [resumen](auditorias/2026-09-29/paso1/candidate1/results_candidate1_summary.json) y [registro](auditorias/2026-09-29/paso1/candidate1/run_candidate1.log).

## Segundo candidato

El visor aplicaba un ColorFiltered también al mostrar colores originales en modo claro. Se añadió un renderizador que omite esa capa cuando no hay filtro y conserva la misma instancia del contenido al activar filtros. Los filtros oscuro, OLED y sepia mantienen las mismas matrices y siguen afectando a las anotaciones.

El teléfono se reconectó y se completó el segundo recorrido. Con 500 trazos, la mediana de raster bajó de 22,56 a **4,78 ms**, y los cuadros sobre presupuesto pasaron de 258/258 a **19/349**. El p95 todavía era 20,03 ms y deshacer/rehacer conservaba un p95 de 102,40 ms. La mejora principal fue dejar de exceder el presupuesto de manera sostenida mientras se mueve el dedo.

Evidencias: [candidato 2](auditorias/2026-09-29/paso1/candidate2/results.json), [resumen](auditorias/2026-09-29/paso1/candidate2/results_summary.json).

## Tercer candidato: reutilización de Path

Se conserva la geometría de cada trazo guardado mediante claves débiles. Se reconstruye si cambia el tamaño de la página o los puntos; ya no se reconstruyen cientos de paths sin cambios al agregar otro trazo o alternar deshacer/rehacer. Las claves débiles permiten liberar geometría cuando el trazo sale del estado y del historial. La caché no modifica colores, grosor, orden, herramientas ni persistencia.

El p95 al dibujar con 500 trazos bajó a **10,03 ms**. Deshacer/rehacer bajó a **37,42 ms** de raster p95 y **9,91 ms** de UI p95. La memoria seguía alta.

Evidencias: [candidato 3](auditorias/2026-09-29/paso1/candidate3/results.json), [resumen](auditorias/2026-09-29/paso1/candidate3/results_summary.json).

## Cuarto candidato: recorte de las capas

Las capas guardada y activa se recortan al área visible del visor. Los puntos completos se conservan; al desplazar la página se pinta la nueva región visible. Se retiró la frontera de repintado duplicada que envolvía toda la capa de anotación y el rectángulo transparente usado para captar eventos; el Listener sigue recibiendo esos eventos. Esta variante es la que queda en el código.

| Escenario | Raster p95 original | Raster p95 final | Cuadros sobre presupuesto final |
|---|---:|---:|---:|
| Dibujar sobre 100 trazos | 13,93 ms | **6,86 ms** | 5/405 |
| Dibujar sobre 500 trazos | 87,71 ms | **13,98 ms** | 20/406 |
| Borrar sobre 500 trazos | 91,36 ms | **19,82 ms** | 22/393 |
| Deshacer/rehacer con 500 trazos | 103,31 ms | **31,71 ms** | 77/93 |

La mediana de raster durante dibujo denso queda en **4,59 ms**. En esa prueba, aproximadamente el 95,1% de los cuadros registrados tuvo ambas etapas dentro de 16,67 ms. Ese porcentaje describe el escenario medido, no garantiza 60 FPS en toda la app. Los cuadros recogidos durante deshacer/rehacer cambian porque el motor produce más cuadros al responder más rápido; comparar también duración por etapa, no solo porcentajes.

El máximo de raster del primer dibujo tras el recorrido con zoom pasó de 491,05 ms en la referencia a **60,17 ms** en la variante final. Es una ejecución por variante, sin garantía de que ese máximo se repita. Aún existe un pico.

**La memoria no quedó resuelta:** al dibujar sobre 500 trazos el RSS fue **1242 MiB**; la muestra Android registró aproximadamente **1168 MiB PSS** y **1295 MiB RSS**. Gran parte permanece en `Other dev`. El recorte no demostró disminuir esa presión en este recorrido y no se presenta como solución de RAM. El siguiente trabajo de este paso será atribuir esas asignaciones antes de cambiar límites de caché.

Evidencias finales: [resultados](auditorias/2026-09-29/paso1/candidate4/results.json), [resumen](auditorias/2026-09-29/paso1/candidate4/results_summary.json), [registro](auditorias/2026-09-29/paso1/candidate4/run.log), [memoria](auditorias/2026-09-29/paso1/candidate4/meminfo_drawing.txt), [temperatura](auditorias/2026-09-29/paso1/candidate4/thermal.txt). Estado térmico 0 en las muestras. Integridad de las nuevas evidencias: [SHA256](auditorias/2026-09-29/paso1/SHA256.json).

## Validación disponible

- Prueba de píxeles: el borrador conserva el fondo PDF, el trazo posterior se dibuja encima, los trazos ocultos permanecen ocultos y las posiciones se conservan al escalar 1× y 2×.
- Prueba de filtro: rojo original, inversión a cian y retorno a rojo; el elemento del visor se conserva durante los tres estados.
- Prueba de viewport: un trazo activo se recorta visualmente y se guarda completo; cambiar la región visible revela el resto del trazo guardado.
- Las tres pruebas pasan. El análisis de los widgets y tests revisados termina sin avisos. El APK profile compila y completa el recorrido físico.
- Candidatos 2, 3 y 4: todos los escenarios terminan sin `error`, cada secuencia guarda los cinco trazos esperados, los gestos de dos dedos no agregan trazos y los registros no muestran pérdida de visibilidad durante los recorridos.
- La captura de PDF ajustado del candidato 2 difiere de la referencia en un máximo de 2 niveles por canal; no hay píxeles con diferencias mayores de 5. Se revisaron también zoom y anotaciones densas de la variante final. El cambio de composición puede producir diferencias mínimas de redondeo.
- Se comprobó la integridad de los 28 archivos originales. No se sobrescribieron sus mediciones.

Archivos: [anotaciones](../lib/features/visor/widgets/annotation_layer.dart), [filtro opcional](../lib/features/visor/widgets/pdf_color_filter.dart), [visor](../lib/features/visor/visor_screen.dart), [prueba de anotaciones](../test/annotation_rendering_test.dart), [prueba de filtro](../test/pdf_color_filter_test.dart).

**Estado: mejora gráfica aplicada y validada en modo claro, con el paso 1 aún abierto.** Quedan presión de memoria y picos de borrado/deshacer. El rendimiento real en modos oscuro/OLED, iOS y otros equipos debe medirse; las pruebas de píxeles verifican los filtros, pero no sustituyen esas mediciones. La meta completa de 60 FPS todavía no se considera alcanzada.
