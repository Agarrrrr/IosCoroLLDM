# Paso 1: comprobación de memoria y transición de zoom

Fecha: 29 de septiembre de 2026. Referencia: [auditoría original](AUDITORIA_RENDIMIENTO_ANDROID_2026-09-29.md) y [mejoras de anotaciones](RENDIMIENTO_PASO_1.md). Se conservan sus resultados originales. Base Git: `e6a2c22d1345e8ce3e4ffde3a0ef136cb955ffd6`, con los cambios locales del candidato 4.

## Resultado

**El consumo elevado se reproduce sin capturas ni la RepaintBoundary raíz añadida por la auditoría.** Por tanto, esas herramientas no explican por sí solas el problema. Un recorrido con pausas más largas no reproduce ese consumo. La secuencia y los tiempos de transición importan; aún no se identificó la asignación exacta responsable ni se corrigió la memoria.

Samsung SM-G986U, Android 13, modo profile, pantalla a 60 Hz, misma app aislada `com.lldm.coro.perfaudit`. Se mantuvo la pantalla encendida por USB y se restauró el ajuste previo (0). No se modificaron los datos de la app del usuario.

## Controles de atribución

Primero se probaron una partitura pequeña y The Holy City (nueve páginas) sin capturas, sin frontera raíz de repintado y sin renderizados nativos previos. Se separaron apertura, cuatro incrementos de zoom, activación de dibujo, cinco trazos, carga de 500 trazos y cierre. El PDF grande terminó el dibujo denso en **479 MiB RSS**.

Después se repitió con regreso a página tras el zoom y variantes de navegación/capturas. Se esperaron cinco segundos después del zoom, tres tras regresar a página y cinco al activar dibujo. La carga nativa del MIDI de Canten a Cristo Rey ocurre antes de estas variantes: estos valores representan el proceso completo, no exclusivamente el PDF.

| Variante de The Holy City | RSS tras dibujo con 500 trazos | Raster p95 del escenario |
|---|---:|---:|
| Sin capturas ni navegación previa | 467 MiB | 8,98 ms |
| Navegación vertical/carrusel, sin capturas | 517 MiB | 8,84 ms |
| Capturas, sin navegación previa | 505 MiB | 8,48 ms |
| Capturas y navegación previa | 529 MiB | 8,39 ms |

Estos p95 incluyen tres segundos de espera al terminar de dibujar; **no son directamente comparables con el benchmark continuo original**. El orden es secuencial en un mismo proceso: hay calentamiento y recursos de variantes anteriores. Las capturas usan ratio 2 y no sustituyen la comprobación de nitidez nativa. El encabezado del JSON de esta ejecución dice `rootCaptureBoundary: false` y `screenshots: false` para toda la prueba; esos campos quedaron sin actualizar al ampliar las variantes. Los casos `*_capture` sí usaron ambos recursos y sus PNG se conservan. El código actual registra la configuración por caso.

Evidencias: [control inicial](auditorias/2026-09-29/memoria/control/results.json), [atribución](auditorias/2026-09-29/memoria/attribution/results.json), [resumen](auditorias/2026-09-29/memoria/attribution/results_summary.json), [registro](auditorias/2026-09-29/memoria/attribution/run.log). Las muestras `meminfo_*` incluyen archivos de fase; son muestras cada diez segundos, no máximos exhaustivos. Estado térmico observado: 0.

## Recorrido original sin capturas

Se ejecutó el recorrido completo original, incluidos renderizados nativos previos, descifrado, navegación, zoom y dibujo. Se desactivaron únicamente las capturas y su frontera raíz, eliminando también sus esperas y asignaciones. El resto de las acciones y pausas se conserva. Esta diferencia de tiempo impide considerarlo una reproducción idéntica a nivel de scheduling, pero comprueba que el pico puede ocurrir sin captura.

| Escenario | RSS al terminar | Raster p95 | Raster máximo |
|---|---:|---:|---:|
| Zoom | 457 MiB | 3,11 ms | 34,58 ms |
| Primer dibujo tras volver a página | 1141 MiB | 7,03 ms | 178,99 ms |
| Dibujo sobre 500 trazos | 1226 MiB | 18,75 ms | 48,37 ms |
| Borrado sobre 500 trazos | 1198 MiB | 19,81 ms | 58,41 ms |
| Deshacer/rehacer | 1189 MiB | 38,63 ms | 44,76 ms |
| Reapertura del visor | 1325 MiB | 106,03 ms | 164,25 ms |

Una muestra tomada entre zoom y primer dibujo ya registra **1094 MiB RSS**, frente a 517 MiB durante carrusel. Durante dibujo caliente, `Other dev` registra **857136 KiB PSS**, el heap nativo **54008 KiB PSS**, y Graphics **60232 KiB**. Durante dibujo denso se capturaron **1173 MiB PSS / 1290 MiB RSS**. Son métricas y momentos distintos del RSS de fin de escenario; no deben sumarse ni intercambiarse.

El crecimiento precede a la densidad de 500 trazos. **No hay evidencia de que los Path o el JSON expliquen el crecimiento principal.** `Other dev` es una clasificación de Android; no identifica por sí sola la textura, controlador o recurso exacto. Al cerrar todo y esperar dos segundos, el RSS final baja a **481 MiB**: hay liberación de recursos, aunque esto no descarta retenciones o fugas en otros recorridos.

El dibujo denso registró 21/405 cuadros con alguna etapa sobre 16,67 ms; borrado 22/393; deshacer/rehacer 78/93. UI p95 de deshacer: 10,16 ms. La mejora anterior sigue siendo parcial y sus máximos no son estables entre ejecuciones.

Los escenarios terminaron sin errores; cada secuencia de dibujo/borrado guardó cinco trazos y los diez gestos de dos dedos agregaron cero trazos inesperados. El descifrado aislado sigue en **7,83 s**. Guardar 2000 trazos tardó **440 ms**, con un intervalo máximo del temporizador principal de **129,59 ms**: persiste trabajo por investigar aunque la serialización use otro isolate.

Evidencias: [resultados completos](auditorias/2026-09-29/memoria/full_without_capture/results.json), [resumen](auditorias/2026-09-29/memoria/full_without_capture/results_summary.json), [registro](auditorias/2026-09-29/memoria/full_without_capture/run.log), [muestra de memoria](auditorias/2026-09-29/memoria/full_without_capture/meminfo_03.txt), [fase](auditorias/2026-09-29/memoria/full_without_capture/meminfo_03_phase.txt), [integridad SHA-256](auditorias/2026-09-29/memoria/SHA256.json).

## Cambios y siguiente acción

Se añadieron controles de memoria y se separaron las capturas del benchmark: `AUDIT_CAPTURE=true` habilita una pasada de captura explícita. La prueba general ahora falla si el recolector guarda un error de escenario. En esta etapa no se cambió el motor PDF ni el comportamiento de anotación.

La siguiente investigación debe reproducir únicamente la transición rápida de zoom/regreso a página y registrar sus asignaciones antes de activar dibujo. Comparar el PDF sin overlays, con overlays vacíos y con anotaciones permitirá decidir dónde limitar o liberar recursos. También deben separarse los renderizados nativos previos y los cambios de navegación para identificar el desencadenante mínimo. El límite de caché de 32 MiB no controla todas las asignaciones del proceso; subirlo no resuelve esta evidencia.

**El paso 1 continúa abierto.** Permanecen presión de memoria y picos de raster de borrado/deshacer. Se necesitan repeticiones de la secuencia mínima y validación en un equipo con menos RAM antes de dar el problema por resuelto. No se extrapolan estos resultados a iOS o 120 Hz.
