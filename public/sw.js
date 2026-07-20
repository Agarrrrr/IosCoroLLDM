import { precacheAndRoute, matchPrecache } from 'workbox-precaching';
import { NavigationRoute, registerRoute } from 'workbox-routing';

// 1. Inyectar el manifiesto de precache de Vite (Maneja instalación y limpieza automáticamente)
precacheAndRoute(self.__WB_MANIFEST);

// 2. Enrutamiento de navegación (SPA Fallback) a prueba de balas
const navigationHandler = async ({ request }) => {
  try {
    const response = await fetch(request);
    
    // RUNTIME CACHING: Guardamos una copia de la página navegada con éxito
    // Esto asegura que si el precache falla o es incompleto (común en dev), 
    // la página esté disponible la próxima vez.
    if (response.status === 200) {
        const cache = await caches.open('pages-runtime-cache');
        cache.put(request, response.clone());
    }
    
    return response;
  } catch (error) {
    console.warn('Modo offline: Sirviendo fallback desde caché de contingencia.');
    
    // 1. Intentar buscar en el caché de runtime (páginas visitadas)
    const runtimeCache = await caches.open('pages-runtime-cache');
    const runtimeResponse = await runtimeCache.match(request);
    if (runtimeResponse) return runtimeResponse;

    // 2. Ampliar matchPrecache para buscar también la raíz y la request original
    const cachedResponse = 
        await matchPrecache(request.url) ||
        await matchPrecache('/auth.html') ||
        await matchPrecache('/gestor.html') ||
        await matchPrecache('/') || 
        await matchPrecache('/index.html') || 
        await matchPrecache('index.html');
        
    if (cachedResponse) return cachedResponse;

    // 3. Construir URLs absolutas para evitar bugs de Safari con rutas relativas
    const urlIndex = new URL('/index.html', location.origin).href;
    const urlRoot = new URL('/', location.origin).href;

    // 4. Buscar usando la request completa y las URLs absolutas
    const urlAuth = new URL('/auth.html', location.origin).href;
    const urlGestor = new URL('/gestor.html', location.origin).href;

    const rawCache = 
        await caches.match(request) ||
        await caches.match(urlRoot, { ignoreSearch: true }) ||
        await caches.match(urlIndex, { ignoreSearch: true }) ||
        await caches.match(urlAuth, { ignoreSearch: true }) ||
        await caches.match(urlGestor, { ignoreSearch: true });
        
    if (rawCache) return rawCache;

    // 5. Fallback de seguridad vital para Safari (Reemplaza el "throw error;")
    return new Response(
      '<html><body><h2>Aplicación sin conexión. No se pudo cargar el caché.</h2></body></html>',
      { status: 503, headers: { 'Content-Type': 'text/html' } }
    );
  }
};
registerRoute(new NavigationRoute(navigationHandler));

// --- FIN DE ZONA WORKBOX ---

// 3. Caché Manual Dinámico (PDFs y MIDIs de Supabase Storage)
const CACHE_PDF = 'pdf-cache-v14';
const CACHE_MIDI = 'midi-cache-v1';

// Receptor de mensajes para precarga forzada de Audio
self.addEventListener('install', event => {
    self.skipWaiting();
    event.waitUntil((async () => {
        try {
            const cachePdf = await caches.open(CACHE_PDF);
            const cacheMidi = await caches.open(CACHE_MIDI);
            
            // Cargar Catálogos
            const resEs = await fetch('/offline_assets/catalogo.json');
            const cantosEs = resEs.ok ? await resEs.json() : [];
            
            const resEn = await fetch('/offline_assets/catalogo_en.json');
            const cantosEn = resEn.ok ? await resEn.json() : [];
            
            const cantos = [...cantosEs, ...cantosEn];
            
            // Precache PDFs
            const pdfs = cantos.map(c => `/offline_assets/pdfs/${c.archivo}`).filter(u => u && !u.includes('null'));
            const uniquePdfs = [...new Set(pdfs)];
            await cachePdf.addAll(uniquePdfs);
            
            // Precache MIDIs
            const midis = cantos.map(c => `/offline_assets/midis/${c.midi_archivo}`).filter(u => u && !u.includes('null'));
            const uniqueMidis = [...new Set(midis)];
            await cacheMidi.addAll(uniqueMidis);
            
            // Precache Piano Sounds
            const notas = ["A0","C1","Ds1","Fs1","A1","C2","Ds2","Fs2","A2","C3","Ds3","Fs3","A3","C4","Ds4","Fs4","A4","C5","Ds5","Fs5","A5","C6","Ds6","Fs6","A6","C7","Ds7","Fs7","C8"];
            const audioUrls = notas.map(n => `/audio/piano/${n}.mp3`);
            await cacheMidi.addAll(audioUrls);
            
            console.log('✅ Service Worker: Todo el repertorio precacheado (Offline Full)');
        } catch(e) {
            console.error('Error precacheando repertorio:', e);
        }
    })());
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (event.data && event.data.type === 'PRECACHE_AUDIO') {
      // Futuro: Lógica para descargar set completo de SoundFont
  }
});

// 4. Interceptor específico (Bypass, PDFs, MIDIs y SoundFonts)
self.addEventListener('fetch', event => {
    if (event.request.method !== 'GET') return;
    const url = new URL(event.request.url);
    if (!url.protocol.startsWith('http')) return;

    // A. INTERCEPTOR DE PDFs
    if (url.pathname.includes('/storage/v1/object/public/partituras/') || url.pathname.includes('/offline_assets/pdfs/')) {
        event.respondWith(
            caches.open(CACHE_PDF).then(cache => {
                return cache.match(event.request, { ignoreSearch: true }).then(response => {
                    return response || fetch(event.request).then(networkResponse => {
                        if (networkResponse && networkResponse.status === 200) {
                            cache.put(event.request, networkResponse.clone());
                        }
                        return networkResponse;
                    }).catch(() => {
                        return new Response('PDF no disponible offline', { status: 503 });
                    });
                });
            })
        );
        return; 
    }

    // B. INTERCEPTOR DE MIDIs y SOUNDFONTS (v2.0.0)
    if (url.pathname.includes('/storage/v1/object/public/midi_files/') || url.pathname.includes('/offline_assets/midis/') || url.pathname.includes('/audio/piano/')) {
        event.respondWith(
            caches.open(CACHE_MIDI).then(cache => {
                return cache.match(event.request, { ignoreSearch: true }).then(response => {
                    return response || fetch(event.request).then(networkResponse => {
                        if (networkResponse && networkResponse.status === 200) {
                            cache.put(event.request, networkResponse.clone());
                        }
                        return networkResponse;
                    }).catch(() => {
                        return new Response('Audio/MIDI no disponible offline', { status: 503 });
                    });
                });
            })
        );
        return;
    }

    // D. BYPASS CRÍTICO: Todo lo demás de Supabase (Auth, API) sale a la red
    if (event.request.url.includes('supabase.co') || event.request.url.startsWith('chrome-extension')) {
        return; 
    }
});

// 5. Manejo de Web Push Nativo (Segundo Plano Real)
self.addEventListener('push', function(event) {
    console.log('📩 Evento Push recibido en SW');
    let titulo = 'Nuevo Aviso en RepertorioBC';
    const origin = self.location.origin;
    let opciones = {
        body: 'Tienes una nueva notificación en tu sede.',
        icon: origin + '/assets/icono.png',
        badge: origin + '/assets/icono.png',
        vibrate: [200, 100, 200],
        tag: 'repertoriobc-notif',
        renotify: true,
        data: { url: origin + '/', tipo: 'RECORDATORIO', canto_id: null }
    };

    if (event.data) {
        try {
            const data = event.data.json();
            console.log('📦 Datos push recibidos:', data);
            titulo = data.title || titulo;
            opciones.body = data.body || opciones.body;
            
            opciones.data = {
                url: (data.url && data.url.startsWith('http')) ? data.url : origin + (data.url || '/'),
                canto_id: data.canto_id || null,
                tipo: data.tipo || 'VIVO'
            };
        } catch (e) {
            console.warn('⚠️ Error parseando push JSON, usando texto:', e);
            opciones.body = event.data.text() || opciones.body;
        }
    }

    // Intentar mostrar siempre, el permiso ya fue validado por el navegador al recibir el push
    event.waitUntil(
        self.registration.showNotification(titulo, opciones).catch(err => {
            console.error('❌ Error al mostrar notificación push:', err);
        })
    );
});

self.addEventListener('notificationclick', event => {
    event.notification.close();
    
    // Asegurar que exista data.url por si falló el parsing
    const urlToOpen = (event.notification.data && event.notification.data.url) ? event.notification.data.url : '/';
    
    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true }).then(windowClients => {
            // Si ya hay una ventana abierta de la app
            if (windowClients.length > 0) {
                const client = windowClients[0];
                if (event.notification.data && event.notification.data.canto_id) {
                    client.postMessage({ type: 'OPEN_CANTO', canto_id: event.notification.data.canto_id });
                }
                return client.focus();
            } else {
                // Si la app estaba completamente cerrada
                return clients.openWindow(urlToOpen);
            }
        })
    );
});