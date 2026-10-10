# Resalte sólido y barra del visor — 2026-10-09

Actualización del trabajo de colores accesibles a petición del usuario.

- El tema seleccionado vuelve a tener relleno sólido de resalte. Se usa `onSecondary` sobre `secondary`, con contraste mínimo de 4.5:1; se conserva el icono de confirmación para que la selección no dependa solo del color.
- La barra y el fondo exterior del visor usan la misma paleta que el papel filtrado: claro `#FFFFFF`, OLED `#000000`, sepia `#F4ECD8`, Quiet `#3C3F42`, oscuro normal `#1B2430`.
- Las cuatro matrices existentes se trasladaron sin cambios a `PdfThemePalette`, que reúne filtro y fondo. No cambia el tratamiento de color del PDF ni el de los trazos.
- Los textos e iconos de la barra usan colores contrastados de la paleta.

## Verificación

95 pruebas aprobadas: contraste de 80 combinaciones de tema/resalte, transparencia, ocho pruebas de preferencias, cinco comparaciones de píxeles entre barra y papel filtrado, y una prueba de continuidad de la capa del filtro. En las comparaciones de píxeles se admite una diferencia máxima de una unidad por canal por cuantización de las matrices.

Los fondos del visor se incluyeron también en las pruebas de contraste sin redondear. Se conserva el criterio WCAG 2.2 AA aplicado al paso anterior: 4.5:1 para texto y 3:1 para indicadores necesarios.

La comparación visual del primer paso en `ACCESIBILIDAD_COLORES_2026-10-09.md` muestra el diseño con contorno que precedió a esta corrección; no representa el resalte sólido actual. Estos cambios no certifican accesibilidad completa de todas las pantallas y no han sido publicados.

Comparación actual: `output/accessibility/themes-solid-2026-10-09.png`, verificada visualmente. Ratios: `output/accessibility/contrast-solid-2026-10-09.json`. La prueba adicional de exportación visual también pasó; la imagen es una comparación de componentes y usa Arial como sustituto de Inter.
