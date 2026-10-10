# Menús, reproductor y anotaciones — 10 de octubre de 2026

Registro independiente. Los informes originales de rendimiento se conservan.

## Cambios

- Ajustes y Obtener Premium están en el pie fijo del menú. Solo se desplazan el encabezado, los filtros y los temas. Verificado con 40 temas y texto al 200 %.
- Los resaltes seleccionados conservan relleno sólido. El dorado de relleno es más luminoso que el dorado usado para texto sobre blanco: se separan ambos usos para mantener contraste. Los pares de texto y relleno se verifican en los cinco temas.
- El cambio de idioma de partitura muestra ENG–ESP.
- Borrador y subrayador tienen iconos dibujados para esas herramientas. La barra y la paleta admiten desplazamiento horizontal en pantallas estrechas, con controles de 48 × 48.
- Subrayador real con opacidad del 32 %. Tiene amarillo neón, azul y rosa, además de los colores del lápiz. Su color y grosor se conservan separados de los del lápiz.
- El subrayador adapta la luminosidad al papel del tema manteniendo el tono. Se ajustan también las muestras de su paleta. Los colores originales permanecen guardados; cambiar de tema no modifica las anotaciones ni su historial.
- El filtro de tema se aplica a las imágenes del PDF, incluidas las imágenes de zoom y los placeholders, mediante el parámetro añadido al fork local de pdfrx. Las anotaciones y sus textos quedan fuera del filtro: rojo no se convierte en cian. La tinta neutra se adapta al fondo; los colores mantienen su tono y ajustan luminosidad cuando falta contraste.
- Las páginas adaptadas y los colores de presentación se reutilizan en caché. No se duplican las listas de puntos en cada movimiento. Las rutas de composición distinguen la transparencia real del subrayador para que el borrador respete el papel y el orden de los trazos.
- La mezcla de voces vuelve a ser un submenú. La velocidad queda dentro de otro submenú; conserva el rango 0.50–2.00× y pasos de 0.05×.
- Mezcla a la izquierda de Play y velocidad a la derecha, en la misma fila que metrónomo y Detener. Sin fila adicional debajo de Play.
- El reproductor puede cerrarse deslizando hacia abajo desde su cabecera. Tiene indicador de arrastre, botón de cierre y acción accesible. Cerrar oculta el panel y mantiene la reproducción. Los gestos hacia arriba, los arrastres cortos y las cancelaciones no lo cierran; el progreso mantiene su propio gesto horizontal.
- El movimiento del metrónomo ocupa el intervalo del pulso, según tempo, velocidad y agrupación. Respeta la preferencia de reducir animaciones.
- La cuota de cantos se muestra como mensaje corto al comenzar a reproducir, una vez en la pantalla. Se retiró el aviso persistente dentro del panel.
- El catálogo diferencia recursos con audio mediante color, piano de 22 px y etiqueta; el texto conserva un color neutro legible.
- Ajustes usa grupos redondeados y espacio, con menos divisores. El ID de soporte oculta el prefijo RCAnonymousID en pantalla; copiar conserva el ID completo para soporte.
- Se retiró la vinculación manual por ID y el método que llamaba a RevenueCat logIn con un ID escrito por el usuario. Se conserva Restaurar compras mediante la cuenta de la tienda.

## Comprobaciones

- Regresión: 184 pruebas aprobadas en `output/accessibility/design-final-tests.log`.
- Distribución compacta final del reproductor: 9 pruebas aprobadas en `output/accessibility/player-compact-final-tests.log`, incluida alineación de mezcla, Play y velocidad en 320 px y texto al 200 %.
- Subrayador: 15 pruebas aprobadas en `output/accessibility/marker-final-tests.log`, incluidas dos comprobaciones adicionales de independencia del lápiz y paleta al 200 %.
- Prueba de píxeles: PDF blanco invertido a negro mientras un overlay rojo sigue rojo, sin píxeles cian.
- Prueba de píxeles: marcador rojo translúcido sobre papel blanco y borrado que deja el papel intacto.
- Contraste de texto, colores de tema, gesto de cierre, submenús, menús fijos, historial rasterizado, anotaciones densas, serialización y estados vacíos incluidos en la regresión.
- Análisis de `lib` y pruebas: sin errores ni advertencias; avisos informativos de `withOpacity` ya presentes.
- Capturas Flutter revisadas en `output/accessibility/design-{settings,drawer,player,marker}-2026-10-10.png`. Usan Arial como fuente local sustituta; no son capturas del dispositivo.

## Límites

Estas comprobaciones son locales; falta validar esta revisión en Android e iOS reales. La transparencia del marcador es decoración sobre el documento: su umbral interno de visibilidad compuesta no equivale al contraste requerido para texto ni acredita una certificación WCAG de toda la app.

Retirar la vinculación por ID elimina ese acceso desde la app. No revoca vínculos de RevenueCat que ya existieran, ni establece un límite de dispositivos en el servidor; esas políticas requieren una revisión independiente sin perjudicar compras legítimas.
