# Exportaciones iOS y contraste del reproductor

## Hallazgos y cambios

- El resultado de `showModalBottomSheet` se recibía antes de terminar su animación de salida. Los selectores de exportación ahora esperan también `TransitionRoute.completed`.
- El diálogo de conversión se cerraba con un `pop` sobre el navegador raíz, sin identificar la ruta. Ahora conserva su propia `DialogRoute`, la cierra de forma idempotente y espera su retirada antes de presentar otra ventana o disponer los notificadores.
- `share_plus` instalado es 10.1.4. Su implementación iOS utiliza un proveedor personalizado de previsualización y asigna `sourceView` también en iPhone. Existen incidencias de iOS 26 en el repositorio del plugin: [presentación y cierre](https://github.com/fluttercommunity/plus_plugins/issues/3943). Esto es evidencia de un riesgo, no reproducción del fallo concreto del usuario.
- PDF y MP3 del visor utilizan ahora un coordinador UIKit propio con URL de archivo. El anclaje se aplica exclusivamente al iPad. Se bloquean presentaciones simultáneas; se espera a que concluya la retirada del controlador nativo para devolver el resultado. Errores y cancelaciones se distinguen de un envío completado.
- Se añade «Guardar en Archivos» mediante `UIDocumentPickerViewController(forExporting:asCopy:)`, para PDF, una voz o un lote. Las copias temporales conservan nombres públicos y se eliminan después de finalizar el selector; se mantienen los originales del repertorio.
- Los anuncios de apertura se suspenden durante compartir/guardar. Cancelar el menú de compartir no consume una exportación de audio ni solicita el anuncio de exportación.
- La codificación escribía directamente en la ruta MP3 definitiva: una interrupción podía dejar un archivo parcial que una próxima exportación reutilizaría. Ahora se codifica en `.pending` y se publica con un renombrado al terminar. La caché pasa a v6 para evitar reutilizar restos de v5; la primera exportación vuelve a convertir el audio.
- El reproductor tiene contorno de 0,75 y sombra, con fondo de superficie. Las etiquetas de compás, indicadores de carga y colores de los iconos de exportación utilizan la paleta accesible. El primer pulso conserva rojo, adaptado al contraste del fondo.

## Validación

92 pruebas Flutter aprobadas: navegación de exportación, contraste del reproductor sepia cargado/en carga, contraste de los cinco temas y dieciséis acentos, gesto de cierre y regresiones MIDI (419 MIDI y 1691 voces).

Las pruebas de navegación cubren resultados de caché inmediatos, cuatro aperturas consecutivas, cierre idempotente, conservación de otra ventana abierta y retirada de listeners antes de disponer el progreso.

Estas pruebas no compilan ni ejecutan UIKit. En este entorno Windows no hay Xcode. Queda pendiente compilar el código Swift y comprobarlo en iPhone/iPad: PDF, una voz, lote, guardar/cancelar, compartir/cancelar, retorno desde otra app y cuatro aperturas consecutivas. Comprobar con y sin Premium.

El usuario confirmó iOS 26 y que desaparece solamente la ventana de compartir, no la aplicación. Esto es compatible con el riesgo de presentación anterior, aunque sigue pendiente reproducir y validar el comportamiento nativo. No se atribuye el fallo a falta de almacenamiento. Los PDF locales son recursos/caché; su presencia no demuestra que se hayan exportado automáticamente.

Referencia de la API nativa: [Apple: UIDocumentPickerViewController](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller).
