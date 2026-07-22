import { Capacitor } from '@capacitor/core';
import { decryptOffThread } from './decryptor.js';

let NativePdf = null;

// Caché de rutas temporales ya desencriptadas (evita re-desencriptar en cada apertura)
const _decryptedCache = new Map();

export const nativePdfBridge = {
    isNative: false,
    
    async init() {
        if (!Capacitor.isNativePlatform()) {
            this.isNative = false;
            return;
        }
        try {
            const { registerPlugin } = await import('@capacitor/core');
            // Verificación real: el proxy de registerPlugin nunca falla aunque el
            // plugin no exista en el bridge nativo. Comprobar disponibilidad real
            // para no entrar en modo nativo con un plugin fantasma.
            if (typeof Capacitor.isPluginAvailable === 'function' && !Capacitor.isPluginAvailable('NativePdf')) {
                console.warn('[NativePdf] Plugin no registrado en el bridge nativo, usando visor web (PDF.js).');
                this.isNative = false;
                return;
            }
            NativePdf = registerPlugin('NativePdf');
            this.isNative = true;
            
            // Escuchar cambios de página desde el plugin nativo
            NativePdf.addListener('pageChanged', ({ page }) => {
                if (window.pdfEngine) {
                    window.pdfEngine._nativePaginaActual = page + 1;
                    window.dispatchEvent(new CustomEvent('pdf-page-changed', {
                        detail: { page: page + 1 }
                    }));
                }
            });
            
            NativePdf.addListener('pdfClosed', () => {
                // Evitar doble cierre: si ya se está cerrando (desde closePdf), ignorar
                if (window.pdfEngine && !window.pdfEngine._cerrandoVisor) {
                    const contenedor = document.getElementById('contenedor-pdf');
                    window.pdfEngine.cerrarVisor(contenedor);
                }
            });

            // Tap nativo en la partitura -> alternar topbar
            NativePdf.addListener('pdfTapped', () => {
                if (window.pdfEngine && window.pdfEngine._modoNativo) {
                    this._toggleBars();
                }
            });
        } catch(e) {
            console.warn('[NativePdf] Plugin no disponible, usando JS fallback:', e);
            this.isNative = false;
        }
    },

    // ---- Control interno de barras ----
    _barsVisible: true,

    _toggleBars() {
        const barraSuperior = document.getElementById('barra-superior');
        if (!barraSuperior) return;
        const visible = barraSuperior.classList.toggle('barra-oculta');
        // visible=true -> clase REMOVIDA -> barras visibles
        const mostrar = !visible;
        this._barsVisible = mostrar;
        this.setBarsVisible(mostrar);
        // Ajustar el inset del PDF: si las barras se muestran, empujar el PDF hacia abajo
        const barraH = barraSuperior.offsetHeight || 64;
        this.setTopbarInset(mostrar ? barraH : 0);
    },

    _applyInitialInset() {
        const barraSuperior = document.getElementById('barra-superior');
        if (!barraSuperior) return;
        const barraH = barraSuperior.offsetHeight || 64;
        this.setTopbarInset(barraH);
    },
    
    async openPdf(archivo, startPage = 0) {
        if (!this.isNative || !NativePdf) return false;
        
        let overlay = null;
        let pageListener = null;
        try {
            const fileUri = await this._getDecryptedFileUri(archivo);
            if (!fileUri) return false;
            
            // Ponytail: un overlay simple sin frameworks
            overlay = document.createElement('div');
            overlay.style.cssText = `position:fixed;inset:0;z-index:9999;background:var(--color-pdf-fondo,#1b2430);display:flex;align-items:center;justify-content:center;transition:opacity 0.4s ease`;
            overlay.innerHTML = '<div class="spinner"></div>';
            document.body.appendChild(overlay);

            pageListener = await NativePdf.addListener('pageChanged', () => {
                overlay.style.opacity = '0';
                setTimeout(() => overlay.remove(), 400);
                pageListener?.remove();
            });

            const theme = localStorage.getItem('tema-ui') || 'claro';
            const modoPaginas = localStorage.getItem('modo-paginas') === 'true';
            const result = await NativePdf.openPdf({ path: fileUri, startPage, theme, modoPaginas });
            
            if (result && result.error) {
                console.error('[NativePdf] Error en openPdf:', result.error);
                overlay.remove();
                pageListener?.remove();
                return false;
            }

            requestAnimationFrame(() => this._applyInitialInset());
            return true;
        } catch(e) {
            console.error('[NativePdf] Error abriendo PDF nativo:', e);
            try { overlay?.remove(); } catch(_) {}
            try { pageListener?.remove(); } catch(_) {}
            return false;
        }
    },
    
    async updateDisplayMode(modoPaginas) {
        if (!this.isNative || !NativePdf) return;
        await NativePdf.updateDisplayMode({ modoPaginas });
    },

    async closePdf() {
        if (!this.isNative || !NativePdf) return;
        this.limpiarRects();
        try { await NativePdf.closePdf(); } catch(e) {}
    },
    
    async setTheme(theme) {
        if (!this.isNative || !NativePdf) return;
        try { await NativePdf.setTheme({ theme }); } catch(e) {}
    },
    
    async setDrawingMode(active) {
        if (!this.isNative || !NativePdf) return;
        try { await NativePdf.setDrawingMode({ active }); } catch(e) {}
    },
    
    async setBarsVisible(active) {
        if (!this.isNative || !NativePdf) return;
        try { await NativePdf.setBarsVisible({ active }); } catch(e) {}
    },

    async setTopbarInset(height) {
        if (!this.isNative) return;
        try { await NativePdf.setTopbarInset({ height }); } catch(e) {}
    },

    async setBottomInset(inset) {
        if (!this.isNative) return;
        try { await NativePdf.setBottomInset({ inset }); } catch(e) {}
    },

    async setInteractiveRects(rects) {
        if (!this.isNative || !NativePdf) return;
        try { await NativePdf.setInteractiveRects({ rects }); } catch(e) {}
    },

    // ---- Registro Centralizado de Rectángulos Interactivos Dinámicos ----
    _rectsActivos: new Map(),

    registrarRect(id, el) {
        if (!this.isNative || !el) return;
        requestAnimationFrame(() => {
            setTimeout(() => {
                const r = el.getBoundingClientRect();
                if (r.width > 0 && r.height > 0) {
                    this._rectsActivos.set(id, {
                        x: r.left,
                        y: r.top,
                        width: r.width,
                        height: r.height
                    });
                }
                this._sincronizarRects();
            }, 50);
        });
    },

    desregistrarRect(id) {
        if (!this.isNative) return;
        this._rectsActivos.delete(id);
        this._sincronizarRects();
    },

    limpiarRects() {
        if (!this.isNative) return;
        this._rectsActivos.clear();
        this._sincronizarRects();
    },

    _sincronizarRects() {
        const rects = Array.from(this._rectsActivos.values());
        this.setInteractiveRects(rects);
    },
    
    async jumpToPage(pageIndex) {
        if (!this.isNative || !NativePdf) return;
        try { await NativePdf.jumpToPage({ page: pageIndex }); } catch(e) {}
    },

    /**
     * Pre-carga (desencripta) un PDF en background para apertura instantánea.
     * Llamar desde pdfEngine.js cuando se anticipa que el usuario abrirá el PDF.
     */
    async preloadPdf(archivo) {
        if (!this.isNative || !archivo || archivo === 'null') return;
        if (_decryptedCache.has(archivo)) return; // Ya está en caché
        this._getDecryptedFileUri(archivo).catch(() => {}); // Fire & forget
    },

    /**
     * Desencripta el PDF, lo escribe al directorio Cache de la app y devuelve
     * su URI file:// para que PDFKit pueda leerlo directamente.
     */
    async _getDecryptedFileUri(archivo) {
        // Revisar caché primero
        if (_decryptedCache.has(archivo)) {
            return _decryptedCache.get(archivo);
        }

        const { Filesystem, Directory } = await import('@capacitor/filesystem');

        // 1. Intentar cargar desde disco offline (archivos descargados por el usuario)
        //    Si existe en Directory.Data, leerlo directo
        let encryptedBuffer = null;
        
        try {
            await Filesystem.stat({
                directory: Directory.Data,
                path: `offline_assets/pdfs/${archivo}`
            });
            // Existe en disco local — leer como base64 y convertir
            const fileResult = await Filesystem.readFile({
                directory: Directory.Data,
                path: `offline_assets/pdfs/${archivo}`
            });
            // fileResult.data es base64
            const base64 = fileResult.data;
            const binary = atob(base64);
            const bytes = new Uint8Array(binary.length);
            for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
            encryptedBuffer = bytes.buffer;
        } catch(e) {
            // No existe en disco local, buscar en assets del bundle (via fetch)
            encryptedBuffer = null;
        }

        // 2. Si no está en disco, buscarlo como asset empaquetado
        if (!encryptedBuffer) {
            try {
                const assetUrl = `/offline_assets/pdfs/${encodeURI(archivo)}`;
                const resp = await fetch(assetUrl);
                if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
                encryptedBuffer = await resp.arrayBuffer();
            } catch(e) {
                console.error('[NativePdf] No se pudo obtener el archivo:', archivo, e);
                return null;
            }
        }

        // 3. Desencriptar (la función detecta automáticamente si ya es un PDF limpio)
        let decryptedBuffer;
        try {
            const { decryptArrayBuffer } = await import('./decryptor.js');
            decryptedBuffer = await decryptArrayBuffer(encryptedBuffer);
        } catch(e) {
            console.error('[NativePdf] Error desencriptando:', archivo, e);
            return null;
        }

        // 4. Escribir el PDF limpio a Directory.Cache con nombre único
        const cacheName = `pdf_native_${archivo}`;
        try {
            // v4.2.0: Optimización - Usar FileReader nativo para conversión instantánea ArrayBuffer -> Base64
            // Evita el bucle en Javascript que tarda segundos en archivos grandes y bloquea la interfaz
            const blob = new Blob([decryptedBuffer], { type: 'application/pdf' });
            const base64 = await new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onloadend = () => {
                    if (typeof reader.result === 'string') {
                        const base64Data = reader.result.split(',')[1];
                        resolve(base64Data);
                    } else {
                        reject(new Error('Fallo al convertir PDF a base64'));
                    }
                };
                reader.onerror = reject;
                reader.readAsDataURL(blob);
            });
            
            await Filesystem.writeFile({
                directory: Directory.Cache,
                path: cacheName,
                data: base64
            });
            
            const uriResult = await Filesystem.getUri({
                directory: Directory.Cache,
                path: cacheName
            });
            
            const fileUri = uriResult.uri;
            _decryptedCache.set(archivo, fileUri);
            return fileUri;
        } catch(e) {
            console.error('[NativePdf] Error escribiendo PDF a cache:', e);
            return null;
        }
    }
};
