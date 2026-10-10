# Reproductor: controles directos — 2026-10-09

## Cambios

- Eliminados el engranaje y el botón duplicado que abrían únicamente la velocidad.
- Velocidad visible dentro del reproductor: 0.50× a 2.00×, pasos de 0.05× y restablecimiento a 1.00×. Se mantiene el callback del motor que conserva la posición de reproducción.
- Mezcla de voces en una sección desplegable dentro del panel, cerrada inicialmente. Conserva activar/silenciar, volumen individual y restablecer mezcla.
- La acción Solo tiene un botón visible; sustituye el gesto oculto de pulsación prolongada.
- Los controles se deshabilitan durante la preparación del audio. El panel conserva desplazamiento para pantallas pequeñas y texto ampliado.
- Los extremos del rango de velocidad admiten espacio reducido sin desbordarse.

## Verificación

Pruebas del panel real a 320 × 640 dp con texto al 200 %: ausencia de engranaje, velocidad directa, restablecimiento, apertura de la mezcla, activación/silencio, volumen, Solo y restablecimiento de mezcla. Se conservan las pruebas de Ajustes, ofertas, cuotas, contraste y las optimizaciones previas incluidas en la publicación.

Registro local: `output/accessibility/player-direct-controls-test.log`.

Resultado: **193 pruebas aprobadas** en la regresión de reproductor, UX, cuotas, temas, anotaciones, cifrado compatible y renderizado diferido del PDF. El análisis del visor y su prueba no presenta errores ni advertencias; quedan avisos de deprecación anteriores de `withOpacity`.

La integración del audio nativo en dispositivos físicos no se ha probado en este paso. No se generó AAB ni se añadieron funciones nuevas al motor de audio.
