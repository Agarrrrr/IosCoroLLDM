# CORO LLDM - MASTER CONTEXT

## Propósito del Proyecto
Sistema de gestión de partituras PWA (Progressive Web App) diseñado para coros, con soporte offline (Service Worker), gestión multi-sede y catálogo maestro. Desarrollado para optimizar la visualización de partituras en dispositivos móviles durante ensayos y presentaciones en vivo (iOS/Android).

## Arquitectura Técnica
- **Frontend:** Vanilla JavaScript (ES6+), Vite (Bundler).
- **Documentación:** Documentos técnicos y manuales organizados en la carpeta `/docs/`.
- **Compatibilidad Legacy:** `@vitejs/plugin-legacy` activado. Motor PDF.js v4.10 (Legacy) para soporte garantizado en Safari 12.1 (iOS 12.5.7). Se incluye un polyfill manual para `Promise.withResolvers` (ES2024) en `src/core/polyfills.js` ya que PDF.js v4 lo requiere y los navegadores antiguos no lo implementan.
- **Estilos Modulares:** CSS dividido en componentes globales (`/styles/components/`) y específicos para el administrador (`/styles/gestor/`).
- **Diseño:** Premium Mobile-First con micro-interacciones (`scale 0.96`), soporte nativo para gestos (swipe para cerrar modales/banners), y diseño tipo Dashboard/iOS nativo (bordes redondeados, menús flotantes, sticky headers).
- **Backend:** Supabase (Auth, Postgres DB, Storage, Realtime).

## Estructura de Controladores Core (`src/core/`)
- `authController.js`: Gestión de sesión, lectura de caché de Supabase, e inicio de sesión.
- `realtimeManager.js`: **[CRÍTICO]** Hub centralizado de conexiones a Supabase Realtime.
- `offlineManager.js`: Gestión del Service Worker y caché nativa del navegador.
- `pdfEngine.js`: Renderizado y control de gestos (Zoom/Pinch) del visor de PDF.js.
- `uiController.js`: Motor de animaciones, Toasts, temas (Oscuro, Claro, Sepia, etc) y modales globales.
- `midiEngine.js`: **[NUEVO v3.5.x]** Motor de audio con filtro anti-ráfagas y sincronización real-time.

## Estructura del Gestor de Administración (`src/gestor/`)
- `gestorApp.js`: Orquestador principal de la vista de administración. Maneja el cambio de sede (`contextoSedeActiva`).
- `/eventos/`: Gestión de Carpetas/Setlists.
    - `eventosPanel.js`: Lógica CRUD y conexión a `realtimeManager`.
    - `eventosUI.js`: Renderizado del DOM (Diseño moderno iOS-style, menús flotantes).
- `/miembros/`: Control de usuarios y roles.
    - `miembrosPanel.js`: Aprobación de solicitudes y cambio de jerarquías.
- `/partituras/`: Catálogo de la sede.
- `/admin/`: `superPanel.js` para visualización global.

## Reglas Críticas y Patrones Establecidos (LEER ANTES DE MODIFICAR)

### 1. True Realtime Unificado
**NUNCA instanciar `supabase.channel()` directamente en los paneles.** Toda conexión de base de datos en tiempo real DEBE pasar por `src/core/realtimeManager.js`.
- El manager crea un único canal llamado `main-${sedeActual}` que escucha: `cantos`, `cantos_coros`, `eventos`, `eventos_cantos` y `perfiles`.
- Los paneles se "enganchan" usando hooks: `realtimeManager.onEventos()`, `realtimeManager.onMiembros()`, etc.
- **Manejo de DELETE:** Los eventos `DELETE` de Supabase envían el payload vacío en `.new`. Siempre verificar `.old` si el evento es un borrado (Implementado en L46 de `realtimeManager.js`).

### 2. Gestión Offline y Optimizaciones
- **Fast-Fail Network:** Antes de ejecutar queries de refresco, los controladores siempre verifican `!navigator.onLine || window.MODO_OFFLINE_FORZADO`. Si no hay red, caen de gracia renderizando las variables en memoria (`cacheCatalogo`, `eventosLocales`, etc).
- **Renderizado Optimista:** Al crear o borrar elementos (Ej. Carpetas en `eventosPanel.js`), se debe modificar el arreglo local de JavaScript y pintar el DOM *antes* de enviar la petición a Supabase, para garantizar feedback visual instantáneo (0ms de latencia).

### 3. Deep Linking y Pase de Invitado
- **Android TWA:** Validado mediante `public/.well-known/assetlinks.json`.
- **iOS:** Validado mediante `public/.well-known/apple-app-site-association`.
- **Link de Carpeta (`/?ev=ID`):** Cuando un usuario abre un link compartido de una carpeta, `main.js` captura el ID y lo guarda en `localStorage ('eventos_permanentes')`.
- **Bypass de RLS (Audiencia):** En `main.js` (`autoFetchEventos()`), si un evento está en `eventos_permanentes`, se fuerza su renderizado (Pase de Invitado), anulando las reglas de filtro por sede. Las carpetas tienen dos estados: Pública (Toda la sede local) u Oculta (Solo Lista de Invitados).

### 4. Estilos y UI
- PROHIBIDO usar estilos en línea pesados para reescribir layout (usar clases).
- Los modales deben usar fondo gris (`#f1f5f9`) con tarjetas blancas (`#fff`) y `border-radius: 12px`, imitando componentes nativos de iOS.
- Las cabeceras de los modales deben ser `position: sticky; top: 0; z-index: 10;`.
- Mantener la compatibilidad en CSS: Prefijar `-webkit-backdrop-filter`. No usar dependencias externas (Tailwind, Bootstrap). Todo es Vanilla CSS en `/src/styles/`.

### 5. Prevención de Errores RLS (Network)
- Los conteos globales (`count: 'exact', head: true`) en tablas protegidas (como `coros` o `perfiles`) arrojarán un HTTP 403/400 si se hacen con credenciales menores a `superadmin`. Estas peticiones deben estar estrictamente bloqueadas mediante validación de rol antes de ejecutarse (Implementado en `superPanel.js` -> `API.obtenerMetricas`).

### 6. Unificación de Dominios (TWA/PWA)
**EL DOMINIO OFICIAL ES `www.lldmcorobc.com`.** 
- Todas las configuraciones en `app/build.gradle`, `twa-manifest.json` y el `manifest.json` de la PWA deben incluir las **www**.
- Android TWA solo delega permisos de notificación si el dominio de la APK y el de la PWA coinciden exactamente. **NUNCA** usar la versión sin www en los manifiestos.

### 7. Patrones Técnicos MIDI (v3.5.x)
- **Filtro Anti-Ráfagas**: El motor descarta automáticamente ráfagas de notas causadas por "catch-up" de CPU (lag) para evitar explosiones de volumen. Límite de polifonía instantánea: 12 notas.
- **Sincronía Real-Time**: Se eliminó el lookahead artificial de 150ms. El audio se agenda en `Tone.now()` para una respuesta inmediata y sincronía perfecta con la barra de progreso.
- **Final de Pista Limpio**: Se aplica un fade-out ultra-rápido (50ms) al llegar a los 0.2s finales para silenciar ruidos residuales de archivos MIDI mal formados.
- **Resonancia Natural**: Se otorgan 2 segundos de gracia al terminar la pista para permitir el release natural del sampler de piano (0.6s) antes de limpiar la sesión.
- **Control Manual**: El reproductor **NUNCA** debe iniciar automáticamente al cargar. Siempre esperar al comando explícito de `Play`.

### 8. Motor de Anotaciones y Suite de Pruebas (v4.0.x)
- **Anotaciones de Texto (UI Nativa)**: El ingreso de texto flotante en la partitura NUNCA debe usar modales (`prompt()` o modales HTML). Debe instanciar un `<input type="text">` posicionado de manera `absolute` sobre las coordenadas exactas del Canvas, destruyéndose en el evento `blur` o `Enter` para transferir la data al estado.
- **Detección Táctil**: `pdfEngine.js` bloquea la creación de trazos cuando detecta Gestos (Pinch-to-zoom) mediante validación estricta de `e.touches.length > 1`.
- **Unit Testing (Vitest)**: La lógica base (`pdfEngine.js`, `anotacionesManager.js`, `midiEngine.js`) se testea en terminal pura mediante `jsdom` (Mock de API Canvas `getContext('2d')` e inyección virtual).
- **E2E Testing (Playwright)**: Las interacciones de trazado y teclado se testean usando Chromium headless. El entorno de tests evita dependencias de red mediante la interceptación de Supabase y el uso del **Pase de Invitado** (`/?ev=ID`) junto a mocks de `localStorage` para forzar la UI de la partitura directa sin logins.
