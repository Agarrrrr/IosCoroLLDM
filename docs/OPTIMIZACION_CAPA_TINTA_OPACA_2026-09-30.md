# Optimización aplicada: composición de tinta opaca

Continuación de la preparación inicial de anotaciones. La auditoría original y los registros anteriores permanecen sin modificaciones.

## Implementación

`lib/features/visor/widgets/annotation_layer.dart`: al preparar una imagen completa de caché con tinta opaca se evita el `saveLayer` adicional. La imagen transparente de destino ya separa el dibujo del PDF y permite aplicar `BlendMode.clear` sin borrar la partitura. El dibujo directo de respaldo conserva su aislamiento, así como la composición incremental del borrador.

La tinta translúcida conserva la capa intermedia: el candidato que la eliminaba también en ese caso produjo una diferencia de tres niveles por canal tras varios borrados, excediendo el límite de dos. Se descartó esa variante; no se relajó el criterio de calidad.

El cambio mantiene el límite de tres imágenes y 24 MiB por capa, la alineación física y los colores almacenados. No modifica el filtro OLED.

## Pruebas y dispositivo

- Cinco pruebas de anotaciones correctas; análisis estático de los dos archivos modificados sin incidencias.
- Se añadió una página densa de tinta opaca con borrados previos. Las tres variantes densas cubren 20 ediciones cada una, comparadas contra vectores independientes. Se mantiene máximo de dos niveles por canal y media inferior a 0,05. También se verifica igualdad exacta entre el primer pintado y la imagen estabilizada, recorte, deshacer/rehacer, posiciones fraccionarias, zoom y fondo del PDF.
- Samsung SM-G986U, 60 Hz, profile, recorrido breve idéntico al registro anterior: dos reaperturas con 505 trazos de The Holy City y una sin notas. App de pruebas separada `com.lldm.coro.perfaudit`, sin trazas ni capturas; tres escenarios sin errores. Se restauró la configuración de pantalla encendida por USB.

| Medición | Antes, reaperturas 1 / 2 | Después, reaperturas 1 / 2 |
|---|---:|---:|
| Raster p95 | 4,833 / 3,247 ms | 3,475 / 3,047 ms |
| Raster máximo | 25,331 / 11,461 ms | 14,090 / 11,564 ms |
| UI máximo | 13,242 / 20,134 ms | 10,945 / 14,223 ms |
| Duración total máxima de cuadro | 116,805 / 121,905 ms | 115,967 / 114,213 ms |
| Cuadros con UI o raster sobre 16,67 ms | 1/144 / 1/144 | 0/145 / 0/146 |
| RSS al terminar el escenario | 416 / 413 MiB | 416 / 412 MiB |

Control sin notas después del cambio: raster máximo 7,965 ms, duración total máxima 10,624 ms y cero cuadros con UI o raster sobre presupuesto (155 muestras).

Se usa la misma prueba y dispositivo, con dos reaperturas por ejecución; no se controla toda la variación térmica o del sistema. No se atribuye un porcentaje preciso de mejora ni una reducción de RSS. El cambio evita una capa intermedia en el código y la validación no detecta regresiones de calidad; ambas reaperturas actuales mantienen UI y raster dentro del presupuesto.

## Pendiente

**La pausa inicial total sigue presente, aproximadamente 114–116 ms.** La eliminación de la capa redundante no demuestra una reducción material de esa pausa. El trabajo de preparar la imagen en GPU puede quedar fuera de `rasterDuration`; cero muestras de UI/raster sobre presupuesto no certifica ausencia de tirones. El siguiente cambio debe actuar sobre esa preparación o su reutilización, con límites de memoria y sin mostrar anotaciones obsoletas.

Los picos del borrador y el rendimiento con grandes densidades translúcidas siguen pendientes; esta validación no los vuelve a medir. El intervalo de apertura incluye 2,5 segundos de espera explícita y no equivale a tiempo de carga.

Evidencia: [resultados](optimizaciones/2026-09-30/capa_tinta_opaca/results_summary.json), [referencia anterior](optimizaciones/2026-09-30/capa_tinta_opaca/baseline_summary.json), [pruebas](optimizaciones/2026-09-30/capa_tinta_opaca/optimization_opaque_target_tests.log) y [SHA-256](optimizaciones/2026-09-30/capa_tinta_opaca/SHA256.json). Se conservan copias de implementación y del recorrido; el log del candidato translúcido fallido se identifica por separado.
