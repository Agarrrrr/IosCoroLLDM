# Colores y resaltes accesibles — 2026-10-09

## Criterio aplicado

WCAG 2.2 nivel AA: contraste sin redondear de al menos 4.5:1 para texto normal y 3:1 para indicadores gráficos necesarios para identificar controles y estados. Para esta paleta se exige 4.5:1 incluso a los textos grandes; el algoritmo apunta a 4.7:1 para texto y 3.2:1 para contornos, dejando margen de cuantización. La selección debe tener una señal adicional al color.

Fuentes oficiales:

- [1.4.3 Contrast (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum).
- [1.4.11 Non-text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).
- [1.4.1 Use of Color](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html).

## Cambios implementados

- Ajuste de resaltes mediante luminancia relativa sRGB y contraste contra los fondos de cada tema, incluyendo fondos de selección compuestos con transparencia.
- Conservación del tono elegido, con saturación y luminosidad más contenidas en temas oscuros. La preferencia original del usuario sigue almacenada.
- Colores de texto sobre botones y contenedores definidos según su fondo; se elimina el blanco fijo sobre resaltes claros.
- Menú de temas: fondo de selección suave, contorno e icono de confirmación, sin sombra de color.
- Categorías, encabezados, buscador y estados vacíos usan colores de texto secundarios opacos que cumplen contraste.
- Corazones y flechas del catálogo visibles en cada tema. El favorito sigue distinguiéndose por su forma llena/vacía.
- Marca de selección de color negra o blanca según contraste, con contorno visible y sin halo.
- Controles del reproductor usan el resalte adaptado del tema en lugar del color original sin adaptar.

## Ejemplo medido: resalte dorado

Comparación del código anterior en HEAD frente al código corregido. Los valores de esta tabla se redondean solamente para presentación; las pruebas usan los valores completos.

| Tema | Texto de resalte sobre superficie, antes → ahora | Texto de tema seleccionado, antes → ahora |
| --- | --- | --- |
| Claro | 2.55 → 5.52 | 2.55 → 18.40 |
| OLED | 12.06 → 9.24 | 1.38 → 13.55 |
| Sepia | 2.41 → 5.45 | 2.62 → 7.16 |
| Quiet | 5.69 → 5.67 | 1.49 → 7.10 |
| Oscuro normal | 11.22 → 8.74 | 1.25 → 11.58 |

Reducir la luminosidad de un resalte que ya tiene contraste suficiente es una decisión de diseño para reducir el brillo percibido, no un requisito de WCAG.

## Verificación

- 80 combinaciones: los cinco temas × once colores disponibles y cinco casos adicionales (negro, blanco, amarillo, azul y color con transparencia).
- Verificación independiente de sRGB: resalte, texto principal y secundario contra superficie, scaffold, contenedores y selección; texto sobre rellenos y contorno de controles.
- 89 pruebas permanentes aprobadas: 81 de contraste y ocho de temas/preferencias.
- Una prueba adicional exporta la comparación visual y ratios de 15 combinaciones. La vista previa usa una fuente Arial cargada como sustituto de Inter y los iconos Material; es una comparación de componentes, no una captura en un teléfono.
- Análisis de Dart en los nueve archivos revisados sin errores ni advertencias; quedan avisos informativos de usos anteriores de `withOpacity` deprecado.

Evidencia visual: `output/accessibility/themes-2026-10-09.png`. Ratios completos: `output/accessibility/contrast-2026-10-09.json`.

## Alcance

Esto valida la paleta y los componentes corregidos; no certifica conformidad WCAG de toda la aplicación. No se comprobó cada pantalla, superposición, animación ni el contenido de todas las partituras. Quedan fuera de este paso la auditoría completa de lectores de pantalla, foco, teclado, ampliación de texto y tamaños de interacción. No se compiló ni publicó una nueva versión.
