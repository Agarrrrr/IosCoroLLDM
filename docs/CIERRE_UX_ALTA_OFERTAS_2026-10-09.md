# Cierre de pendientes altos de UX: ofertas y selección Premium

Continuación de `MEJORAS_UX_AJUSTES_2026-10-09.md`. El registro anterior describe la primera implementación y se conserva. No se modifica el informe original de rendimiento.

## Implementado

- **Ofertas reales en iOS:** consulta `checkTrialOrIntroductoryPriceEligibility` del SDK instalado. La duración introductoria aparece solo si el resultado es elegible. La consulta usa los productos de la oferta y se recalcula cuando cambia el cliente o el catálogo de paquetes; cambiar el estado «ocupado» no repite la consulta.
- **Ofertas en Android:** se describe `defaultOption`, la opción que utiliza la compra del paquete. Se muestran sus fases en orden: prueba gratuita, posibles descuentos intermedios y precio normal con su periodo. No se llama al API de elegibilidad de iOS en Android.
- **Datos desconocidos:** ausencia de elegibilidad, error, tiempo de espera o duración no interpretable mantienen un aviso de confirmación por la tienda. No se inventa una semana gratuita. Las condiciones de la tienda se confirman antes del pago.
- **Plan mensual y anual comparables:** precio localizado y periodo junto a cada plan. Ambos aparecen con el mismo diseño y sin etiquetas de ahorro calculadas con datos incompletos.
- **Una acción principal:** seleccionar un plan no inicia la compra. «Continuar con el plan seleccionado» queda deshabilitado hasta elegir uno y durante una operación. Se envía a la compra exactamente el paquete elegido.
- **Selección y foco:** resalte sólido y marcador de selección; indicador de foco de 2 dp usando el par accesible del tema. El recorrido por Tab permanece dentro del diálogo hasta cerrarlo.
- Cerrar, restaurar, privacidad y términos permanecen accesibles. No se cambian precios configurados, cuotas, catálogo, anotaciones ni el mecanismo de identidad existente.

## Validación

Regresión completa: **161 pruebas permanentes**, que incluyen las 148 anteriores y 13 nuevas:

- Diez pruebas de condiciones de oferta: elegible/inelegible/desconocida, duración distinta de una semana, descuento pagado, fases Android intermedias y precio final, formato desconocido, consulta nativa del SDK, cambio de cliente, fallo y separación de plataformas.
- Dos recorridos en español e inglés con texto al 200 %: elegir mensual y luego anual no compra; continuar envía únicamente anual.
- Una prueba de foco con veinte pasos de Tab, indicador visible y cierre del diálogo.
- Se conserva la matriz de pantallas con texto al 200 %, cinco temas, ambos idiomas y orientación horizontal.
- Análisis estático sin incidencias. Capturas revisadas visualmente, con precios y elegibilidad de prueba, en `output/accessibility/ux-offers-*-2026-10-09.png`. Se usa una fuente local de sustitución en la vista previa.

```text
flutter test test/subscription_terms_test.dart test/premium_selection_test.dart test/ux_accessibility_test.dart test/restore_purchases_test.dart test/theme_contrast_test.dart test/theme_provider_test.dart test/pdf_theme_palette_test.dart test/pdf_color_filter_test.dart test/monetization_state_test.dart
```

## Límites pendientes de validación manual

Las consultas del SDK se probaron mediante su canal nativo simulado; no se efectuaron compras reales ni se inspeccionaron ofertas comerciales en las consolas. Falta probar compra/restauración en sandbox de App Store y Google Play y el recorrido con VoiceOver/TalkBack. Android entrega ofertas de la tienda; ofertas con elegibilidad definida por el desarrollador requieren que esa política esté correctamente configurada. La presentación describe la opción devuelta por el SDK y no sustituye la confirmación final de la tienda.

Los cuatro problemas altos originales cuentan con corrección de código y pruebas automatizadas; esto no constituye certificación de accesibilidad de toda la app. La revisión de otras pantallas con texto ampliado y los pendientes medios del informe continúan separados.

Referencias: [RevenueCat: ofertas y elegibilidad](https://www.revenuecat.com/docs/subscription-guidance/subscription-offers), [ofertas Google Play](https://production-docs.revenuecat.com/docs/subscription-guidance/subscription-offers/google-play-offers), [WCAG: foco visible](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html), [WCAG: texto ampliable](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html).
