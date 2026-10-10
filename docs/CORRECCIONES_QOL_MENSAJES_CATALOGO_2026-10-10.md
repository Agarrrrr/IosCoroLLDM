# QoL: mensajes, exportación y catálogo — 2026-10-10

Continúa `VERIFICACION_QOL_2026-10-09.md`. Se conserva la auditoría original y sus registros. La indicación del usuario es explicar los fallos de recursos locales sin ofrecer reintentos que no solucionan archivos ausentes.

## Cambios realizados

### Archivos y mensajes

- Pantalla legible, centrada y desplazable para PDF no disponible o ilegible. Sustituye el mensaje genérico de conexión y la excepción técnica del error nativo por una explicación simple en español/inglés.
- Los errores nativos del PDF se presentan fuera del filtro de color del papel, para evitar que el modo oscuro transforme el mensaje.
- Fallos al obtener o preparar MIDI muestran un aviso breve y un estado «Audio no disponible» en el panel, sin dejar controles aparentemente cargando. El motor informa éxito/fallo de carga y limpia la canción anterior al comenzar otra carga.
- Errores de exportación explican que no se pudo crear, guardar o compartir el archivo, según la fase; los detalles técnicos se conservan en registros, fuera del texto de usuario.
- No se añade un botón Reintentar. No se modifica la resolución de recursos: el código conserva caché, assets y descarga de respaldo existentes. No se afirma que todo fallo equivalga necesariamente a un asset ausente.

### Exportación

- El botón usa una única operación asíncrona desde la preparación de voces hasta terminar o cancelar el flujo completo. Acepta una sola pulsación incluso antes de repintar el botón; durante la operación muestra actividad y queda deshabilitado.
- El bloqueo se libera mediante `finally`, incluido el cierre del menú. La pantalla maneja fallos inesperados de preparación con un mensaje simple.
- Cancelar un lote notifica inmediatamente al indicador; el estado Cancelando se conserva al llegar nuevos eventos de progreso. La cancelación continúa al terminar el archivo actual.

### Catálogo

- «No tienes cantos favoritos» solo aparece cuando la colección realmente está vacía; favoritos existentes sin coincidencias muestran «Sin coincidencias».
- Un catálogo vacío y uno ilegible tienen mensajes distintos. Si falla cargar el catálogo sin caché, el proveedor emite un error en lugar de una lista vacía; sus consumidores manejan el error sin lanzar al construir la pantalla.
- Retirado el gesto de recarga del estado vacío, cuyo callback no realizaba ninguna acción.
- «Limpiar búsqueda y filtros» permite recuperar resultados sin eliminar favoritos ni cambiar el idioma elegido.
- Limpiar cancela el debounce pendiente, evitando que una búsqueda anterior reaparezca. El campo refleja la búsqueda de sesión cuando se reconstruye el catálogo.

## Verificación

- **185 pruebas de regresión aprobadas**, incluyendo seis pruebas nuevas del catálogo real, fallo de lectura, ausencia de favoritos, limpieza conservando favoritos, doble pulsación antes del repintado y estado de audio fallido.
- Las pruebas del catálogo usan 320 × 640 dp y texto al 200 %. Se conserva la regresión previa de temas, Ajustes, ofertas, cuotas, controles del reproductor y búsqueda.
- Análisis de los archivos afectados sin errores ni advertencias; permanecen avisos anteriores de deprecación de `withOpacity`.
- Evidencia local: `output/accessibility/qol-feedback-regression.log` y `output/accessibility/qol-messages-analysis.log`.
- La carga de audio nativo, fallos de exportación nativa y envío mediante aplicaciones externas requieren comprobación en dispositivo; no se presentan como pruebas completadas aquí.

No se cambiaron políticas de anuncios/cuotas, navegación Atrás, encuadre al girar ni funciones del motor de reproducción. No se generó AAB/IPA ni se publicó un commit en este paso.
