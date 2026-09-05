# Coro LLDM — sitio promocional

Sitio web React independiente para presentar Coro LLDM, su catálogo, demos, repertorio BC y servicios de desarrollo de aplicaciones a medida para coros.

## Desarrollo local

```bash
npm install
npm run dev
```

El servidor local ejecuta `sync:catalog` antes de iniciar y sincroniza los catálogos desde `../assets/catalogo.json` y `../assets/catalogo_en.json`.

La convención de rutas, idioma y fuentes de contenido está documentada en [docs/architecture/navigation-and-content.md](docs/architecture/navigation-and-content.md).
El proceso de generación y publicación de previews está documentado en [docs/audio-preview-pipeline.md](docs/audio-preview-pipeline.md).
El límite de seguridad y la política de publicación de previews están explicados en [docs/public-preview-access.md](docs/public-preview-access.md).

## Comandos de calidad y build

```bash
npm run lint          # ESLint y reglas de hooks
npm run format:check  # Prettier
npm test              # pruebas de rutas, metadatos, filtros y previews
npm run check         # lint + formato + pruebas + build + prerender
npm run build         # build de Vite, catálogo, sitemap y prerender
```

`sync:catalog` también genera `public/catalog-meta.json`, `public/catalog-stats.json` y una selección estable de `public/roadmap-pending.json`. La selección y su fecha solo cambian cuando cambia el contenido real de los catálogos. El reporte técnico detallado se conserva localmente en `.reports/catalog-validation.json` y no se publica.

### Política de artefactos

Los JSON de catálogo, sus estadísticas, metadatos y sitemap son derivados: no se editan a mano y `prebuild` los regenera desde `../assets/`. `preview-manifest.json` es el registro de publicación de previews: solo se actualiza cuando el renderer terminó ambos formatos y debe viajar con el despliegue de Pages **después** de que los archivos equivalentes ya estén en R2. Así el sitio no apunta a previews que todavía no existen.

## Render y publicación de previews

Para generar previews de piano de hasta 1:30 en Opus y AAC/M4A (fallback de Safari/iOS), define la clave solo en tu terminal y ejecuta:

```powershell
$env:MIDI_PREVIEW_KEY = 'tu-clave-de-cifrado'
npm run render:previews
```

Como alternativa local segura, crea `website/.env.preview.local` —ya ignorado por Git— con una sola línea: `MIDI_PREVIEW_KEY=tu-clave-de-cifrado`. No compartas esa clave por chat ni la subas al repositorio.

El script escribe ambos formatos en `.preview-output/previews` y actualiza `public/preview-manifest.json`. Los nombres se derivan del MIDI ya normalizado, por lo que un nuevo render cambia la URL y no queda retenido por la caché inmutable.

El render y la subida fallan si algún archivo no se pudo procesar o publicar; así no se debe desplegar un manifest que apunte a previews ausentes. Los MIDI que ya están en texto plano pueden renderizarse sin clave, pero para el lote completo hace falta `MIDI_PREVIEW_KEY`.

Si los previews Opus ya existen y se requiere solamente el fallback de Safari/iOS, no hace falta acceder a ningún MIDI: `npm run transcode:previews` convierte los Opus existentes a AAC/M4A y conserva ambos formatos en el manifest. Si falta un Opus local, el script lo descarga del Worker público para convertirlo; no descarga ni expone MIDI.

La subida a R2 es independiente del sitio:

```powershell
$env:MIDI_PREVIEW_KEY = 'tu-clave-de-cifrado'
npm run upload:previews
```

Para publicar únicamente el fallback nuevo sin volver a subir los Opus existentes: `npm run upload:previews -- --format=aac --concurrency=4`.

Después de publicar, `npm run validate:previews` comprueba los dos formatos de cada preview en el Worker público y que Pages exponga el manifest v2. El reporte queda local en `.reports/preview-validation.json`.

## Despliegue en Cloudflare Pages

El proyecto se construye con `npm run build` y se publica desde `website/dist`. En Cloudflare Pages configura:

- Build command: `npm run build`
- Build output directory: `dist`
- Root directory: `website`

El dominio canónico previsto es `https://lldmcoro.com`. Hasta que tenga un registro DNS hacia Pages, la versión pública verificable es `https://coro-lldm.pages.dev/`. El workflow de GitHub Actions ejecuta la cadena de calidad en cada cambio que afecte a `website`; la publicación queda bajo el control del proyecto de Cloudflare Pages.

## Límites actuales

- Los archivos remotos y cifrados se clasifican y reportan en `.reports/catalog-validation.json`; su existencia remota requiere una verificación contra el servicio que los sirve.
- Las pruebas E2E responsive y la validación con herramientas externas de accesibilidad deben ejecutarse contra el sitio desplegado antes de publicar cambios visuales.
