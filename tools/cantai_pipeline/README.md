# Cantai: preparación y revisión reutilizable

Herramienta local para los PDF/MIDI del catálogo y los archivos editables del respaldo. Los productos de trabajo quedan en `output/cantai_pipeline`; los MSCZ finales se entregan por separado a `E:/MusescoreCantai` después de la revisión. No modifica el catálogo ni los archivos fuente.

## Uso

Desde la raíz del repositorio, con el Python que contiene pdfplumber y cryptography:

```powershell
python tools/cantai_pipeline/cli.py enqueue 'Yo te seguiré' 'Rey Eterno'
python tools/cantai_pipeline/cli.py prepare
python tools/cantai_pipeline/cli.py status
python tools/cantai_pipeline/cli.py omr un_grande_honor
python tools/cantai_pipeline/cli.py audit-xml ruta/a/partitura.musicxml --report output/audit.json
python tools/cantai_pipeline/cli.py diff-midi original.mid synthesizer.mid --report output/diff.json
python -m unittest discover -s tools/cantai_pipeline -p test_pipeline.py
```

## Qué ahorra trabajo

- Búsqueda de títulos sin depender de acentos o mayúsculas; coincidencias dudosas quedan pendientes, no se eligen automáticamente.
- Índice persistente de MSCZ/MusicXML/MXL del respaldo. Un archivo editable es una fuente candidata, no una garantía de que contenga letra o dinámicas.
- Descifrado y preparación sólo cuando cambia el hash de la fuente. Cada canto conserva sus PDF, MIDI, texto y vistas previas.
- Caché comprimida de geometría vectorial: guarda exactamente los caracteres y trazos deduplicados, sin inferir notas. No intenta leer imágenes escaneadas como si fueran texto.
- Ejecución por etapas con huellas de entradas, argumentos y salidas. Reutiliza resultados verificados; vuelve a ejecutar si cambian las entradas o alguien altera una salida. Los registros completos van a disco, no a la conversación.
- Comparación de los ataques MIDI y localización de secciones con desplazamientos de tiempo. Las diferencias de articulación/ligadura se reportan y requieren interpretación musical; no se aceptan automáticamente.
- Segunda lectura de MusicXML mediante music21, independiente del lector propio, para cotejar nota, parte, compás, inicio y duración.
- Lectura de PDF de MuseScore con glifos SMuFL/Leland y pentagramas fragmentados, además de Opus. Las correcciones de detección y los cambios de clave siguen documentados en cada `config.json`.
- Protección de vocalizaciones y respuestas durante sus ligaduras: otra voz no puede introducir palabras dentro del melisma escrito. La letra compartida anterior a la respuesta se conserva.
- Desarrollo de pasajes indicados para una sola estrofa. Cada ataque omitido queda declarado en `verse-activity-review.json`; el comparador solamente acepta las omisiones expresamente documentadas.
- Separación de líneas de apoyo y divisi; conservación de finales situados dentro del compás y de sus anacrusas sin añadir silencios de relleno.
- Exportación para Synthesizer sin números de estrofa, con las palabras que comparten una nota unidas. La disposición de video conserva la letra impresa y su puntuación.
- Cobertura de todas las cabezas de nota detectadas: rechaza una asignación de voces que omita alguna, aunque el compás todavía cuadre. Respeta las plicas separadas y da prioridad a las respuestas escritas sobre la letra común.
- Adaptador de escaneos con correcciones explícitas revisadas contra el PDF. Guarda las diferencias reales con el MIDI, las sílabas por compás y las dinámicas verificadas en `raster-review.json`; no sustituye automáticamente lo impreso por lo que suena en el MIDI.
- Entrega con SHA-256 y comprobación previa de todos los archivos. Una corrección sólo reemplaza una entrega propia si sus bytes siguen iguales; las modificaciones del usuario se conservan y la copia anterior queda respaldada en el área de trabajo.

## Reconocimiento óptico

Audiveris sirve de propuesta para escaneos y como segunda lectura. Se usa una copia oficial 5.11.0 extraída dentro del proyecto, con perfil y modelos Tesseract locales. La ruta antigua `C:/Program Files/Audiveris` ya no estaba disponible. La herramienta intenta primero esa ruta y después la copia del proyecto. No envía PDF ni MIDI a servidores.

Un resultado OMR no se publica sin comprobar notas, ritmos, claves, letra, voces, dinámicas y repeticiones contra el PDF y el MIDI. homr es una alternativa investigada, aún no incorporada ni comparada en este lote. Sus mejoras recientes de voces múltiples son prometedoras, pero no prueban exactitud en estas partituras.

## Versiones y procedencia

- [Audiveris 5.11.0](https://github.com/Audiveris/audiveris/releases/tag/5.11.0), AGPL-3.0; metadatos y hash del instalador guardados en `output/cantai_pipeline/engines`.
- [music21](https://github.com/cuthbertLab/music21), 10.5.1 instalado con sus dependencias en `output/cantai_dependencies`; sólo se carga para la auditoría independiente.
- [Tesseract tessdata](https://github.com/tesseract-ocr/tessdata), inglés y español, modelos completos compatibles con el modo heredado requerido por Audiveris; URLs y hashes en `engines/tessdata/provenance.json`. Los modelos LSTM de tessdata_fast no son suficientes para ese modo.
- [homr](https://github.com/liebharc/homr) y su [mejora de voces múltiples](https://github.com/liebharc/homr/pull/156), consulta de investigación; no está instalado.
- [Verovio](https://book.verovio.org/toolkit-reference/input-formats.html), alternativa de representación investigada; MuseScore continúa siendo el motor para producir y volver a abrir los MSCZ.

No se promete un porcentaje de ahorro de tokens ni de exactitud sin medirlo. La caché y los informes compactos reducen lecturas, repeticiones y contexto innecesario; la revisión musical sigue siendo necesaria.

## Corrección del criterio de revisión (26 de octubre de 2026)

La comparación entre dos exportaciones del mismo modelo, la coincidencia de dos lectores de MusicXML y la cobertura de cabezas detectadas son comprobaciones técnicas. **No acreditan fidelidad al PDF**: pueden compartir un error de lectura o asignación. No deben describirse como revisión musical completa.

La corrección independiente del usuario de «Viene de Dios» se conserva en `output/cantai_audit_2026_10_26/viene_de_dios/`, con hashes y diferencias por compás. Reveló letra ausente, entradas y duraciones incorrectas, una alternativa de segunda vuelta interpretada como divisi y dinámicas con alcance incorrecto. Un `f` con la indicación «Alto y Tenor» no corresponde a soprano; tampoco se debe desplazar una marca al siguiente ataque de una voz que está en silencio.

`notation_geometry.py` distingue los ganchos por su plica y extremo real, y resuelve las plicas de notas desplazadas por intervalos de segunda. Las pruebas de regresión emplean coordenadas reales del PDF y la revisión del usuario. `audit_delivered_corpus.py` inventaría los archivos de destino y busca estos fallos; sus resultados son hallazgos para revisión, **no una certificación de todas las partituras**. Las revisiones y cambios posteriores del usuario se conservan.

Una reparación nativa aprobada se convierte en fuente autorizada para ese archivo. No regenerar después desde el modelo anterior sin integrar y volver a cotejar esa reparación: perdería los ajustes de letra y balance del usuario.
