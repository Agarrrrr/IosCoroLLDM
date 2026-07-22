import { pdfEngine } from '../core/pdfEngine.js';
import { midiEngine } from '../core/midiEngine.js';
import { uiController } from './uiController.js';
import { limitsManager } from '../core/limitsManager.js';
import { i18n } from '../core/i18n.js';
import { nativePdfBridge } from '../core/nativePdfBridge.js';
/**
 * @typedef {{ soprano:number, alto:number, tenor:number, bajo:number }} TracksSatb
 */

/** @type {any} */
const win = window;

export const visorUI = {
    pinchZoomando: false,
    distanciaInicial: 0,
    zoomInicial: 100,
    ultimoScroll: 0,
    centroToqueX: 0, centroToqueY: 0,
    porcentajeX: 0, porcentajeY: 0,
    touchStartX: 0, touchStartY: 0,
    currentScale: 1,
    focalX: 0,
    focalY: 0,
    visorController: null,
    midiCargado: false,
    midiIntervalId: null,
    isDraggingSlider: false,

    /**
     * @param {HTMLElement} contenedorPdf
     * @param {HTMLElement} btnResetZoom
     * @param {HTMLElement} barraSuperior
     */
    iniciarEventos: function(contenedorPdf, btnResetZoom, barraSuperior) {
        if (this.visorController) this.visorController.abort();
        this.visorController = new AbortController();
        const signal = this.visorController.signal;

        // v2.6.0: Variables para Zoom de precisión
        this.currentScale = 1;
        this.focalX = 0;
        this.focalY = 0;

        // Menú Tres Puntos (Móvil)
        const btnOpciones = document.getElementById('btn-visor-mas-opciones');
        const menuOpciones = document.getElementById('contenedor-botones-secundarios');
        if (btnOpciones && menuOpciones) {
            btnOpciones.addEventListener('click', (e) => {
                e.stopPropagation();
                if (window.innerWidth <= 600) {
                    const abrir = (menuOpciones.style.display !== 'flex');
                    menuOpciones.style.display = abrir ? 'flex' : 'none';
                    if (window.pdfEngine && window.pdfEngine._modoNativo && window.pdfEngine._nativeBridge) {
                        window.pdfEngine._nativeBridge.setBarsVisible(!abrir).catch(()=>{});
                    }
                }
            }, { signal });

            document.addEventListener('click', (e) => {
                if (window.innerWidth <= 600 && menuOpciones.style.display === 'flex') {
                    if (e.target instanceof Node && !menuOpciones.contains(e.target) && e.target !== btnOpciones) {
                        menuOpciones.style.display = 'none';
                        if (window.pdfEngine && window.pdfEngine._modoNativo && window.pdfEngine._nativeBridge) {
                            window.pdfEngine._nativeBridge.setBarsVisible(true).catch(()=>{});
                        }
                    }
                }
            }, { signal });

            menuOpciones.querySelectorAll('button').forEach(btn => {
                btn.addEventListener('click', () => {
                    // Evitar cerrar el menú si es el botón de temas, para que el sub-menú de colores pueda mostrarse
                    if (btn.id === 'btn-visor-tema') return;
                    if (window.innerWidth <= 600) {
                        menuOpciones.style.display = 'none';
                        if (window.pdfEngine && window.pdfEngine._modoNativo && window.pdfEngine._nativeBridge) {
                            window.pdfEngine._nativeBridge.setBarsVisible(true).catch(()=>{});
                        }
                    }
                }, { signal });
            });
        }

        // --- GESTOS VISOR ---
        contenedorPdf.addEventListener('touchstart', /** @param {TouchEvent} e */ (e) => {
            if (e.touches.length === 1) {
                this.touchStartX = e.touches[0].clientX;
                this.touchStartY = e.touches[0].clientY;
            }
            if (e.touches.length === 2) {
                this.pinchZoomando = true;
                
                // 1. Distancia inicial
                this.distanciaInicial = Math.hypot(
                    e.touches[0].clientX - e.touches[1].clientX,
                    e.touches[0].clientY - e.touches[1].clientY
                );

                // 2. Escala inicial
                this.zoomInicial = pdfEngine.nivelZoom;
                const escalaActual = this.zoomInicial / 100;

                // 3. Capturar Punto Focal Invariante relativo al documento (#zoom-layer)
                const zl = document.getElementById('zoom-layer');
                if (!zl) return;

                const fingerCenterX = (e.touches[0].clientX + e.touches[1].clientX) / 2;
                const fingerCenterY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
                const rect = contenedorPdf.getBoundingClientRect();
                
                // El punto focal es la posición en el documento (considerando offsets) dividida por la escala actual
                this.focalX = (contenedorPdf.scrollLeft + (fingerCenterX - rect.left) - zl.offsetLeft) / escalaActual;
                this.focalY = (contenedorPdf.scrollTop + (fingerCenterY - rect.top) - zl.offsetTop) / escalaActual;
            }
        }, { passive: true, signal });

        contenedorPdf.addEventListener('touchmove', /** @param {TouchEvent} e */ (e) => {
            if (this.pinchZoomando && e.touches.length === 2) {
                e.preventDefault();
                
                // Cacheamos los valores del evento antes de entrar al frame asíncrono
                const t0 = { x: e.touches[0].clientX, y: e.touches[0].clientY };
                const t1 = { x: e.touches[1].clientX, y: e.touches[1].clientY };

                if (!this.zoomTicking) {
                    this.zoomTicking = true;
                    
                    requestAnimationFrame(() => {
                        this.zoomTicking = false;

                        const dist = Math.hypot(
                            t0.x - t1.x,
                            t0.y - t1.y
                        );
                        
                        const factor = dist / this.distanciaInicial;
                        const nuevoZoom = Math.min(Math.max(this.zoomInicial * factor, 100), 500);
                        const nuevaEscala = nuevoZoom / 100;

                        if (nuevoZoom !== pdfEngine.nivelZoom) {
                            pdfEngine.nivelZoom = nuevoZoom;

                            const zl = document.getElementById('zoom-layer');
                            if (!zl) return;

                            // 1. Centro de dedos actual
                            const currentFingerX = (t0.x + t1.x) / 2;
                            const currentFingerY = (t0.y + t1.y) / 2;
                            const rect = contenedorPdf.getBoundingClientRect();

                            // 2. ACTUALIZAR DOM (Espaciador y Escala)
                            this.actualizarUIZoom(contenedorPdf, btnResetZoom);

                            // 3. ANCLAJE MATEMÁTICO ABSOLUTO CONSCIENTE DE OFFSETS:
                            contenedorPdf.scrollLeft = (zl.offsetLeft + this.focalX * nuevaEscala) - (currentFingerX - rect.left);
                            contenedorPdf.scrollTop = (zl.offsetTop + this.focalY * nuevaEscala) - (currentFingerY - rect.top);
                        }
                    });
                }
            }
        }, { passive: false, signal });


        contenedorPdf.addEventListener('touchend', () => { this.pinchZoomando = false; }, { signal });

        contenedorPdf.addEventListener('scroll', () => {
            const actual = contenedorPdf.scrollTop;
            if (pdfEngine.modoDibujo) {
                barraSuperior.classList.remove('barra-oculta');
                if (pdfEngine._modoNativo) nativePdfBridge.setBarsVisible(true);
                return;
            }
            if (actual > this.ultimoScroll && actual > 50) {
                barraSuperior.classList.add('barra-oculta');
                if (pdfEngine._modoNativo) nativePdfBridge.setBarsVisible(false);
            } else {
                barraSuperior.classList.remove('barra-oculta');
                if (pdfEngine._modoNativo) nativePdfBridge.setBarsVisible(true);
            }
            this.ultimoScroll = actual;
        }, { passive: true, signal });

        // Clic para alternar la visibilidad de la barra superior
        contenedorPdf.addEventListener('click', (e) => {
            // Evitamos si el click provino de los controles superpuestos
            if (e.target.closest('#metronomo-flotante') || e.target.closest('.anotacion-flotante') || e.target.closest('#overlay-anotaciones') || e.target.closest('#overlay-anotaciones-tools')) return;
            if (pdfEngine.modoDibujo) return;
            const esOculta = barraSuperior.classList.toggle('barra-oculta');
            if (pdfEngine._modoNativo) nativePdfBridge.setBarsVisible(!esOculta);
        }, { signal });

        // v3.6.1: Mantener integridad visual al rotar el dispositivo
        window.addEventListener('resize', () => {
            if (document.getElementById('vista-visor').style.display === 'block') {
                this.actualizarUIZoom(contenedorPdf, btnResetZoom);
                
                // Recalibrar alturas de las páginas para evitar deformación
                document.querySelectorAll('.pdf-page-wrapper').forEach(wrapperElement => {
                    const wrapper = /** @type {HTMLElement} */ (wrapperElement);
                    const proporcion = parseFloat(wrapper.dataset.proporcion);
                    if (proporcion) {
                        const anchoReal = wrapper.offsetWidth;
                        const alturaCalculada = anchoReal * proporcion;
                        wrapper.style.minHeight = `${alturaCalculada}px`;
                        wrapper.style.height = `${alturaCalculada}px`;
                    }
                });

                // Recalibrar scroll en modo páginas para no quedar entre dos páginas
                const esModoPaginas = localStorage.getItem('modo-paginas') === 'true';
                if (esModoPaginas && pdfEngine.nivelZoom === 100) {
                    const anchoPagina = window.innerWidth;
                    const indiceActual = Math.round(contenedorPdf.scrollLeft / anchoPagina);
                    contenedorPdf.scrollLeft = indiceActual * anchoPagina;
                }
            }
        }, { passive: true, signal });

        btnResetZoom.onclick = () => { pdfEngine.nivelZoom = 100; this.actualizarUIZoom(contenedorPdf, btnResetZoom); };

        // RESTAURAR: Mostrar/Ocultar barra al dar click en la partitura
        contenedorPdf.onclick = /** @param {MouseEvent} e */ (e) => {
            if (this.pinchZoomando) return;

            const esModoPaginas = localStorage.getItem('modo-paginas') === 'true';
            const rect = contenedorPdf.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const anchoTotal = rect.width;

            // Navegación por TAP lateral (Solo en Modo Páginas y sin mucho zoom para evitar conflictos)
            if (esModoPaginas && pdfEngine.nivelZoom < 150) {
                const anchoPagina = window.innerWidth;
                
                // Si el usuario presiona rápido, 'scrollLeft' sigue en medio de la animación.
                // Guardamos la intención (el target virtual) por 500ms para permitir spam de toques.
                if (typeof this._indiceVirtual !== 'number') {
                    this._indiceVirtual = Math.round(contenedorPdf.scrollLeft / anchoPagina);
                }
                
                if (this._clearVirtualTimeout) clearTimeout(this._clearVirtualTimeout);
                if (this._restoreSnapTimeout) clearTimeout(this._restoreSnapTimeout);
                
                // DESACTIVAR SNAP TEMPORALMENTE (Evita que el navegador detenga o atragante la animación de scroll)
                contenedorPdf.style.scrollSnapType = 'none';

                let realizarScroll = false;
                if (x < anchoTotal * 0.2) {
                    // Tap Izquierdo: Página Anterior
                    this._indiceVirtual = Math.max(0, this._indiceVirtual - 1);
                    realizarScroll = true;
                } else if (x > anchoTotal * 0.8) {
                    // Tap Derecho: Siguiente Página
                    this._indiceVirtual = this._indiceVirtual + 1;
                    realizarScroll = true;
                }

                if (realizarScroll) {
                    contenedorPdf.scrollTo({ left: this._indiceVirtual * anchoPagina, behavior: 'smooth' });
                    
                    // Restaurar el snap después de que termine la animación (Aprox 400ms)
                    const clearTime = 500;
                    this._clearVirtualTimeout = setTimeout(() => { this._indiceVirtual = null; }, clearTime);
                    this._restoreSnapTimeout = setTimeout(() => { contenedorPdf.style.scrollSnapType = ''; }, clearTime);
                    return;
                }
            }

            // Click central o fuera de los bordes (Anteriormente ocultaba la barra)
            const target = /** @type {HTMLElement | null} */ (e.target);
        };

        // --- ANOTACIONES UI ---
        let btnAnotar = document.getElementById('btn-visor-anotar');
        let overlayAnotaciones = document.getElementById('overlay-anotaciones-tools');
        
        if (!btnAnotar) {
            btnAnotar = document.createElement('button');
            btnAnotar.id = 'btn-visor-anotar';
            btnAnotar.className = 'btn-topbar';
            btnAnotar.title = i18n.t('visor.anotar_desc') || 'Anotar';
            btnAnotar.innerHTML = `
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"></path>
                </svg>
                <span class="texto-btn-menu">${i18n.t('visor.anotar') || 'Anotar'}</span>
            `;
            const menuOpciones = document.getElementById('contenedor-botones-secundarios');
            if (menuOpciones) {
                menuOpciones.appendChild(btnAnotar);
            } else {
                barraSuperior.appendChild(btnAnotar);
            }
        }

        if (!overlayAnotaciones) {
            overlayAnotaciones = document.createElement('div');
            overlayAnotaciones.id = 'overlay-anotaciones-tools';
            overlayAnotaciones.style.position = 'absolute';
            overlayAnotaciones.style.top = '90px'; // Evita chocar con la barra superior
            overlayAnotaciones.style.right = '20px';
            overlayAnotaciones.style.display = 'none';
            overlayAnotaciones.style.flexDirection = 'column';
            overlayAnotaciones.style.gap = '10px';
            overlayAnotaciones.style.zIndex = '3000';
            overlayAnotaciones.style.pointerEvents = 'auto';
            overlayAnotaciones.style.touchAction = 'manipulation';
            
            const addTouchClick = (el, handler) => {
                el.style.pointerEvents = 'auto';
                el.style.touchAction = 'manipulation';
                el.addEventListener('pointerdown', (e) => { e.stopPropagation(); });
                el.addEventListener('touchstart', (e) => { e.stopPropagation(); }, { passive: true });
                el.addEventListener('click', (e) => {
                    e.stopPropagation();
                    handler(e);
                });
            };

            const btnDeshacer = document.createElement('button');
            btnDeshacer.title = 'Deshacer';
            btnDeshacer.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7v6h6"></path><path d="M21 17a9 9 0 0 0-9-9 9 9 0 0 0-6 2.3L3 13"></path></svg>`;

            const btnRehacer = document.createElement('button');
            btnRehacer.title = 'Rehacer';
            btnRehacer.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 7v6h-6"></path><path d="M3 17a9 9 0 0 1 9-9 9 9 0 0 1 6 2.3l3 2.7"></path></svg>`;

            const btnBorrarTodo = document.createElement('button');
            btnBorrarTodo.title = 'Borrar Todo';
            btnBorrarTodo.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>`;

            const btnLapiz = document.createElement('button');
            btnLapiz.title = 'Lápiz';
            btnLapiz.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"></path></svg>`;
            
            const btnTexto = document.createElement('button');
            btnTexto.title = 'Texto';
            btnTexto.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 7 4 4 20 4 20 7"></polyline><line x1="9" y1="20" x2="15" y2="20"></line><line x1="12" y1="4" x2="12" y2="20"></line></svg>`;

            const btnBorrador = document.createElement('button');
            btnBorrador.title = 'Borrador';
            btnBorrador.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m7 21-4.3-4.3c-1-1-1-2.5 0-3.4l9.6-9.6c1-1 2.5-1 3.4 0l5.6 5.6c1 1 1 2.5 0 3.4L13 21"></path><path d="M22 21H7"></path><path d="m5 11 9 9"></path></svg>`;

            [btnDeshacer, btnRehacer, btnBorrarTodo, btnLapiz, btnTexto, btnBorrador].forEach(btn => {
                btn.style.padding = '10px';
                btn.style.borderRadius = '50%';
                btn.style.border = '1px solid var(--border-color, #ccc)';
                btn.style.background = 'var(--bg-card, #fff)';
                btn.style.color = 'var(--text-primary, #000)';
                btn.style.cursor = 'pointer';
                btn.style.display = 'flex';
                btn.style.alignItems = 'center';
                btn.style.justifyContent = 'center';
                btn.style.boxShadow = '0 2px 5px rgba(0,0,0,0.2)';
                btn.style.width = '46px';
                btn.style.height = '46px';
                btn.style.pointerEvents = 'auto';
                btn.style.touchAction = 'manipulation';
            });
            const selectTool = (tool, btn) => {
                pdfEngine.herramientaDibujo = tool;
                [btnLapiz, btnTexto, btnBorrador].forEach(b => {
                    b.style.border = '1px solid var(--border-color, #ccc)';
                    b.style.backgroundColor = 'var(--bg-card, #fff)';
                    b.style.color = 'var(--text-primary, #000)';
                });
                btn.style.border = '2px solid var(--color-acento, #0A84FF)';
                btn.style.backgroundColor = 'var(--color-acento, #0A84FF)';
                btn.style.color = '#ffffff';
            };

            selectTool('lapiz', btnLapiz);

            const coloresContainer = document.createElement('div');
            coloresContainer.style.display = 'flex';
            coloresContainer.style.flexDirection = 'column';
            coloresContainer.style.gap = '8px';
            coloresContainer.style.background = 'var(--color-superficie, #ffffff)';
            coloresContainer.style.padding = '8px';
            coloresContainer.style.borderRadius = '20px';
            coloresContainer.style.border = '1px solid var(--color-borde, #ccc)';
            coloresContainer.style.alignItems = 'center';
            coloresContainer.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15)';
            coloresContainer.style.pointerEvents = 'auto';

            const colores = ['#000000', '#ffffff', '#ef4444', '#22c55e', '#3b82f6']; // negro, blanco, rojo, verde, azul
            colores.forEach(c => {
                const cb = document.createElement('button');
                cb.style.width = '26px';
                cb.style.height = '26px';
                cb.style.borderRadius = '50%';
                cb.style.backgroundColor = c;
                cb.style.border = '2px solid transparent';
                cb.style.cursor = 'pointer';
                cb.style.padding = '0';
                cb.style.pointerEvents = 'auto';
                cb.style.touchAction = 'manipulation';
                
                if (c === '#ffffff') {
                    cb.style.boxShadow = 'inset 0 0 0 1px rgba(0,0,0,0.3)';
                }

                addTouchClick(cb, () => {
                    pdfEngine.colorDibujo = c;
                    Array.from(coloresContainer.children).forEach(child => child.style.border = '2px solid transparent');
                    cb.style.border = '2px solid var(--color-acento, #0A84FF)';
                    
                    if (pdfEngine.herramientaDibujo === 'borrador') {
                        selectTool('lapiz', btnLapiz);
                    }
                });
                if (c === '#000000') cb.style.border = '2px solid var(--color-acento, #0A84FF)';
                coloresContainer.appendChild(cb);
            });

            overlayAnotaciones.appendChild(btnDeshacer);
            overlayAnotaciones.appendChild(btnRehacer);
            overlayAnotaciones.appendChild(btnBorrarTodo);
            overlayAnotaciones.appendChild(btnTexto);
            overlayAnotaciones.appendChild(btnBorrador);

            // Contenedor de herramientas ocultas del pincel
            const herramientasPincel = document.createElement('div');
            herramientasPincel.style.display = 'none';
            herramientasPincel.style.flexDirection = 'column';
            herramientasPincel.style.gap = '10px';
            herramientasPincel.style.pointerEvents = 'auto';
            
            // Contenedor visual para tamaños del pincel
            const sizeContainer = document.createElement('div');
            sizeContainer.id = 'anotaciones-size-container';
            sizeContainer.style.display = 'flex';
            sizeContainer.style.flexDirection = 'column';
            sizeContainer.style.gap = '8px';
            sizeContainer.style.background = 'var(--color-superficie, #ffffff)';
            sizeContainer.style.padding = '8px';
            sizeContainer.style.borderRadius = '20px';
            sizeContainer.style.border = '1px solid var(--color-borde, #ccc)';
            sizeContainer.style.alignItems = 'center';
            sizeContainer.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15)';
            sizeContainer.style.pointerEvents = 'auto';

            const sizesLapiz = [3, 6, 12];
            const sizesText = [24, 36, 48];
            sizesLapiz.forEach((s, index) => {
                const cir = document.createElement('div');
                cir.style.width = (s * 2 + 6) + 'px';
                cir.style.height = (s * 2 + 6) + 'px';
                cir.style.borderRadius = '50%';
                cir.style.background = 'var(--color-texto-principal, #000)';
                cir.style.cursor = 'pointer';
                cir.style.border = '2px solid transparent';
                if (index === 0) cir.style.border = '2px solid var(--color-acento, #0A84FF)';
                
                addTouchClick(cir, () => {
                    pdfEngine.grosorLapiz = s;
                    pdfEngine.tamanoTexto = sizesText[index];
                    Array.from(sizeContainer.children).forEach(child => child.style.border = '2px solid transparent');
                    cir.style.border = '2px solid var(--color-acento, #0A84FF)';
                });
                sizeContainer.appendChild(cir);
            });
            
            herramientasPincel.appendChild(coloresContainer);
            herramientasPincel.appendChild(sizeContainer);
            
            overlayAnotaciones.appendChild(btnLapiz);
            overlayAnotaciones.appendChild(herramientasPincel);

            document.getElementById('vista-visor').appendChild(overlayAnotaciones);

            addTouchClick(btnAnotar, () => {
                pdfEngine.setModoDibujo(!pdfEngine.modoDibujo);
                const menuOpciones = document.getElementById('contenedor-botones-secundarios');
                if (window.innerWidth <= 600 && menuOpciones) {
                    menuOpciones.style.display = 'none';
                }
            });

            addTouchClick(btnDeshacer, () => pdfEngine.deshacerAnotacion());
            addTouchClick(btnRehacer, () => pdfEngine.rehacerAnotacion());
            addTouchClick(btnBorrarTodo, () => {
                if (confirm('¿Estás seguro de borrar todos los trazos de esta página?')) {
                    pdfEngine.borrarAnotaciones();
                }
            });

            addTouchClick(btnLapiz, () => {
                selectTool('lapiz', btnLapiz);
                if (herramientasPincel.style.display === 'none') {
                    herramientasPincel.style.display = 'flex';
                    herramientasPincel.classList.remove('anim-pop-in');
                    void herramientasPincel.offsetWidth;
                    herramientasPincel.classList.add('anim-pop-in');
                } else {
                    herramientasPincel.style.display = 'none';
                }
            });

            addTouchClick(btnTexto, () => {
                selectTool('texto', btnTexto);
                if (herramientasPincel.style.display === 'none') {
                    herramientasPincel.style.display = 'flex';
                } else {
                    herramientasPincel.style.display = 'none';
                }
            });

            addTouchClick(btnBorrador, () => {
                selectTool('borrador', btnBorrador);
                herramientasPincel.style.display = 'none';
            });
        }

        // --- REPRODUCTOR MIDI ---
        this.configurarMidiUI(signal);
    },

    /**
     * @param {AbortSignal} signal
     */
    configurarMidiUI: function(signal) {
        const btnVoces = /** @type {HTMLElement | null} */ (document.getElementById('btn-visor-voces'));
        const playerSheet = /** @type {HTMLElement | null} */ (document.getElementById('midi-player-container'));
        const handle = playerSheet ? /** @type {HTMLElement | null} */ (playerSheet.querySelector('.midi-drag-handle')) : null;
        const btnPlay = /** @type {HTMLElement | null} */ (document.getElementById('midi-btn-play'));
        const btnRepeat = /** @type {HTMLElement | null} */ (document.getElementById('midi-btn-repeat'));
        const sliderProgreso = /** @type {HTMLInputElement | null} */ (document.getElementById('midi-progress'));
        const advancedPanel = /** @type {HTMLElement | null} */ (document.getElementById('midi-advanced-panel'));

        if (!btnVoces || !playerSheet || !handle || !btnPlay || !sliderProgreso || !advancedPanel) return;
        
        sliderProgreso.step = '0.001';

        // Configuración de Botón de Repetir
        if (btnRepeat) {
            const savedRepeat = localStorage.getItem('midi-repeat') === 'true';
            midiEngine.repetirTrack = savedRepeat;
            if (savedRepeat) {
                btnRepeat.classList.add('activo');
                btnRepeat.style.opacity = '1';
                btnRepeat.style.color = 'var(--color-acento)';
            }
            btnRepeat.onclick = (e) => {
                e.preventDefault(); e.stopPropagation();
                const isRepeat = btnRepeat.classList.toggle('activo');
                midiEngine.repetirTrack = isRepeat; // Sincronizar con el engine
                localStorage.setItem('midi-repeat', String(isRepeat));
                if (isRepeat) {
                    btnRepeat.style.opacity = '1';
                    btnRepeat.style.color = 'var(--color-acento)';
                } else {
                    btnRepeat.style.opacity = '0.5';
                    btnRepeat.style.color = '';
                }
            };
        }

        let startY = 0, startX = 0, isDragging = false, isSliding = false;

        playerSheet.addEventListener('touchstart', /** @param {TouchEvent} e */ (e) => {
            const target = /** @type {HTMLElement} */ (e.target);
            
            // Ignorar el toque si están manipulando un slider o tocando áreas scrolleables (Mixer/Voces)
            if (target.tagName === 'INPUT' && /** @type {HTMLInputElement} */ (target).type === 'range') return;
            if (target.closest('.mixer-grid')) return;
            if (target.closest('.midi-voice-selector')) return;
            
            startY = e.touches[0].clientY;
            startX = e.touches[0].clientX;
            isDragging = true;
            isSliding = false;
        }, { passive: true, signal });

        document.addEventListener('touchmove', /** @param {TouchEvent} e */ (e) => {
            if (!isDragging) return;
            const diffY = e.touches[0].clientY - startY;
            const diffX = e.touches[0].clientX - startX;
            
            if (!isSliding) {
                // Si el movimiento es horizontal, cancelar el arrastre
                if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 10) {
                    isDragging = false;
                    return;
                }
                // Si ya empezó a mover en Y, activamos el slide
                if (Math.abs(diffY) > 5) {
                    isSliding = true;
                    playerSheet.style.transition = 'none';
                }
            }

            if (isSliding) {
                // Límite elástico (resistencia) al estirar hacia arriba
                let renderDiff = diffY;
                if (diffY < 0) renderDiff = Math.max(-60, diffY); 
                
                playerSheet.style.transform = `translateX(-50%) translateY(${renderDiff}px)`;
            }
        }, { passive: true, signal });

        document.addEventListener('touchend', /** @param {TouchEvent} e */ (e) => {
            if (!isDragging) return;
            isDragging = false;
            if (!isSliding) return;
            
            playerSheet.style.transition = 'transform 0.3s cubic-bezier(0.2, 0.8, 0.2, 1)';
            const diffY = e.changedTouches[0].clientY - startY;
            
            // Lógica de dos pasos para cerrar
            const isExpanded = advancedPanel && advancedPanel.style.display === 'block';

            if (isExpanded) {
                if (diffY > 40) {
                    // Si está expandido, cualquier arrastre hacia abajo solo lo contrae
                    advancedPanel.style.display = 'none';
                    playerSheet.style.transform = '';
                } else {
                    playerSheet.style.transform = '';
                }
            } else {
                // Si está contraído
                if (diffY > 50) {
                    // Cerrar por completo
                    playerSheet.classList.remove('activo');
                    playerSheet.style.transform = '';
                } else if (diffY < -30) {
                    // Expandir
                    if (advancedPanel) advancedPanel.style.display = 'block';
                    playerSheet.style.transform = '';
                } else {
                    // Rebotar a posición original
                    playerSheet.style.transform = '';
                }
            }
            
            // Limpiar transición después de animar
            setTimeout(() => { if (!isDragging) playerSheet.style.transition = ''; }, 300);
        }, { passive: true, signal });

        btnVoces.onclick = async () => {
            if (midiEngine.desbloquearAudioSync) {
                midiEngine.desbloquearAudioSync();
            }
            // Verificar límites ANTES de mostrar el reproductor para evitar frustración
            if (!limitsManager.puedeReproducirAudio()) {
                if (window.uiController && typeof window.uiController.mostrarModalPremium === 'function') {
                    window.uiController.mostrarModalPremium('audio');
                }
                return; // Bloquea la apertura del reproductor
            }

            const estaActivo = playerSheet.classList.toggle('activo');
            if (window.pdfEngine && window.pdfEngine._nativeBridge) {
                setTimeout(() => {
                    const height = estaActivo ? Math.max(playerSheet.offsetHeight || 0, 280) : 0;
                    window.pdfEngine._nativeBridge.setBottomInset(height).catch(()=>{});
                }, 30);
            }
            if (estaActivo && advancedPanel) {
                advancedPanel.style.display = 'none'; // Restaurar estado comprimido al abrir
            }
            
            // El engine maneja la repetición internamente via repetirTrack.
            // Solo necesitamos capturar el fin para actualizar el ícono en el caso no-repeat.
            midiEngine.onTrackEnd = () => {
                this.setPlayIcon(false);
            };

            if (estaActivo && !this.midiCargado) {
                if (!pdfEngine.pdfActual) return;
                const currentCantoId = pdfEngine.pdfActual.cantoId;
                
                // v4.0.1: Si estamos offline, verificar que esté en caché antes de bloquear el visor intentando cargarlo de red
                if (!navigator.onLine && pdfEngine.pdfActual.midiUrl) {
                    try {
                        const cache = await caches.open('midi-cache-v1');
                        const match = await cache.match(pdfEngine.pdfActual.midiUrl);
                        if (!match) {
                            playerSheet.classList.remove('activo');
                            if (window.uiController) window.uiController.mostrarToast("Audio no descargado para uso offline.", "advertencia");
                            return; // Abortamos para no bloquear la pantalla con el cargador infinito
                        }
                    } catch(e) {}
                }

                await this.cargarMidi(pdfEngine.pdfActual.midiUrl);
                if (!pdfEngine.pdfActual || pdfEngine.pdfActual.cantoId !== currentCantoId) return;

                // v3.6.2: Forzar pintado inmediato del tiempo total antes de reproducir
                const tiempos = midiEngine.getTiempos();
                const totalTime = document.getElementById('midi-time-total');
                if (totalTime && tiempos.total > 0) totalTime.textContent = this.formatearSegundos(tiempos.total);
            }
        };

        btnPlay.onclick = async () => {
            console.log("▶️ [VISOR] PLAY PRESIONADO EN JS");
            // Reanudar e iniciar contexto de forma estrictamente síncrona en el gesto del usuario
            if (midiEngine.desbloquearAudioSync) {
                midiEngine.desbloquearAudioSync();
            }
            if (window.requestWakeLock) window.requestWakeLock();
            
            const estaReproduciendo = midiEngine.isPlaying();

            if (estaReproduciendo) {
                // Pausa real: el player está sonando activamente
                midiEngine.pause();
                this.setPlayIcon(false);
            } else if (midiEngine._pendingPlay) {
                // Cancelar intención pendiente sin llamar pause() (que silenciaría el audio entrante)
                midiEngine._pendingPlay = false;
                this.setPlayIcon(false);
            } else {
                // Forzar sincronía del metrónomo con el UI del visor justo antes de reproducir
                // Esto previene cualquier desajuste si la Jukebox u otro componente lo apagó internamente
                const metronomoToggle = /** @type {HTMLInputElement | null} */ (document.getElementById('midi-metronomo-toggle'));
                if (metronomoToggle) {
                    midiEngine.toggleMetronomo(metronomoToggle.checked);
                }

                midiEngine.play();
                this.setPlayIcon(true);
            }
        };

        const btnOpcionesToggle = /** @type {HTMLElement | null} */ (document.getElementById('midi-btn-opciones'));
        if (btnOpcionesToggle) {
            btnOpcionesToggle.onclick = /** @param {MouseEvent} e */ (e) => {
                e.preventDefault(); e.stopPropagation();
                advancedPanel.style.display = (advancedPanel.style.display === 'none' || advancedPanel.style.display === '') ? 'block' : 'none';
            };
        }

        sliderProgreso.addEventListener('input', (e) => {
            this.isDraggingSlider = true; // Pausa el setInterval de UI
            if (midiEngine.midiData) {
                const target = /** @type {HTMLInputElement} */ (e.target);
                const perc = parseFloat(target.value);
                const total = midiEngine.midiData.duration / midiEngine.speed;
                const currentTime = document.getElementById('midi-time-current');
                if (currentTime) currentTime.textContent = this.formatearSegundos((perc / 100) * total);
            }
        });

        sliderProgreso.addEventListener('change', (e) => {
            const target = /** @type {HTMLInputElement} */ (e.target);
            midiEngine.saltarA(parseFloat(target.value));
            // Pequeño retardo antes de reanudar el tracking de la UI
            setTimeout(() => { this.isDraggingSlider = false; }, 250);
        });

        const masterVolume = /** @type {HTMLInputElement | null} */ (document.getElementById('midi-master-volume'));
        if (masterVolume) {
            const savedVol = localStorage.getItem('midi-vol');
            if (savedVol) {
                masterVolume.value = savedVol;
                midiEngine.setVolumen(savedVol);
            }
            masterVolume.oninput = /** @param {Event} e */ (e) => {
                const target = /** @type {HTMLInputElement} */ (e.target);
                midiEngine.setVolumen(target.value);
                localStorage.setItem('midi-vol', target.value);
            };
        }

        // v3.6.0: Control de Velocidad
        const speedControl = /** @type {HTMLInputElement | null} */ (document.getElementById('midi-speed-control'));
        const speedValue = document.getElementById('midi-speed-value');
        const btnSpeedReset = document.getElementById('midi-btn-speed-reset');
        
        if (speedControl && speedValue) {
            speedControl.oninput = /** @param {Event} e */ (e) => {
                const target = /** @type {HTMLInputElement} */ (e.target);
                const val = parseFloat(target.value);
                speedValue.textContent = val.toFixed(2) + 'x';
                midiEngine.setSpeed(val);
            };
            if (btnSpeedReset) {
                btnSpeedReset.onclick = () => {
                    speedControl.value = '1';
                    speedValue.textContent = '1.00x';
                    midiEngine.setSpeed(1.0);
                };
            }
        }

        // v4.0.0: Control de Metrónomo
        const metronomoToggle = /** @type {HTMLInputElement | null} */ (document.getElementById('midi-metronomo-toggle'));
        if (metronomoToggle) {
            const savedMetro = localStorage.getItem('midi-metro') === 'true';
            metronomoToggle.checked = savedMetro;
            midiEngine.toggleMetronomo(savedMetro);
            
            metronomoToggle.onchange = /** @param {Event} e */ (e) => {
                const target = /** @type {HTMLInputElement} */ (e.target);
                midiEngine.toggleMetronomo(target.checked);
                localStorage.setItem('midi-metro', String(target.checked));
            };
        }

        document.querySelectorAll('.btn-voz').forEach((btnElement) => {
            const btn = /** @type {HTMLElement} */ (btnElement);
            btn.onclick = () => {
                document.querySelectorAll('.btn-voz').forEach((bElement) => {
                    const b = /** @type {HTMLElement} */ (bElement);
                    b.classList.remove('activo');
                });
                btn.classList.add('activo');
                this.cambiarVoz(/** @type {string} */ (btn.dataset.voz));
            };
        });

        // Evento visual de metrónomo desde midiEngine
        let lastNumerator = 0;
        window.addEventListener('midi-beat', (e) => {
            const detail = /** @type {any} */ (e).detail;
            const container = document.getElementById('metronomo-flotante');
            if (!container) return;

            if (detail && detail.activo) {
                container.style.display = 'flex';
                const { isFirstBeat, beatIndex, numerator } = detail;

                // Si la métrica cambió o el contenedor está vacío, regeneramos los puntos
                if (numerator !== lastNumerator || container.children.length === 0) {
                    container.innerHTML = '';
                    lastNumerator = numerator;

                    // Determinar cómo agrupar los puntos (ej. 3 para 6/8, 4 para 4/4)
                    let groupSize = numerator;
                    if (numerator % 3 === 0) groupSize = 3;
                    else if (numerator % 2 === 0) groupSize = 4;

                    let currentGroup = null;
                    for (let i = 0; i < numerator; i++) {
                        if (i % groupSize === 0) {
                            currentGroup = document.createElement('div');
                            currentGroup.style.display = 'flex';
                            currentGroup.style.gap = '4px';
                            container.appendChild(currentGroup);
                        }
                        const dot = document.createElement('div');
                        dot.className = 'metro-dot';
                        dot.style.width = '12px';
                        dot.style.height = '12px';
                        dot.style.borderRadius = '50%';
                        dot.style.backgroundColor = 'var(--color-acento)';
                        dot.style.opacity = '0.3';
                        dot.style.transition = 'opacity 0.15s ease, transform 0.15s ease, box-shadow 0.15s ease';
                        if (currentGroup) currentGroup.appendChild(dot);
                    }
                }

                const allDots = container.querySelectorAll('.metro-dot');
                if (!allDots || allDots.length === 0) return;

                // Iluminar el punto actual
                const activeDot = /** @type {HTMLElement} */ (allDots[beatIndex]);
                if (activeDot) {
                    activeDot.style.opacity = '1';
                    activeDot.style.transform = isFirstBeat ? 'scale(1.4)' : 'scale(1.1)';
                    activeDot.style.boxShadow = isFirstBeat 
                        ? '0 0 12px var(--color-acento)' 
                        : '0 0 5px rgba(255, 255, 255, 0.4)';
                    
                    // Apagar el punto después del destello
                    setTimeout(() => {
                        if (activeDot) {
                            activeDot.style.opacity = '0.3';
                            activeDot.style.transform = 'scale(1)';
                            activeDot.style.boxShadow = 'none';
                        }
                    }, 150);
                }
            } else {
                container.style.display = 'none';
            }
        });

        this.iniciarIntervaloMidi();
    },

    iniciarIntervaloMidi: function() {
        if (this.midiIntervalId) clearInterval(this.midiIntervalId);
        
        const playerSheet = /** @type {HTMLElement | null} */ (document.getElementById('midi-player-container'));
        const sliderProgreso = /** @type {HTMLInputElement | null} */ (document.getElementById('midi-progress'));
        
        this.midiIntervalId = setInterval(() => {
            if (!document.body.contains(playerSheet)) {
                clearInterval(this.midiIntervalId);
                this.midiIntervalId = null;
                return;
            }
            if (midiEngine.isPlaying() && !this.isDraggingSlider) {
                const perc = midiEngine.getProgreso();
                if (sliderProgreso) sliderProgreso.value = String(perc);
                const tiempos = midiEngine.getTiempos();
                const currentTime = document.getElementById('midi-time-current');
                const totalTime = document.getElementById('midi-time-total');
                if (currentTime) currentTime.textContent = this.formatearSegundos(tiempos.actual);
                if (totalTime) totalTime.textContent = this.formatearSegundos(tiempos.total);
            }
        }, 50);
    },

    /** @param {string} url */
    cargarMidi: async function(url) {
        try {
            // v3.6.1: Si es una carga compartida (misma URL), evitamos resetear el mixer y mutear el engine
            // para no cortar el sonido ni borrar los ajustes del usuario por el doble disparo (timeout vs click manual)
            const esCargaCompartida = midiEngine._loadingUrl === url && (midiEngine.cargando || midiEngine.midiData);

            if (!esCargaCompartida) {
                // v3.6.0: Hard-Reset de Mixer y Audio antes de cargar nueva pista
                midiEngine.silenciarTodo();
                this.resetearEstadoMixer();
            }
            
            const currentCantoId = pdfEngine.pdfActual ? pdfEngine.pdfActual.cantoId : null;
            await midiEngine.cargarCancion(url, null, currentCantoId);
            this.midiCargado = true;
            this.iniciarIntervaloMidi();
            
            if (!esCargaCompartida) {
                this.generarMixer();
            }
        } catch (err) { 
            console.error("❌ [VISOR] Error al cargar voces:", err); 
            
            // v3.0.0: Graceful Degradation (Manejo de OOM)
            if (window.uiController) {
                window.uiController.mostrarToast("Error: " + (err.message || err.toString()).substring(0, 50), "error");
            }

            this.resetMidiUI();
        }
    },

    resetearEstadoMixer: function() {
        win.MIXER_STATE = {};
        // Por defecto, ensamble total (hasta que se cargue la preferencia del usuario en generarMixer)
        const totalTracks = midiEngine.midiData ? midiEngine.midiData.tracks.length : 16;
        for (let i = 0; i < totalTracks; i++) {
            win.MIXER_STATE[i] = 1.0;
        }
    },

    generarMixer: function() {
        const contenedor = /** @type {HTMLElement | null} */ (document.getElementById('midi-mixer-sliders'));
        if (!contenedor || !midiEngine.midiData) return;
        contenedor.innerHTML = '';
        const tracksValidos = midiEngine.getTracksConNotas();
        
        let soprano = [], alto = [], tenor = [], bajo = [], solista = [];
        
        let matchesRegex = tracksValidos.some(t => /sop|alt|contr|ten|baj|bas|sol|s1|s2|a1|a2|t1|t2|b1|b2|bar/i.test(t.nombre));
        
        if (matchesRegex) {
            tracksValidos.forEach(t => {
                const n = t.nombre;
                if (/\b(sol|solo|soloist|solista)\b/i.test(n)) {
                    solista.push(t.index);
                } else if (/(sop|s1|s2)/i.test(n)) {
                    soprano.push(t.index);
                } else if (/(alt|contr|a1|a2)/i.test(n)) {
                    alto.push(t.index);
                } else if (/(ten|t1|t2)/i.test(n)) {
                    tenor.push(t.index);
                } else if (/(baj|bas|b1|b2|bar)/i.test(n)) {
                    bajo.push(t.index);
                }
            });
        } else {
            const fallbackTracks = tracksValidos.map(t => t.index);
            if (fallbackTracks.length > 0) soprano.push(fallbackTracks[0]);
            if (fallbackTracks.length > 1) alto.push(fallbackTracks[1]);
            if (fallbackTracks.length > 2) tenor.push(fallbackTracks[2]);
            if (fallbackTracks.length > 3) bajo.push(fallbackTracks[3]);
        }

        win.TRACKS_SATB = { soprano, alto, tenor, bajo, solista };

        const btnSolista = document.querySelector('.btn-voz[data-voz="solista"]');
        if (btnSolista) {
            const hasSolista = Array.isArray(solista) ? solista.length > 0 : solista !== -1;
            btnSolista.style.display = hasSolista ? 'inline-block' : 'none';
        }

        tracksValidos.forEach((trackObj) => {
            const trackIndex = trackObj.index;
            const trackNum = trackIndex + 1;
            const mixerItem = document.createElement('div');
            mixerItem.className = 'mixer-item';
            
            // Renderizado inteligente de nombres en UI (Traducción completa)
            let nombreBase = trackObj.nombre.toUpperCase();
            let isSop = (Array.isArray(win.TRACKS_SATB.soprano) ? win.TRACKS_SATB.soprano.includes(trackIndex) : win.TRACKS_SATB.soprano === trackIndex) || /SOP|S1|S2/i.test(nombreBase);
            let isAlt = (Array.isArray(win.TRACKS_SATB.alto) ? win.TRACKS_SATB.alto.includes(trackIndex) : win.TRACKS_SATB.alto === trackIndex) || /ALT|CONTR|A1|A2/i.test(nombreBase);
            let isTen = (Array.isArray(win.TRACKS_SATB.tenor) ? win.TRACKS_SATB.tenor.includes(trackIndex) : win.TRACKS_SATB.tenor === trackIndex) || /TEN|T1|T2/i.test(nombreBase);
            let isBaj = (Array.isArray(win.TRACKS_SATB.bajo) ? win.TRACKS_SATB.bajo.includes(trackIndex) : win.TRACKS_SATB.bajo === trackIndex) || /BAJ|BAS|B1|B2/i.test(nombreBase);
            let isBar = /BAR/i.test(nombreBase);
            let isSol = (Array.isArray(win.TRACKS_SATB.solista) ? win.TRACKS_SATB.solista.includes(trackIndex) : win.TRACKS_SATB.solista === trackIndex) || /\b(SOL|SOLO|SOLOIST|SOLISTA)\b/i.test(nombreBase);
            
            // Detectar si la voz original especifica 1 o 2 (ej: Tenor I vs Tenor II o T1 vs T2)
            let sufijo = "";
            if (/\b1\b|(?:\b[SATB]1\b)|\bI\b/i.test(trackObj.nombre)) {
                sufijo = " 1";
            } else if (/\b2\b|(?:\b[SATB]2\b)|\bII\b/i.test(trackObj.nombre)) {
                sufijo = " 2";
            }

            let nombreLabel = "";
            if (isSol) nombreLabel = i18n.t('midi.voz_sol') + sufijo;
            else if (isSop) nombreLabel = i18n.t('midi.voz_soprano') + sufijo;
            else if (isAlt) nombreLabel = i18n.t('midi.voz_alto') + sufijo;
            else if (isTen) nombreLabel = i18n.t('midi.voz_tenor') + sufijo;
            else if (isBar) nombreLabel = i18n.t('midi.voz_baritono') + sufijo;
            else if (isBaj) nombreLabel = i18n.t('midi.voz_bajo') + sufijo;
            else {
                nombreLabel = trackObj.nombre;
                if (nombreLabel.length > 15) nombreLabel = nombreLabel.substring(0, 15);
            }
            
            mixerItem.innerHTML = `<span style="font-size: 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 100%; display: block; text-align: center;" title="${nombreLabel}">${nombreLabel}</span><input type="range" class="slider-vertical" min="0" max="1.5" step="0.1" value="1" data-track="${trackNum}">`;
            const input = /** @type {HTMLInputElement | null} */ (mixerItem.querySelector('input'));
            if (input) {
                input.oninput = /** @param {Event} e */ (e) => {
                    const target = /** @type {HTMLInputElement} */ (e.target);
                    if (!win.MIXER_STATE) win.MIXER_STATE = {};
                    win.MIXER_STATE[trackIndex] = parseFloat(target.value);

                    // v3.2.0: Activar ENSAMBLE automáticamente al mover el mixer
                    const btnEnsamble = document.querySelector('.btn-voz[data-voz="ensamble"]');
                    if (btnEnsamble && !btnEnsamble.classList.contains('activo')) {
                        document.querySelectorAll('.btn-voz').forEach(b => b.classList.remove('activo'));
                        btnEnsamble.classList.add('activo');
                    }
                };
            }
            contenedor.appendChild(mixerItem);
        });

        // v4.1.0: Recuperar y aplicar la voz preferida del usuario
        const vozPreferida = localStorage.getItem('voz-preferida') || 'ensamble';
        
        // Simular clic en el botón correspondiente para aplicar estado visual y mezcla
        const btnPreferido = document.querySelector(`.btn-voz[data-voz="${vozPreferida}"]`);
        if (btnPreferido) {
            document.querySelectorAll('.btn-voz').forEach(b => b.classList.remove('activo'));
            btnPreferido.classList.add('activo');
            this.cambiarVoz(vozPreferida, true); // true = no guardar en localstorage (es carga inicial)
        } else {
            // Si por alguna razón no existe el botón (ej. no hay soprano en este MIDI), por defecto ensamble
            const btnEnsamble = document.querySelector('.btn-voz[data-voz="ensamble"]');
            if (btnEnsamble) btnEnsamble.classList.add('activo');
            this.cambiarVoz('ensamble', true);
        }
    },

    /** @param {boolean} isPlaying */
    setPlayIcon: function(isPlaying) {
        const iconPlay = /** @type {HTMLElement | null} */ (document.querySelector('.icon-play'));
        const iconPause = /** @type {HTMLElement | null} */ (document.querySelector('.icon-pause'));
        if (iconPlay) iconPlay.style.display = isPlaying ? 'none' : 'block';
        if (iconPause) iconPause.style.display = isPlaying ? 'block' : 'none';
        
        // Esconder el metrónomo visual si se pausa la música
        if (!isPlaying) {
            const dot = document.getElementById('metronomo-flotante');
            if (dot) dot.style.display = 'none';
        }
    },

    /** 
     * @param {string} voz 
     * @param {boolean} [isInitialLoad=false]
     */
    cambiarVoz: function(voz, isInitialLoad = false) {
        if (!win.MIXER_STATE) win.MIXER_STATE = {};
        
        if (!isInitialLoad) {
            localStorage.setItem('voz-preferida', voz);
        }
        const totalTracks = (midiEngine.midiData && midiEngine.midiData.tracks)
            ? midiEngine.midiData.tracks.length
            : 16;
        
        // v3.4.1: Resetear todos a 0 primero
        for (let i = 0; i < totalTracks; i++) win.MIXER_STATE[i] = 0;

        if (voz === 'ensamble') {
            // Activar todos al 100% (1.0)
            for (let i = 0; i < totalTracks; i++) win.MIXER_STATE[i] = 1.0;
        } else {
            // Activar solo la voz seleccionada al 100% (1.0)
            const targets = win.TRACKS_SATB ? win.TRACKS_SATB[voz] : [];
            if (Array.isArray(targets)) {
                targets.forEach(t => {
                    if (t !== -1) win.MIXER_STATE[t] = 1.0;
                });
            } else if (targets !== -1) {
                win.MIXER_STATE[targets] = 1.0;
            }
        }
        
        // Sincronizar sliders visuales
        document.querySelectorAll('.slider-vertical').forEach((sElement) => {
            const s = /** @type {HTMLInputElement} */ (sElement);
            const idx = parseInt(s.dataset.track) - 1;
            s.value = win.MIXER_STATE[idx] !== undefined ? String(win.MIXER_STATE[idx]) : '0';
        });
    },

    /** @param {number} s */
    formatearSegundos: (s) => {
        if (isNaN(s) || s < 0) return "0:00";
        return `${Math.floor(s/60)}:${Math.floor(s%60).toString().padStart(2,'0')}`;
    },

    resetMidiUI: function() {
        if (this.midiIntervalId) {
            clearInterval(this.midiIntervalId);
            this.midiIntervalId = null;
        }
        const playerSheet = /** @type {HTMLElement | null} */ (document.getElementById('midi-player-container'));
        if (playerSheet) {
            playerSheet.classList.remove('activo');
            playerSheet.style.transform = '';
        }
        try { midiEngine.destruirSesion(); } catch (e) {}
        this.setPlayIcon(false);
        this.midiCargado = false;
        const sliderProgreso = /** @type {HTMLInputElement | null} */ (document.getElementById('midi-progress'));
        if (sliderProgreso) sliderProgreso.value = '0';
        const timeCurrent = document.getElementById('midi-time-current');
        if (timeCurrent) timeCurrent.textContent = '0:00';

        // Reset Velocidad
        const speedControl = /** @type {HTMLInputElement | null} */ (document.getElementById('midi-speed-control'));
        if (speedControl && speedControl.value !== '1') {
            speedControl.value = '1';
            const speedValue = document.getElementById('midi-speed-value');
            if (speedValue) speedValue.textContent = '1.00x';
            midiEngine.setSpeed(1);
        }

        // Reset Volumen si está silenciado
        const masterVol = /** @type {HTMLInputElement | null} */ (document.getElementById('midi-master-volume'));
        if (masterVol && masterVol.value === '0') {
            masterVol.value = '1';
            midiEngine.setVolumen(1);
        }
    },

    /**
     * @param {HTMLElement} c
     * @param {HTMLElement} b
     */
    actualizarUIZoom: (c, b) => {
        const zl = document.getElementById('zoom-layer');
        if (!zl) return;
        const z = pdfEngine.nivelZoom;
        const s = z / 100;
        
        if (z > 100) {
            c.classList.add('zoom-activo');
            b.style.display = 'flex';
            
            // Recalcular altura de cada wrapper ANTES de aplicar el transform.
            // El CSS zoom-activo cambia width de 95% → 100%, lo que hace el wrapper más ancho.
            // Si no actualizamos el height, el canvas (que tiene height fijo en px) queda más alto
            // que el wrapper y overflow:hidden lo recorta, cortando los márgenes del PDF.
            const contenedorAncho = c.offsetWidth;
            document.querySelectorAll('.pdf-page-wrapper').forEach(pw => {
                const proporcion = parseFloat(pw.dataset.proporcion);
                if (proporcion) {
                    const nuevaAltura = contenedorAncho * proporcion;
                    pw.style.height = `${nuevaAltura}px`;
                    pw.style.minHeight = `${nuevaAltura}px`;
                }
            });

            // Leer dimensiones ANTES de aplicar transform para evitar reflows inconsistentes
            const originalWidth = zl.offsetWidth;
            const originalHeight = zl.offsetHeight;
            
            // Escalado proporcional desde la esquina superior izquierda
            zl.style.transformOrigin = '0 0';
            zl.style.transform = `scale(${s})`;
            
            // Expandir el área de scroll exactamente al tamaño visual del contenido.
            // Con pages al 100% de ancho (forzado por CSS .zoom-activo), el PDF ocupa
            // todo el originalWidth, por lo que no hay dead-space a la derecha.
            zl.style.marginRight = (originalWidth * (s - 1)) + 'px';
            zl.style.marginBottom = (originalHeight * (s - 1)) + 'px';

            const spacer = document.getElementById('zoom-spacer');
            if (spacer) spacer.remove();
            
        } else {
            c.classList.remove('zoom-activo');
            b.style.display = 'none';
            zl.style.transform = 'none';
            zl.style.width = '100%';
            zl.style.marginRight = '0';
            zl.style.marginBottom = '0';

            // Restaurar alturas originales basadas en el ancho real del 95%
            const anchoReal = c.offsetWidth * 0.95;
            document.querySelectorAll('.pdf-page-wrapper').forEach(pw => {
                const proporcion = parseFloat(pw.dataset.proporcion);
                if (proporcion) {
                    const alturaOriginal = anchoReal * proporcion;
                    pw.style.height = `${alturaOriginal}px`;
                    pw.style.minHeight = `${alturaOriginal}px`;
                }
            });
            
            const spacer = document.getElementById('zoom-spacer');
            if (spacer) spacer.remove();
        }
    }
};

if (typeof window !== 'undefined') {
    win.visorUI = visorUI;
}
