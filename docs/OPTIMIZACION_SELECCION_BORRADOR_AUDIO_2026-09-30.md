# Selección del borrador, preparación fría, PDF y audio — 30/09/2026

Registro separado. No reemplaza la auditoría original ni los registros anteriores.

## Estado de los cuatro trabajos

| Trabajo | Estado en esta etapa |
| --- | --- |
| Pico al seleccionar borrador | Corrección implementada y medida: preparar en cuatro cuadros separados. |
| Primera preparación densa sin caché | Sigue pendiente. Dos alternativas se descartaron por calidad o rendimiento. |
| PDF de render nativo costoso | Medición repetida y estructura del original revisada; recursos sin modificar. |
| Audio / otros dispositivos / iOS | Audio probado en Samsung; iOS y otros modelos requieren hardware adicional. |

## Código retenido

`AnnotationLayer` separa la preparación de los programas gráficos del borrador en **contorno, partición, restauración y borrado**. Antes se ejecutaban juntos en una selección. Cada etapa preserva la imagen guardada y avanza en un callback posterior al cuadro. Si empieza un gesto, se cancela la preparación restante para no agregar trabajo al movimiento.

La preparación sigue limitada a Android y páginas densas con tinta opaca. No modifica el modelo, los colores, alpha, historial ni almacenamiento. Se mantiene el indicador de diámetro durante 220 ms. No se implementó un marcador traslúcido.

El nuevo `integration_test/performance_followup_test.dart` añade preparación fría explícita, tres renders por tamaño y reproducción real de MIDI durante preparación, dibujo y borrado. Comprueba conteos de trazos, estado de reproducción y avance de posición. Resuelve la carpeta de resultados también en plataformas nativas distintas de Android; eso prepara el harness, no certifica su ejecución en iOS.

## Comparación en dispositivo

Samsung SM-G986U, Android 13, 60 Hz, DPR 2.8125. App aislada `com.lldm.coro.perfaudit`, profile, sin timeline ni capturas durante las mediciones. Referencia `baseline`, candidato intermedio de tres fases `phased` y resultado retenido de cuatro fases `final`.

| Selección del borrador | Referencia | Tres fases | Cuatro fases |
| --- | ---: | ---: | ---: |
| UI máximo | 14,827 ms | 5,016 ms | 2,477 ms |
| Raster máximo | 20,369 ms | 17,149 ms | **11,106 ms** |
| TotalSpan máximo | 37,101 ms | 19,399 ms | **18,487 ms** |
| UI o raster sobre 16,67 ms | 1/29 | 1/30 | **0/30** |

Comparación de ejecuciones, sin control completo de temperatura y carga del sistema. El conteo compara UI/raster por separado; no representa cuadros perdidos directamente. TotalSpan incluye espera entre etapas. No se afirma que seleccionar el borrador jamás cause un pico en otro dispositivo.

El gesto de borrado sin audio conserva picos aislados en esta ejecución: **4/416 cuadros** sobre presupuesto, raster p95 **4,628 ms**, máximo **25,809 ms**. La referencia de esta etapa tenía 2/409 y máximo 22,022 ms. No se declara mejorado ni cerrado el rendimiento de todos los gestos a partir de la mejora en selección. Son pendientes distintos.

## Prueba con audio nativo

Se inicializó FluidSynth y el SoundFont real de la app y se reprodujo **Canten a Cristo Rey** mientras el visor mostraba **The Holy City**. El panel MIDI permaneció cerrado; su StreamBuilder seguía montado. No representa todas las combinaciones de canto, panel abierto, metrónomo, Bluetooth o exportación.

| Escenario | Raster p95 / máximo | UI máximo | UI o raster sobre 16,67 ms |
| --- | ---: | ---: | ---: |
| Preparar 500 trazos con audio | 5,645 / 15,903 ms | 15,351 ms | 0/53 |
| Dibujar cinco trazos con audio | 6,031 / 23,573 ms | 8,237 ms | 1/412 |
| Seleccionar borrador con audio | 8,194 / 9,045 ms | 8,013 ms | 0/30 |
| Borrar cinco trazos con audio | 4,426 / 22,246 ms | 7,367 ms | 2/417 |

Cada ensayo de movimiento recibió 600 eventos y agregó cinco trazos. La reproducción permaneció activa y su posición avanzó durante los intervalos. Eso verifica concurrencia y progreso del motor; **no mide cortes acústicos**, latencia de salida ni exactitud de cada nota. No se grabó loopback de audio. Todos los escenarios terminaron sin error.

## Preparación fría: pendiente y candidatos retirados

La inserción de 500 trazos antes de tener una imagen mostró TotalSpan máximo **164,676 ms** en la referencia y **177,289 ms** en el código retenido. Con audio: **155,100 / 158,289 ms**. UI/raster por separado no exponen toda esa pausa; no se declara optimizada la preparación fría.

1. **Imagen por franjas de 192 píxeles físicos:** las comparaciones durante la preparación mostraron diferencias que superaban el umbral de dos niveles por canal, incluso con un margen físico. Se retiró el candidato completo; no se relajó la tolerancia.
2. **Imagen completa asíncrona mediante `Picture.toImage`:** ejecución física `async`, descartada. TotalSpan frío **355,212 ms** y máximo raster **102,783 ms**; con audio, TotalSpan **338,797 ms** y raster **101,525 ms**. Aumentó el trabajo gráfico respecto al código retenido. Se retiró la ruta experimental y su define.

La prueba visual extendida de 600 puntos lógicos también falló bajo la referencia síncrona. Por tanto, su diferencia no se atribuye exclusivamente al candidato asíncrono. Sus fuentes y logs se conservan como caso diagnóstico pendiente; no se presenta como una regresión aislada demostrada ni como una prueba aprobada. Antes de adoptar otra representación de caché se debe aislar ese caso con densidad y geometría controladas.

## PDF: resultados y estructura

Cada celda contiene tres renders independientes de la primera página, en milisegundos. No incluye crear una textura Flutter. Se excluye de estos intervalos la preparación/descifrado del archivo.

| PDF | Lado mayor 1800 px | Lado mayor 3600 px |
| --- | --- | --- |
| Canten a Cristo Rey | 25,142 / 15,425 / 15,341 | 58,652 / 47,676 / 45,582 |
| The Holy City | 65,447 / 57,219 / 57,100 | 128,714 / 111,387 / 110,619 |
| El Llamado a mi Ser | **303,441 / 286,397 / 288,353** | **480,755 / 469,516 / 469,988** |

Se inspeccionó una copia temporal de El Llamado con pypdf, pdfinfo y render Poppler siguiendo la habilidad PDF. El original tiene **dos páginas**, 7.361.367 bytes descifrados, páginas de 3024 × 4032 puntos y una fotografía JPEG de **4032 × 3024 píxeles** por página, con perfil ICC. Cada stream de contenido tiene solo 59 bytes. La revisión visual confirma una fotografía de la partitura impresa, con textura del papel y márgenes.

La evidencia dirige la siguiente optimización de ese recurso a sus imágenes y procesamiento de color. No demuestra cuánto corresponde exactamente a JPEG, ICC, escalado o PDFium. No se recomprimió ni redujo resolución: cualquier candidato debe compararse en móvil y conservar legibilidad al ampliar. Una edición digital vectorial puede evaluarse por separado verificando todas las notas musicales.

En las pruebas nativas sobre una pantalla estática se registraron cero cuadros Flutter: son latencias de render, **no una demostración de ausencia de bloqueos de pantalla**. El temporizador continuó funcionando. No se cambió la caché global ni la resolución base.

## Validación retenida y límites

- Análisis de los tres archivos: sin incidencias.
- Siete pruebas de anotaciones aprobadas. La prueba de selección compara los píxeles guardados en cada una de las cuatro fases y al volver al pintor normal; conserva el conteo de anotaciones.
- Se mantienen las comparaciones de tinta opaca, transparencia futura, borrados previos, veinte ediciones, recortes, offsets fraccionarios, undo/redo y fondo PDF.
- El código retenido se compiló nuevamente sin los experimentos. El último ajuste del harness solo cambia la carpeta de salida en plataformas distintas de Android.
- La configuración de pantalla encendida por USB se restauró tras cada ejecución. No se generó AAB de distribución ni se realizó commit/push.
- Solo se encontró un Android conectado. **iOS no se ejecutó**: requiere Mac con Xcode y un iPhone disponible. Antes de instalar el harness allí se necesita un bundle de pruebas separado y su firma; no debe reemplazar la app habitual. Otros modelos y 120 Hz también están pendientes.

## Siguientes acciones concretas

1. Actuar sobre la primera preparación GPU conservando fidelidad; las dos alternativas anteriores no son soluciones aceptadas.
2. Aislar los picos puntuales de movimiento/confirmación que también aparecen con audio, sin confundirlos con la selección ya mejorada.
3. Preparar un candidato del PDF fotográfico con comparación visual y musical al ampliar, antes de reemplazar recursos del catálogo.
4. Ejecutar el mismo harness en un segundo Android y en iPhone; ampliar después a panel MIDI abierto, metrónomo, rutas de audio y exportación.

Evidencia nueva: [seleccion_borrador_audio](optimizaciones/2026-09-30/seleccion_borrador_audio). Resultados, logs, estructura PDF, código retenido, candidatos retirados y SHA-256 quedan separados del informe original.
