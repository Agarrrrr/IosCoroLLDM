# Roadmap de Coro LLDM

Fuente única de verdad para el estado, las prioridades y la deuda técnica del sitio. Cada pendiente tiene un identificador único; las prioridades solo apuntan a esos identificadores para evitar duplicados.

Última auditoría: **4 de septiembre de 2026**.

## 1. Estado completado

### Producto y experiencia

- [x] Sitio independiente construido con React y Vite.
- [x] Diseño responsive para escritorio, tablet y móvil.
- [x] Temas claro y oscuro con preferencia guardada.
- [x] Sitio completo en español e inglés mediante rutas `/en/...`.
- [x] Páginas independientes para Inicio, Producto, Repertorio, Novedades, Soluciones, Roadmap, Contacto y contenido legal.
- [x] Descargas oficiales desde Google Play y App Store.
- [x] Repertorio BC presentado como referencia de desarrollo a medida, no como otra versión de Coro LLDM.
- [x] FAQ visible, capacidades comprobables y notas de versión largas editables por versión.
- [x] Política de privacidad, términos de uso y atribuciones públicas.
- [x] Página 404 personalizada.

### Catálogo y audio

- [x] Catálogos español e inglés sincronizados desde los assets de la aplicación.
- [x] Skeletons, estado vacío, error y reintento básico.
- [x] Catálogo conservado en memoria durante la sesión y previews solicitados bajo demanda.
- [x] Metadatos y estadísticas del catálogo versionados por hash; el reporte técnico de validación queda local, fuera del despliegue.
- [x] Selección estable de próximos audios generada desde el catálogo real.
- [x] Previews de piano en Opus almacenados en Cloudflare R2.
- [x] Reproductor flotante con anterior, siguiente, progreso y detener.
- [x] Reproducción detenida al cambiar de página o esconder la pestaña.
- [x] Worker verificado con Range Requests, ETag, `audio/ogg; codecs=opus` y caché immutable.

### SEO, accesibilidad y calidad

- [x] 22 documentos HTML prerenderizados, un `h1` por página y rutas directas funcionales.
- [x] Títulos, descripciones, canonical, hreflang, Open Graph, Twitter Cards y JSON-LD bilingües.
- [x] `robots.txt`, `sitemap.xml`, `llms.txt`, favicon, Apple touch icon y manifest web.
- [x] Imágenes sociales de 1200 × 630 en español e inglés.
- [x] Sitemap con alternates y `lastmod` para el repertorio.
- [x] Enlace para saltar al contenido, foco visible, semántica base del menú móvil y anuncios accesibles del reproductor.
- [x] Animaciones compatibles con `prefers-reduced-motion`.
- [x] Headers de seguridad desplegados en Pages: CSP, `Referrer-Policy`, `Permissions-Policy`, `X-Content-Type-Options` y protección de framing.
- [x] ESLint, reglas de hooks, Prettier y pruebas unitarias básicas.
- [x] `npm run check` correcto: lint, formato, 11 pruebas unitarias, 11 E2E, build, sincronización, prerender y validación de 22 HTML.
- [x] `npm audit` sin vulnerabilidades conocidas el 4 de septiembre de 2026; Playwright se actualizó a 1.63.0 tras corregir una alerta de la herramienta de pruebas.
- [x] Versión pública disponible en `https://coro-lldm.pages.dev/` con rutas directas y 404 correctos.

## 2. Prioridades actuales

Las prioridades referencian la deuda canónica de la sección 3. No representan tareas adicionales.

1. **Catálogo, previews y compatibilidad Safari/iOS:** DT-20 a DT-25. DT-25 está implementado en código, pero seguirá abierto hasta renderizar, subir y probar AAC/M4A en Safari/iOS real.
2. **Reducir el monolito y mejorar mantenimiento:** DT-32, DT-36 y DT-40.
3. **Accesibilidad y rendimiento medido:** DT-42 y DT-45 a DT-47.
4. **Revisión visual con menos texto y más evidencia gráfica:** DT-48 a DT-55.
5. **Contacto real:** DT-57 a DT-62. Se aborda cuando esté definido el proveedor de correo.
6. **Publicación final, dominio y SEO de producción:** DT-01 a DT-06. Esta fase comienza únicamente después de completar las prioridades anteriores.

## 3. Deuda técnica

### Publicación, Cloudflare y SEO

- [x] **DT-01 — Activar CI desde la raíz.** Verificado el 4 de septiembre de 2026: `.github/workflows/website-quality.yml` se ejecuta desde la raíz, instala dependencias y Chromium, y lanza la verificación completa en `website/`.
- [x] **DT-02 — Resolver la URL canónica temporal.** Verificado el 4 de septiembre de 2026: mientras `lldmcoro.com` no tenga DNS, canonical, hreflang, Open Graph, sitemap, `robots.txt`, `llms.txt` y JSON-LD usan `https://coro-lldm.pages.dev`. Al conectar el dominio, `SITE_ORIGIN` debe regresar a `https://lldmcoro.com` y el despliegue debe verificarse de nuevo.
- [x] **DT-03 — Retirar el reporte técnico del despliegue.** Verificado el 29 de agosto de 2026: `sync:catalog` escribe el reporte de aproximadamente 450 KB en `website/.reports/catalog-validation.json`, lo ignora Git y elimina la copia de `public/`.
- [x] **DT-04 — Alinear y desplegar CORS del Worker.** Verificado el 29 de agosto de 2026: producción responde para `https://coro-lldm.pages.dev` con CORS restringido, Range, ETag y caché inmutable; también sirve AAC/M4A con `audio/mp4; codecs=mp4a.40.2`.
- [x] **DT-05 — Añadir configuración reproducible de Pages.** Verificado el 4 de septiembre de 2026: `website/wrangler.jsonc` fija el proyecto, el directorio `dist` y la fecha de compatibilidad; `npm run deploy:pages` reproduce el comando de Pages.
- [ ] **DT-06 — Validar datos estructurados externamente.** Ejecutar Rich Results Test y Schema Markup Validator contra la URL pública definitiva.
- [x] **DT-07 — Evitar metadatos duplicados tras arrancar React.** Verificado el 4 de septiembre de 2026: el prerender y React comparten identificadores para canonical, tres alternates y JSON-LD; la plantilla dejó de emitir social tags base duplicados y el validador exige una sola etiqueta para `og:locale` y cada Twitter Card.
- [x] **DT-08 — Mantener una fuente única para SEO y prerender.** Verificado el 3 de septiembre de 2026: `src/seo.js` alimenta React, JSON-LD, canonical, alternates y sitemap; `src/prerender-content.js` deriva encabezados, FAQ, novedades, soluciones y legales de las mismas fuentes que React. Se retiró el copy editorial paralelo, incluidas promesas antiguas sobre equipo y administradores.
- [x] **DT-09 — Estabilizar `lastmod`.** Verificado el 3 de septiembre de 2026: `sync:catalog` conserva `catalog-meta.generatedAt` cuando los hashes de ambos idiomas no cambian, y el sitemap deriva `lastmod` de esa misma fecha.

### Navegación, idioma y fuentes de verdad

- [x] **DT-10 — Corregir `pageFromPath`.** Verificado el 29 de agosto de 2026: `pageFromPath()` recibe el `pathname` actual al navegar; ya no depende de `locationParts` calculado al importar.
- [x] **DT-11 — Unificar utilidades duplicadas.** Verificado el 29 de agosto de 2026: `src/site-utils.js` es la fuente única de rutas, idioma, metadatos y previews; `app-config.js` solo adapta esas funciones al navegador y las pruebas cubren la misma implementación que usa React.
- [x] **DT-12 — Centralizar configuración pública.** Verificado el 4 de septiembre de 2026: dominio, tiendas, demo, Worker de previews y redes están en `src/site-data.js`, consumido por React, footer, sitemap y prerender.
- [x] **DT-13 — Centralizar textos y comprobar traducciones.** Verificado el 4 de septiembre de 2026: `App.jsx` ya no contiene copy editorial; Inicio, Catálogo, Soluciones, Contacto, cabecera y footer consumen componentes y claves bilingües. Las pruebas comparan las claves ES/EN y la validación estática cubre `alt`, dimensiones de imágenes y controles de icono.
- [x] **DT-14 — Hacer coherente idioma y URL.** Decisión documentada y verificada el 29 de agosto de 2026: la URL es la autoridad (`/en/...` es inglés; las demás rutas son español), el selector cambia la URL y ya no se conserva una preferencia que la contradiga.

### Catálogo, caché y reproductor

- [x] **DT-15 — Separar la carga del roadmap.** Verificado el 29 de agosto de 2026: `/roadmap` solicita solo `roadmap-pending.json`; los catálogos y manifest se cargan exclusivamente al entrar a Repertorio.
- [x] **DT-16 — Cargar estadísticas solo donde se usan.** Verificado el 29 de agosto de 2026: `catalog-stats.json` se solicita solo en Inicio y se mantiene en memoria durante la sesión.
- [x] **DT-17 — Determinar audio desde el preview público.** Verificado el 29 de agosto de 2026: las tarjetas, los filtros y la navegación del reproductor usan una URL de preview que `canPlayType()` declara reproducible; un MIDI sin preview ya no se anuncia como audio disponible.
- [x] **DT-18 — Separar métricas de MIDI y preview.** Verificado el 29 de agosto de 2026: `catalog-stats.json` expone `withMidi` y `withPreview` por idioma; la interfaz muestra el segundo valor.
- [x] **DT-19 — Aplicar realmente el hash del catálogo.** Verificado el 29 de agosto de 2026: `catalog-meta.json` conserva su fecha si los hashes no cambian y el frontend incorpora hash/versión a las URLs de catálogo, manifest y estadísticas.
- [x] **DT-20 — Definir política de artefactos generados.** Verificado el 29 de agosto de 2026 y documentado en el README: catálogos, estadísticas, metadatos y sitemap se regeneran desde assets durante `prebuild`; el manifest se publica solo después de que sus archivos ya existen en R2.
- [ ] **DT-21 — Fortalecer la validación del catálogo.** El render y la subida ya fallan si el lote de previews queda incompleto. Falta verificar assets remotos/cifrados y decidir qué debe bloquear `sync:catalog`; el reporte permite actualmente 4 relaciones huérfanas, 13 no recíprocas y 2 assets cifrados sin verificar.
- [x] **DT-22 — Mostrar errores de reproducción.** Verificado el 29 de agosto de 2026: el reproductor muestra feedback bilingüe específico para interrupción, red, decodificación y formato no compatible; la prueba unitaria cubre el mapeo y no deja el toast activo tras un fallo.
- [x] **DT-23 — Manejar red lenta y cancelación.** Verificado el 29 de agosto de 2026: las cargas JSON usan timeout de 12 segundos y `AbortController`, se cancelan al desmontar, el arranque de audio vence a los 12 segundos y existe una prueba automatizada del fallback por timeout.
- [x] **DT-24 — Versionar previews.** Verificado el 29 de agosto de 2026: el renderer usa nombres por contenido para renders futuros; el manifest v2 con 380 pares Opus/M4A está publicado en Pages y la validación pública comprobó los 760 archivos, CORS y MIME correctos.
- [ ] **DT-25 — Añadir fallback AAC/M4A y probar Safari/iOS.** Implementado y publicado el 29 de agosto de 2026: 380 previews AAC-LC/M4A, Worker con MIME/Range/CORS y Pages con manifest v2 fueron validados públicamente. Falta únicamente una prueba manual en Safari iOS real; Chrome Android y escritorio usan Opus como antes.
- [x] **DT-26 — Documentar el pipeline de audio.** Verificado el 3 de septiembre de 2026: `docs/audio-preview-pipeline.md` registra render de piano, límite de 1:30, Opus/AAC, manifest, subida a R2, caché por contenido, recuperación y manejo seguro de la clave.
- [x] **DT-27 — Documentar el modelo de acceso público.** Verificado el 4 de septiembre de 2026: `docs/public-preview-access.md` define qué se publica, qué permanece privado, el límite real de protección y el proceso de revocación.
- [ ] **DT-28 — Revisar caché y observabilidad del Worker.** Confirmar acceso del bucket, logs, alertas, rotación de secretos y revocación de previews.
- [ ] **DT-29 — Preparar crecimiento del catálogo.** Añadir paginación o virtualización cuando las mediciones demuestren que el render incremental actual ya no es suficiente.
- [ ] **DT-30 — Mostrar fecha visible del repertorio.** Definir si representa sincronización de assets o publicación editorial y no confundirla con la fecha de las tiendas.

### Arquitectura, calidad y mantenimiento

- [x] **DT-31 — Dividir `App.jsx`.** Verificado el 4 de septiembre de 2026: `App.jsx` quedó en 131 líneas como composición de rutas; Inicio, Catálogo, Soluciones, Contacto, cabecera, footer, datos de catálogo y efectos viven en componentes/hooks separados, todos por debajo de 300 líneas salvo `styles.css`.
- [x] **DT-32 — Dividir `styles.css`.** Verificado el 4 de septiembre de 2026: `styles.css` es ahora un punto de entrada de nueve imports; tokens, base, layout, componentes, páginas, responsive y catálogo/roadmap se mantienen en archivos independientes con cortes solo en bloques CSS cerrados. Vite recompila el mismo CSS final.
- [x] **DT-33 — Añadir un Error Boundary.** Verificado el 3 de septiembre de 2026: `ErrorBoundary` envuelve la aplicación, registra el fallo y muestra una recuperación bilingüe con recarga en lugar de una pantalla blanca.
- [x] **DT-34 — Aislar APIs del navegador.** Verificado el 4 de septiembre de 2026: `browser-runtime.js` encapsula almacenamiento, historial, eventos, foco y timers; `app-config` recibe ubicación bajo demanda y el reproductor permite inyectar audio/runtime para pruebas. No hay acceso a `window` durante la importación.
- [x] **DT-35 — Ordenar dependencias.** Verificado el 4 de septiembre de 2026: `@vitejs/plugin-react`, Vite y Wrangler son dependencias de desarrollo fijadas; se retiró TypeScript sin uso. Playwright 1.63.0 añade pruebas E2E y `npm audit` no reporta vulnerabilidades.
- [ ] **DT-36 — Actualizar documentación.** Avance verificado el 3 de septiembre de 2026: README ya no recomienda Supabase y enlaza la documentación de navegación y previews. Falta confirmar CI y dominio antes de describirlos como operativos.
- [ ] **DT-37 — Añadir pruebas de integración y E2E.** Avance verificado el 4 de septiembre de 2026: Playwright recorre 9 rutas ES/EN, valida un único `h1`, tema, idioma, navegación móvil y errores de página/consola propios. Falta cubrir audio real, `AudioContext`, Range/CORS, 401/404 y Safari/iOS.
- [x] **DT-38 — Ampliar validación de CI.** Verificado el 4 de septiembre de 2026: `check` incluye HTML/JSON-LD, enlaces y assets locales, headers estáticos, nombres de iconos, dimensiones de imágenes y E2E. Pendiente mover el workflow a la raíz (DT-01).
- [x] **DT-39 — Limpiar efectos asíncronos.** Verificado el 4 de septiembre de 2026: abortos de `fetch`, timers de feedback/animación y reproducción se limpian al desmontar; el catálogo conserva su carga de sesión sin actualizar estado después de la limpieza.
- [x] **DT-40 — Ignorar artefactos locales.** Verificado el 4 de septiembre de 2026: la raíz del repositorio excluye `website/.reports`, `.preview-output`, `.preview-tmp`, `.wrangler`, resultados de Playwright, logs locales y `.pnpm-store`, evitando subir artefactos de desarrollo.

### Accesibilidad y rendimiento

- [x] **DT-41 — Completar navegación por teclado.** Verificado el 3 de septiembre de 2026: Escape cierra el menú móvil y devuelve foco al control; las rutas principales exponen `aria-current` y la navegación SPA enfoca el contenido principal.
- [ ] **DT-42 — Auditar contraste y lector de pantalla.** Medir WCAG AA en ambos temas y recorrer toda la web con teclado y lector real.
- [x] **DT-43 — Corregir nombres accesibles restantes.** Verificado el 4 de septiembre de 2026: el logo repetido del footer es decorativo, la marca de cabecera tiene texto alternativo, los controles de icono tienen nombre y la validación falla si falta `alt`, dimensiones o nombre en un botón de icono prerenderizado.
- [x] **DT-44 — Evitar el destello de tema.** Verificado el 3 de septiembre de 2026: un script mínimo aplica el tema guardado antes de React y el runtime sincroniza `data-theme` y `theme-color` en cada cambio.
- [ ] **DT-45 — Optimizar imágenes.** Avance verificado el 4 de septiembre de 2026: las imágenes de React tienen dimensiones; Repertorio BC se difiere y decodifica asíncronamente. Falta convertir los PNG de logo (198–345 KB), la ilustración 404 (1.86 MB) y las imágenes sociales (1.4 MB) a formatos/tamaños optimizados sin perder calidad.
- [ ] **DT-46 — Medir rendimiento real.** Ejecutar Chrome DevTools/Lighthouse para LCP, CLS, INP, FCP, TBT, Speed Index, red y accesibilidad. Chrome DevTools MCP no está configurado en esta sesión.
- [ ] **DT-47 — Reducir recursos innecesarios.** Revisar Google Fonts, preconnects, imports de Lucide, carga diferida del módulo de audio, Brotli y caché real. No copiar a `dist` el kit social completo de 1–2.5 MB por imagen cuando no sea necesario para la web.

### Contenido y experiencia visual

- [ ] **DT-48 — Reducir texto repetido.** Cada sección debe comunicar una sola idea sin repetir consecutivamente partituras, ensayo, voces, offline y repertorio.
- [ ] **DT-49 — Mantener Inicio como puerta de entrada.** Conservar la descarga como bloque principal aprobado y dirigir a páginas específicas sin explicar todo el producto en la landing.
- [ ] **DT-50 — Hacer Producto más visual.** Sustituir listas extensas por capturas reales, iconos y microcopy de visor, anotaciones, audio y uso offline.
- [ ] **DT-51 — Simplificar Soluciones.** Explicar el desarrollo a medida mediante un proceso gráfico de descubrimiento, diseño, desarrollo, publicación y soporte.
- [ ] **DT-52 — Simplificar Roadmap y Novedades.** Mostrar solo trabajo confirmado; dar prioridad gráfica a partituras y audios nuevos y permitir expandir el detalle largo.
- [ ] **DT-53 — Verificar paridad visual bilingüe.** Revisar jerarquía, longitud, promesas y densidad en móvil, tablet y escritorio después de cada recorte.
- [ ] **DT-54 — Añadir evidencia real cuando exista.** Incorporar testimonios, capturas y resultados sin inventarlos.
- [ ] **DT-55 — Retirar dependencias externas obsoletas.** Verificar si la demo de Vercel sigue siendo necesaria y eliminar sus recursos cuando deje de usarse.
- [x] **DT-56 — Revisar el manifest instalable.** Verificado el 4 de septiembre de 2026: el manifest identifica ambas marcas, describe la experiencia bilingüe e incorpora propósito `maskable`; `start_url` permanece español como decisión explícita del manifest único.

### Contacto real — última fase

- [ ] **DT-57 — Elegir backend de correo.** Definir proveedor, Worker/endpoint y secrets sin incluir credenciales en el frontend.
- [ ] **DT-58 — Construir mensajes completos.** Enviar a `contacto@lldmcoro.com` con subject según proyecto, colaboración o soporte, `Reply-To`, HTML y texto plano.
- [ ] **DT-59 — Validar y sanitizar.** Añadir `name`, `required`, `autocomplete`, límites, formato de correo, protección contra header injection y HTML inseguro.
- [ ] **DT-60 — Proteger contra abuso.** Integrar Turnstile o equivalente, rate limiting y logs mínimos sin retener datos innecesarios.
- [ ] **DT-61 — Mostrar todos los estados.** Cubrir enviando, éxito, error, timeout y reintento con mensajes asociados mediante `aria-describedby`.
- [ ] **DT-62 — Revisar privacidad del contacto.** Añadir consentimiento o aviso contextual cuando corresponda.

## 4. Información pendiente del propietario

- [ ] **IP-01 — Redes sociales:** URLs oficiales de Facebook, Instagram, YouTube y TikTok.
- [ ] **IP-02 — Correo:** proveedor que procesará los mensajes enviados a `contacto@lldmcoro.com`.
- [ ] **IP-03 — Dominio:** activación DNS de `lldmcoro.com`, decisión sobre `www` y redirección hacia el dominio canónico.
- [ ] **IP-04 — Tiendas:** fuente o proceso editorial para mantener versión, fecha y notas sincronizadas con Play Store y App Store. La versión 2.5.2 del 26 de agosto de 2026 está capturada manualmente.
- [ ] **IP-05 — Evidencia visual:** capturas reales, mockups finales y testimonios autorizados que se quieran publicar.
- [ ] **IP-06 — Contenido editorial:** futuras notas de versión, textos promocionales y cambios del roadmap confirmados por Huri Tolentino.
