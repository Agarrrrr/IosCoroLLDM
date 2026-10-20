# Revisión de LLDM Comunidad — 15 de octubre de 2026

## Alcance

Inspección autorizada en el Samsung SM-G986U conectado. App en primer plano: com.jcht.community, versión 1.10.1, código 49. Se examinó el APK instalado, su catálogo SQLite distribuido, los módulos JavaScript del lector y cuatro respuestas públicas de MusicXML. Se abrió el lector beta en el dispositivo para Acércame a Ti y A-el-oid. No se accedió a archivos privados de sesión, no se extrajeron credenciales ni se eludió autenticación. No se modificó el repertorio propio.

## Conclusión sobre los MIDI

No se encontró evidencia suficiente para afirmar que esta aplicación haya copiado nuestros archivos MIDI. El flujo específico del lector beta revisado no descarga un .mid ni carga nuestros recursos de audio: obtiene MusicXML, lo procesa con Verovio y reproduce notas mediante Web Audio.

Esto identifica el mecanismo de reproducción observado; no demuestra la procedencia histórica de sus PDF/MusicXML ni excluye cualquier uso pasado de archivos ajenos. Los metadatos se pueden modificar y no acreditan autoría, permiso o independencia por sí solos. No se tuvo acceso al backend ni a su historial de fuentes.

Los cuatro MusicXML indican Audiveris 5.11.0 y ProxyMusic 4.0.3, fecha de codificación 2026-10-11 y referencia al PDF del canto. Es consistente con reconocimiento óptico musical previo. Los tres MusicXML locales disponibles indican Sheet Music Scanner, fecha 2026-07-16. No son archivos XML idénticos.

## Casos revisados

| Canto | ID de su catálogo | Nuestro MIDI | Datos de su beta |
|---|---:|---|---|
| A él Oíd / A-el-oid | 14 | Cuatro pistas; tempo 90 | MusicXML de Audiveris; tempo explícito 80 |
| Acepto el Reto | 15 | Cuatro pistas; tempo 90 | MusicXML de Audiveris; tempo explícito 90 |
| Acércame a Ti | 16 | Cuatro pistas; tempo 90 | MusicXML de Audiveris; tempo explícito 9, visible en pantalla |
| Adelante Juventud | 17 | Cuatro pistas; cambios de tempo y ritardando | MusicXML de Audiveris; sound con tempo 100 |

La diferencia 9/90 en Acércame a Ti es observable tanto en la respuesta XML como en el lector. La partitura mostrada indica 90; los datos de la beta indican 9. No se evaluó acústicamente toda la reproducción.

## Comparación de contenido

Se compararon eventos musicales de los tres MusicXML locales disponibles con los públicos de la beta. Se normalizaron divisiones a fracciones de negra y se compararon parte, compás, posición, duración y altura MIDI, ignorando metadatos y nombres. Se cuentan multiconjuntos de eventos, incluyendo notas simultáneas y sin desplegar repeticiones. Son medidas de coincidencia de arreglo, no probabilidades de copia ni dictámenes de autoría.

- Acepto el Reto: 969 eventos coincidentes; 976 eventos locales y 976 remotos. No son secuencias normalizadas idénticas.
- Acércame a ti: 391 eventos coincidentes; 405 eventos locales y 403 remotos. No son secuencias normalizadas idénticas.
- Adelante Juventud: 937 eventos coincidentes; 945 eventos locales y 942 remotos. No son secuencias normalizadas idénticas.

La gran coincidencia es compatible con el mismo arreglo y una fuente de partitura común. No permite deducir quién obtuvo el archivo de quién. Nuestros MIDI de los tres cantos coinciden byte a byte con los originales locales de AudiosJulio; no se obtuvo un MIDI suyo para una comparación de hashes de MIDI a MIDI, porque el flujo examinado no descarga ese formato.

Se descargaron sus PDF públicos de A-el-oid, Acepto el Reto y Adelante Juventud. Ninguno coincide byte a byte con el PDF claro de la app propia; los suyos identifican Ghostscript como productor. Una recompresión cambia el hash y no excluye que compartan el mismo PDF de origen. La URL PDF declarada para Acércame a Ti respondió 404; no se intentaron variantes inventadas. La app sí muestra imágenes del documento ya descargado y su MusicXML público funciona.

## Desarrollo del lector beta

1. **Contenedor móvil:** Capacitor, con interfaz Angular e Ionic en WebView. No se observó Flutter en el frontend inspeccionado.
2. **Catálogo:** SQLite; tabla choir con ID, título, nombre de archivo, páginas y favoritos.
3. **Partitura normal:** el servicio obtiene un manifiesto público y guarda páginas WebP mediante Capacitor Filesystem.
4. **Partitura interactiva:** descarga MusicXML desde /public/choir/{id}/score. La preparación con Audiveris se infiere de los metadatos; no se inspeccionó su proceso de backend.
5. **Grabado musical:** Verovio, cargado de forma diferida desde módulos JavaScript. Importa XML, lo convierte internamente a MEI y genera SVG. Recalcula el diseño según ancho y tamaño elegido. No añade interacción sobre los píxeles del PDF original.
6. **Modelo temporal:** renderToTimemap y getMIDIValuesForElement producen identificadores, alturas, posiciones y duraciones por nota.
7. **Audio:** implementación Web Audio propia: AudioContext, osciladores de onda triangular, envolvente de ganancia y filtro de paso bajo. No se encontró un SoundFont de piano en este flujo.
8. **Sincronización visual:** requestAnimationFrame actualiza notas activas; añade clase playing a elementos SVG y desplaza el sistema musical activo al centro.
9. **Interacción:** tocar una nota inicia desde esa posición; silenciar voz con toque y escuchar solo una con pulsación larga. Tempo entre 50–150 %, transposición de -6 a +6 semitonos y cinco escalas de presentación.
10. **Offline:** existe almacenamiento explícito de imágenes WebP. No se encontró en este servicio un almacenamiento persistente equivalente para el MusicXML; solicita el XML por HTTP al abrir. No se hizo una prueba completa sin red.

## Limitación de la separación SATB

El método tagVoices asigna voces por número de pentagrama y capa. Para dos pentagramas, alterna S/A y T/B según número de capa. No separa por análisis melódico las dos notas de un acorde que comparten capa.

En A-el-oid, las voces de MusicXML se distribuyen en P1: 205 notas en voz 1 y 3 en voz 2; P2: 192 y 3. En Acepto el Reto: P1 492 y 4; P2 476 y 4. Incluyen acordes con varias notas en la misma voz. Esto muestra que cuatro botones SATB no acreditan cuatro líneas vocales completas. El síntoma final de cada aislamiento necesita una comprobación de reproducción por cuerda; no se presenta aquí como escucha exhaustiva.

## Evidencia conservada

- APK instalado: SHA256 0b86018336d7108443d36529be8a60b979af8c078d6e1601cd0d103347d85a3e
- Código relevante dentro del APK: assets/public/chunk-XDM42UEE.js (lector y audio); chunk-ITASOHPQ.js (servicio); chunk-3AAFBXG4.js (interfaz Verovio); chunk-KKD64UQJ.js (motor).
- Datos y capturas: output/lldm_comunidad/2026-10-15/.
- Se conservan hashes de los XML y de los PDF accesibles. No se publican datos privados del desarrollador incrustados en las rutas fuente de los XML.
- Las inspecciones de fuentes son de solo lectura y no se incorporó código de terceros a la aplicación propia.

## Fuentes públicas

- https://www.lldm-comunidad.com/public/choir/14/score
- https://www.lldm-comunidad.com/public/choir/15/score
- https://www.lldm-comunidad.com/public/choir/16/score
- https://www.lldm-comunidad.com/public/choir/17/score
- https://book.verovio.org/toolkit-reference/toolkit-methods.html
- https://audiveris.github.io/audiveris/

La documentación oficial confirma las capacidades de las herramientas; las afirmaciones sobre esta aplicación se basan en el código y los datos instalados/servidos inspeccionados.
