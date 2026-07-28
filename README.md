# CORO LLDM - App de Gestión de Partituras

![Versión](https://img.shields.io/badge/Versi%C3%B3n-4.0.0-gold)
![PWA](https://img.shields.io/badge/PWA-Ready-green)
![Backend](https://img.shields.io/badge/Backend-Supabase-blue)
![iOS](https://img.shields.io/badge/iOS-12.5.7+-silver)
![ToneJS](https://img.shields.io/badge/Audio-ToneJS-orange)

**Coro LLDM** es una aplicación

El sistema se aloja bajo el dominio unificado oficial **[www.lldmcorobc.com](https://www.lldmcorobc.com)**, el cual sirve tanto a la Progressive Web App (PWA) en iOS como a la Trusted Web Activity (TWA) nativa en Android.

---

## 🌟 Características Principales

### 📱 Experiencia Móvil de Primer Nivel
- **Diseño Mobile-First Premium:** Interfaz limpia tipo Dashboard/iOS, optimizada para el uso con una sola mano.
- **Micro-interacciones:** Feedback táctil en cada acción (`scale 0.96`), animaciones sutiles y vibración de confirmación.
- **Gestos Nativos:** Navegación por gestos (swipes) para cerrar modales, descartar notificaciones, y zoom (Pinch-to-zoom).

### 🎼 Visor de Partituras y Anotaciones (v4.0.x)
- **Motor PDF.js Legacy:** Compatibilidad total asegurada con dispositivos antiguos (iPad Air 1, iOS 12.5.7 y Safari 12).
- **Anotaciones Táctiles:** Dibuja, subraya o inserta texto directamente en el pentagrama de forma nativa sin perder la vista del PDF.
- **Prevención de Errores:** Bloqueo inteligente del trazado al usar gestos multi-touch (como hacer zoom).
- **Bloqueo de Pantalla (Wake Lock):** Evita que la pantalla se apague durante los ensayos y presentaciones.

### 🎹 Reproductor MIDI y Jukebox (v3.5.x)
- **Capa de Audio (ToneJS):** Motor de piano digital para ensayos y entonación.
- **Jukebox de Fondo:** Controla la reproducción desde la pantalla de bloqueo (OS MediaSession) para ensayar múltiples cantos secuencialmente.
- **Web Workers:** El parseo de los archivos MIDI pesados ocurre en un hilo paralelo (Background Worker) para mantener la interfaz fluida a 60 FPS.
- **Filtro Anti-ráfagas:** Sincronización real-time (`Tone.now()`) con polifonía controlada y finales de pista con `fade-out` de 50ms para limpieza de audio.

### 📶 Robustez Offline y PWA
- **Sincronización IndexDB:** Un sistema de Cola de Sincronización (`syncQueue`) permite operar (agregar/editar/eliminar) sin internet. Al recuperar la red, las transacciones se envían a Supabase en segundo plano.
- **Acceso Sin Conexión:** Los coristas pueden acceder al Service Worker Cache para ver partituras físicas en sótanos o lugares sin señal.

### ⚡ Comunicación True Realtime
- **Canto en Vivo:** El director señala instantáneamente qué canto se está interpretando.
- **Workarounds de RLS:** Renderizado optimista y "Sync Silenciosa" para reflejar cambios destructivos instantáneamente en el DOM, anulando retrasos de red o base de datos.
- **Pase de Invitado:** Deep linking (`/?ev=ID`) que permite a miembros de otras sedes visualizar setlists temporales sobrepasando las reglas de filtro de Supabase.

---

## 📚 Documentación de la Arquitectura

Hemos documentado detalladamente el código fuente (`/src`) para garantizar la mantenibilidad y evolución. Todos los documentos están localizados en la carpeta `/docs/`:

1. **[🏗️ Mapa de Arquitectura](docs/MAPA_ARQUITECTURA.md):** Guía maestra de cómo están conectados todos los módulos (`/src/app`, `/src/features`, `/src/core`, etc).
2. **[⚙️ Documentación Técnica](docs/DOCS_TECNICA.md):** Lógica del motor Offline, Service Workers, Web Workers y sincronización Realtime.
3. **[🎨 Arquitectura UI/Frontend](docs/ARQUITECTURA_FRONTEND.md):** Estándares de CSS Vanilla, componentes UI, gestos y accesibilidad.
4. **[🗄️ Contexto de Base de Datos](docs/contexto.md):** Estructura de tablas en Supabase y roles de seguridad (RBAC).
5. **[📖 Guía de Usuario](docs/GUIA_USUARIO.md):** Manual destinado a directores y coristas sobre cómo usar la PWA día a día.

---

## 🚀 Instalación y Desarrollo Local

1. **Clonación:**
   ```bash
   git clone https://github.com/tu-usuario/corolldm.git
   cd corolldm
   ```
2. **Dependencias:**
   ```bash
   npm install
   ```
3. **Entorno:** 
   Crea un archivo `.env` en la raíz con tus claves públicas de Supabase:
   ```env
   VITE_SUPABASE_URL=tu_url
   VITE_SUPABASE_ANON_KEY=tu_key
   ```
4. **Desarrollo:**
   ```bash
   npm run dev
   ```
5. **Pruebas (Vitest & Playwright):**
   ```bash
   npm run test      # Unit testing
   npm run test:e2e  # Flujos E2E en Chromium
   ```
6. **Construcción:**
   ```bash
   npm run build
   ```

---

## 📄 Licencia

Este proyecto es de uso privado para la organización Coros BC.
