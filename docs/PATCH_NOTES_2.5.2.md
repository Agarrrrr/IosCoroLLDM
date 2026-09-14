# Patch notes — Coro LLDM 2.5.2

## Audio y exportaciones

- Los MP3 exportados se comparten como audio MPEG reproducible directamente en WhatsApp, en lugar de entregarse como un archivo genérico.
- Los nombres públicos de PDF, MIDI y MP3 ya no exponen identificadores internos.
- Se elevó la ganancia del máster de exportación en **+10 dB**, con protección contra picos y clipping.
- Se reforzó la configuración de la ruta de audio para mejorar la reproducción por Bluetooth y evitar que el piano se pierda al cambiar de salida.
- Se mantuvo la compatibilidad con exportaciones MIDI y con los límites de uso de la versión gratuita.

## Visor de partituras

- El modo carrusel ahora navega por páginas individuales, no como un lienzo continuo.
- Cada página se ajusta completa dentro del visor al abrirse, reduciendo el zoom inicial y respetando los límites del PDF.
- Se corrigieron cambios de página con zoom, cambios de orientación y reposicionamiento del visor.
- Se añadió navegación tocando las zonas laterales de la pantalla.
- La flecha de avance aparece brevemente en el extremo derecho, centrada verticalmente, y se desvanece para no obstruir la lectura.
- Se limitaron caché y renderizado para reducir consumo de memoria y mejorar el rendimiento.

## Anotaciones

- Las anotaciones se guardan de forma persistente por canto y página.
- Se restauran aunque cambie la versión del PDF.
- Las anotaciones corruptas se ignoran sin impedir abrir el canto.
- El almacenamiento anterior se conserva mediante migración retroactiva.

## Temas y personalización

- Se añadió el switch **Oscuro OLED** en Ajustes.
- El modo oscuro normal usa la paleta azul grisácea definida para la aplicación.
- OLED, tema, navegación y color de resalte se guardan en almacenamiento persistente y se migran automáticamente desde instalaciones anteriores.
- Los colores de resalte se adaptan por tema ajustando saturación y luminosidad para conservar contraste y legibilidad.
- Se añadió el color café (`#8B5A2B`) a la paleta.
- El resalte personalizado también se aplica correctamente a los temas sepia, quiet y oscuro normal.

## Verificación

- Análisis de Dart sin errores.
- Suite de Flutter aprobada: **25 pruebas**.
- Artefacto Android generado en modo release mediante `flutter build appbundle --release`.

## Notas para Google Play Console (máximo 500 caracteres)

### Español

Mejoras en audio y exportaciones MP3 para WhatsApp, incluyendo mayor ganancia y compatibilidad Bluetooth. El visor de partituras ahora ofrece carrusel por páginas, navegación lateral, zoom ajustado y mejor rendimiento. Las anotaciones son persistentes y se migran automáticamente. Se añadieron modo oscuro OLED, oscuro normal, resaltes adaptativos y color café.

### English

Improved audio and MP3 exports for WhatsApp, with higher gain and better Bluetooth compatibility. The score viewer now supports page-by-page carousel navigation, side taps, fitted zoom and improved performance. Annotations persist across updates and migrate automatically. Added OLED dark mode, standard dark mode, adaptive accents and brown accent color.
