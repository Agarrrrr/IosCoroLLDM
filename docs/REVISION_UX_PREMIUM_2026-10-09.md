# Revisión de UX y experiencia premium — 2026-10-09

Revisión del código y de documentación oficial. No es una prueba de usabilidad con participantes ni una auditoría visual de todas las pantallas. No se modificó la app en este paso. El usuario descarta introducir inicio de sesión.

## Problemas identificados

| Prioridad | Evidencia | Mejora propuesta |
| --- | --- | --- |
| Alta | `lib/app/app.dart` limita `textScaler` a 1.35. | Permitir ampliación equivalente a 200 % y adaptar el diseño sin perder contenido ni controles. |
| Alta | El diálogo de recompensa usa texto dorado fijo `#D4AF37` de 10 px sobre un fondo teñido al 14 %. El cálculo de contraste resulta 1.910:1 en claro, 1.774:1 en sepia y 3.254:1 en Quiet. | Incluir todos los componentes premium en la paleta accesible, midiendo cada fondo compuesto y extremo del gradiente. |
| Alta | La semana gratis se anuncia siempre que existe paquete mensual; no se consulta duración ni elegibilidad de la oferta para construir ese mensaje. | Obtener el contenido de la oferta real de la tienda y manejar elegibilidad desconocida. Mostrar duración y precio posterior junto al plan correspondiente. |
| Alta | `restore()` devuelve false tanto ante ausencia de Premium como ante una excepción; el diálogo convierte ambos resultados en «No se encontró una compra Premium activa». | Diferenciar restauración sin compras, error de red/tienda y éxito; ofrecer reintento con un mensaje útil. |
| Media | Hay objetivos de interacción de 40 px en colores y de 42 px en controles del visor; el corazón del catálogo usa densidad compacta y restricciones vacías. | Medir las áreas táctiles reales y ampliarlas a las recomendaciones de cada plataforma, conservando iconos pequeños si conviene. Esto no prueba por sí solo una infracción WCAG de tamaño mínimo. |
| Media | Los nombres de canto se truncan a una línea tanto en el catálogo como en la barra del visor. | Permitir dos líneas en catálogo y acceso al título completo en el visor. Probar títulos similares y largos para evitar escoger otra obra. |
| Media | Hay colores dorados, halos y tipografías de 9–10 px particulares en premium, mientras otras pantallas ya usan la nueva paleta. | Unificar tipografía, espaciado, color, estados y componentes; conservar la identidad sin comprometer lectura. |
| Media | La cuota aparece principalmente cuando se alcanza el límite. El código cuenta IDs de cantos para audio y operaciones exitosas para exportación. | Mostrar cantos distintos disponibles y exportaciones restantes antes de bloquear. Explicar qué consume cada cuota. |
| Media | Al elegir Premium desde el límite de reproducción, `_showAudioLimitDialog` abre el diálogo y vuelve sin iniciar el audio tras una compra exitosa. | Reanudar la intención original una vez comprobado el acceso, sin que el usuario deba repetirla. |
| Media | Comprar/restaurar desactiva botones, pero no muestra un estado de progreso propio en esos botones. Se exponen errores técnicos, el nombre RevenueCat y el ID de soporte en la pantalla de compra. | Mostrar progreso y resultados, traducir los errores y trasladar identificadores a Ayuda/Soporte. No sugerir que hay una cuenta con inicio de sesión. |

Las cifras de contraste se calcularon con luminancia sRGB y composición alfa sobre `surface`; no son mediciones de un panel físico. Las condiciones de la oferta y sus precios reales no se inspeccionaron en las consolas de las tiendas.

## Referencias y aplicación

- **WCAG 2.2 AA**, criterios verificables: contraste, uso del color, foco, texto ampliable y objetivos de interacción. [Texto ampliable](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html) y [tamaño mínimo](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html). El mínimo AA de objetivos es 24 × 24 CSS px con excepciones; no debe confundirse con las recomendaciones nativas.
- **Apple HIG**, guía de diseño: controles familiares y objetivos de al menos 44 × 44 pt como regla general. [Botones](https://developer.apple.com/design/human-interface-guidelines/buttons).
- **Material/Android**, guía de diseño: áreas táctiles recomendadas de al menos 48 × 48 dp. [Android Accessibility](https://support.google.com/accessibility/android/answer/7101858).
- **Apple, presentación de suscripciones**: información clara de precio/duración y del precio posterior al periodo de prueba. [Suscripciones](https://developer.apple.com/app-store/subscriptions/).
- **RevenueCat, ofertas reales**: comprobar datos de la oferta y el comportamiento de elegibilidad específico de cada plataforma; la consulta de elegibilidad de iOS no funciona igual en Android. [Ofertas](https://www.revenuecat.com/docs/subscription-guidance/subscription-offers).
- **Heurísticas de Nielsen**, principios de evaluación, no certificación: visibilidad del estado, consistencia, control del usuario, prevención y recuperación de errores. [Referencia](https://www.nngroup.com/articles/ten-usability-heuristics/).

## Dirección de diseño propuesta

1. Lectura: jerarquía tipográfica común, texto ampliable, títulos identificables y controles cómodos.
2. Consistencia: componentes reutilizables y tokens compartidos para radios, espaciado y estados. Una escala de espaciado de 4/8 unidades sería una decisión del proyecto, no una exigencia WCAG.
3. Compra: beneficios concretos, dos planes comparables, total y periodo visibles, selección explícita y una acción principal. Prueba gratis solo cuando corresponda; restaurar y cerrar fáciles de encontrar.
4. Continuidad: conservar el canto, zoom y reproducción al abrir/cerrar paneles; retomar la acción que motivó comprar o ver un anuncio.
5. Validación: teléfonos pequeños, tabletas, orientación horizontal, todos los temas, texto al 200 %, VoiceOver/TalkBack y estados offline, error y compra cancelada. Medir tareas completadas, errores y tiempo de ejecución; no afirmar mejoras de conversión sin datos.

Primero se recomienda corregir accesibilidad y mensajes de compra/restauración; después reorganizar catálogo, visor y pantalla premium. No se propone cambiar precios, cuotas, anuncios ni introducir autenticación sin una petición posterior.
