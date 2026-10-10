# Mejoras de UX, Premium y Ajustes — 2026-10-09

Registro de implementación a partir de `REVISION_UX_PREMIUM_2026-10-09.md`. Los informes anteriores se conservan como evidencia histórica.

## Prioridades altas

1. **Ampliación de texto:** eliminado el tope global de 135 %. La aplicación respeta la configuración del sistema. Ajustes, menú lateral y diálogos Premium/recompensas permiten envolver y desplazar contenido. El menú completo se desplaza para que su pie no desborde una pantalla pequeña. El encabezado y cierre de Ajustes quedan visibles.
2. **Contraste de Premium:** retirados el dorado fijo sobre fondos transparentes, los halos y la insignia pequeña. Los avisos usan pares de colores accesibles del tema. Premium mantiene un relleno sólido; el estado seleccionado también se reconoce por un indicador, sin depender solo del color.
3. **Restauración:** sustituido el resultado booleano por `RestoreResult`. Éxito, ausencia de compra, tienda no disponible, fallo y operación en curso tienen mensajes diferentes. Las solicitudes simultáneas se evitan. Ambos puntos de restauración usan la misma traducción y explican el reintento. Los detalles técnicos permanecen fuera del texto mostrado al usuario.
4. **Prueba gratuita:** eliminada la promesa fija de «1 semana gratis». Se muestran el precio localizado y el periodo del plan, con renovación automática y cancelación. La pantalla explica que la tienda confirmará ofertas y condiciones antes de pagar. **No se implementó una consulta de elegibilidad ni un anuncio dinámico de duración**: se adoptó el mensaje neutral para evitar promesas sin datos verificados. Las ofertas configuradas y el flujo nativo de compra siguen vigentes.

## Ajustes y menús

- Grupos claros: Idioma, Apariencia, Color de resalte, Pasar páginas, Compras y dispositivos, Ayuda e identificador.
- Cinco fondos directamente seleccionables: Claro, Oscuro, Negro OLED, Sepia y Gris de lectura. La elección conserva los mismos valores de preferencias; elegir una variante oscura también actualiza la preferencia utilizada al alternar día/noche.
- «Deslizar hacia arriba» y «Deslizar hacia los lados» sustituyen términos técnicos. Cada opción explica su comportamiento.
- Colores con nombre, tooltip, estado accesible seleccionado y objetivo táctil de 48 × 48 dp. El icono de cierre tiene una etiqueta accesible.
- Restaurar y vincular dispositivos quedan separados del código de soporte. El identificador se puede desplegar y copiar en Ayuda; se retiró del diálogo de compra.
- Se conserva la vinculación manual existente de Premium y se explica dónde encontrar el identificador. No se introduce registro ni inicio de sesión. No se modifican las anotaciones ni su sincronización.
- Menú con etiquetas en lenguaje natural: Todos los cantos, Mis favoritos, Filtrar por tema, Obtener Premium y Ajustes. Los nombres de los temas conservan sus mayúsculas originales.
- Avisos de cuota explican que escuchar consume cantos distintos, mientras exportar consume exportaciones. No se cambian cuotas ni anuncios.

## Evidencia de validación

- **148 pruebas permanentes:** 95 de temas/contraste/filtro PDF, 2 de estado de monetización, 5 de restauración y 46 de UX.
- Matriz de UX: cuatro pantallas × cinco temas × dos idiomas, 320 × 640 dp y texto al 200 %, desplazando su contenido sin excepciones de diseño.
- Cuatro comprobaciones adicionales en horizontal, 640 × 320 dp, texto al 200 %; selección de opciones/nombres de colores/áreas táctiles; apertura y cancelación de vinculación al 200 %.
- Restauración simulada mediante el canal del SDK: Premium activo, consulta sin compras, excepción de red, tienda sin configurar y peticiones duplicadas. No se realizan compras reales.
- Análisis estático de los archivos modificados: sin incidencias.
- Capturas de revisión en `output/accessibility/ux-*-2026-10-09.png`; los precios son datos de prueba, no precios comerciales verificados. La vista previa usa una fuente local de sustitución.

Comando de regresión:

```text
flutter test test/ux_accessibility_test.dart test/restore_purchases_test.dart test/theme_contrast_test.dart test/theme_provider_test.dart test/pdf_theme_palette_test.dart test/pdf_color_filter_test.dart test/monetization_state_test.dart
```

## Criterios y límites

Se aplican [texto ampliable de WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html), [contraste mínimo](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), controles nativos de Material y la recomendación [Android de objetivos táctiles de 48 dp](https://support.google.com/accessibility/android/answer/7101858). Las condiciones de ofertas siguen la documentación de [RevenueCat](https://www.revenuecat.com/docs/subscription-guidance/subscription-offers), cuyo mecanismo de elegibilidad difiere entre plataformas.

Esto verifica el código y los escenarios descritos; no certifica toda la aplicación. Quedan la revisión manual con TalkBack/VoiceOver en dispositivos reales, compra/restauración en sandbox de ambas tiendas y revisión de las demás pantallas con texto ampliado. Los pendientes medios del informe original —títulos completos, visibilidad previa de cuotas y retomar la reproducción tras comprar— siguen pendientes.
