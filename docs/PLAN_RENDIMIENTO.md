# Plan de rendimiento

Referencia acordada con el usuario: [auditoría Android del 29 de septiembre de 2026](AUDITORIA_RENDIMIENTO_ANDROID_2026-09-29.md). Sus [mediciones y capturas originales](auditorias/2026-09-29/evidencias/) se conservan con [hashes SHA-256](auditorias/2026-09-29/SHA256.json).

Las futuras mediciones se guardarán en otra carpeta con fecha y commit. El informe inicial conserva sus resultados y limitaciones; las conclusiones posteriores deben enlazar sus propias evidencias.

Avance del paso 1: [comparación de las mejoras de anotaciones](RENDIMIENTO_PASO_1.md). La variante final reduce el p95 de raster con 500 trazos de 87,71 a 13,98 ms en modo claro. Continúan abiertas la presión de memoria y las pausas al borrar/deshacer; no se da por alcanzada la meta completa ni se ha iniciado el paso de descifrado.

## Orden de trabajo

Comprobación posterior: [memoria y transición de zoom](RENDIMIENTO_MEMORIA.md). El recorrido completo reproduce 1226 MiB RSS sin capturas; los controles con pausas más largas quedan en 467–529 MiB. La próxima acción es aislar la transición rápida y sus overlays antes de modificar límites de caché. El paso 1 continúa abierto.

1. **Anotaciones y memoria gráfica.** Aislar mediante perfilado la penalización de la página con 500 trazos y la combinación de zoom e interacción posterior. Evaluar reutilización de geometría y caché por regiones visibles, con invalidación al editar. Comprobar dibujo, borrado, deshacer/rehacer, colores y alineación a diferentes escalas.
2. **Descifrado de PDF grandes.** Comparar una implementación acelerada compatible con el formato AES-GCM existente. El control de referencia es El Llamado a mi Ser: 7,7–7,8 segundos de descifrado. Verificar que genera el mismo contenido, conserva compatibilidad y mejora la primera apertura.
3. **Persistencia masiva.** Separar transferencia entre isolates, serialización y escritura Hive. Reducir costes y agrupar guardados pendientes cuando sea necesario, preservando el estado más reciente de cada canto. Comprobar reapertura y cambios rápidos entre cantos.
4. **Caché PDF.** Corregir o actualizar el criterio de desalojo comprobado en pdfrx 1.3.5. Medir reutilización y tiempo hasta contenido visible al volver de página; determinar con evidencia si hay flashes blancos.

## Criterio para aceptar una mejora

- Repetir los escenarios válidos en el mismo dispositivo a 60 Hz, en modo profile, con la app visible durante toda la medición.
- Comparar UI y raster p95/p99, cuadros que exceden 16,67 ms, latencia de operación y memoria. La meta gráfica es mantener ambas etapas dentro del presupuesto; una mejora parcial debe documentarse como parcial.
- Evitar errores ocultos por el recolector y descartar escenarios afectados por cambios de visibilidad.
- Verificar conservación de anotaciones, exportaciones y calidad del PDF cuando corresponda a la modificación.
- Validar después en otro equipo, especialmente uno con menos RAM; usar un dispositivo iOS para cualquier conclusión sobre iOS.
- Integrar cambios pequeños y medibles. Registrar resultados antes/después antes de preparar una versión de publicación.

El aumento de caché a ciegas, la eliminación del límite base de 1800 px y el reemplazo de setState no tienen justificación suficiente como soluciones generales con las evidencias actuales.
