# Correcciones de interacción del visor — 10 de octubre de 2026

Registro independiente de los cambios de interacción posteriores al commit `d5a21ed`. La auditoría original de rendimiento se conserva en `AUDITORIA_RENDIMIENTO_ANDROID_2026-09-29.md`.

## Cambios aplicados

| Área | Resultado |
| --- | --- |
| Título del canto | Es texto informativo. Pulsarlo ya no abre una ventana. |
| Reproductor | Eliminados la flecha, la barra negra de arrastre y el rótulo «Reproductor». Conserva el piano, el tempo y los controles compactos, con mezclador y velocidad a los lados de Play. Sombra exterior para distinguirlo del fondo. |
| Cierre del reproductor | Se conserva el gesto hacia abajo y la acción accesible de cierre. Los gestos cortos, hacia arriba o cancelados no lo cierran. |
| Escritura | Vista previa con ancho disponible, posición contenida en el borde superior/lateral y líneas sin el anterior máximo de cuatro. Fondo según el tema y color legible. El tamaño coincide con el texto dibujado en la página. |
| Borrador | La tinta desaparece durante el contacto y el movimiento, antes de levantar el dedo. El gesto completo se guarda como una sola operación; cancelarlo restaura la tinta. |
| Deshacer/Rehacer | Ambos reflejan el historial real. Rehacer está desactivado sin operaciones pendientes y se invalida al dibujar después de deshacer. |
| Borrar todo | Requiere confirmación e informa que afecta a todas las páginas del canto. Cancelar conserva las anotaciones. El botón se desactiva cuando no hay anotaciones. |
| Límite de cantos | Banner superior redondeado, sombra suave, entrada/salida animadas y mensaje corto. Desaparece tras tres segundos o al tocarlo; un nuevo aviso sustituye al anterior. |

## Causas y solución técnica

- El borrador activo mostraba el cursor, pero excluía el trazo de borrado de la pintura hasta finalizar el gesto. Ahora combina la capa guardada con el borrado activo en una capa temporal limitada a la zona afectada. Reutiliza la preparación de la página y alinea la zona con la cuadrícula física de píxeles para mantener el resultado con zoom y posiciones fraccionarias. No escribe el historial durante cada movimiento.
- El editor flotante usaba ancho intrínseco reducido y un máximo de cuatro líneas. Ahora dispone del espacio restante, permite líneas adicionales y adapta el fondo al tema. Mantiene las coordenadas originales para guardar la anotación y utiliza el tamaño del lienzo para que vista previa y resultado no difieran con la escala de texto de la interfaz.
- Rehacer utiliza el historial existente del motor PDF; se añadieron indicadores `canUndo` y `canRedo` para habilitar los controles correctamente.

## Verificación

**44 pruebas automatizadas aprobadas**, en:

- `test/annotation_live_feedback_test.dart`: borrado inmediato con 1 y 101 trazos, lápiz/subrayador, cancelación, deshacer, confirmación y rehacer; texto completo en claro/OLED; comparación de borrado temporal y guardado con origen fraccionario a escala 2×.
- `test/app_notification_banner_test.dart`: aviso redondeado, sustitución, expiración y texto al 200 %.
- `test/ux_medium_widgets_test.dart` y `test/player_dismiss_test.dart`: título pasivo, panel compacto, controles, cierre y cancelación de gestos.
- `test/annotation_rendering_test.dart`, `test/annotation_theme_test.dart` y `test/pdf_deferred_render_test.dart`: regresiones de caché, tinta opaca/translúcida, borrado, zoom, temas y renderizado PDF.

Análisis estático: **sin errores ni advertencias**; 13 observaciones informativas de estilo/deprecaciones. Registro: `output/accessibility/interaction-feedback-analyze-2026-10-10.log`. Pruebas: `output/accessibility/interaction-feedback-tests-2026-10-10.log`.

Capturas revisadas con sombras activadas:

- `output/accessibility/interaction-player-2026-10-10.png`
- `output/accessibility/interaction-banner-2026-10-10.png`
- `output/accessibility/interaction-text-2026-10-10.png`

La captura reproducible está en `tmp/interaction_preview_test.dart`; su ejecución aprobada se registra en `output/accessibility/interaction-preview-2026-10-10.log`. Utiliza Arial como sustitución de las fuentes para la revisión local. No representa una captura en dispositivo físico.

## Alcance de la evidencia

Se verificaron comportamiento y píxeles en pruebas Flutter. Esta entrega no incluye una nueva medición de FPS/GPU en Android o iOS; el coste del borrado continuo debe contrastarse en dispositivo, especialmente en páginas densas. Las comprobaciones de texto al 200 % corresponden a controles y avisos de interfaz; el texto de anotación conserva la escala propia de la partitura. No se afirma certificación WCAG.
