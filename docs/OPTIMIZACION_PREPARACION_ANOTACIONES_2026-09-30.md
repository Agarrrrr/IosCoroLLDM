# Optimización aplicada: preparación de anotaciones densas

Fecha: 2026-09-30. Implementación posterior al registro de picos residuales. La auditoría original y los registros anteriores se conservan sin modificaciones.

## Cambio en la aplicación

En páginas con al menos 100 trazos, cuando no existe una imagen reutilizable ni un prefijo válido, el primer pintado prepara la imagen de anotaciones y dibuja esa misma imagen inmediatamente. Antes se dibujaban todos los vectores en pantalla y, después del cuadro, se repetía el dibujo para preparar la caché.

La preparación resuelve la geometría después del layout, conserva la alineación a píxeles físicos y mantiene el límite de tres imágenes y 24 MiB por capa. La actualización del estado se realiza después del cuadro. Si no se puede preparar la imagen, se conserva el dibujo directo. La composición incremental desde un prefijo opaco mantiene su comportamiento.

Archivos: `lib/features/visor/widgets/annotation_layer.dart` y `test/annotation_rendering_test.dart`. El interruptor de caché marcado `visibleForTesting` permite comparar contra vectores independientes; la aplicación conserva la caché activada por defecto.

## Validación breve

- Ocho pruebas de anotaciones, geometría progresiva del PDF y filtros: correctas. Análisis estático de los dos archivos modificados: sin incidencias.
- Cuatro pruebas de anotaciones repetidas después de añadir la comprobación del primer pintado: correctas. La primera imagen coincide exactamente con la imagen estabilizada; la comparación contra vectores permite como máximo dos niveles por canal y una media inferior a 0,05. Incluye transparencia, borrados, deshacer/rehacer, recorte y posiciones fraccionarias.
- Samsung SM-G986U, profile, 60 Hz, aplicación de pruebas separada `com.lldm.coro.perfaudit`, sin trazas ni capturas. Dos reaperturas de The Holy City con 505 trazos y un control sin anotaciones. Todos los escenarios terminaron sin errores. La configuración de pantalla encendida por USB se restauró al terminar.

| Medición | Reapertura densa 1 | Reapertura densa 2 | Sin notas |
|---|---:|---:|---:|
| Raster p95 | 4,833 ms | 3,247 ms | 3,240 ms |
| Raster máximo | 25,331 ms | 11,461 ms | 5,385 ms |
| UI máximo | 13,242 ms | 20,134 ms | 13,248 ms |
| Duración total máxima del cuadro | 116,805 ms | 121,905 ms | 17,960 ms |
| Cuadros con UI o raster sobre 16,67 ms | 1/144 | 1/144 | 0/154 |
| RSS al terminar el escenario | 416 MiB | 413 MiB | 418 MiB |

Como referencia histórica, el recorrido completo anterior registró raster máximo de 151–153 ms y duración total máxima de 258–264 ms en reapertura densa. El recorrido breve actual usa 505 trazos y comienza con otro estado de memoria; **no es una comparación A/B controlada ni permite atribuir un porcentaje exacto de mejora**. Sí verifica que la implementación funciona en el dispositivo y que la imagen inicial aparece sin sustituir un dibujo vectorial completo.

El trabajo de GPU puede quedar fuera de `rasterDuration`: los máximos totales de 117–122 ms muestran que todavía existe una pausa inicial. No se declara eliminada. Los picos del borrador y el rendimiento con grandes cantidades de tinta translúcida siguen pendientes; no se midieron de nuevo en esta validación.

Los intervalos de apertura incluyen 2,5 segundos de espera explícita; no son tiempos de carga. Los cuadros sobre presupuesto no equivalen a un recuento de cuadros perdidos en pantalla. RSS incluye instrumentación y recursos gráficos.

Evidencia: [resultados](optimizaciones/2026-09-30/preparacion_anotaciones/results_summary.json), [primer pintado](optimizaciones/2026-09-30/preparacion_anotaciones/optimization_cold_first_paint_tests.log) y [SHA-256](optimizaciones/2026-09-30/preparacion_anotaciones/SHA256.json). Se conserva una copia de los archivos implementados y del recorrido de validación.
