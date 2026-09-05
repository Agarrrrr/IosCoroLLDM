# Navegación, idioma y fuentes de verdad

## Regla de idioma

La URL es la autoridad del idioma. Las rutas que comienzan con `/en/` se muestran en inglés; todas las demás se muestran en español. El selector de idioma conserva la página actual y reemplaza la URL, por ejemplo `/repertorio` pasa a `/en/repertorio`.

No se usa `localStorage` ni `?lang=` para decidir el idioma. Así un enlace compartido, una recarga, una navegación con Atrás/Adelante y el HTML prerenderizado siempre describen el mismo idioma.

## Rutas

`src/site-utils.js` es la fuente única de rutas, idioma, metadatos de página y URLs de previews. Sus funciones puras se prueban en `tests/site-utils.test.js`.

- `languageFromPath(pathname, base)` determina el idioma.
- `pageFromPath(pathname, search, base)` resuelve la página, incluido el alias histórico `/colabora`.
- `routePath(page, language, base)` crea enlaces internos coherentes.
- `pageMetadata` alimenta títulos y descripciones en React.

`src/app-config.js` no replica esa lógica: solamente adapta esas funciones al navegador y reúne los datos estructurados de runtime.

## Configuración pública

`src/site-data.js` concentra el dominio canónico, URLs de tiendas, origen de previews y enlaces sociales. React, SEO runtime y los scripts deben importar esas constantes; no se deben repetir URLs públicas en componentes nuevos.

Otras fuentes especializadas son:

- `src/content/`: copy bilingüe, FAQ y contenido de soluciones.
- `src/site-config.js`: notas de versión y fechas editoriales.
- `src/legal-content.js`: textos legales bilingües.
- `public/catalog-meta.json` y `public/preview-manifest.json`: artefactos generados del catálogo, no editables a mano.

## Convención para cambios

1. Añadir rutas y metadatos en `src/site-utils.js`.
2. Añadir copy en ambos idiomas bajo `src/content/`.
3. Usar `routePath()` para todo enlace interno.
4. Mantener el idioma en la URL; nunca recuperar una preferencia que contradiga la ruta.
5. Ejecutar `npm run check` antes de publicar.

## Límite pendiente

Todavía hay microcopy histórico inline en `App.jsx` y texto editorial duplicado en `scripts/prerender.mjs`. El roadmap DT-13 y DT-08 controlan esa migración; no deben modificarse a mano en un solo idioma.
