# Prioridades medias de UX y ajustes intuitivos — 2026-10-09

Continúa `REVISION_UX_PREMIUM_2026-10-09.md` y los registros de prioridades altas. Se conservan los informes anteriores y el informe original de rendimiento.

## Correcciones medias

| Problema | Implementación |
| --- | --- |
| Títulos cortados | El catálogo muestra hasta dos líneas y ofrece el nombre completo mediante tooltip. Tocar el título de la barra del visor abre un diálogo con el nombre completo seleccionable. El encabezado del menú de exportación también muestra el nombre completo. |
| Controles pequeños | Favoritos y controles secundarios de audio pasan a un área mínima de 48 × 48 dp. Favoritos tiene etiquetas para agregar/quitar y tocarlo no abre la partitura. El selector de idioma del visor usa un botón de traducción con tooltip. Los colores de Ajustes ya tenían 48 dp. |
| Cuotas visibles solo al bloquear | El reproductor muestra cantos nuevos disponibles; un canto previamente abierto aparece como desbloqueado. El menú de exportación muestra operaciones restantes y explica que un lote puede incluir varias voces y que el PDF no consume esta cuota. |
| Se pierde la intención tras obtener Premium | Al cerrar Premium se comprueba el acceso y se inicia la reproducción pendiente si corresponde. Exportar conserva la selección de voces tras Premium o una recompensa y continúa sin volver a abrir el menú. No se reanuda una pantalla abandonada. Se evitan solicitudes de reproducción duplicadas durante la comprobación. |
| Consistencia y mensajes Premium | Los resaltes sólidos, condiciones de planes, mensajes de error y «Procesando» se corrigieron en los pasos anteriores. Se conserva ese trabajo. |

### Coherencia de las cuotas

Se observan los mismos contadores Hive que utiliza el controlador, sin una nueva consulta de red para dibujar el aviso. Los avisos se actualizan al cambiar contadores y a medianoche local. Se conservan los límites de cinco cantos distintos y tres operaciones de exportación, además de los créditos de recompensa existentes. Exportar varias voces en una sola operación consume un acceso, como ya hacía el código.

Se corrigió un fallo concreto: la primera recompensa de exportación de un nuevo día podía perderse cuando el siguiente consumo reiniciaba los contadores. Ahora se establece el día antes de otorgar la recompensa. Los reinicios relacionados se escriben juntos con `putAll` para evitar mostrar contadores de días distintos durante la transición.

### Panel de audio

La prueba del panel real a 320 px con texto al 200 % encontró un desbordamiento horizontal en el encabezado. Se permite distribuir sus elementos en varias líneas. El panel tiene altura limitada y contenido desplazable para conservar todos sus controles; cuando está cerrado se sitúa completamente fuera de la pantalla. No se incorporan nuevas funciones del reproductor ni se cambia su velocidad, mezcla o reproducción musical.

## Ajustes generales más intuitivos

La pantalla inicial muestra grupos desplegables con un resumen del valor actual:

- **Apariencia:** fondo y color; por ejemplo «Negro OLED · Azul».
- **Partituras:** dirección utilizada para pasar páginas.
- **Idioma y repertorio:** Español o English.
- **Premium y dispositivos:** estado del acceso y opciones de restauración/vinculación.
- **Ayuda e identificador:** código de soporte y copia.

Los resúmenes cambian inmediatamente con la elección. Se conservan los mismos proveedores y valores persistentes, los controles con relleno sólido y el encabezado con cierre visible. No se introduce inicio de sesión ni se modifican anotaciones, catálogos o el motor PDF.

## Validación

- **175 pruebas permanentes aprobadas:** 161 anteriores y 14 nuevas de cuotas, continuidad, títulos/favoritos y panel real de audio.
- Cuotas iniciales, agotadas, créditos extra, cambio de día y recompensa de exportación comprobados con el controlador y almacenamiento reales de prueba.
- Continuidad comprobada con acceso autorizado/denegado y salida de pantalla antes o durante la comprobación. La integración nativa de compra, anuncios y reproducción requiere validación en dispositivo.
- Componentes y panel real probados a 320 × 640 dp y texto al 200 %. Favoritos medido en al menos 48 dp; el panel permite desplazar hasta los controles.
- Matriz previa de cinco temas y ambos idiomas ahora abre también los grupos de Ajustes. Se comprueba que los resúmenes reflejan tema, color y navegación.
- Archivos nuevos, Ajustes y controlador: análisis estático sin incidencias. El visor mantiene avisos anteriores de deprecación de `withOpacity`, sin errores ni advertencias.
- Capturas revisadas en `output/accessibility/ux-medium-settings-2026-10-09.png` y `ux-medium-settings-appearance-2026-10-09.png`, usando una fuente local de sustitución.
- Evidencia de regresión: `output/accessibility/ux-medium-regression-2026-10-09.log`.

## Orden de los siguientes pasos

1. Revisar la experiencia de estos ajustes reorganizados con usuarios/dispositivos y afinar etiquetas si hace falta.
2. Revisión completa de accesibilidad: TalkBack/VoiceOver, foco, estados, controles del visor y reproductor, contraste y texto ampliado en las demás pantallas. No se afirma certificación de toda la app.
3. Las nuevas funciones y mayor libertad en los ajustes del reproductor se reservan para una etapa posterior, según la indicación del usuario.

No se generó una versión de distribución ni se publicó en GitHub en este paso.
