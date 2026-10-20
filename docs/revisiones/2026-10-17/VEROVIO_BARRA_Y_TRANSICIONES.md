# Seguimiento: barra de reproducción y transiciones

Actualización del piloto nativo 0.3.1+4. Conserva los informes anteriores.

## Problemas encontrados

- La barra extrapolaba una posición recibida cada 50 ms y reiniciaba esa extrapolación con cualquier notificación del reproductor, incluidas las del mezclador. Esto podía provocar correcciones visuales innecesarias.
- El último ataque de un sistema quedaba inmóvil hasta comenzar el siguiente.
- La compilación del SVG ocurría al crear la página visible. El vector compilado se perdía al destruir ese widget.
- El cambio de página reconstruía toda la pantalla y sus geometrías de seguimiento. Una búsqueda lejana animaba el recorrido por páginas intermedias.

## Cambios

- La barra consulta en cada vsync la posición musical del mismo reloj que utiliza el planificador MIDI. No depende de las notificaciones de progreso para moverse ni vuelve a anclarse al cambiar un control del mezclador.
- Interpolación entre ataques y recorrido del último tiempo hasta el extremo del sistema. El cambio al siguiente pentagrama ocurre en su inicio musical; no se dibuja una trayectoria diagonal entre sistemas.
- Caché de seis vectores compilados, compartida por las páginas; preparación anticipada de la página siguiente y preparación del destino antes de animar.
- Caché de la relación nota/página para evitar consultas nativas repetidas.
- Geometría del cursor calculada al cargar la página. Indicador de página actualizado de forma local.
- Las búsquedas a páginas no contiguas saltan directamente al destino.

## Verificación de código

- Análisis estático sin incidencias en lector y motor MIDI.
- Tres pruebas específicas: interpolación a 60 pasos por segundo, final del sistema y entrega al siguiente, búsqueda hacia atrás.
- Once pruebas existentes de ligaduras, duración de notas, correspondencia musical y estilos de voces aprobadas.

## Límites

La compilación de vectores sigue utilizando el isolate de UI; anticiparla y conservarla reduce el trabajo durante una transición, pero no garantiza ausencia de cuadros lentos en todos los dispositivos. La sincronización sigue el reloj del planificador MIDI, no una medición del sonido que llega físicamente al altavoz. Se mantiene pendiente la validación en iOS y otros equipos.

## Dispositivo real

- Instalado el piloto 0.3.1+4 en Samsung SM-G986U, Android 13.
- Reproducción de Acércame a Ti con seguimiento por varios sistemas y páginas; después Al Gran Señor con cambios frecuentes de página. Capturas, grabaciones y log de la sesión en `output/verovio_pilot_support/device/native-smooth*`.
- En Al Gran Señor, las páginas 2 a 11 se compilaron en 6–11 ms y no se registraron cuadros por encima de 16,667 ms en los lotes posteriores a su preparación inicial. Acércame registró algunos cuadros lentos aislados; no se afirma que todo el recorrido esté libre de tirones.
- El indicador `over16ms` compara el máximo de construcción y rasterización por cuadro; no equivale a una medición del audio ni a certificar FPS sostenidos. Los lotes no incluyen el remanente inferior a 120 cuadros.
- Resumen numérico conservado en `output/verovio_pilot_support/complete/native-smooth-performance.json`.
