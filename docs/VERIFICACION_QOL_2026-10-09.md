# Verificación de los siete puntos de QoL — 2026-10-09

Revisión del código actual y de la cobertura de pruebas disponible. No se ejecutaron compras, exportaciones nativas ni navegación en un móvil en este paso. Se corrige la lista de propuestas anterior: no todos sus puntos eran carencias de la aplicación. Los informes originales se conservan.

## 1. Carga y errores claros — parcial

Ya existen carga del catálogo, preparación del PDF, estado de preparación del reproductor, progreso de sincronización y conversión MP3. Exportación múltiple muestra archivo actual y cantidad completada; la restauración de compras distingue resultados.

Pendientes comprobados:
- `visor_screen.dart:1434`: el error del PDF se muestra como texto, sin acción de reintento. `pdf_engine.dart:142` agrupa los fallos bajo un mensaje sobre conexión, aunque también pueden corresponder a archivos locales o descifrado.
- `visor_screen.dart:116`: la obtención del MIDI falla con un `debugPrint`, sin mensaje ni reintento visible. No se afirma aquí que todos los posibles errores internos del motor sean silenciosos.
- `visor_screen.dart:832`, `926`, `1117` y `1237`: los errores de exportación incorporan la excepción técnica al mensaje. La preparación de la lista de voces también expone `$e`.

## 2. Conservar contexto — parcial

Ya existe memoria del desplazamiento del catálogo en Hive (`dashboard_screen.dart:30`, `40`, `67`), y abrir/cerrar paneles del visor usa el mismo controlador PDF y motor MIDI. Las preferencias generales son persistentes. El cambio de velocidad conserva la reproducción mediante el motor existente.

Límites comprobados:
- `visor_screen.dart:1296`: al girar, se conserva la página utilizada para recalcular la vista, pero se reajusta a ancho de página o al encuadre del carrusel; no se conserva el zoom exacto. Puede ser una política intencional y no se clasifica automáticamente como defecto.
- El controlador PDF pertenece al estado del visor; no se encontró persistencia por canto de su matriz/página para reabrirlo. La persistencia de las anotaciones sí existe y es distinta de guardar la vista.
- `visor_screen.dart:dispose` llama a `_midi.dispose()`, que detiene la reproducción; no existe continuidad al salir del visor. Reproducción en segundo plano o reanudación entre sesiones serían decisiones de producto, no requisitos incumplidos.
- El texto de búsqueda vive en un proveedor de sesión; el `TextEditingController` se crea vacío al recrear el Dashboard. La navegación normal con `push` mantiene la pantalla existente, pero no se promete restauración tras reiniciar la app.

## 3. Navegación predecible — parcial

Los diálogos y hojas usan las rutas normales de Flutter y cierres con `Navigator.pop`. Las exportaciones bloquean Atrás deliberadamente mientras trabajan; las múltiples ofrecen Cancelar.

Pendiente concreto: `visor_screen.dart:1324` intercepta Atrás y sale del visor directamente. No consulta `_showMidi`, `_showTools` ni `_showDrawingPalette`. Los paneles internos son parte de un Stack, no rutas independientes, y no se cierran primero.

## 4. Exportación comprensible — implementada en gran parte

Ya existen opciones explícitas de PDF, ensamble, voces individuales, todas con/sin ensamble y una voz por nombre (`visor_screen.dart:575` en adelante). Android permite elegir guardar o compartir. La conversión informa qué procesa, el lote informa progreso y ofrece cancelación. Guardar muestra confirmación; compartir abre la hoja del sistema. No falta una selección comprensible de qué exportar.

Pendientes comprobados:
- `_mostrarMenuCompartirMp3` prepara las voces antes de abrir la hoja, sin guardia de operación pendiente ni indicación de esa preparación. Mientras se espera pueden entrar pulsaciones repetidas; la conversión posterior sí tiene diálogo modal bloqueante. No se afirma haber reproducido múltiples exportaciones simultáneas en móvil.
- El botón Cancelar asigna `progress.value = progress.value` en ambas exportaciones múltiples. Esa asignación no notifica si el valor es igual; el texto puede no cambiar inmediatamente a «Cancelando» hasta el siguiente progreso. La bandera de cancelación y la consulta del servicio sí existen.
- La cancelación individual no existe; la múltiple espera a terminar el archivo actual. Permitir interrupción inmediata sería una mejora adicional que requiere soporte del motor.

## 5. Catálogo y búsqueda — implementados con límites concretos

Ya existen búsqueda normalizada, botón para limpiar texto, favoritos, filtros de tema, selección resaltada y la opción Todos los cantos que quita tema/favoritos (`app_drawer.dart:138`). Existen mensajes para resultados vacíos y favoritos vacíos (`dashboard_screen.dart:198`).

Pendientes comprobados:
- Los filtros se consultan en el menú lateral; no existe un resumen/chips de filtros activos sobre la lista. Añadirlo es una propuesta de comodidad, no ausencia de filtros.
- No existe botón de recuperación dentro del estado vacío, aunque la búsqueda y el menú permiten cambiar los criterios.
- El `RefreshIndicator` del estado vacío tiene `onRefresh: () async {}`: el gesto no recarga nada.
- Si se combina búsqueda con Favoritos y no hay coincidencias, el mensaje usa únicamente `soloFavoritos` y dice «No tienes cantos favoritos», sin comprobar que realmente la colección de favoritos esté vacía.
- Si falla la carga de catálogos sin caché, el proveedor retorna `[]`, confundiendo fallo de carga con resultados vacíos.

## 6. Consistencia visual — parcial, no rediseño pendiente de toda la app

Ya se comparten tema/paleta accesible y rellenos sólidos. Ajustes, compra y cuota fueron adaptados; la barra del visor coincide con el papel filtrado. Se probaron temas, idiomas y texto ampliado en los componentes documentados.

Quedan usos puntuales que requieren revisión: textos del reproductor a 10–11 px con gris fijo, el icono de reproducción blanco fijo sobre el acento y `_ToolBtn` con objetivo de 40 × 40. Esto demuestra diferencias de implementación; no demuestra por sí solo que cada color falle contraste ni que toda la interfaz necesite rehacerse. La verificación integral de contraste/tamaño pertenece a la fase de accesibilidad.

## 7. Recuperación de acciones — ya existe para anotaciones

`pdf_engine.dart:170` conserva el estado previo en el historial. Eliminar un trazo, limpiar una página y borrar todas las anotaciones pasan por ese historial. `undo()`/`redo()` persisten el resultado; el visor muestra sus botones. Borrar todo no solicita confirmación, pero es reversible en el historial disponible. Quitar un favorito también se revierte pulsando de nuevo.

No corresponde afirmar que falte Deshacer ni introducir confirmaciones generales como requisito. El historial está limitado y no se guarda entre sesiones; ampliar esa recuperación sería una función adicional. Los botones Deshacer/Rehacer no se deshabilitan cuando el historial no permite la acción, por lo que pueden parecer operativos sin producir un cambio.

## Lista corregida

Trabajo concreto de QoL: errores accionables, Atrás para paneles internos, preparación única y visible del menú de exportación, actualización inmediata del estado Cancelando, estados vacíos correctos y retirada del gesto de recarga que no hace nada. Después, validar decisiones sobre giro/reapertura y la consistencia restante junto con accesibilidad.

No se modificó código ni se publicó un commit durante esta verificación. Las 193 pruebas previas no se presentan como cobertura de los siete flujos completos.
