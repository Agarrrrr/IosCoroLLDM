# Piloto local de Verovio con letra y SATB

Fecha: 15 de octubre de 2026.

## Alcance

Aplicación Android independiente: `com.lldm.veroviopilot.coro_lldm`, nombre visible
«Coro · Prueba lector». Proyecto en `output/verovio_pilot`.

Incluye los primeros ocho compases de «Acércame a Ti» y «Al Gran Señor».
No representa la transcripción completa de los cantos ni habilita el lector en
el catálogo de producción. El código, los catálogos y los recursos de la app
principal permanecen sin cambios por este piloto.

## Procedencia y preparación

- Se usan los MusicXML y MIDI locales del usuario, no los archivos de la otra
  aplicación. `manifest.json` registra rutas y SHA-256 de ambos originales.
- «Acércame a Ti»: el editable original tiene cero letras. La primera estrofa
  del fragmento se transcribió manualmente de la página 1 del PDF de nuestra
  aplicación. Se incluyeron las entradas compartidas y las respuestas de las
  cuerdas. La colocación editorial debe revisarse musicalmente; no se declara
  una recuperación automática ni una transcripción definitiva.
- «Al Gran Señor»: se conserva la letra del MusicXML editable; en la copia se
  separa explícitamente el texto unido «granSe» como «gran Se». No se declara
  que cada palabra y sinalefa de esa fuente haya sido corregida contra el PDF.
- Las voces de la partitura cerrada se separan por coincidencia de posición
  musical y altura con las cuatro pistas MIDI. Los casos ambiguos detienen
  la preparación. No se asignan voces solamente por altura o número de pentagrama.
- Se generan dos presentaciones de los mismos eventos: cuatro pentagramas
  abiertos o dos pentagramas con dos voces cada uno. En cerrado se utilizan
  líneas de letra distintas para evitar superponer textos de ambas cuerdas.
- Se preservan los originales; los cambios están exclusivamente en copias.

## Lector y reproducción

- Verovio oficial 6.3.0, compilación `6.3.0-425dd7b`, JavaScript/WebAssembly
  incluido localmente. Distribución y licencia registradas en `assets/reader`.
- Reproducción con una copia del motor nativo de nuestra aplicación y Piano.sf2.
  El MIDI original se reproduce únicamente durante el fragmento de ocho compases.
- Los identificadores de las notas SVG se enlazan con los eventos MIDI usando
  voz, altura e inicio musical. Si falta una correspondencia, la reproducción
  del lector no queda habilitada.
- Controles: reproducción/pausa, inicio, posición, velocidades 1×/0.75×/0.5×,
  activar/desactivar cada cuerda, mantener pulsada una cuerda para escucharla
  sola, tocar una nota para situarse allí, tamaño de notación y abierto/cerrado.
- El cambio de distribución pausa la reproducción y conserva la posición.
- El motor, la música, la letra y el SoundFont están empaquetados. La página
  restringe conexiones externas con CSP; no utiliza CDN ni API de partituras.

## Validación anterior a la instalación

| Fragmento | Soprano | Alto | Tenor | Bajo | Total |
|---|---:|---:|---:|---:|---:|
| Acércame a Ti | 20 | 24 | 22 | 24 | 90 |
| Al Gran Señor | 46 | 53 | 29 | 32 | 160 |

Las cuatro variantes renderizadas conservan el 100 % de las correspondencias
de voz, altura e inicio del fragmento. Esta comprobación demuestra coherencia
entre nuestras fuentes XML/MIDI, no exactitud musical absoluta frente al PDF.

Dos pruebas del parser nativo verifican además que el orden real de sus cuatro
pistas coincide con el mapa utilizado por el lector. Ambas pasaron. El análisis
de Dart del piloto no detectó incidencias.

Evidencias: `output/verovio_pilot_support/manifest.json`,
`mapping-validation.json`, `render-report.json`, MEI/SVG renderizados y pruebas
en `output/verovio_pilot/test/score_mapping_test.dart`.

## Límites

- No se ha construido un proceso general de reconocimiento de PDF a MusicXML.
- No hay evaluación exhaustiva de letras, melismas, ortografía musical,
  repeticiones complejas, divisiones o repertorio completo.
- Se conserva el reproductor nativo; el piloto no modifica su planificación
  temporal ni demuestra una mejora de latencia del motor de audio.
- No incluye anotaciones ni su migración al formato que cambia de distribución.
- No se ha validado en iOS ni está preparado para publicar en tiendas.

## Comprobación en dispositivo

Instalado y abierto en Samsung SM-G986U (Android 13), identificado por ADB como
`R5CN30027WW`. La aplicación principal no se reemplaza.

- Se abrieron ambos fragmentos en abierto y cerrado; el motor notificó 90 y
  160 notas enlazadas, respectivamente, y 93/155 elementos de sílaba MEI.
- Se observó reproducción con seguimiento visual, aislamiento de una cuerda
  y cambio de distribución. Los registros también muestran navegación por nota.
  No constituye una evaluación acústica exhaustiva de las cuatro cuerdas.
- La revisión visual detectó exceso de tamaño/compresión de letra en la primera
  versión. Se redujo el tamaño y se aumentó el espacio entre palabras.
- El ajuste actual usa `lyricSize=3.6` y `lyricWordSpace=2.5`. Según el cálculo
  de Verovio, el espacio mínimo entre palabras equivale aproximadamente a
  1 sp: 2.5 × (3.6 / 4.5) = 2 unidades MEI = 1 espacio de pentagrama.
  Esta separación no inserta espacios entre los caracteres de una palabra.
  Los guiones y sinalefas conservan sus reglas de notación; no se declara que
  cada separación entre sílabas mida exactamente 1 sp.
- La APK instalada no declara permiso `android.permission.INTERNET`; la
  carga inicial de partitura y piano funcionó igualmente. El lector de esta
  prueba utiliza exclusivamente sus recursos empaquetados.
- Se detectó y corrigió un arranque intermitente: la notificación de inicio de
  WebAssembly podía producirse antes de cargar el código del lector. La
  inicialización ahora comprueba también la disponibilidad del motor e informa
  un error si no inicia, en lugar de mantener un indicador indefinido.
- La APK final pasó tres reaperturas completas, cada una con un proceso nuevo:
  2.157 s, 2.156 s y 1.531 s hasta recibir la preparación de la partitura.
  El trabajo interno de renderizado/enlace notificó 589, 530 y 566 ms.
  Estas cifras son de un fragmento pequeño y no son una medición de FPS.
- Pruebas específicas del arranque: inicialización anticipada, tardía, aviso
  duplicado y error por tiempo de espera; las cuatro pasaron.
- Se restauró a 0 la opción global de mantener la pantalla encendida por USB,
  utilizada temporalmente durante la revisión. La ventana del piloto mantiene
  la pantalla encendida mientras está visible.

Evidencias: `output/verovio_pilot_support/device/`, especialmente
`startup-check.json` y `permissions.txt`. La APK conservada es
`output/verovio_pilot_support/Coro-Prueba-Lector-0.1.0.apk`; su huella se registra
en `output/verovio_pilot_support/installed-apk.json`.

El piloto empezó el 15 de octubre y las comprobaciones finales del arranque
terminaron después de medianoche, el 16 de octubre de 2026.
