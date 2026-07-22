// Nota: Hemos bajado a la v4.x legacy porque la v5+ ya no soporta oficialmente navegadores tan antiguos como Safari 12.
// Además, Vite Legacy se encargará de transpilar el resto del código de la app.

import { store } from './stateManager.js';
import { partiturasController } from './partiturasController.js';
import { anotacionesManager } from './anotacionesManager.js';
import { localDB } from '../api/localDB.js';
import { decryptOffThread } from './decryptor.js';
import { limitsManager } from './limitsManager.js';

let pdfjsLibCargado = null;

// Detección de dispositivo legacy (Safari 12 / iOS 12)
const esLegacy = /iPad|iPhone|iPod/.test(navigator.userAgent) && 
                 (/OS 12_/.test(navigator.userAgent) || /Version\/12/.test(navigator.userAgent));

if (esLegacy) console.log("[PDF-DEBUG] Dispositivo Legacy detectado. Ajustando parámetros de rendimiento.");

export const pdfEngine = {
    nivelZoom: 100,
    modoDibujo: false,
    colorDibujo: '#000000',
    herramientaDibujo: 'lapiz', // 'lapiz' o 'borrador'
    pdfActual: null, // Referencia al documento activo para limpieza

    pdfActualPreview: null, // Referencia para vista previa rápida
    observador: null, // Referencia al observador para limpieza
    renderTasks: new Map(), // Control de tareas activas por pagina
    _midiPreloadTimeout: null, // v2.4.5: Referencia para cancelar pre-cargas colisionadas

    async _initPDF() {
        if (pdfjsLibCargado) return;

        // 1. Si el script defer en index.html ya se ejecutó y cargó globalThis
        if (window.pdfjsLib) {
            pdfjsLibCargado = window.pdfjsLib;
            pdfjsLibCargado.GlobalWorkerOptions.workerSrc = '/vendor/pdf.worker.legacy.min.js';
            pdfjsLibCargado.GlobalWorkerOptions.verbosity = pdfjsLibCargado.VerbosityLevel ? pdfjsLibCargado.VerbosityLevel.ERRORS : 0;
            return;
        }

        // 2. Si no, forzamos la inyección dinámica manual y esperamos
        try {

            await new Promise((resolve, reject) => {
                const script = document.createElement('script');
                script.src = '/vendor/pdf.legacy.min.js';
                script.onload = () => {
                    pdfjsLibCargado = window.pdfjsLib;
                    if (!pdfjsLibCargado) return reject(new Error("PDF.js global object missing after manual injection"));
                    
                    pdfjsLibCargado.GlobalWorkerOptions.workerSrc = '/vendor/pdf.worker.legacy.min.js';
                    pdfjsLibCargado.GlobalWorkerOptions.verbosity = pdfjsLibCargado.VerbosityLevel ? pdfjsLibCargado.VerbosityLevel.ERRORS : 0;
                    resolve();
                };
                script.onerror = () => reject(new Error("Failed to load PDF.js script natively"));
                document.head.appendChild(script);
            });
        } catch (error) {            console.error("[PDF-DEBUG] Error en Lazy Loading de PDF.js:", error);
            throw error;
        }
    },
    
    renderizarVistaPreviaRapida: async function(archivo, contenedor) {
        await this._initPDF();

        // --- LIMPIEZA DE MEMORIA: Destruir previa anterior ---
        if (this.pdfActualPreview) {
            try { 
                await this.pdfActualPreview.destroy(); 
                this.pdfActualPreview = null; 
            } catch (e) {
                console.warn("[PDF-DEBUG] Error al destruir preview previa:", e);
            }
        }

        const url = (archivo && archivo !== 'null') 
            ? localDB.resolverUrlPdf(archivo)
            : '';
            
        if (!url) {
            contenedor.innerHTML = '<p style="color:var(--text-secondary); text-align:center; margin-top:20px;">Esta partitura no tiene un PDF asociado.</p>';
            return;
        }
        
        contenedor.innerHTML = '';
        const pCarga = document.createElement('p');
        pCarga.style.cssText = 'text-align:center; color:var(--text-secondary); margin-top:20px;';
        pCarga.textContent = 'Generando vista previa...';
        contenedor.appendChild(pCarga);

        try {
            const decryptedBuffer = await decryptOffThread(url);
            const loadingTask = pdfjsLibCargado.getDocument(new Uint8Array(decryptedBuffer));
            const pdf = await loadingTask.promise;
            this.pdfActualPreview = pdf;
            
            contenedor.innerHTML = ''; 
            const numPages = Math.min(pdf.numPages, 2); 
            
            for (let i = 1; i <= numPages; i++) {
                const page = await pdf.getPage(i);
                const viewportRaw = page.getViewport({ scale: 1.0 });
                let previewScale = esLegacy ? 0.6 : 0.8;
                if (viewportRaw.width < 800) {
                    previewScale = previewScale * (800 / viewportRaw.width);
                }
                const viewport = page.getViewport({ scale: previewScale });
                const canvas = document.createElement('canvas');
                canvas.style.width = "100%";
                canvas.style.marginBottom = "10px";
                canvas.style.borderRadius = "8px";
                canvas.style.boxShadow = "0 4px 6px rgba(0,0,0,0.1)";
                
                const context = canvas.getContext('2d');
                const dpr = window.devicePixelRatio || 1;
                canvas.width = viewport.width * dpr;
                canvas.height = viewport.height * dpr;
                context.scale(dpr, dpr);
                
                contenedor.appendChild(canvas);
                await page.render({ canvasContext: context, viewport: viewport }).promise;
                page.cleanup(); 
            }

            if (pdf.numPages > 2) {
                const aviso = document.createElement('p');
                aviso.textContent = `+ ${pdf.numPages - 2} PÁGINAS ADICIONALES (VISTA PREVIA LIMITADA)`;
                aviso.style.cssText = "font-size: 10px; color: gray; text-align: center; margin-top: 10px; font-weight: 700;";
                contenedor.appendChild(aviso);
            }
        } catch (err) {
            console.error("[PDF-DEBUG] Error en vista previa:", err);
            contenedor.innerHTML = '<p style="color:red; text-align:center; margin-top:20px;">Error al cargar la previsualización.</p>';
        }
    },

    abrirVisor: async function(canto, contenedorPdf, barraSuperior) {
        if (canto.vinculo_idioma) {
            let prefIdioma = localStorage.getItem('idioma-partitura');
            if (!prefIdioma) {
                prefIdioma = navigator.language.startsWith('es') ? 'es' : 'en';
            }
            let esInglesPref = prefIdioma === 'en';
            let esInglesCanto = canto._idioma === 'en' || (canto.id && String(canto.id).startsWith('en_'));
            
            if (esInglesPref !== esInglesCanto && window.partiturasController) {
                try {
                    const globalData = await window.partiturasController.obtenerCatalogoGlobal();
                    const opuesto = globalData.find(c => c.id === canto.vinculo_idioma);
                    if (opuesto) canto = opuesto;
                } catch(e) {}
            }
        }

        limitsManager.registrarAperturaPdf();
        if (this._midiPreloadTimeout) {
            clearTimeout(this._midiPreloadTimeout);
            this._midiPreloadTimeout = null;
        }

        // v5.0: Intentar visor nativo primero - Inicializar bridge
        if (!this._nativeBridgeInit) {
            const { nativePdfBridge } = await import('./nativePdfBridge.js');
            await nativePdfBridge.init();
            this._nativeBridge = nativePdfBridge;
            this._nativeBridgeInit = true;
            // Exponer globalmente para diagnósticos on-device
            window.pdfEngine = this;
            window.nativePdfBridge = nativePdfBridge;
            
            // Escuchar cambios de página para actualizar el canvas de dibujo nativo
            window.addEventListener('pdf-page-changed', (e) => {
                if (this._modoNativo && this.pdfActual) {
                    this._nativePaginaActual = e.detail.page;
                    this.actualizarCanvasNativo(this.pdfActual.cantoId);
                }
            });
        }

        // --- PREPARACIÓN DE BOTONES AUXILIARES Y COMPARTIR/DESCARGAR (LÓGICA COMÚN) ---
        const btnCompartir = document.getElementById('btn-visor-compartir');
        const btnDescargar = document.getElementById('btn-descargar-pdf');
        
        const actualizarBotonesAuxiliares = (cantoActual) => {
            const btnVoces = document.getElementById('btn-visor-voces');
            if (btnVoces) {
                const tieneMidi = !!(cantoActual && (
                    (cantoActual.midi_archivo && cantoActual.midi_archivo !== 'null' && cantoActual.midi_archivo !== 'undefined') ||
                    (cantoActual.midi_url && cantoActual.midi_url !== 'null' && cantoActual.midi_url !== 'undefined') ||
                    (cantoActual.midiUrl && cantoActual.midiUrl !== 'null' && cantoActual.midiUrl !== 'undefined')
                ));
                btnVoces.style.display = tieneMidi ? 'flex' : 'none';
            }
            
            const btnDescargarPdf = document.getElementById('btn-descargar-pdf');
            if (btnDescargarPdf) {
                btnDescargarPdf.style.display = 'none'; // Desactivado permanentemente por request
            }
            
            const pdfUrl = (cantoActual && cantoActual.archivo && cantoActual.archivo !== 'null') ? localDB.resolverUrlPdf(cantoActual.archivo) : '';
            const nombrePdf = `${(cantoActual.nombre || 'Partitura').replace(/[<>:"\/\\|?*]+/g, '').trim()}.pdf`;

            if (btnCompartir && pdfUrl) {
                btnCompartir.style.display = 'flex';
                btnCompartir.onclick = (e) => {
                    e.stopPropagation();
                    decryptOffThread(pdfUrl).then(buffer => new Blob([buffer], { type: 'application/pdf' })).then(blob => {
                        if (navigator.share && navigator.canShare) {
                            const file = new File([blob], nombrePdf, { type: 'application/pdf' });
                            if (navigator.canShare({ files: [file] })) {
                                navigator.share({
                                    title: cantoActual.nombre,
                                    files: [file]
                                }).catch(()=>{});
                                return;
                            }
                        }
                        if (window.uiController) window.uiController.mostrarToast('No se puede compartir en este dispositivo', 'aviso');
                    }).catch(e => {
                        if (window.uiController) window.uiController.mostrarToast('Error al compartir', 'error');
                    });
                };
            }
        };

        // --- LÓGICA DEL SWITCH BILINGÜE ---
        const contenedorSwitch = document.getElementById('contenedor-switch-idioma');
        const toggleIdioma = document.getElementById('toggle-idioma-partitura');
        
        if (contenedorSwitch && toggleIdioma) {
            if (canto.vinculo_idioma) {
                contenedorSwitch.style.display = 'flex';
                let esIngles = canto._idioma === 'en' || (canto.id && String(canto.id).startsWith('en_'));
                toggleIdioma.checked = esIngles;
                
                let cantoActivo = canto;
                let cantoOpuesto = null;
                let ReactModule = null;
                let ReactPdfViewerModule = null;
                
                // Precarga de módulos para React
                import('react').then(m => ReactModule = m);
                import('./ReactPdfViewer.jsx').then(m => ReactPdfViewerModule = m);
                partiturasController.obtenerCatalogoGlobal().then(globalData => {
                    const targetId = (cantoActivo.id === canto.id) ? canto.vinculo_idioma : canto.id;
                    cantoOpuesto = globalData.find(c => c.id === targetId);
                });
                
                toggleIdioma.onchange = async (e) => {
                    const isChecked = e.target.checked;
                    
                    if (!this._modoNativo && (!cantoOpuesto || !ReactModule || !ReactPdfViewerModule)) {
                        e.target.checked = !isChecked;
                        if (window.mostrarToast) window.mostrarToast("Cargando partitura...", "info");
                        return;
                    }
                    
                    toggleIdioma.disabled = true;
                    try {
                        localStorage.setItem('idioma-partitura', isChecked ? 'en' : 'es');
                        cantoActivo = (cantoActivo.id === canto.id) ? cantoOpuesto : canto;
                        document.getElementById('titulo-canto').textContent = cantoActivo.nombre;
                        actualizarBotonesAuxiliares(cantoActivo);
                        
                        if (this._modoNativo) {
                            // En modo nativo recargar el archivo en el visor nativo
                            await this._nativeBridge.openPdf(cantoActivo.archivo);
                            this.pdfActual.cantoId = cantoActivo.id;
                            this._nativePaginaActual = 1;
                            this.actualizarCanvasNativo(cantoActivo.id);
                        } else if (this._reactRoot) {
                            this._reactRoot.render(ReactModule.createElement(ReactPdfViewerModule.default, { canto: cantoActivo }));
                            this.pdfActual.cantoId = cantoActivo.id;
                        }
                    } catch(err) {
                        console.error("Error al swapear partitura bilingüe:", err);
                        e.target.checked = !isChecked;
                    }
                    toggleIdioma.disabled = false;
                };
            } else {
                contenedorSwitch.style.display = 'none';
                toggleIdioma.onchange = null;
            }
        }
        
        actualizarBotonesAuxiliares(canto);

        // --- PRE-CARGA DEL REPRODUCTOR MIDI ---
        const rawMidi = (canto && (canto.midi_archivo || canto.midi_url || canto.midiUrl)) || '';
        const midiUrl = (rawMidi && rawMidi !== 'null' && rawMidi !== 'undefined')
            ? localDB.resolverUrlMidi(rawMidi)
            : '';

        if (midiUrl && window.visorUI) {
            window.visorUI.cargarMidi(midiUrl).catch(() => {});
        } else if (window.midiEngine) {
            this._midiPreloadTimeout = setTimeout(() => {
                window.midiEngine.inicializar().catch(() => {});
                this._midiPreloadTimeout = null;
            }, 2000);
        }

        // Telemetría
        try {
            const { perfil } = store.getState();
            if (perfil) partiturasController.registrarVistaCanto(canto.id, perfil.coro_id);
        } catch (e) {}

        // --- INTENTAR CARGA DE PDF NATIVO ---
        const archivo = canto.archivo;
        if (this._nativeBridge?.isNative && archivo && archivo !== 'null') {
            const opened = await this._nativeBridge.openPdf(archivo);
            if (opened) {
                this._modoNativo = true;
                this.pdfActual = { cantoId: canto.id, midiUrl: midiUrl };
                window.location.hash = 'visor';
                
                // El usuario pidió que el dashboard se mueva por encima del PDF.
                const vistaMenu = document.getElementById('vista-menu');
                const vistaVisor = document.getElementById('vista-visor');
                
                vistaVisor.style.display = 'block';
                vistaVisor.style.opacity = '1';
                
                vistaMenu.classList.remove('anim-dashboard-in');
                vistaMenu.classList.add('anim-dashboard-out');
                
                const onAnimationEndIn = (e) => {
                    if (e.animationName === 'dashboardOut') {
                        vistaMenu.style.display = 'none';
                        vistaMenu.removeEventListener('animationend', onAnimationEndIn);
                    }
                };
                vistaMenu.addEventListener('animationend', onAnimationEndIn);
                document.getElementById('titulo-canto').textContent = canto.nombre;
                const barraSuperior = document.getElementById('barra-superior');
                if (barraSuperior) {
                    barraSuperior.classList.remove('barra-oculta');
                    barraSuperior.style.display = 'flex';
                    barraSuperior.style.opacity = '1';
                }
                
                // Hacer el fondo completamente transparente para ver el PDFView nativo debajo
                document.getElementById('vista-visor').style.backgroundColor = 'transparent';
                document.documentElement.style.backgroundColor = 'transparent';
                document.body.style.backgroundColor = 'transparent';
                document.body.classList.add('con-visor');
                
                // Configurar contenedor-pdf y crear canvas overlay nativo
                const contenedor = document.getElementById('contenedor-pdf');
                contenedor.style.backgroundColor = 'transparent';
                contenedor.style.pointerEvents = 'none'; // Permite pasar gestos al PDFView nativo
                contenedor.innerHTML = '';
                
                const canvas = document.createElement('canvas');
                canvas.className = 'canvas-anotaciones native-overlay';
                canvas.style.cssText = "position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; z-index: 5;";
                contenedor.appendChild(canvas);
                
                // Dibujar y enlazar eventos para página 1
                this._nativePaginaActual = 1;
                this.actualizarCanvasNativo(canto.id);
                
                // Sincronizar anotaciones desde la nube en background
                anotacionesManager.bajarTrazosNube(canto.id).then(() => {
                    if (this.pdfActual && this.pdfActual.cantoId === canto.id) {
                        this.actualizarCanvasNativo(canto.id);
                    }
                }).catch(e => console.warn("[PDF] Error syncing strokes", e));
                
                return;
            }
        }

        // --- FALLBACK: RENDERIZADO CON PDF.JS Y REACT ---
        this._modoNativo = false;
        const contenedor = document.getElementById('contenedor-pdf');
        contenedor.style.pointerEvents = ''; // Resetear
        
        await this._initPDF();

        // --- LIMPIEZA DE MEMORIA ---
        if (this.pdfActual) {
            try { await this.pdfActual.destroy(); } catch(e) {}
            this.pdfActual = null;
        }
        if (this.observador) {
            this.observador.disconnect();
            this.observador = null;
        }
        this.renderTasks.forEach(task => { try { task.cancel(); } catch(e) {} });
        this.renderTasks.clear();

        window.location.hash = 'visor';
        
        // Sincronizar anotaciones y redibujar si es necesario
        anotacionesManager.bajarTrazosNube(canto.id).then(() => {
            if (this.pdfActual && this.pdfActual.cantoId === canto.id) {
                for (let pag in this.anotacionesEstado) {
                    this.anotacionesEstado[pag].trazos = anotacionesManager.obtenerTrazosLocal(canto.id, parseInt(pag)) || [];
                    this.forzarRedibujoAnotaciones(parseInt(pag));
                }
            }
        }).catch(e => console.warn("[PDF] Error syncing strokes", e));

        const vistaMenu = document.getElementById('vista-menu');
        const vistaVisor = document.getElementById('vista-visor');
        
        if (barraSuperior) {
            barraSuperior.style.display = 'flex';
            barraSuperior.style.opacity = '1';
        }
        
        vistaVisor.style.display = 'block';
        vistaVisor.classList.remove('anim-slide-in', 'anim-slide-out');
        
        vistaMenu.classList.remove('anim-dashboard-in', 'anim-dashboard-out');
        void vistaMenu.offsetWidth;
        vistaMenu.classList.add('anim-dashboard-out');
        
        const onAnimationEndOut = (e) => {
            if (e.animationName === 'dashboardOut') {
                vistaMenu.style.display = 'none';
                vistaMenu.removeEventListener('animationend', onAnimationEndOut);
            }
        };
        vistaMenu.addEventListener('animationend', onAnimationEndOut);
        document.getElementById('titulo-canto').textContent = canto.nombre;
        barraSuperior.classList.remove('barra-oculta');

        // Iniciar React híbrido
        const React = await import('react');
        window.React = React;
        const { createRoot } = await import('react-dom/client');
        const { default: ReactPdfViewer } = await import('./ReactPdfViewer.jsx');
        
        this.pdfActual = { cantoId: canto.id, midiUrl: midiUrl };
        
        if (!this._reactRoot) {
            contenedorPdf.innerHTML = '';
            this._reactRoot = createRoot(contenedorPdf);
            this._reactRootContainer = contenedorPdf;
        } else if (this._reactRootContainer !== contenedorPdf) {
            try { this._reactRoot.unmount(); } catch(e) {}
            contenedorPdf.innerHTML = '';
            this._reactRoot = createRoot(contenedorPdf);
            this._reactRootContainer = contenedorPdf;
        }
        
        this._reactRoot.render(React.createElement(ReactPdfViewer, { canto: canto }));

        // PREFETCHING HEURÍSTICO (1 segundo después para no competir con el render principal)
        if (this._prefetchTimeout) clearTimeout(this._prefetchTimeout);
        this._prefetchTimeout = setTimeout(() => {
            const state = store.getState();
            if (state.cantosVisibles && state.cantosVisibles.length > 0) {
                const idx = state.cantosVisibles.findIndex(c => c.id === canto.id);
                if (idx !== -1) {
                    const nextCanto = state.cantosVisibles[idx + 1];
                    const prevCanto = state.cantosVisibles[idx - 1];
                    
                    if (nextCanto && nextCanto.archivo && nextCanto.archivo !== 'null') {
                        const url = localDB.resolverUrlPdf(nextCanto.archivo);
                        if (url) decryptOffThread(url).catch(()=>{});
                    }
                    if (prevCanto && prevCanto.archivo && prevCanto.archivo !== 'null') {
                        const url = localDB.resolverUrlPdf(prevCanto.archivo);
                        if (url) decryptOffThread(url).catch(()=>{});
                    }
                }
            }
        }, 1000);
    },

    actualizarCanvasNativo: function(cantoId) {
        const canvas = document.querySelector('.canvas-anotaciones.native-overlay');
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        if (!ctx) return;
        
        const numPagina = this._nativePaginaActual || 1;
        canvas.setAttribute('data-pagina', numPagina); // Sincroniza con forzarRedibujoAnotaciones
        
        // Limpiar cualquier event listener viejo abortando su controlador
        const paginasAnteriores = Object.keys(this.anotacionesEstado);
        paginasAnteriores.forEach(p => {
            const estado = this.anotacionesEstado[p];
            if (estado?.abortController && !estado.abortController.signal.aborted) {
                estado.abortController.abort();
                estado.abortController = null;
            }
        });
        
        const rect = canvas.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;
        canvas.width = rect.width * dpr;
        canvas.height = rect.height * dpr;
        ctx.scale(dpr, dpr);
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        
        // Dibujar trazos guardados
        const trazos = anotacionesManager.obtenerTrazosLocal(cantoId, numPagina);
        ctx.clearRect(0, 0, rect.width, rect.height);
        if (trazos) {
            this.dibujarTrazos(ctx, trazos, rect.width, rect.height);
        }
        
        // Enlazar eventos de dibujo para la página actual
        this.bindEventosDibujo(canvas, ctx, numPagina, rect.width, rect.height, cantoId);
    },

    setModoDibujo: function(activo) {
        this.modoDibujo = activo;
        
        // Notificar al plugin nativo si estamos en iOS/Android
        if (this._modoNativo && this._nativeBridge) {
            this._nativeBridge.setDrawingMode(activo);
        }
        
        // Si estamos en modo nativo, controlar pointerEvents del contenedor y del canvas nativo
        if (this._modoNativo) {
            const contenedorPdf = document.getElementById('contenedor-pdf');
            if (contenedorPdf) {
                contenedorPdf.style.pointerEvents = activo ? 'auto' : 'none';
            }
            const canvasNativo = document.querySelector('.canvas-anotaciones.native-overlay');
            if (canvasNativo) {
                canvasNativo.style.pointerEvents = activo ? 'auto' : 'none';
                canvasNativo.style.backgroundColor = activo ? 'rgba(255,255,255,0.01)' : 'transparent';
            }
            document.body.classList.toggle('modo-dibujo', activo);
        }
        
        const canvases = document.querySelectorAll('.canvas-anotaciones');
        canvases.forEach(c => {
            c.style.pointerEvents = activo ? 'auto' : 'none';
        });

        const btnAnotar = document.getElementById('btn-visor-anotar');
        const overlayAnotaciones = document.getElementById('overlay-anotaciones-tools');
        if (btnAnotar) btnAnotar.style.color = activo ? '#3b82f6' : '';
        if (overlayAnotaciones) {
            overlayAnotaciones.style.display = activo ? 'flex' : 'none';
            if (activo) {
                overlayAnotaciones.classList.remove('anim-pop-in');
                void overlayAnotaciones.offsetWidth;
                overlayAnotaciones.classList.add('anim-pop-in');
            }
        }
        
        // Bloquear scroll si está activo
        const contenedor = document.getElementById('visor-pdf');
        if (contenedor) {
            contenedor.style.overflow = activo ? 'hidden' : 'auto';
        }
    },

    tamanoTexto: 24,

    dibujarTrazos: function(ctx, trazos, width, height) {
        // v4.0.1: Seguridad estricta de estado (Previene el bug de cambio de tamaño al Deshacer en iOS)
        if (ctx.resetTransform) ctx.resetTransform();
        else ctx.setTransform(1, 0, 0, 1, 0, 0); // Fallback Safari antiguo

        ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
        
        // v4.0.2: Usar relación intrínseca del canvas en lugar de un devicePixelRatio dinámico.
        // En iOS Safari, hacer pinch-to-zoom altera el window.devicePixelRatio en tiempo real.
        // Si usamos el dinámico, el canvas (que se creó con un DPR fijo) dibujará todo desfasado.
        const scaleX = ctx.canvas.width / width;
        const scaleY = ctx.canvas.height / height;
        ctx.scale(scaleX, scaleY);

        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';

        if (!trazos || trazos.length === 0) return;

        trazos.forEach(trazo => {
            if (trazo.herramienta === 'texto') {
                if (trazo.oculto) return;
                ctx.globalCompositeOperation = "source-over";
                ctx.fillStyle = trazo.color || '#000000';
                const fontSize = (trazo.size || 24) * (width / 1000);
                ctx.font = `bold ${fontSize}px sans-serif`;
                ctx.textBaseline = 'bottom';
                ctx.fillText(trazo.texto, trazo.pos.x * width, trazo.pos.y * height);
                return;
            }

            if (!trazo.puntos || trazo.puntos.length < 2) return;
            ctx.beginPath();
            ctx.strokeStyle = trazo.color || '#000000';
            ctx.lineWidth = (width / 1000) * (trazo.herramienta === 'borrador' ? 20 : (trazo.size || 3));
            
            if (trazo.herramienta === 'borrador') {
                ctx.globalCompositeOperation = "destination-out";
            } else {
                ctx.globalCompositeOperation = "source-over";
            }

            const p0 = trazo.puntos[0];
            ctx.moveTo(p0.x * width, p0.y * height);
            for (let i = 1; i < trazo.puntos.length; i++) {
                const p = trazo.puntos[i];
                ctx.lineTo(p.x * width, p.y * height);
            }
            ctx.stroke();
        });
        ctx.globalCompositeOperation = "source-over";
    },

    anotacionesEstado: {},

    ultimaPaginaModificada: 1,

    deshacerAnotacion: function() {
        const pag = this.ultimaPaginaModificada;
        const estado = this.anotacionesEstado[pag];
        if (estado && estado.trazos.length > 0) {
            estado.redoStack.push(estado.trazos.pop());
            anotacionesManager.guardarTrazoLocal(estado.cantoId, pag, estado.trazos);
            this.forzarRedibujoAnotaciones(pag);
        }
    },

    rehacerAnotacion: function() {
        const pag = this.ultimaPaginaModificada;
        const estado = this.anotacionesEstado[pag];
        if (estado && estado.redoStack.length > 0) {
            estado.trazos.push(estado.redoStack.pop());
            anotacionesManager.guardarTrazoLocal(estado.cantoId, pag, estado.trazos);
            this.forzarRedibujoAnotaciones(pag);
        }
    },

    borrarAnotaciones: function() {
        for (const pag in this.anotacionesEstado) {
            const estado = this.anotacionesEstado[pag];
            if (estado && estado.trazos.length > 0) {
                estado.redoStack = [...estado.trazos].reverse().concat(estado.redoStack);
                estado.trazos = [];
                anotacionesManager.guardarTrazoLocal(estado.cantoId, pag, estado.trazos);
                this.forzarRedibujoAnotaciones(pag);
            }
        }
    },

    forzarRedibujoAnotaciones: function(numPagina) {
        const canvas = document.querySelector(`.canvas-anotaciones[data-pagina="${numPagina}"]`);
        if (canvas) {
            const ctx = canvas.getContext('2d');
            const dpr = window.devicePixelRatio || 1;
            const width = canvas.width / dpr;
            const height = canvas.height / dpr;
            ctx.clearRect(0, 0, width, height); // Limpiar frame previo
            this.dibujarTrazos(ctx, this.anotacionesEstado[numPagina].trazos, width, height);
        }
    },

    bindEventosDibujo: function(canvas, ctx, numPagina, width, height, cantoId) {
        let isDrawing = false;
        let trazoActual = null;
        let draggingTextoIndex = -1;
        let hasMoved = false;
        let posNuevoTexto = null;
        
        if (!this.anotacionesEstado[numPagina]) {
            this.anotacionesEstado[numPagina] = {
                trazos: anotacionesManager.obtenerTrazosLocal(cantoId, numPagina),
                redoStack: [],
                abortController: new AbortController(),
                cantoId: cantoId
            };
        } else if (!this.anotacionesEstado[numPagina].abortController) {
            this.anotacionesEstado[numPagina].abortController = new AbortController();
        }
        const estado = this.anotacionesEstado[numPagina];
        const signal = estado.abortController.signal;

        const getPos = (e) => {
            const rect = canvas.getBoundingClientRect();
            let clientX, clientY;
            if (e.touches && e.touches.length > 0) {
                clientX = e.touches[0].clientX;
                clientY = e.touches[0].clientY;
            } else {
                clientX = e.clientX;
                clientY = e.clientY;
            }
            return {
                x: (clientX - rect.left) / rect.width,
                y: (clientY - rect.top) / rect.height
            };
        };

        const estaEnBoundingBox = (posClick, trazo) => {
            if (trazo.herramienta !== 'texto') return false;
            const fontSize = (trazo.size || 24) * (width / 1000);
            ctx.font = `bold ${fontSize}px sans-serif`;
            const metrics = ctx.measureText(trazo.texto);
            const w = metrics.width / width; 
            const h = fontSize / height;     
            
            const px = trazo.pos.x;
            const py = trazo.pos.y;
            
            return (posClick.x >= px && posClick.x <= px + w &&
                    posClick.y >= py - h && posClick.y <= py + (h * 0.2));
        };

        const crearInputTexto = (trazoExistente, index, pos) => {
            const input = document.createElement('input');
            input.type = 'text';
            input.value = trazoExistente ? trazoExistente.texto : '';
            input.style.position = 'absolute';
            
            const fontSizeCSS = (pdfEngine.tamanoTexto || 24) * (canvas.width / (window.devicePixelRatio || 1) / 1000);
            const rect = canvas.getBoundingClientRect();
            const px = pos.x * rect.width;
            const py = pos.y * rect.height;
            
            input.style.left = px + 'px';
            input.style.top = (py - fontSizeCSS) + 'px';
            input.style.fontSize = fontSizeCSS + 'px';
            input.style.fontWeight = 'bold';
            input.style.color = pdfEngine.colorDibujo || '#000000';
            input.style.fontFamily = 'sans-serif';
            input.style.background = 'rgba(255, 255, 255, 0.8)';
            input.style.border = '1px dashed #ccc';
            input.style.outline = 'none';
            input.style.minWidth = '150px';
            input.style.zIndex = '2000';
            input.style.borderRadius = '4px';
            input.style.padding = '0 4px';
            
            const wrapper = canvas.parentElement;
            wrapper.style.position = 'relative';
            wrapper.appendChild(input);
            
            if (trazoExistente) {
                trazoExistente.oculto = true;
                pdfEngine.dibujarTrazos(ctx, estado.trazos, width, height);
            }

            setTimeout(() => input.focus(), 50);

            let finalizado = false;
            const finalizarEdicion = () => {
                if (finalizado) return;
                finalizado = true;
                const val = input.value.trim();
                
                if (trazoExistente) {
                    delete trazoExistente.oculto;
                    if (val === '') {
                        estado.redoStack.push(estado.trazos[index]);
                        estado.trazos.splice(index, 1);
                    } else {
                        trazoExistente.texto = val;
                        trazoExistente.color = pdfEngine.colorDibujo || '#000000';
                        trazoExistente.size = pdfEngine.tamanoTexto || 24;
                    }
                } else if (val !== '') {
                    estado.trazos.push({
                        herramienta: 'texto',
                        texto: val,
                        pos: pos,
                        color: pdfEngine.colorDibujo || '#000000',
                        size: pdfEngine.tamanoTexto || 24
                    });
                    estado.redoStack = [];
                }
                
                if (input.parentNode) wrapper.removeChild(input);
                anotacionesManager.guardarTrazoLocal(cantoId, numPagina, estado.trazos);
                pdfEngine.dibujarTrazos(ctx, estado.trazos, width, height);
            };

            input.addEventListener('blur', finalizarEdicion);
            input.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') finalizarEdicion();
            });
        };

        const onStart = (e) => {
            if (!pdfEngine.modoDibujo) return;
            if (e.touches && e.touches.length > 1) return; // Ignorar multi-touch
            e.preventDefault();
            hasMoved = false;
            const pos = getPos(e);

            if (pdfEngine.herramientaDibujo === 'borrador') {
                const index = estado.trazos.findIndex(t => estaEnBoundingBox(pos, t));
                if (index !== -1) {
                    estado.redoStack.push(estado.trazos[index]);
                    estado.trazos.splice(index, 1);
                    anotacionesManager.guardarTrazoLocal(cantoId, numPagina, estado.trazos);
                    pdfEngine.dibujarTrazos(ctx, estado.trazos, width, height);
                    return;
                }
            }

            if (pdfEngine.herramientaDibujo === 'texto') {
                const index = estado.trazos.findIndex(t => estaEnBoundingBox(pos, t));
                if (index !== -1) {
                    draggingTextoIndex = index;
                    isDrawing = true;
                    return;
                }
                posNuevoTexto = pos;
                isDrawing = true;
                return;
            }

            isDrawing = true;
            trazoActual = {
                color: pdfEngine.colorDibujo,
                herramienta: pdfEngine.herramientaDibujo,
                puntos: [pos],
                size: pdfEngine.grosorLapiz || 3
            };
        };

        const onMove = (e) => {
            if (!isDrawing || !pdfEngine.modoDibujo) return;
            if (e.touches && e.touches.length > 1) return;
            e.preventDefault();
            hasMoved = true;
            const pos = getPos(e);
            
            if (draggingTextoIndex !== -1) {
                estado.trazos[draggingTextoIndex].pos = pos;
                pdfEngine.dibujarTrazos(ctx, estado.trazos, width, height);
                return;
            }

            if (pdfEngine.herramientaDibujo === 'borrador') {
                const indexesABorrar = [];
                estado.trazos.forEach((t, i) => {
                    if (estaEnBoundingBox(pos, t)) indexesABorrar.push(i);
                });
                if (indexesABorrar.length > 0) {
                    for (let i = indexesABorrar.length - 1; i >= 0; i--) {
                        estado.redoStack.push(estado.trazos[indexesABorrar[i]]);
                        estado.trazos.splice(indexesABorrar[i], 1);
                    }
                    anotacionesManager.guardarTrazoLocal(cantoId, numPagina, estado.trazos);
                    pdfEngine.dibujarTrazos(ctx, [...estado.trazos, trazoActual], width, height);
                }
            }

            if (trazoActual && trazoActual.herramienta !== 'texto') {
                trazoActual.puntos.push(pos);
                pdfEngine.ultimaPaginaModificada = numPagina;
                pdfEngine.dibujarTrazos(ctx, [...estado.trazos, trazoActual], width, height);
            }
        };

        const onEnd = (e) => {
            if (!isDrawing || !pdfEngine.modoDibujo) return;
            e.preventDefault();
            isDrawing = false;
            
            if (pdfEngine.herramientaDibujo === 'texto') {
                if (draggingTextoIndex !== -1) {
                    if (!hasMoved) {
                        crearInputTexto(estado.trazos[draggingTextoIndex], draggingTextoIndex, estado.trazos[draggingTextoIndex].pos);
                    }
                    draggingTextoIndex = -1;
                    anotacionesManager.guardarTrazoLocal(cantoId, numPagina, estado.trazos);
                    pdfEngine.dibujarTrazos(ctx, estado.trazos, width, height);
                    return;
                }
                if (posNuevoTexto && !hasMoved) {
                    crearInputTexto(null, -1, posNuevoTexto);
                }
                posNuevoTexto = null;
                return;
            }

            if (trazoActual && trazoActual.puntos && trazoActual.puntos.length > 1) {
                estado.trazos.push(trazoActual);
                estado.redoStack = []; 
                anotacionesManager.guardarTrazoLocal(cantoId, numPagina, estado.trazos);
                pdfEngine.ultimaPaginaModificada = numPagina;
            }
            trazoActual = null;
            pdfEngine.dibujarTrazos(ctx, estado.trazos, width, height);
        };

        canvas.addEventListener('mousedown', onStart, { passive: false, signal });
        canvas.addEventListener('mousemove', onMove, { passive: false, signal });
        window.addEventListener('mouseup', onEnd, { passive: false, signal });

        canvas.addEventListener('touchstart', onStart, { passive: false, signal });
        canvas.addEventListener('touchmove', onMove, { passive: false, signal });
        window.addEventListener('touchend', onEnd, { passive: false, signal });
    },
    cerrarVisor: function(contenedorPdf) {
        if (this._prefetchTimeout) {
            clearTimeout(this._prefetchTimeout);
            this._prefetchTimeout = null;
        }

        if (this._modoNativo && this._nativeBridge) {
            this._nativeBridge.closePdf();
            document.body.classList.remove('con-visor');
            document.body.classList.remove('modo-dibujo');
        }

        if (this.observador) {
            this.observador.disconnect();
            this.observador = null;
        }

        this.anotacionesEstado = {}; 
        this.setModoDibujo(false);
        
        if (this.renderTasks) {
            this.renderTasks.forEach(task => {
                try { task.cancel(); } catch(e) {}
            });
            this.renderTasks.clear();
        }

        // v2.0.0: Resetear Reproductor MIDI al cerrar
        if (window.visorUI && typeof window.visorUI.resetMidiUI === 'function') {
            window.visorUI.resetMidiUI();
        }

        const vistaMenu = document.getElementById('vista-menu');
        const vistaVisor = document.getElementById('vista-visor');
        const barraSuperior = document.getElementById('barra-superior');
        
        // Ocultar topbar al instante para que no estorbe visualmente mientras el dashboard entra
        if (barraSuperior) {
            barraSuperior.style.opacity = '0';
        }

        vistaMenu.style.display = 'flex';
        vistaMenu.classList.remove('anim-dashboard-out');
        vistaMenu.classList.remove('anim-dashboard-in');
        
        // Forzar reflow para que la animación reinicie y dispare el evento
        void vistaMenu.offsetWidth;
        
        vistaMenu.classList.add('anim-dashboard-in');

        const onAnimationEndOut = (e) => {
            if (e.animationName === 'dashboardIn') {
                vistaVisor.style.display = 'none';
                vistaVisor.style.backgroundColor = '';
                document.getElementById('contenedor-pdf').style.backgroundColor = '';
                document.documentElement.style.backgroundColor = '';
                document.body.style.backgroundColor = '';
                vistaMenu.removeEventListener('animationend', onAnimationEndOut);
                
                // PREVENCIÓN DE FUGAS DE MEMORIA: Desmontaje real de React
                // Anterior: render({ canto: null }) NO llamaba cleanup de useEffect, dejando
                // addEventListener('visibilitychange') + IntersectionObserver + canvas VRAM
                // activos indefinidamente tras ~30 PDFs → canvas negros → crash en Android.
                if (this._reactRoot) {
                    try {
                        this._reactRoot.unmount(); // Dispara cleanup de todos los useEffect
                        this._reactRoot = null;
                    } catch(e) {
                        console.warn('[PDF] Error en unmount:', e);
                    }
                    if (contenedorPdf) contenedorPdf.innerHTML = '';
                }
            }
        };
        vistaMenu.addEventListener('animationend', onAnimationEndOut);


        // Mostrar Intersticial si ya superó el límite sin anuncios de hoy
        if (limitsManager.debeMostrarIntersticial() && window.adManager) {
            window.adManager.mostrarIntersticial();
        }

        // Restaurar Banner inferior al volver al Index
        if (window.adManager) {
            window.adManager.mostrarBannerInferior();
        }
    },

    /**
     * Elimina referencias y finaliza workers activos.
     * Llamar para liberar toda la memoria asociada al motor de PDF.
     */
    limpiarMotorPdf: async function() {
        if (this.pdfActual) {
            try { await this.pdfActual.destroy(); } catch(e) {}
            this.pdfActual = null;
        }
        if (this.pdfActualPreview) {
            try { await this.pdfActualPreview.destroy(); } catch(e) {}
            this.pdfActualPreview = null;
        }
        if (this.observador) {
            this.observador.disconnect();
            this.observador = null;
        }
    }
};