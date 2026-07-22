/**
 * globalErrorHandler.js
 * Actúa como un "Error Boundary" a nivel de aplicación para Vanilla JS.
 * Captura fallos críticos (como excepciones de PDF.js o del Service Worker)
 * y muestra una interfaz de rescate en lugar de una pantalla blanca.
 */

export const globalErrorHandler = {
    iniciar() {
        if (typeof window === 'undefined') return;

        // Captura errores de sintaxis o ejecución síncrona
        window.addEventListener('error', (event) => {
            var msg = event.message || 'Error desconocido';
            var stack = null;
            if (event.error && event.error.stack) {
                stack = event.error.stack;
            }
            this.mostrarPantallaFallo(msg, event.filename, event.lineno, stack);
        });

        // Captura promesas rechazadas sin un bloque catch
        window.addEventListener('unhandledrejection', (event) => {
            var reason = event.reason;
            console.error("[UnhandledRejection] Promesa no manejada capturada:", reason);
        });
    },

    async reportarError(mensaje, origen, linea, stackTrace) {
        // En modo offline estático, la telemetría está desactivada.
        console.error("TELEMETRIA LOCAL:", { mensaje, origen, linea, stackTrace });
    },

    mostrarPantallaFallo(mensaje, origen, linea, stackTrace = null) {
        // Ignoramos errores inofensivos que suelen ocurrir por extensiones del navegador
        if (mensaje && mensaje.includes('ResizeObserver')) return;
        if (mensaje && mensaje.includes('Extension')) return;
        if (mensaje === 'Script error.') return; // Ignorar errores genéricos de scripts cross-origin

        console.error(`[CRÍTICO] Error Global Capturado: ${mensaje} en ${origen}:${linea}`);
        
        // Reportar el error de forma silenciosa a la telemetría de Supabase
        this.reportarError(mensaje, origen, linea, stackTrace);

        // Si ya existe la pantalla de error, no la duplicamos
        if (document.getElementById('error-boundary-overlay')) return;

        const overlay = document.createElement('div');
        overlay.id = 'error-boundary-overlay';
        overlay.style.cssText = `
            position: fixed;
            top: 0; left: 0; width: 100vw; height: 100vh;
            background-color: #fdfdfd;
            z-index: 999999;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 20px;
            text-align: center;
            font-family: system-ui, -apple-system, sans-serif;
            color: #333;
        `;

        const icono = document.createElement('div');
        icono.innerHTML = `<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#ef4444" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>`;
        icono.style.marginBottom = '20px';

        const titulo = document.createElement('h2');
        titulo.textContent = 'ALGO SALIÓ MAL';
        titulo.style.color = '#ef4444';
        titulo.style.margin = '0 0 10px 0';

        const desc = document.createElement('p');
        desc.textContent = 'La aplicación encontró un error inesperado y no puede continuar.';
        desc.style.marginBottom = '20px';

        const debugInfo = document.createElement('code');
        debugInfo.textContent = `${mensaje.substring(0, 100)}...`;
        debugInfo.style.cssText = `
            display: block;
            background: #f1f5f9;
            padding: 10px;
            border-radius: 6px;
            font-size: 12px;
            color: #64748b;
            margin-bottom: 30px;
            max-width: 90%;
            word-break: break-all;
        `;

        const btnRecargar = document.createElement('button');
        btnRecargar.textContent = 'RECARGAR APLICACIÓN';
        btnRecargar.style.cssText = `
            padding: 12px 24px;
            background-color: #D4AF37;
            color: white;
            border: none;
            border-radius: 8px;
            font-weight: bold;
            font-size: 14px;
            cursor: pointer;
            width: 100%;
            max-width: 300px;
            margin-bottom: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        `;
        btnRecargar.onclick = () => window.location.reload();

        const btnLimpiar = document.createElement('button');
        btnLimpiar.textContent = 'RESTABLECER DE FÁBRICA';
        btnLimpiar.style.cssText = `
            padding: 12px 24px;
            background-color: transparent;
            color: #ef4444;
            border: 2px solid #ef4444;
            border-radius: 8px;
            font-weight: bold;
            font-size: 14px;
            cursor: pointer;
            width: 100%;
            max-width: 300px;
        `;
        btnLimpiar.onclick = async () => {
            if (confirm("Esto borrará la caché offline y cerrará tu sesión. ¿Proceder?")) {
                btnLimpiar.textContent = "RESTABLECIENDO...";
                localStorage.clear();
                if ('caches' in window) {
                    try {
                        const keys = await caches.keys();
                        await Promise.all(keys.map(key => caches.delete(key)));
                    } catch (e) {}
                }
                window.location.replace('/auth.html');
            }
        };

        overlay.append(icono, titulo, desc, debugInfo, btnRecargar, btnLimpiar);
        document.body.appendChild(overlay);
    }
};
