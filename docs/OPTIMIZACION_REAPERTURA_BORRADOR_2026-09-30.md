# Optimización de reapertura y borrador — 30 de septiembre de 2026

Registro nuevo de implementación. La auditoría original y los registros anteriores se conservan sin modificaciones. Se verificaron nuevamente los SHA-256 de sus 28 archivos de evidencia.

## Cambios implementados

- **Reutilización al reabrir:** caché de sesión con una sola imagen de anotaciones, limitada a 24 MiB. Transfiere la propiedad de la imagen al cerrar y recuperarla; exige el mismo canto, página, snapshot y geometría. Libera la imagen y los Paths ante presión de memoria y al destruir el contenedor.
- **Geometría real después del layout:** vuelve a buscar una imagen ya preparada cuando el pintado conoce el tamaño y origen definitivos. Evita crear otra imagen GPU por la diferencia entre la geometría provisional del build y la del paint. Normaliza únicamente ruido numérico de 1e-9; conserva la fase subpíxel real.
- **Paths de sesión:** caché débil compartida para no reconstruir trazos inmutables al reabrir. No mantiene vivos los trazos por sí sola.
- **Borrador:** contorno con un Path circular compartido, sin el disco relleno del indicador. Al seleccionar la herramienta muestra su diámetro durante 220 ms. Para páginas densas opacas en Android prepara una vez la composición y el borrado en una capa temporal, restaura la imagen antes de mostrarla y no agrega trazos al modelo ni al almacenamiento. El trabajo se adelanta a la selección de herramienta.
- **Prueba de dispositivo:** verifica que los eventos realmente producen cinco trazos de borrador. El driver ahora rechaza resultados sin escenarios, incluso si Flutter imprime una salida aparentemente satisfactoria.

## Opacidad y futuro marcador

La tinta actual continúa **opaca y sólida**. No se añadió un marcador ni se cambiaron los colores guardados, la matriz OLED o el alpha de las anotaciones. La preparación específica del borrador requiere tinta opaca; los snapshots con transparencia siguen la ruta compatible. Las pruebas con transparencia son cobertura de compatibilidad para el futuro, no evidencia de una función ya disponible.

## Validación final en móvil

Samsung SM-G986U, Android 13, 60 Hz, DPR 2.8125. APK profile del paquete aislado `com.lldm.coro.perfaudit`; aplicación de producción preservada. Ejecución final sin `--trace-skia` ni captura de timeline. Página de The Holy City, 505 trazos para las reaperturas y 500 trazos opacos para iniciar el borrador.

| Escenario | UI máx. ms | Raster p95 / máx. ms | TotalSpan máx. ms | UI o raster >16,67 ms |
| --- | ---: | ---: | ---: | ---: |
| Reapertura densa 1 | 9,395 | 3,295 / 6,004 | 12,915 | 0/154 |
| Reapertura densa 2 | 13,632 | 3,282 / 6,376 | 16,712 | 0/154 |
| Seleccionar borrador | 7,565 | 3,821 / 26,074 | 35,047 | 1/29 |
| Cinco borrados sobre 500 trazos | 7,172 | 3,512 / 12,860 | 21,122 | 0/397 |
| Reapertura sin anotaciones | 9,035 | 3,087 / 3,608 | 12,352 | 0/155 |

El borrado recibió **600 movimientos** y confirmó **5 trazos nuevos**. Todos los escenarios terminaron sin error. El conteo de presupuesto compara UI y raster por separado: no equivale a contar cuadros perdidos en pantalla. TotalSpan incluye esperas entre etapas; por eso 0 cuadros sobre presupuesto no significa ausencia absoluta de retrasos. RSS observado tras cada escenario: 384–431 MiB, incluyendo instrumentación y recursos gráficos; no demuestra una reducción de memoria.

En el registro anterior `capa_tinta_opaca`, las dos reaperturas equivalentes registraban TotalSpan máximo de **115,967 y 114,213 ms**. Ahora son **12,915 y 16,712 ms**. Las capturas de diagnóstico intermedias permitieron atribuir la recreación de imágenes y comprobar que desaparecía después de la reutilización tras el layout. Es una comparación de ejecuciones, no una garantía para todos los equipos.

El borrador anterior tenía picos raster de 45–47 ms. La ejecución nueva mantiene el movimiento y la confirmación por debajo del presupuesto, pero cambia la preparación al momento de seleccionar la herramienta: **queda un pico de 26,074 ms en esa selección**. No se declara resuelto ese pico ni se presenta la comparación como un ensayo A/B idéntico. La primera imagen de una página sin caché todavía puede requerir preparación costosa; tampoco se certifican iOS o pantallas de 120 Hz.

## Verificación de corrección

- Análisis de los cinco archivos Dart: sin incidencias.
- `test/annotation_rendering_test.dart`: **7 pruebas aprobadas** con el código final.
- Comparaciones de píxeles con referencia vectorial: tinta opaca, transparencia futura, borradores iniciales, veinte cambios, zoom y offsets fraccionarios. Comprueban fondo PDF, orden de trazos, undo/redo, reapertura e invalidación.
- Se comprueba que la preparación del borrador conserva exactamente la imagen guardada y no agrega anotaciones. La prueba espera también la desaparición del indicador temporal.
- Compilación APK profile y prueba en dispositivo completadas. No se generó AAB de distribución ni se hizo commit/push en este paso.

## Evidencia y experimentos descartados

Evidencias nuevas: [reapertura_borrador](optimizaciones/2026-09-30/reapertura_borrador). Incluye resultados finales, resúmenes, logs, fuentes y manifiesto SHA-256.

- `probe`: el borrador recibió cero trazos por una configuración incorrecta del harness; no valida rendimiento de borrado.
- `probe2`: fallo de inicio sin escenarios; descartado. Motivó endurecer el driver.
- `probe3`: eventos válidos; mostró recreación de imagen por geometría definitiva distinta.
- `probe4–6`: preparación offscreen no eliminó las compilaciones durante el gesto; esa implementación fue retirada.
- `probe7`: preparación en pantalla parcial; persistían compilaciones del contorno y del primer borrado. Se añadió el indicador al seleccionar, se compartió el Path del contorno y se preparó el borrado restaurando el contenido antes de componer.
- `final`: ejecución aceptada, sin trazas adicionales. Las capturas instrumentadas de los probes sirven para atribuir causas, no para comparar directamente sus tiempos con el resultado final.

## Pendientes concretos

1. Reducir el pico de preparación al seleccionar el borrador; medir selección y gesto por separado.
2. Medir y optimizar la primera preparación sin caché y los cambios reales de geometría, manteniendo los límites de memoria.
3. Validar dispositivos adicionales e iOS antes de atribuir estos resultados a todas las plataformas.
4. Diseñar el marcador traslúcido como función nueva, con sus propias reglas de composición y pruebas; no cambiar la tinta sólida actual para anticiparlo.
