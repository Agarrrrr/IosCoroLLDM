from pathlib import Path
import json,hashlib
out=Path('output/lldm_comunidad/2026-10-15');docs=Path('docs/revisiones/2026-10-15');docs.mkdir(parents=True,exist_ok=True)
comparison=json.loads((out/'comparison.json').read_text(encoding='utf-8'))
normalized=json.loads((out/'normalized_comparison.json').read_text(encoding='utf-8'))
report='''# Revisi\u00f3n de LLDM Comunidad \u2014 15 de octubre de 2026

## Alcance

Inspecci\u00f3n autorizada en el Samsung SM-G986U conectado. App en primer plano: com.jcht.community, versi\u00f3n 1.10.1, c\u00f3digo 49. Se examin\u00f3 el APK instalado, su cat\u00e1logo SQLite distribuido, los m\u00f3dulos JavaScript del lector y cuatro respuestas p\u00fablicas de MusicXML. Se abri\u00f3 el lector beta en el dispositivo para Ac\u00e9rcame a Ti y A-el-oid. No se accedi\u00f3 a archivos privados de sesi\u00f3n, no se extrajeron credenciales ni se eludi\u00f3 autenticaci\u00f3n. No se modific\u00f3 el repertorio propio.

## Conclusi\u00f3n sobre los MIDI

No se encontr\u00f3 evidencia suficiente para afirmar que esta aplicaci\u00f3n haya copiado nuestros archivos MIDI. El flujo espec\u00edfico del lector beta revisado no descarga un .mid ni carga nuestros recursos de audio: obtiene MusicXML, lo procesa con Verovio y reproduce notas mediante Web Audio.

Esto identifica el mecanismo de reproducci\u00f3n observado; no demuestra la procedencia hist\u00f3rica de sus PDF/MusicXML ni excluye cualquier uso pasado de archivos ajenos. Los metadatos se pueden modificar y no acreditan autor\u00eda, permiso o independencia por s\u00ed solos. No se tuvo acceso al backend ni a su historial de fuentes.

Los cuatro MusicXML indican Audiveris 5.11.0 y ProxyMusic 4.0.3, fecha de codificaci\u00f3n 2026-10-11 y referencia al PDF del canto. Es consistente con reconocimiento \u00f3ptico musical previo. Los tres MusicXML locales disponibles indican Sheet Music Scanner, fecha 2026-07-16. No son archivos XML id\u00e9nticos.

## Casos revisados

| Canto | ID de su cat\u00e1logo | Nuestro MIDI | Datos de su beta |
|---|---:|---|---|
| A \u00e9l O\u00edd / A-el-oid | 14 | Cuatro pistas; tempo 90 | MusicXML de Audiveris; tempo expl\u00edcito 80 |
| Acepto el Reto | 15 | Cuatro pistas; tempo 90 | MusicXML de Audiveris; tempo expl\u00edcito 90 |
| Ac\u00e9rcame a Ti | 16 | Cuatro pistas; tempo 90 | MusicXML de Audiveris; tempo expl\u00edcito 9, visible en pantalla |
| Adelante Juventud | 17 | Cuatro pistas; cambios de tempo y ritardando | MusicXML de Audiveris; sound con tempo 100 |

La diferencia 9/90 en Ac\u00e9rcame a Ti es observable tanto en la respuesta XML como en el lector. La partitura mostrada indica 90; los datos de la beta indican 9. No se evalu\u00f3 ac\u00fasticamente toda la reproducci\u00f3n.

## Comparaci\u00f3n de contenido

Se compararon eventos musicales de los tres MusicXML locales disponibles con los p\u00fablicos de la beta. Se normalizaron divisiones a fracciones de negra y se compararon parte, comp\u00e1s, posici\u00f3n, duraci\u00f3n y altura MIDI, ignorando metadatos y nombres. Se cuentan multiconjuntos de eventos, incluyendo notas simult\u00e1neas y sin desplegar repeticiones. Son medidas de coincidencia de arreglo, no probabilidades de copia ni dict\u00e1menes de autor\u00eda.

'''
for r in normalized:
 report+='- '+r['title']+': '+str(r['matchingPitchOnsetDurationMeasureEvents'])+' eventos coincidentes; '+str(r['localPitchedEvents'])+' eventos locales y '+str(r['remotePitchedEvents'])+' remotos. No son secuencias normalizadas id\u00e9nticas.\n'
report+='''
La gran coincidencia es compatible con el mismo arreglo y una fuente de partitura com\u00fan. No permite deducir qui\u00e9n obtuvo el archivo de qui\u00e9n. Nuestros MIDI de los tres cantos coinciden byte a byte con los originales locales de AudiosJulio; no se obtuvo un MIDI suyo para una comparaci\u00f3n de hashes de MIDI a MIDI, porque el flujo examinado no descarga ese formato.

Se descargaron sus PDF p\u00fablicos de A-el-oid, Acepto el Reto y Adelante Juventud. Ninguno coincide byte a byte con el PDF claro de la app propia; los suyos identifican Ghostscript como productor. Una recompresi\u00f3n cambia el hash y no excluye que compartan el mismo PDF de origen. La URL PDF declarada para Ac\u00e9rcame a Ti respondi\u00f3 404; no se intentaron variantes inventadas. La app s\u00ed muestra im\u00e1genes del documento ya descargado y su MusicXML p\u00fablico funciona.

## Desarrollo del lector beta

1. **Contenedor m\u00f3vil:** Capacitor, con interfaz Angular e Ionic en WebView. No se observ\u00f3 Flutter en el frontend inspeccionado.
2. **Cat\u00e1logo:** SQLite; tabla choir con ID, t\u00edtulo, nombre de archivo, p\u00e1ginas y favoritos.
3. **Partitura normal:** el servicio obtiene un manifiesto p\u00fablico y guarda p\u00e1ginas WebP mediante Capacitor Filesystem.
4. **Partitura interactiva:** descarga MusicXML desde /public/choir/{id}/score. La preparaci\u00f3n con Audiveris se infiere de los metadatos; no se inspeccion\u00f3 su proceso de backend.
5. **Grabado musical:** Verovio, cargado de forma diferida desde m\u00f3dulos JavaScript. Importa XML, lo convierte internamente a MEI y genera SVG. Recalcula el dise\u00f1o seg\u00fan ancho y tama\u00f1o elegido. No a\u00f1ade interacci\u00f3n sobre los p\u00edxeles del PDF original.
6. **Modelo temporal:** renderToTimemap y getMIDIValuesForElement producen identificadores, alturas, posiciones y duraciones por nota.
7. **Audio:** implementaci\u00f3n Web Audio propia: AudioContext, osciladores de onda triangular, envolvente de ganancia y filtro de paso bajo. No se encontr\u00f3 un SoundFont de piano en este flujo.
8. **Sincronizaci\u00f3n visual:** requestAnimationFrame actualiza notas activas; a\u00f1ade clase playing a elementos SVG y desplaza el sistema musical activo al centro.
9. **Interacci\u00f3n:** tocar una nota inicia desde esa posici\u00f3n; silenciar voz con toque y escuchar solo una con pulsaci\u00f3n larga. Tempo entre 50\u2013150 %, transposici\u00f3n de -6 a +6 semitonos y cinco escalas de presentaci\u00f3n.
10. **Offline:** existe almacenamiento expl\u00edcito de im\u00e1genes WebP. No se encontr\u00f3 en este servicio un almacenamiento persistente equivalente para el MusicXML; solicita el XML por HTTP al abrir. No se hizo una prueba completa sin red.

## Limitaci\u00f3n de la separaci\u00f3n SATB

El m\u00e9todo tagVoices asigna voces por n\u00famero de pentagrama y capa. Para dos pentagramas, alterna S/A y T/B seg\u00fan n\u00famero de capa. No separa por an\u00e1lisis mel\u00f3dico las dos notas de un acorde que comparten capa.

En A-el-oid, las voces de MusicXML se distribuyen en P1: 205 notas en voz 1 y 3 en voz 2; P2: 192 y 3. En Acepto el Reto: P1 492 y 4; P2 476 y 4. Incluyen acordes con varias notas en la misma voz. Esto muestra que cuatro botones SATB no acreditan cuatro l\u00edneas vocales completas. El s\u00edntoma final de cada aislamiento necesita una comprobaci\u00f3n de reproducci\u00f3n por cuerda; no se presenta aqu\u00ed como escucha exhaustiva.

## Evidencia conservada

- APK instalado: SHA256 '''+hashlib.sha256((out/'base.apk').read_bytes()).hexdigest()+'''
- C\u00f3digo relevante dentro del APK: assets/public/chunk-XDM42UEE.js (lector y audio); chunk-ITASOHPQ.js (servicio); chunk-3AAFBXG4.js (interfaz Verovio); chunk-KKD64UQJ.js (motor).
- Datos y capturas: output/lldm_comunidad/2026-10-15/.
- Se conservan hashes de los XML y de los PDF accesibles. No se publican datos privados del desarrollador incrustados en las rutas fuente de los XML.
- Las inspecciones de fuentes son de solo lectura y no se incorpor\u00f3 c\u00f3digo de terceros a la aplicaci\u00f3n propia.

## Fuentes p\u00fablicas

- https://www.lldm-comunidad.com/public/choir/14/score
- https://www.lldm-comunidad.com/public/choir/15/score
- https://www.lldm-comunidad.com/public/choir/16/score
- https://www.lldm-comunidad.com/public/choir/17/score
- https://book.verovio.org/toolkit-reference/toolkit-methods.html
- https://audiveris.github.io/audiveris/

La documentaci\u00f3n oficial confirma las capacidades de las herramientas; las afirmaciones sobre esta aplicaci\u00f3n se basan en el c\u00f3digo y los datos instalados/servidos inspeccionados.
'''
(docs/'LLDM_COMUNIDAD_LECTOR_Y_PROCEDENCIA.md').write_text(report,encoding='utf-8',newline='\n')
(docs/'comparacion_cantos.json').write_text(json.dumps({'pdfAndMidiHashes':comparison,'normalizedXmlComparison':normalized},ensure_ascii=False,indent=2),encoding='utf-8')
print(str((docs/'LLDM_COMUNIDAD_LECTOR_Y_PROCEDENCIA.md').resolve()))
