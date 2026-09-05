# Pipeline de previews de audio

Los MIDI fuente son privados. La web pública sirve únicamente previews de piano en Opus y AAC/M4A; cualquier archivo publicado puede descargarse, por lo que no se usa como mecanismo de protección.

## Flujo de publicación

1. Sincroniza el catálogo: `npm run sync:catalog`.
2. Renderiza previews de piano de hasta 1:30 con `npm run render:previews`. Para MIDI cifrado, define `MIDI_PREVIEW_KEY` en la sesión o en `.env.preview.local`.
3. Si ya existe Opus, genera solo el fallback Safari: `npm run transcode:previews`.
4. Publica el lote completo con `npm run upload:previews`, o solo AAC con `npm run upload:previews -- --format=aac --concurrency=4`.
5. Valida ambos formatos y el manifest publicado: `npm run validate:previews`.
6. Solo después despliega Pages. `preview-manifest.json` debe apuntar a archivos que ya existen en R2.

## Caché e invalidación

Los nombres de preview se derivan del contenido normalizado. Un render nuevo crea una URL distinta, de modo que la caché inmutable no sirve audio anterior. El manifest v2 relaciona cada MIDI con sus archivos Opus y AAC/M4A.

## Recuperación ante fallo

- Si el render falla, no publiques el manifest.
- Si falla una subida, vuelve a ejecutar la subida del formato afectado; el script falla cuando el lote queda incompleto.
- Si Safari no reproduce, verifica el M4A mediante `validate:previews` y realiza una prueba manual en Safari iOS antes de anunciar compatibilidad.
- Nunca subas `MIDI_PREVIEW_KEY`, MIDIs fuente ni `.env.preview.local`.
