# Integración inicial Flutter nativa y reproductor de la aplicación

Seguimiento del 17 de octubre de 2026. No sustituye ni modifica los informes previos. El informe de partituras completas describe la versión anterior con WebView; este documento registra su sustitución.

## Qué cambió

- Se elimina la WebView de la instalación de prueba. Verovio se ejecuta como biblioteca C++ mediante FFI, con un worker isolate. La interfaz, el dibujo vectorial, el cursor y las interacciones se realizan en Flutter.
- `verovio_flutter` 0.3.3 aporta la biblioteca nativa. `jovial_svg` 1.1.29 pinta los vectores y el texto en Flutter. No se ejecutan HTML, JavaScript ni WASM en esta ruta.
- Se extrae el `MidiPanel` existente de `visor_screen.dart` a `features/visor/widgets/midi_panel.dart`, conservando su cuerpo y auxiliares. El visor principal importa ese mismo componente y mantiene su exportación pública para los consumidores existentes.
- El nuevo lector utiliza ese panel: mezclador y velocidad en los laterales del botón de reproducción, progreso y tiempos, metrónomo, volúmenes, Solo, reinicio de mezcla y cierre por gesto.
- La implementación del lector queda en `lib/features/interactive_score/`. Se instala mediante el proyecto separado de prueba 0.3.0+3. **Todavía no hay una ruta de catálogo publicada ni conversión del repertorio entero.** Los tres recursos de prueba siguen en el paquete independiente; no se añadieron MIDI descifrados de prueba al paquete principal.

## Prolongaciones: fallos reales y correcciones

La validación anterior de 24 prolongaciones no cubría todos los arcos de la fuente. Se encontraron **cinco prolongaciones adicionales de Tenor en Al Gran Señor**: llegada al compás 3 y pasajes de los compases 80, 81, 84 y 85 del editable. Estaban codificadas como fraseo, aunque unen notas consecutivas de igual altura sin una nueva sílaba ni un silencio intermedio.

El plan actual cubre **29 ocurrencias**: 12 de Acércame, 13 de Al Gran Señor y 4 de Ven a la Cena. En Al Gran Señor se suprimen nueve ataques de continuación: cuatro del cierre ya identificados y estos cinco adicionales. Las demás prolongaciones ya correspondían a un solo ataque del MIDI.

Reglas del audio preparado:

1. Misma voz y altura; la prolongación extiende la duración del ataque inicial.
2. Una cadena de tres o más notas ligadas conserva un solo ataque.
3. Se conservan las repeticiones de altura sin ligadura y los arcos de fraseo que recorren otras notas.
4. No se reescribe el MIDI original. La preparación se aplica a la canción parseada antes de programar el audio del lector.

También se corrigió un fallo independiente del motor: los apagados de notas usaban temporizadores calculados con la velocidad vigente al comenzar la nota. Cambiar a 0,5× durante una nota larga podía cortarla antes de tiempo. Ahora una cola de duraciones libera las notas según el **reloj musical**, que ya incorpora los cambios de velocidad. No crea un temporizador por nota. Pausar, detener o buscar vacía la cola; al reanudar dentro de una nota se recupera únicamente su duración restante.

Se restablece el contador de emisión de progreso cuando cambia la velocidad; reiniciar el cronómetro sin restablecer ese contador podía congelar temporalmente el progreso visible. Tras un retraso del hilo no se disparan notas cuyo intervalo ya terminó.

## Gráficos y rendimiento

- Composición, exportación SVG y cálculo de geometría en el worker nativo; transformaciones XML/SVG mediante `compute`.
- Páginas bajo demanda y caché por documento. El cursor es un `CustomPainter` con su propio repintado y un reloj interpolado; no modifica SVG ni reconstruye el lector en cada cuadro.
- El panel escucha el estado de audio por separado.
- Cambiar la máscara de voces procesa el dibujo una sola vez y descarta resultados antiguos antes de compilar el vector en Flutter. Se atenúan barras, silencios, alteraciones particulares y arcos asociados a voces silenciadas; las armaduras y letras comunes siguen visibles.
- Se normaliza el SVG de Verovio: viewport anidado convertido a transformación de grupo, estilos de plicas y líneas materializados como atributos. Es necesario porque no hay un DOM/CSS de navegador.
- La tipografía del texto de partitura se empaqueta localmente como `ScoreText`/Noto Serif. La elisión lírica privada SMuFL se representa con su carácter de texto equivalente U+203F, presente en la fuente empaquetada. No debe confundirse con la ligadura musical, que conserva su curva vectorial.
- Se empaqueta Inter para que el reproductor de prueba utilice su tipografía sin descargas.

### Observaciones en Samsung SM-G986U / Android 13

Compilación release ARM64, recursos ya preparados:

- Acércame: aperturas observadas de 571–628 ms hasta preparar primera página y audio, seis páginas con el tamaño del móvil.
- Compilación vectorial en el hilo Flutter de las páginas observadas: aproximadamente 9–17 ms. Sigue existiendo trabajo síncrono al mostrar una página nueva.
- Muestra de reproducción y uso del mezclador: **8.028 cuadros registrados, 29 con construcción o rasterizado por encima de 16,667 ms** (aproximadamente 0,36 %).
- En los lotes observados, P95 de rasterizado llegó a superar el presupuesto durante interacciones. **Quedan picos y no se garantiza 120 FPS ni ausencia de tirones.** Esta medición tampoco sustituye una comparación controlada contra la implementación anterior.

Datos: `output/verovio_pilot_support/complete/native-performance.json`. Capturas y registros `native-*` en la carpeta de evidencias del dispositivo. Los primeros registros de esta iteración incluyen errores de adaptación gráfica intermedios; las capturas finales se identifican por su nombre de entrega.

El APK nativo de prueba ronda 65 MB frente a unos 45 MB de la prueba anterior: incorpora biblioteca nativa, recursos musicales y fuentes. El peso del paquete aún requiere una revisión antes de incorporarlo a una distribución comercial.

## Comprobaciones

- Once pruebas del prototipo: correspondencia de los tres MIDI, prolongaciones completas, cadena de tres notas, conservación de una repetición sin ligadura, duraciones al variar velocidad, independencia de voces, limpieza al buscar/pausar y atenuado de elementos SVG.
- Seis pruebas existentes de la aplicación principal: cierre del reproductor, contraste sepia y movimiento del metrónomo. Pasaron tras extraer el componente compartido.
- Análisis estático de la ruta nativa y los componentes modificados sin incidencias; compilación release e instalación separada en el Android conectado.
- La revisión visual incluye pentagramas y letras nativos, reproducción/cursor, apertura del mezclador real y Solo. No es una escucha certificada de todas las voces de principio a fin.

## Límites que permanecen

- Las diferencias entre PDF, editable y MIDI de Al Gran Señor siguen documentadas: cierre distinto y una altura de Tenor. Esta integración no las resuelve ni sustituye originales.
- Ven a la Cena mantiene las variantes rítmicas PDF/MIDI descritas en el informe anterior.
- Faltan validación iOS, exposición definitiva desde el catálogo, diseño de temas y una campaña de rendimiento repetible sobre más dispositivos.
- No se hizo push ni se modificaron los catálogos ni los PDF/MIDI originales.

## Diferencia de audio advertida por el usuario

El usuario comparaba la prueba Android con la aplicación de iPhone. Se verificó:

- El SoundFont de la prueba coincide byte por byte con `assets/Piano.sf2` de la aplicación: SHA-256 `e3027675f97639e0bb92d7fbb8b0714c9dc6e96d839d28050713a0fae807c9ac`.
- Las bibliotecas FluidSynth de la app Android instalada y de la prueba coinciden. Las secciones de código, constantes y símbolos del puente nativo también coinciden; no falta una biblioteca de efectos distinta en la prueba.
- En iOS, el plugin usa AVAudioEngine con ecualizador y reverberación. El valor de ganancia termina limitado a +12 dB por el backend.
- En Android, el plugin usa FluidSynth, sí aplica reverberación, pero `setEqualizer` es una operación sin efecto. **No existe equivalencia de timbre entre ambas plataformas por reutilizar el mismo código Dart.**
- La ganancia enviada anteriormente a FluidSynth era aproximadamente 5,342, mientras todas las notas se disparaban a velocidad 96. La normalización de velocidad no es un compresor de señal.
- Se conserva la configuración de iOS y se cambia únicamente la ganancia Android a 0,80 para quitar la sobre-amplificación (aproximadamente 16,5 dB menos que antes). Es un ajuste de margen de salida; **no es un nuevo compresor ni una certificación de ausencia de clipping**.
- Quedan pendientes implementar/verificar el ecualizador equivalente en Android y comparar auditivamente el resultado con iPhone. No se ha medido el pico PCM de la salida física del móvil.

Referencias técnicas: [plugin nativo y API del proveedor](https://pub.dev/packages/verovio_flutter), [pintor SVG con texto en Flutter](https://pub.dev/packages/jovial_svg), [opciones oficiales de Verovio](https://book.verovio.org/toolkit-reference/toolkit-options.html).
