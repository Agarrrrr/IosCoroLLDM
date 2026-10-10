# Auditoría de integridad y apertura offline — 10 de octubre de 2026

## Estado

La verificación local, del paquete Android y del Android físico terminó. **Los 2.108 archivos abrieron con los motores de la aplicación en el Samsung probado.** Hay una incidencia de apertura offline desde el catálogo: Pecador intenta acceder a internet. Además, la inspección estructural detectó dos flujos comprimidos truncados en Maravillosa Gracia, aunque el motor nativo renderizó ambas páginas. iOS no fue probado; no se certifica integridad absoluta ni comportamiento en todos los dispositivos.

Esta auditoría conserva los catálogos y archivos originales. No se reasignaron obras ni audios, no se eliminaron recursos y no se hizo push a GitHub. El informe original de rendimiento permanece intacto.

## Cobertura y resultados

| Comprobación | Resultado |
| --- | --- |
| Canciones de los dos catálogos | 1.651: 1.343 español y 308 inglés |
| Archivos PDF físicos | 1.664, incluidos los cifrados |
| Páginas renderizadas con Poppler | 4.454; todas produjeron imagen, ninguna completamente blanca |
| Archivos MIDI físicos | 444, incluidos los cifrados |
| Descifrado y autenticación de recursos | 2.108 archivos correctos |
| MIDI: estructura SMF, eventos, pistas y datos musicales | 444 correctos; también procesados por el parser de la aplicación |
| Rutas PDF de la aplicación con caché vacía y HTTP bloqueado | 1.650 correctas; 1 intenta acceder a internet |
| Rutas MIDI de la aplicación con caché vacía y HTTP bloqueado | 644 correctas; 1.007 canciones sin MIDI declarado o heredado |
| Referencias MIDI directas | 631 canciones, 413 archivos distintos; otros 13 cantos heredan audio mediante el vínculo bilingüe existente |
| Archivos locales ausentes respecto de las referencias locales | 0 |
| APK: archivos PDF/MIDI, ambos catálogos y Piano.sf2 | 2.111 recursos coinciden exactamente con sus originales; CRC ZIP correcto |
| SoundFont | Cabecera RIFF/sfbk y longitud correctas |
| Flujos PDF FlateDecode revisados | 34.209; dos truncados en un único PDF |
| IDs de catálogo duplicados | 0 |
| Android físico: PDFium/pdfrx | 1.664 PDF abiertos; 4.454 páginas renderizadas |
| Android físico: MidiEngine y SoundFont local | 444 MIDI cargados, con voces y duración positivas |
| Android físico: rutas del catálogo con HTTP bloqueado | 1.650 PDF y 644 MIDI correctos; una incidencia PDF |

Los 1.007 cantos sin audio declarado no representan MIDI corruptos o extraviados: esta auditoría no permite concluir que deban tener audio. Hay 45 recursos físicos sin referencia directa: 14 PDF y 31 MIDI. Se conservaron; uno de esos PDF es la copia local de Pecador.

## Hallazgo 1: Pecador, Ven al Dulce Jesús depende de internet

- ID: `c35b5fd9-8d99-445f-89e3-21dd998a3e92`.
- El catálogo apunta a una URL de Supabase para el PDF.
- Existe una copia local válida: `assets/offline_assets/pdfs/pecador-ven-al-dulce-jesus-1777250932709.pdf`.
- `OfflineFiles.ensurePdf` no utiliza el recurso empaquetado cuando la referencia comienza por `http`.
- En la prueba con caché vacía, esa ruta intentó usar HTTP y falló al estar bloqueado. Su MIDI sí abrió offline.

**Impacto:** una instalación nueva sin internet no puede abrir esa partitura mediante la ruta actual. Una copia previamente almacenada puede ocultar el problema.

**Corrección propuesta:** sustituir únicamente la referencia remota por la ruta local verificada, manteniendo ID, obra y audio; repetir la prueba sin red. No aplicada en esta auditoría.

## Hallazgo 2: Maravillosa Gracia tiene dos flujos PDF truncados

- Archivo: `assets/offline_assets/pdfs/maravillosa-gracia-1782161328444.pdf`.
- Dos páginas; objetos 47 y 49 de `/Contents` en la segunda página fallan al descomprimir con zlib.
- Poppler informa errores de cabecera de bloque Flate en esos mismos datos.
- Ambas páginas se renderizaron con Poppler y con PDFium/pdfrx en el Android físico; la revisión visual mostró música y letra legibles.

**Impacto:** defecto estructural confirmado, pero no se ha demostrado pérdida visible de notas o texto. Que un motor recupere la página no convierte el archivo en íntegro.

**Corrección propuesta:** recuperar o exportar nuevamente desde la fuente y comparar ambas páginas antes de sustituir el PDF. No se reparó ni alteró el original.

## Avisos de compatibilidad PDF

915 PDF generaron algún aviso de Poppler, entre ellos acciones de página, fuentes, grupos de contenido opcional y referencias XObject desconocidas. 317 incluyen avisos de XObject desconocido. **No equivalen a 915 archivos que no abren.** Todos renderizaron sus páginas. La muestra visual de `I Praise the Omnipotent God`, que presenta ese aviso, resultó legible; esto no valida visualmente todos los demás archivos.

Los avisos completos quedan por archivo en el JSON. La revisión de todos los flujos comprimidos identificó solamente el defecto de Maravillosa Gracia descrito arriba. La equivalencia musical con las fuentes originales no puede establecerse mediante hashes o renderizado: requiere comparar con dichas fuentes.

## Método y límites

1. Inventario de ambos catálogos, vínculos bilingües existentes y todos los archivos de las carpetas offline.
2. Carga mediante `rootBundle`, descifrado con `FileCrypto` y comparación SHA-256 de los archivos extraídos por la ruta real de la aplicación.
3. Caché de prueba vacía; `HttpOverrides` rechaza toda creación de cliente HTTP. Se prueba cada ruta PDF y MIDI independientemente, incluso si falla la otra.
4. Lectura PDF con pypdf, acceso a contenidos de todas las páginas y renderizado Poppler de cada página a 256 px. La resolución detecta fallos generales, no certifica cada símbolo musical.
5. Comprobación adicional de todos los flujos FlateDecode con zlib y revisión visual de muestras seleccionadas.
6. Validación estricta SMF y apertura por `NativeMidiParser`. No equivale a escuchar cada voz o certificar su asignación musical.
7. Verificación ZIP y hashes de los recursos dentro del APK debug; esto no certifica un IPA ni un AAB diferente.

La prueba automatizada de rutas terminó con error esperado porque exige cero intentos de red y encontró uno: Pecador. El fallo no invalida las otras 1.650 aperturas PDF y 644 MIDI registradas.

### Prueba física completada

Dispositivo: Samsung SM_G986U, Android 13, serial R5CN30027WW. La aplicación de auditoría usa el paquete separado `com.lldm.coro.perfaudit` para preservar la aplicación y datos del usuario. El primer intento no produjo resultados de recursos mientras el móvil estaba con pantalla apagada. El dispositivo se reconectó y se recuperó el JSON de la ejecución completada del 10 de octubre de 2026.

Resultado: 2.108 recursos con estado `ok`, 4.454 páginas renderizadas y 444 MIDI cargados mediante MidiEngine. Las 1.651 rutas de cantos se comprobaron con HTTP bloqueado y caché vacía por recurso. Se registró un solo intento de red y una sola incidencia: el PDF de Pecador. Su MIDI abrió correctamente. Los hashes de los archivos extraídos se compararon con los recursos que ya habían abierto mediante los motores nativos.

El motor nativo recuperó correctamente las dos páginas de Maravillosa Gracia. Esto confirma apertura en este dispositivo, pero no elimina el defecto estructural identificado por zlib. La pantalla indica una incidencia porque cuenta fallos de apertura/rutas, no avisos de estructura de archivos. No se ha validado iOS, reproducción audible completa, exportación de cada voz ni fidelidad musical de cada archivo.

## Evidencias

- [Resultado del Android físico](../output/offline_integrity/2026-10-10/offline-integrity-device.json)
- [Rutas reales, hashes y MIDI](../output/offline_integrity/2026-10-10/bundle-and-midi.json)
- [Archivos, páginas, avisos y paquete](../output/offline_integrity/2026-10-10/deep-files-and-apk.json)
- [Flujos comprimidos de todos los PDF](../output/offline_integrity/2026-10-10/all-pdf-streams.json)
- [Reverificación del último APK de auditoría](../output/offline_integrity/2026-10-10/latest-audit-apk.json)
- [Inspección de los PDF con avisos](../output/offline_integrity/2026-10-10/warning-stream-inspection.json)
- [Prueba local](../test/offline_integrity_audit_test.dart)
- [Prueba física preparada](../integration_test/offline_integrity_device_test.dart)

Las imágenes de muestra están en `output/offline_integrity/2026-10-10/previews/`. No se guardaron copias de PDF descifradas como parte de la inspección.
