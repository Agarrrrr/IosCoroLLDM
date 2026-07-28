# Documentación Técnica - Coro LLDM

Este documento profundiza en las complejidades internas, motores lógicos, flujos de red y estrategias offline que operan "bajo el capó" de Coro LLDM.

---

## 1. 🔄 SyncQueue y Persistencia Offline (IndexedDB)
Para los directores, una mala conexión a internet durante un ensayo no puede ser un impedimento. Se implementó una **Cola de Mutaciones Sincrónicas (`syncQueue.js`)** mediante IndexedDB.

### El Flujo de Trabajo (Director)
1. **Acción Offline:** Un director elimina o agrega un canto a una carpeta, pero no hay red (o está en Modo Offline Forzado).
2. **Cola de Espera:** En vez de enviar la petición `fetch` a Supabase y recibir un error, la acción (`INSERT`, `UPDATE`, `DELETE`) y su payload se guardan en IndexedDB localmente.
3. **Renderizado Optimista:** El frontend repinta instantáneamente el DOM asumiendo que la acción fue un éxito. El director ve el cambio sin 1 milisegundo de latencia.
4. **Resincronización Silenciosa:** Cuando el navegador lanza el evento `online` o el `appInitializer.js` detecta red en un Cold Start, el `syncQueue` recorre los pendientes, efectúa las peticiones `supabase.from()...` en segundo plano, y borra las tareas de IndexedDB si reciben HTTP 200/201.

---

## 2. ⚡ Comunicación True Realtime y Workarounds (RLS)
La base de datos utiliza Row Level Security (RLS) en Postgres. Esto complica la distribución de eventos Realtime, particularmente los de eliminación.

### El Problema del "DELETE"
Supabase Realtime evalúa las políticas RLS *sobre el registro actual* para decidir a quién enviarle el evento por WebSocket. Sin embargo, si el registro se borró (`DELETE`), la fila ya no existe para ser evaluada, y el payload llega al cliente completamente vacío.

### La Solución: "SYNC_SILENCIOSA"
Para garantizar un *True Realtime*, se implementó un workaround a través de la tabla `avisos`:
1. Cuando un canto se desvincula de un coro, el servidor inserta un registro temporal en la tabla `avisos` con el tipo `SYNC_SILENCIOSA`.
2. Como los clientes están suscritos al canal `avisos-[sedeActual]`, reciben este mensaje.
3. El `realtimeManager.js` intercepta el payload, busca el `canto_id` en el `stateManager`, lo elimina de memoria y desencadena un re-renderizado del `dashboardUI`. El canto desaparece de las pantallas de todos los coristas de la sede al instante, anulando el RLS.

---

## 3. 🎫 Bypass de Seguridad: Pase de Invitado (Guest Pass)
Normalmente, un corista solo puede ver las carpetas de su propia Sede. Sin embargo, en eventos magnos (Eventos Estatales), miembros de otros municipios son invitados.

El **Guest Pass** soluciona esto usando Deep Linking:
- **URL Base:** `https://www.lldmcorobc.com/?ev=[UUID_CARPETA]`
- **Flujo `router.js`:** Cuando se abre el link, el router extrae el parámetro `ev`.
- **Almacenamiento Local:** El UUID se guarda en un array llamado `eventos_permanentes` en el `localStorage`.
- **Anulación de Filtros:** Cuando `eventosController.js` consulta las carpetas activas a Supabase, inyecta explícitamente una instrucción `.or('id.in.(...eventos_permanentes)')`. Esto obliga a Postgres a devolver el evento específico y sus cantos asociados, incluso si las políticas de la Sede local intentarían ocultarlo.

---

## 4. 🎛️ Multihilos y Web Workers (MIDI Parsing)
El decodificador MIDI (`@tonejs/midi`) realiza operaciones de parseo intensivas en CPU sobre archivos binarios (`.mid`).

### Hilo Principal vs Web Worker
Si el parseo de un archivo complejo con miles de notas ocurriera en el `visor.js` (hilo de UI principal), la aplicación se "congelaría" (Frame Drop de 60fps a 0fps) por entre 50ms y 500ms dependiendo del hardware, resultando en una experiencia tosca.

Para evitarlo, se delegó la carga pesada al `midiParser.worker.js`:
1. El `midiEngine.js` descarga el buffer binario del archivo.
2. Envía el buffer vía `postMessage()` al Web Worker.
3. El Worker hace la magia matemática y convierte el binario en un objeto JSON (Time/Note maps).
4. El Worker devuelve el JSON a `midiEngine.js`, el cual simplemente se lo alimenta al Sampler de ToneJS.

---

## 5. 🛠️ Build, Optimización y TWA
La aplicación utiliza `Vite` con configuraciones altamente específicas:

- **Legacy Mode (`@vitejs/plugin-legacy`):** Exporta un bundle ES5 con polyfills masivos para Safari 12.1. Esto penaliza el tamaño final del archivo, por lo que el `rollupOptions` implementa **code-splitting** agresivo (separando `vendor-supabase`, `vendor-pdf` y `vendor-legacy`).
- **Domain Unificado (`www.lldmcorobc.com`):** Un aspecto crítico. Para que Android OS valide la aplicación como una Trusted Web Activity (TWA) genuina y habilite privilegios (como ocultar por completo la barra de navegación de Chrome), el dominio en el archivo `public/.well-known/assetlinks.json` y el `manifest.json` **deben coincidir a la perfección**. Siempre se usa el subdominio `www`.

---

---

## 7. 🎹 Motor de Reproducción MIDI y Puente Nativo (iOS / WebAudio)

### A. Desbloqueo Síncrono de AudioContext
En iOS WebKit, el `AudioContext` arranca en estado `suspended` hasta ser reanudado síncronamente dentro de la pila de llamadas de una interacción explícita del usuario (`touchstart` / `click`).
- `midiEngine.desbloquearAudioSync()` ejecuta `rawCtx.resume()` y `Tone.start()` de forma estrictamente síncrona en el primer toque.
- Se eliminaron las esperas asíncronas de `Tone.loaded()` que causaban latencia inicial o timeouts de 15 segundos, marcando `instrumentoCargado = true` inmediatamente al terminar la decodificación de las muestras en memoria.

### B. Decodificación de Muestras Acústicas Reales
- **Compatibilidad con WebKit**: Se emplea `rawCtx.decodeAudioData(bufferCopy)` pasando un duplicado del buffer (`arrayBuffer.slice(0)`) para prevenir que Safari desasocie la memoria durante la decodificación.
- **Resolución de Assets del Bundle**: Las muestras (`audio/piano/*.mp3` y `audio/metro/*.mp3`) se resuelven mediante `new URL(cleanPath, window.location.href).href` (`capacitor://localhost/audio/piano/*.mp3`), garantizando que se lean directamente del paquete web empaquetado sin invocar `Capacitor.convertFileSrc` (el cual está reservado únicamente para archivos del sistema de archivos local de iOS).

### C. Jerarquía de Capas Nativas y Eventos Táctiles (PDFKit vs WKWebView)
- La vista de lectura de partituras utiliza un visor nativo `PDFView` (PDFKit) posicionado por debajo de la `WKWebView`.
- `TouchForwardView.hitTest` en `NativePDFPlugin.swift` retorna `nil`, delegando el control táctil a la `WKWebView`.
- En la interfaz web:
  - Los controles interactivos (botones Play, Voces, barra de progreso, menú de 3 puntos, opciones de Compartir y herramientas de Anotaciones) tienen CSS `pointer-events: auto`, recibiendo el 100% de la interactividad táctil inmediatamente.
  - La zona transparente de la partitura tiene CSS `pointer-events: none`, permitiendo que los gestos de scroll, cambio de página y pinch-zoom pasen de forma transparente al motor nativo `PDFView` subyacente.

