# Mapa de Arquitectura - Coro LLDM

Este documento detalla la estructura completa del código fuente (`src/`) del proyecto. Sirve como mapa maestro para entender cómo interactúan los módulos, qué controla cada área, y dónde hacer modificaciones sin afectar dependencias.

---

## 1. 🚀 Arranque y Enrutamiento (`/src/app/`)
Esta carpeta maneja el ciclo de vida inicial y el enrutamiento de la aplicación.

- **`appInitializer.js`**: El orquestador del arranque (Bootstrap). Maneja la diferencia entre "Warm Start" (inicios rápidos desde el caché localStorage) y "Cold Start" (consulta de red). Inicializa el Service Worker y orquesta la conexión a Supabase Realtime de manera unificada.
- **`router.js`**: Intercepta los parámetros de la URL para habilitar **Deep Linking**:
  - `?canto=ID`: Abre el visor de partituras automáticamente.
  - `?ev=ID`: Activa un **Pase de Invitado**, guardándolo en el localStorage para bypassear temporalmente el control de acceso estricto y permitir ver setlists a personas externas.
  - También gestiona los popups nativos de "Agregar a la Pantalla de Inicio" (A2HS) en iOS Safari.

---

## 2. 🧩 Características de Interfaz (`/src/features/`)
Los bloques funcionales grandes de la UI se aíslan aquí para no contaminar el `core` y hacerlos modulares.

- **`dashboard/` (`dashboardUI.js`)**: El gestor principal de la interfaz de la lista de canciones. Es altamente reactivo: se suscribe al estado central y renderiza condicionalmente el DOM según roles (mostrando u ocultando botones de administrador). Implementa también la lógica de swipe-to-dismiss para los banners en vivo.
- **`jukebox/` (`jukeboxController.js`, `jukeboxUI.js`)**: Modulo independiente que maneja la reproducción de listas MIDI en segundo plano. Inyecta componentes DOM dinámicamente y se integra estrechamente con la **OS MediaSession API**, lo que permite a los usuarios pausar/reproducir o adelantar canciones desde la pantalla de bloqueo de su celular.

---

## 3. ⚙️ Núcleo / Lógica de Negocio (`/src/core/`)
Aquí reside el cerebro de la aplicación.

- **`authController.js`**: Control de sesión y roles (`miembro`, `director`, `superadmin`). Trabaja junto con la persistencia en `localStorage`.
- **`stateManager.js` & `types.js`**: Estado global en memoria para evitar llamadas redundantes a la DB, junto a definiciones de tipos JSDoc para el IDE.
- **`realtimeManager.js`**: Hub WebSocket único. Establece la comunicación instantánea por sede (Canales Dinámicos). Maneja los bypass de seguridad (Ej: interceptar `SYNC_SILENCIOSA` para borrar cantos de la UI antes de que el servidor lo haga).
- **`pdfEngine.js`**: Controlador de renderizado PDF.js Legacy (Safari 12). Gestiona lazy-loading, paginación, limpieza manual de RAM (`pdf.destroy()`) y control estricto de gestos (Pinch-to-zoom).
- **`anotacionesManager.js` (v4.0.x)**: Motor gráfico sobre Canvas para pintar trazos libres e inyectar inputs absolutos (`<input type="text">`) sobre la partitura. Bloquea el trazado si detecta `e.touches.length > 1`.
- **`midiEngine.js` (v3.5.x)**: Orquestador de Audio (ToneJS). Implementa el límite de polifonía (12 notas) y filtro anti-ráfagas. Ajusta los eventos usando `Tone.now()` para precisión temporal.
- **`syncQueue.js`**: Motor de transacciones Offline (IndexedDB). Si el director hace un cambio sin red, este archivo encola un `INSERT/UPDATE/DELETE`. Al detectar `online`, vacía la cola hacia Supabase silenciosamente.
- **`globalErrorHandler.js`**: Capturador de fallos no manejados para prevenir que la UI quede congelada y para proveer Toasts de error informativos.

---

## 4. 🧰 Subprocesos de Background (`/src/workers/`)
Para garantizar que la aplicación mantenga los 60 FPS y las animaciones no se congelem, las tareas pesadas se sacan del hilo principal.

- **`midiParser.worker.js`**: Un Web Worker que recibe el buffer binario del archivo `.mid` y utiliza `@tonejs/midi` para decodificarlo, devolviendo un JSON estructurado listo para ser interpretado por ToneJS.

---

## 5. 🎛️ Gestor Administrativo (`/src/gestor/`)
Aplicación secundaria exclusiva para administradores. Construida sobre el mismo `core` pero con vistas distintas.

- **`gestorApp.js`**: Controlador maestro del Sidebar del administrador.
- **Submódulos (Ej: `/metricas`, `/eventos`, `/miembros`)**: Utilizan un patrón MVC básico con un `*Panel.js` (Lógica) y un `*UI.js` (Renderizado del DOM).

---

## 6. 🌐 Capa de API (`/src/api/`)
- **`supabase.js`**: Configuración e inicialización del Singleton del cliente nativo de Supabase, extrayendo las variables de Vite (`import.meta.env`).

---

## 7. 🎨 Estilos Base (`/src/styles/`)
Arquitectura CSS Vanilla, modular y optimizada.

- **`/components/`**: Módulos agnósticos (`layout.css`, `modals.css`, `notifications.css`). Mantienen un diseño Premium estilo iOS nativo (borders radius 12px, backdrop-filters, etc).
- **`/gestor/`**: Hojas de estilo restrictivas para la consola de administración.

---

## Flujo Recomendado para Nuevos Desarrollos

> [!TIP]
> Si deseas alterar una función clave de visualización: 
> 1. Modifica la lógica base en el **Core** (`/src/core/`).
> 2. Si es una función pesada, pásala al **Worker** (`/src/workers/`).
> 3. Ajusta cómo responde la interfaz en el **Feature Module** pertinente (`/src/features/`).
> 4. Actualiza los selectores y utilidades visuales en **UI** (`/src/ui/`).
