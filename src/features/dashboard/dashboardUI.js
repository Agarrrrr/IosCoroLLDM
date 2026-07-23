import { pdfEngine } from '../../core/pdfEngine.js';
import { offlineManager } from '../../core/offlineManager.js';
import { buscadorUI } from '../../ui/buscador.js';
import { visorUI } from '../../ui/visor.js';
import { partiturasController } from '../../core/partiturasController.js';
import { uiController } from '../../ui/uiController.js';
import { i18n } from '../../core/i18n.js';
import { store } from '../../core/stateManager.js';
import { router } from '../../app/router.js';
import { appInitializer } from '../../app/appInitializer.js';
import { jukeboxController } from '../jukebox/jukeboxController.js';

let ultimoScrollLista = 0;
let uiCaches = {
    cantos: null,
    cantosVisibles: null
};

const APP_STATE = store.getState();

const DOM = {
    listaCantos: document.getElementById('lista-cantos'),
    listaTemas: document.getElementById('lista-temas'),
    inputBuscador: document.getElementById('buscador'),
    contadorCantos: document.getElementById('contador-cantos'),
    contenedorPdf: document.getElementById('contenedor-pdf'),
    barraSuperior: document.getElementById('barra-superior'),
    btnLimpiarBusqueda: document.getElementById('btn-limpiar-busqueda'),
    contadorDescargas: document.getElementById('contador-descargas'),
    btnResetZoom: document.getElementById('btn-reset-zoom'),
    btnCerrar: document.getElementById('btn-cerrar'),
    btnVivoVisor: document.getElementById('btn-vivo-visor'),
    btnSelectorTema: document.getElementById('btn-selector-tema'),
    btnToggleSidebar: document.getElementById('btn-toggle-sidebar'),
    btnModoEscucha: document.getElementById('btn-modo-escucha'),
    sidebar: document.getElementById('sidebar-temas'),
    overlay: document.getElementById('overlay-sidebar') || crearOverlaySidebar()
};

function crearOverlaySidebar() {
    let overlay = document.getElementById('overlay-sidebar');
    if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'overlay-sidebar';
        const vistaMenu = document.getElementById('vista-menu') || document.body;
        vistaMenu.appendChild(overlay);
    }
    return overlay;
}

// --- REACTIVIDAD PURA (STORE -> DOM) ---
store.subscribe((state) => {
    Object.assign(APP_STATE, state);

    if (uiCaches.cantos !== state.cantos) {
        uiCaches.cantos = state.cantos;
        if (state.cantos) {
            const repSede = state.cantos; // Modelo monolítico
            if (DOM.contadorDescargas) offlineManager.actualizarContador(repSede, DOM.contadorDescargas);
            offlineManager.actualizarEstadisticas(repSede);
        }
    }

    // 1. Re-renderizar menú de temas solo si cambió la categoría actual o la lista cruda
    if (uiCaches.categoriaActiva !== state.categoriaActiva || uiCaches.cantosBase !== state.cantos) {
        uiCaches.categoriaActiva = state.categoriaActiva;
        uiCaches.cantosBase = state.cantos;
        
        let cantosCat = [];
        const cat = state.categoriaActiva;
        if (state.cantos) {
            if (cat === 'favoritos') {
                const favs = JSON.parse(localStorage.getItem('favoritos_repertorio') || '[]');
                cantosCat = state.cantos.filter(c => favs.includes(c.id));
            } else {
                // Modelo monolítico global
                cantosCat = state.cantos;
            }
        }

        buscadorUI.generarMenuTemas(cantosCat, DOM.listaTemas, (tema) => {
            if (DOM.inputBuscador) DOM.inputBuscador.value = '';
            if (DOM.btnLimpiarBusqueda) DOM.btnLimpiarBusqueda.classList.add('oculto');
            store.setState({ temaSeleccionado: tema, busqueda: '' });
            if (window.innerWidth <= 1024) uiController.alternarSidebar(DOM.sidebar, DOM.overlay, true);
        });
        
        // Mantener la UI de botones sincronizada con el estado real
        const btnTemas = document.querySelectorAll('.nav-btn[data-cat]');
        btnTemas.forEach(b => {
            b.classList.toggle('activo', b.dataset.cat === state.categoriaActiva);
        });
    }

    // 2. Re-renderizar lista de cantos solo si cambió la vista filtrada (Buscador/Temas)
    if (uiCaches.cantosVisibles !== state.cantosVisibles) {
        uiCaches.cantosVisibles = state.cantosVisibles;
        
        if (DOM.contadorCantos) {
            DOM.contadorCantos.textContent = `${state.cantosVisibles.length} ${i18n.t('sidebar.cantos_count')}`;
        }
        
        let msjVacio = null;
        if (state.categoriaActiva === 'favoritos' && state.cantosVisibles.length === 0) {
            msjVacio = 'No tienes cantos favoritos.<br><br><span style="font-size: 0.9em; opacity: 0.8;">Toca el ícono de corazón <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: middle;"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path></svg> en cualquier canto para guardarlo aquí.</span>';
        }

        buscadorUI.renderizarLista(state.cantosVisibles, DOM.listaCantos, (canto) => {
            ultimoScrollLista = DOM.listaCantos.scrollTop;
            window.location.hash = 'visor';
            pdfEngine.abrirVisor(canto, DOM.contenedorPdf, DOM.barraSuperior);
            if (window.requestWakeLock) window.requestWakeLock();
        }, msjVacio);
    }
});

function renderizarPantallaEspera() {
    document.body.innerHTML = '';
    const container = document.createElement('div');
    container.style.cssText = 'display:flex; flex-direction:column; align-items:center; justify-content:center; height:100%; text-align:center; padding:20px; font-family:sans-serif; background:#fdfdfd;';

    const h2 = document.createElement('h2');
    h2.style.cssText = 'color:#D4AF37; margin-bottom: 10px;';
    h2.textContent = 'CUENTA EN ESPERA';

    const p = document.createElement('p');
    p.style.color = '#555';
    p.textContent = 'Tu acceso aún no ha sido aprobado por el Director de tu sede.';

    const btnReintentar = document.createElement('button');
    btnReintentar.style.cssText = 'margin-top:20px; padding:12px 24px; background:#D4AF37; color:white; border:none; border-radius:8px; font-weight:bold; cursor:pointer;';
    btnReintentar.textContent = 'REINTENTAR';
    btnReintentar.onclick = () => location.reload();

    const btnCerrar = document.createElement('button');
    btnCerrar.style.cssText = 'margin-top:15px; background:none; border:none; color:#888; text-decoration:underline; cursor:pointer;';
    btnCerrar.textContent = 'CERRAR SESIÓN';
    btnCerrar.onclick = () => authController.cerrarSesion();

    container.append(h2, p, btnReintentar, btnCerrar);
    document.body.appendChild(container);
}



async function cargarCategoriaActual() {
    // Ya no inyectamos cantosCategoria. stateManager lo maneja al vuelo al cambiar categoriaActiva
    // Solo forzamos una actualización
    store.setState({});
}

function construirInterfaz() {
    // La app es local, no verificamos si es director.
    document.body.classList.add('es-director');
        
    const seccionDirector = document.getElementById('seccion-director-ajustes');
    if (seccionDirector) seccionDirector.style.display = 'block';

    const toggleOcultar = document.getElementById('toggle-ocultar-en-vivo');
    if (toggleOcultar) {
        toggleOcultar.checked = ocultarEnVivo;
        toggleOcultar.onchange = (e) => {
            localStorage.setItem('ocultarBtnEnVivo', e.target.checked);
        };
    }

    // Ajuste responsivo de Sidebar (Tablets / Móvil) según orientación
    const syncSidebarOrientation = () => {
        const esPortrait = window.matchMedia('(orientation: portrait)').matches || window.innerHeight > window.innerWidth;
        const esTabletOEscritorioLandscape = (window.innerWidth >= 768 && window.matchMedia('(orientation: landscape)').matches) || window.innerWidth > 1024;

        if (esPortrait) {
            // EN MODO VERTICAL (PORTRAIT): Siempre forzar ocultar el sidebar en celulares y tablets al rotar
            if (DOM.sidebar) DOM.sidebar.classList.add('oculto');
            if (DOM.overlay) {
                DOM.overlay.style.opacity = '0';
                DOM.overlay.style.display = 'none';
                DOM.overlay.classList.remove('activo');
            }
        } else if (esTabletOEscritorioLandscape) {
            // EN MODO HORIZONTAL (TABLET / ESCRITORIO): Siempre visible 100% fijo (App Store Guidelines)
            if (DOM.sidebar) DOM.sidebar.classList.remove('oculto');
            if (DOM.overlay) {
                DOM.overlay.style.opacity = '0';
                DOM.overlay.style.display = 'none';
                DOM.overlay.classList.remove('activo');
            }
        } else {
            // Celulares en Horizontal: Ocultar sidebar para dar espacio a la pantalla
            if (DOM.sidebar) DOM.sidebar.classList.add('oculto');
            if (DOM.overlay) {
                DOM.overlay.style.opacity = '0';
                DOM.overlay.style.display = 'none';
                DOM.overlay.classList.remove('activo');
            }
        }
    };

    syncSidebarOrientation();
    window.addEventListener('resize', syncSidebarOrientation);
    window.addEventListener('orientationchange', syncSidebarOrientation);

    // Forzar el primer tick reactivo y cargar categoría inicial asíncrona si es necesario
    store.setState({ categoriaActiva: APP_STATE.categoriaActiva || 'todos' });
    cargarCategoriaActual();
    
    // Iniciar Banner
    if (window.adManager) {
        window.adManager.mostrarBannerInferior();
    }

    // Getter dinámico para evitar atrapar valores nulos si la DB aún no ha cargado
    const getRepertorioSede = () => {
        const s = store.getState();
        return s.cantos || [];
    };
    
    if (localStorage.getItem('ahorroDatos') !== 'true' && navigator.onLine) {
        const triggerSync = () => {
            offlineManager.sincronizarPartituras(getRepertorioSede(), DOM.contadorDescargas);
        };
        if ('requestIdleCallback' in window) requestIdleCallback(triggerSync, { timeout: 15000 });
        else setTimeout(triggerSync, 8000);
    }

    const btnForzarSync = document.getElementById('btn-forzar-sync');
    if (btnForzarSync) {
        btnForzarSync.style.display = 'none'; // Siempre oculto, la app ya es 100% offline
        btnForzarSync.onclick = async () => {
            const rep = getRepertorioSede();
            
            if (rep.length === 0) {
                return uiController.mostrarToast(i18n.t('dashboard.aviso_descarga_vacia'), 'aviso');
            }
            
            if (DOM.contadorDescargas && DOM.contadorDescargas.classList.contains('completado')) {
                return uiController.mostrarToast(i18n.t('dashboard.aviso_descarga_completa'), 'exito');
            }

            if (!confirm(i18n.t('dashboard.confirm_descarga'))) return;
            const btnOriginal = btnForzarSync.innerHTML;
            btnForzarSync.innerHTML = i18n.t('dashboard.descargando');
            btnForzarSync.disabled = true;
            
            await offlineManager.forzarSincronizacion(getRepertorioSede(), DOM.contadorDescargas, (actual, total) => {
                btnForzarSync.innerHTML = `${i18n.t('dashboard.descargando')} ${actual}/${total}`;
            });
            
            offlineManager.actualizarEstadisticas(getRepertorioSede());
            
            btnForzarSync.innerHTML = btnOriginal;
            btnForzarSync.disabled = false;
            uiController.mostrarToast(i18n.t('dashboard.descarga_completada'), 'exito');
        };
    }

    const btnLimpiarCache = document.getElementById('btn-limpiar-cache');
    if (btnLimpiarCache) {
        btnLimpiarCache.onclick = async () => {
            if (!confirm(i18n.t('dashboard.confirm_limpiar'))) return;
            try {
                if ('caches' in window) {
                    await caches.delete('pdf-cache-v14');
                    await caches.delete('midi-cache-v1');
                    uiController.mostrarToast(i18n.t('dashboard.limpiar_exito'), 'exito');
                    if (DOM.contadorDescargas) {
                        offlineManager.actualizarContador(getRepertorioSede(), DOM.contadorDescargas);
                    }
                    offlineManager.actualizarEstadisticas(getRepertorioSede());
                }
            } catch(e) {
                uiController.mostrarToast(i18n.t('dashboard.error_limpiar'), 'error');
            }
        };
    }
        
    visorUI.iniciarEventos(DOM.contenedorPdf, DOM.btnResetZoom, DOM.barraSuperior);
    cargarNotificacionesRecientes();
}

async function manejarNuevoAviso(aviso, esEstatal) {
    if (aviso.tipo === 'VIVO') {
        const banner = document.getElementById('banner-vivo');
        const texto = document.getElementById('banner-texto');
        const btnAbrir = document.getElementById('btn-abrir-vivo');
        if (banner && texto && btnAbrir) {
            texto.textContent = esEstatal ? `ESTATAL CANTANDO: ${aviso.mensaje.toUpperCase()}` : `CANTANDO AHORA: ${aviso.mensaje.toUpperCase()}`;
            
            banner.classList.toggle('estatal', esEstatal);
            banner.style.display = 'flex';
            banner.style.transform = 'translateX(-50%) translateY(0)';
            btnAbrir.onclick = () => {
                const canto = APP_STATE.cantos.find(c => c.id == aviso.metadata.id_canto);
                if (canto) {
                    pdfEngine.abrirVisor(canto, DOM.contenedorPdf, DOM.barraSuperior);
                    uiController.cerrarBanner('banner-vivo');
                }
            };
            setTimeout(() => {
                if (banner.style.display === 'flex') uiController.cerrarBanner('banner-vivo');
            }, 600000);
        }
    } else if (aviso.tipo === 'RECORDATORIO') {
        const esNuevoCanto = aviso.metadata && aviso.metadata.subtipo === 'NUEVO_CANTO';
        const esSyncSilenciosa = aviso.metadata && aviso.metadata.subtipo === 'SYNC_SILENCIOSA';

        if (esSyncSilenciosa) {
            // El store se actualizará mágicamente desde la DB por el canal realtime, no necesitamos forzar
            return;
        } else if (esNuevoCanto) {
            const nombreCanto = aviso.mensaje.toUpperCase();
            uiController.mostrarToast(`NUEVO: ${nombreCanto}`, 'exito');

            if ('Notification' in window && Notification.permission === 'granted') {
                navigator.serviceWorker.ready.then(reg => {
                    try {
                        reg.showNotification('NUEVO CANTO AÑADIDO', {
                            body: nombreCanto,
                            icon: '/assets/icono.png',
                            badge: '/assets/icono.png',
                            vibrate: [200, 100, 200],
                            tag: 'nuevo-canto', 
                            renotify: true,
                            data: { url: `/?canto=${aviso.metadata.id_canto}`, canto_id: aviso.metadata.id_canto, tipo: 'NUEVO_CANTO' }
                        });
                    } catch (e) { }
                });
            }
            if ('vibrate' in navigator) navigator.vibrate([100, 50, 100]);
        } else {
            const bannerRec = document.getElementById('banner-recordatorio');
            const textoRec = document.getElementById('recordatorio-texto');
            if (bannerRec && textoRec) {
                textoRec.textContent = aviso.mensaje.toUpperCase();
                bannerRec.style.display = 'flex';
                bannerRec.style.transform = 'translateX(-50%) translateY(0)';
            }
            if ('Notification' in window && Notification.permission === 'granted') {
                if (navigator.serviceWorker) {
                    navigator.serviceWorker.ready.then(reg => {
                        try {
                            reg.showNotification('Recordatorio de Sede', { body: aviso.mensaje, icon: '/assets/icono.png' });
                        } catch (e) { }
                    });
                }
            }
        }
        cargarNotificacionesRecientes();
    }
}

const VAPID_PUBLIC_KEY = 'BNnAwTLnmvBR-FIWaViSki2XgjT0rxceF0vHFRJS-DfxD4ftsBZvbdGg-8f-OibMUDQnGG3G3JXyd2y640X5v1M';

function urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
        outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
}

async function registrarSuscripcionPush() {
    console.log("Notificaciones offline deshabilitadas");
}

async function actualizarUIEstadoNotificaciones() {
    const card = document.getElementById('card-notificaciones');
    const txt = document.getElementById('txt-estado-notif');
    const icon = card ? card.querySelector('.icono-estado') : null;
    if (!card || !txt || !icon) return;

    card.style.backgroundColor = '';
    card.style.borderColor = '';
    const textElements = card.querySelectorAll('h4, .tarjeta-notif-estado');
    textElements.forEach(el => el.style.color = '');

    if (!('Notification' in window) || !('PushManager' in window)) {
        txt.textContent = 'No soportado';
        icon.innerHTML = '<circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line>';
        icon.style.color = 'var(--color-error, #ef4444)';
        card.style.backgroundColor = 'rgba(239, 68, 68, 0.1)';
        card.style.borderColor = 'rgba(239, 68, 68, 0.5)';
        textElements.forEach(el => el.style.color = 'var(--color-error, #ef4444)');
        return;
    }

    if (Notification.permission === 'granted') {
        // Verificar si existe la suscripción en el SW
        const reg = await navigator.serviceWorker.ready;
        const sub = await reg.pushManager.getSubscription();

        if (sub) {
            // VERIFICACIÓN CRÍTICA: ¿La llave coincide con la actual?
            const currentKey = btoa(String.fromCharCode.apply(null, new Uint8Array(sub.options.applicationServerKey)))
                .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
            const targetKey = VAPID_PUBLIC_KEY.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

            if (currentKey === targetKey) {
                txt.textContent = 'Activas';
                icon.innerHTML = '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline>';
                icon.style.color = 'var(--color-exito, #10b981)';
                card.style.backgroundColor = 'rgba(16, 185, 129, 0.1)';
                card.style.borderColor = 'rgba(16, 185, 129, 0.5)';
            } else {
                txt.textContent = 'Actualización requerida';
                icon.innerHTML = '<circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line>';
                icon.style.color = 'var(--color-aviso, #f59e0b)';
                card.style.backgroundColor = 'rgba(245, 158, 11, 0.1)';
                card.style.borderColor = 'rgba(245, 158, 11, 0.5)';
            }
        } else {
            txt.textContent = 'Sincronización pendiente';
            icon.innerHTML = '<circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line>';
            icon.style.color = 'var(--color-aviso, #f59e0b)';
            card.style.backgroundColor = 'rgba(245, 158, 11, 0.1)';
            card.style.borderColor = 'rgba(245, 158, 11, 0.5)';
        }
    }
 else if (Notification.permission === 'denied') {
        txt.textContent = 'Bloqueadas';
        icon.innerHTML = '<circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line>';
        icon.style.color = 'var(--color-error, #ef4444)';
        card.style.backgroundColor = 'rgba(239, 68, 68, 0.1)';
        card.style.borderColor = 'rgba(239, 68, 68, 0.5)';
        textElements.forEach(el => el.style.color = 'var(--color-error, #ef4444)');
    } else {
        txt.textContent = 'Tocar para activar';
        icon.innerHTML = '<circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line>';
        icon.style.color = 'var(--color-texto-suave, #888)';
    }
}

async function cargarNotificacionesRecientes() {
    const lista = document.getElementById('historial-notificaciones');
    if (!lista) return;
    lista.innerHTML = '<p class="mensaje-vacio">Sin notificaciones recientes</p>';
}

function configurarEventosGlobales() {
    window.addEventListener('keydown', (e) => {
        if (e.key === 'Backspace') {
            const target = e.target;
            if (!target) return;
            const tag = target.tagName ? target.tagName.toLowerCase() : '';
            const isInput = tag === 'input' || tag === 'textarea' || target.isContentEditable;
            if (!isInput) e.preventDefault();
        }
    });

    if (DOM.sidebar) {
        DOM.sidebar.addEventListener('click', (e) => {
            const btnCat = e.target.closest('.nav-btn[data-cat]');
            if (btnCat) {
                store.setState({ categoriaActiva: btnCat.dataset.cat, busqueda: '', temaSeleccionado: 'Todos' });
                if (DOM.inputBuscador) DOM.inputBuscador.value = '';
                if (DOM.btnLimpiarBusqueda) DOM.btnLimpiarBusqueda.classList.add('oculto');
                cargarCategoriaActual();
                if (window.innerWidth <= 1024) uiController.alternarSidebar(DOM.sidebar, DOM.overlay, true);
            }
        });
    }

    const btnVincularCarpeta = document.getElementById('btn-vincular-link');
    if (btnVincularCarpeta) {
        btnVincularCarpeta.addEventListener('click', () => {
            const modalAjustes = document.getElementById('modal-ajustes');
            if (modalAjustes) modalAjustes.style.display = 'none';

            setTimeout(() => {
                const link = prompt('Pega el link o código de la carpeta compartida:');
                if (link && link.trim() !== '') {
                    let id = link.trim();
                    try {
                        if (link.includes('ev=')) {
                            const url = new URL(link.startsWith('http') ? link : 'https://' + link);
                            id = url.searchParams.get('ev');
                        }
                    } catch (err) {}
                    
                    if (id) {
                        router.manejarLinkEvento(id).then(() => appInitializer.autoFetchEventos());
                    }
                }
            }, 100);
        });
    }

    let debounceTimer;
    if (DOM.inputBuscador) {
        DOM.inputBuscador.addEventListener('input', () => {
            if (DOM.btnLimpiarBusqueda) {
                if (DOM.inputBuscador.value.length > 0) {
                    DOM.btnLimpiarBusqueda.classList.remove('oculto');
                } else {
                    DOM.btnLimpiarBusqueda.classList.add('oculto');
                }
            }
            clearTimeout(debounceTimer);
            debounceTimer = setTimeout(() => {
                if (DOM.listaCantos) DOM.listaCantos.scrollTop = 0; 
                
                const textoBuscado = DOM.inputBuscador.value;
                const estado = store.getState();
                
                // Si está buscando algo y hay un tema específico seleccionado, resetear a 'Todos'
                if (textoBuscado.trim() !== '' && estado.temaSeleccionado !== 'Todos') {
                    store.setState({ busqueda: textoBuscado, temaSeleccionado: 'Todos' });
                    
                    // Actualizar visualmente las "píldoras" de temas
                    buscadorUI.temaActual = 'Todos';
                    document.querySelectorAll('.item-tema').forEach(item => {
                        item.classList.toggle('activo', item.dataset.tema === 'Todos');
                    });
                } else {
                    store.setState({ busqueda: textoBuscado });
                }
            }, 150);
        });
    }

    if (DOM.btnLimpiarBusqueda) {
        DOM.btnLimpiarBusqueda.addEventListener('click', () => { 
            if (DOM.inputBuscador) DOM.inputBuscador.value = ''; 
            if (DOM.btnLimpiarBusqueda) DOM.btnLimpiarBusqueda.classList.add('oculto');
            if (DOM.listaCantos) DOM.listaCantos.scrollTop = 0;
            store.setState({ busqueda: '' }); 
        });
    }
    
    if (DOM.btnCerrar) {
        DOM.btnCerrar.addEventListener('click', () => { 
            if (window.location.hash === '#visor') {
                window.history.back();
            } else {
                pdfEngine.cerrarVisor(DOM.contenedorPdf);
                visorUI.resetMidiUI();
                if(window.releaseWakeLock) window.releaseWakeLock();
            }
        });
    }

    if (DOM.btnModoEscucha) {
        // Inicializar el controlador (inyecta el modal en el DOM si no existe)
        jukeboxController.inicializar();
        
        DOM.btnModoEscucha.onclick = () => {
            // Se le pasa el catálogo global (del store centralizado) a la Jukebox
            const catalogoGlobal = store.getState().cantos;
            if (!catalogoGlobal || catalogoGlobal.length === 0) {
                uiController.mostrarToast('El catálogo aún no está cargado.', 'error');
                return;
            }
            jukeboxController.abrirConCatalogo(catalogoGlobal);
        };
    }



    window.addEventListener('popstate', () => {
        const visor = document.getElementById('vista-visor');
        if (visor && visor.style.display === 'block' && window.location.hash !== '#visor') {
            pdfEngine.cerrarVisor(DOM.contenedorPdf); 
            if (visorUI && typeof visorUI.resetMidiUI === 'function') visorUI.resetMidiUI();
            pdfEngine.limpiarMotorPdf();
            if (typeof releaseWakeLock === 'function') releaseWakeLock();
            
            if (DOM.listaCantos && ultimoScrollLista > 0) {
                const delay = (/iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)) ? 150 : 50;
                setTimeout(() => {
                    DOM.listaCantos.scrollTo({ top: ultimoScrollLista, behavior: 'instant' });
                }, delay);
            }
        }
    });

    if (DOM.btnToggleSidebar) {
        DOM.btnToggleSidebar.addEventListener('click', (e) => {
            e.stopPropagation();
            uiController.alternarSidebar(DOM.sidebar, DOM.overlay);
        });
    }
    if (DOM.overlay) DOM.overlay.addEventListener('click', () => uiController.alternarSidebar(DOM.sidebar, DOM.overlay, true));

    // Gesto Swipe de izquierda a derecha para abrir sidebar
    let swipeStartX = 0;
    let swipeStartY = 0;
    document.addEventListener('touchstart', (e) => {
        swipeStartX = e.changedTouches[0].screenX;
        swipeStartY = e.changedTouches[0].screenY;
    }, { passive: true });

    document.addEventListener('touchend', (e) => {
        const swipeEndX = e.changedTouches[0].screenX;
        const swipeEndY = e.changedTouches[0].screenY;
        const diffX = swipeEndX - swipeStartX;
        const diffY = Math.abs(swipeEndY - swipeStartY);

        // Margen de seguridad: iniciar en los primeros 30px, deslizar al menos 40px horizontales y sin moverse mucho en vertical
        if (swipeStartX <= 30 && diffX > 40 && diffY < 40) {
            if (DOM.sidebar && DOM.sidebar.classList.contains('oculto')) {
                const visor = document.getElementById('vista-visor');
                // No abrir si el visor PDF está activo
                if (!visor || visor.style.display !== 'block') {
                    uiController.alternarSidebar(DOM.sidebar, DOM.overlay, false);
                }
            }
        }
    }, { passive: true });

    const btnVisorTema = document.getElementById('btn-visor-tema');
    if (btnVisorTema) {
        btnVisorTema.addEventListener('click', (e) => {
            e.stopPropagation();
            uiController.toggleMenuTemas(btnVisorTema);
        });
    }

    // Ya no existen btn-tema-opcion, pero dejamos el código comentado o limpio para no causar errores
    window.actualizarBotonesAjustesTema = function() {
        const temaActual = localStorage.getItem('tema-ui') || 'claro';
        document.querySelectorAll('.btn-tema-opcion').forEach(btn => {
            btn.classList.toggle('activo', btn.getAttribute('data-tema') === temaActual);
        });
    };
    actualizarBotonesAjustesTema();

    // Gestos Banners
    if (window.gestureController) window.gestureController.abort();
    window.gestureController = new AbortController();
    const gestureSignal = window.gestureController.signal;

    let toqueInicialY = 0;
    let toqueInicialX = 0;
    document.addEventListener('touchstart', e => { 
        toqueInicialY = e.changedTouches[0].screenY; 
        toqueInicialX = e.changedTouches[0].screenX;
    }, { passive: true, signal: gestureSignal });
    
    document.addEventListener('touchend', e => {
        const deltaY = toqueInicialY - e.changedTouches[0].screenY;
        const deltaX = e.changedTouches[0].screenX - toqueInicialX;
        
        if (deltaY > 50 || deltaX > 50) {
            const banner = e.target.closest('.banner-vivo') || e.target.closest('.banner-recordatorio') || e.target.closest('#banner-actualizacion');
            if (banner) { 
                banner.style.transform = deltaX > 50 ? 'translateX(100vw)' : 'translateX(-50%) translateY(-150%)'; 
                setTimeout(() => {
                    banner.style.display = 'none';
                    banner.style.transform = '';
                }, 300); 
            }
        }
    }, { passive: true, signal: gestureSignal });

    const btnAjustes = document.getElementById('btn-ajustes');
    if (btnAjustes) {
        btnAjustes.addEventListener('click', async () => {
            const modal = document.getElementById('modal-ajustes');
            if (modal) {
                // 1. Mostrar modal inmediatamente para UX instantánea
                modal.style.display = 'flex';
                
                // 2. Llenar datos síncronos cacheados
                if (APP_STATE.perfil) {
                    ['nombre', 'email', 'sede', 'rol'].forEach(k => {
                        const el = document.getElementById(`info-${k}`);
                        if (el) el.textContent = (APP_STATE.perfil[k === 'sede' ? 'coro_id' : k] || '').toUpperCase();
                    });
                }
                
                // Las siguientes funciones deben manejar internamente si hay o no perfil
                if (typeof actualizarUIEstadoNotificaciones === 'function') actualizarUIEstadoNotificaciones();
                if (typeof cargarNotificacionesRecientes === 'function') cargarNotificacionesRecientes();
            }
        });
    }

    const cardNotif = document.getElementById('card-notificaciones');
    if (cardNotif) {
        cardNotif.addEventListener('click', async () => {
            if (!('Notification' in window)) return;

            const estadoActual = Notification.permission;
            
            if (estadoActual === 'denied') {
                alert('Las notificaciones están bloqueadas. Debes activarlas manualmente desde los Ajustes de tu dispositivo (Aplicaciones > Coro LLDM > Permisos).');
                return;
            }
            
            if (estadoActual === 'default') {
                try {
                    const perm = await Notification.requestPermission();
                    if (typeof actualizarUIEstadoNotificaciones === 'function') actualizarUIEstadoNotificaciones();
                } catch(e) {}
                return;
            }

            // Si está 'granted', preguntamos si desea forzar reparación
            if (confirm('¿Dejaste de recibir notificaciones? Presiona OK para limpiar la caché de sincronización y reparar el enlace. La app se recargará.')) {
                try {
                    if ('serviceWorker' in navigator) {
                        const regs = await navigator.serviceWorker.getRegistrations();
                        for (let reg of regs) {
                            await reg.unregister();
                        }
                    }
                    if ('caches' in window) {
                        const keys = await caches.keys();
                        for (let key of keys) {
                            await caches.delete(key);
                        }
                    }
                    window.location.reload(true);
                } catch (e) {
                    console.error('Error al reparar notificaciones:', e);
                    alert('Hubo un problema automático. Tendrás que borrar los datos de la app desde los ajustes de Android.');
                }
            }
        });
    }

    const btnCerrarAjustes = document.getElementById('btn-cerrar-ajustes');
    if (btnCerrarAjustes) btnCerrarAjustes.addEventListener('click', () => uiController.cerrarModal('modal-ajustes'));
    
    const btnCerrarBanner = document.getElementById('btn-cerrar-banner');
    if (btnCerrarBanner) btnCerrarBanner.addEventListener('click', () => uiController.cerrarBanner('banner-vivo'));
    
    const btnCerrarRecordatorio = document.getElementById('btn-cerrar-recordatorio');
    if (btnCerrarRecordatorio) btnCerrarRecordatorio.addEventListener('click', () => uiController.cerrarBanner('banner-recordatorio'));
    
    const btnCerrarActualizacion = document.getElementById('btn-cerrar-actualizacion');
    if (btnCerrarActualizacion) btnCerrarActualizacion.addEventListener('click', () => uiController.cerrarBanner('banner-actualizacion'));
    
    const modalAjustes = document.getElementById('modal-ajustes');
    if (modalAjustes) {
        modalAjustes.addEventListener('click', function(e) {
            if (e.target === modalAjustes) uiController.cerrarModal('modal-ajustes');
        });
    }

    document.addEventListener('click', function(e) {
        if (e.target.classList.contains('modal-overlay')) {
            e.target.style.display = 'none';
            const previewContainer = e.target.querySelector('#contenedor-preview-pdf');
            if (previewContainer) previewContainer.innerHTML = '';
        }
    });

    const btnSalir = document.getElementById('btn-salir');
    if (btnSalir) btnSalir.style.display = 'none';

    const btnNavScroll = document.getElementById('btn-nav-scroll');
    const btnNavPaginas = document.getElementById('btn-nav-paginas');

    const btnLangEs = document.getElementById('btn-lang-es');
    const btnLangEn = document.getElementById('btn-lang-en');

    if (btnLangEs && btnLangEn) {
        // Inicializar estado visual
        if (i18n.getLanguage() === 'es') {
            btnLangEs.classList.add('activo');
            btnLangEn.classList.remove('activo');
        } else {
            btnLangEn.classList.add('activo');
            btnLangEs.classList.remove('activo');
        }

        btnLangEs.onclick = () => {
            btnLangEs.classList.add('activo');
            btnLangEn.classList.remove('activo');
            i18n.setLanguage('es');
        };

        btnLangEn.onclick = () => {
            btnLangEn.classList.add('activo');
            btnLangEs.classList.remove('activo');
            i18n.setLanguage('en');
        };
    }
    if (btnNavScroll && btnNavPaginas) {
        const esModoPaginas = localStorage.getItem('modo-paginas') === 'true';
        if (esModoPaginas) {
            DOM.contenedorPdf.classList.add('modo-paginas');
            btnNavPaginas.classList.add('activo');
            btnNavScroll.classList.remove('activo');
        } else {
            DOM.contenedorPdf.classList.remove('modo-paginas');
            btnNavScroll.classList.add('activo');
            btnNavPaginas.classList.remove('activo');
        }

        btnNavScroll.onclick = () => {
            localStorage.setItem('modo-paginas', 'false');
            DOM.contenedorPdf.classList.remove('modo-paginas');
            btnNavScroll.classList.add('activo');
            btnNavPaginas.classList.remove('activo');
            if (window.pdfEngine && window.pdfEngine._modoNativo && window.pdfEngine._nativeBridge) {
                window.pdfEngine._nativeBridge.updateDisplayMode(false);
            }
        };

        btnNavPaginas.onclick = () => {
            localStorage.setItem('modo-paginas', 'true');
            DOM.contenedorPdf.classList.add('modo-paginas');
            btnNavPaginas.classList.add('activo');
            btnNavScroll.classList.remove('activo');
            if (window.pdfEngine && window.pdfEngine._modoNativo && window.pdfEngine._nativeBridge) {
                window.pdfEngine._nativeBridge.updateDisplayMode(true);
            }
        };
    }
    const btnDescargarPdf = document.getElementById('btn-descargar-pdf');
    if (btnDescargarPdf) {
        btnDescargarPdf.style.display = 'none';
    }
    const chkJukebox = document.getElementById('chk-habilitar-jukebox');
    if (DOM.btnModoEscucha) {
        DOM.btnModoEscucha.style.display = 'none';
    }
}

// WakeLock
let wakeLock = null;
window.requestWakeLock = async function() { 
    if ('wakeLock' in navigator && !wakeLock && document.getElementById('vista-visor').style.display === 'block') { 
        try { wakeLock = await navigator.wakeLock.request('screen'); } catch (err) { }
    } 
};
window.releaseWakeLock = function() { 
    if (wakeLock) { wakeLock.release().then(() => wakeLock = null); } 
};

document.addEventListener('visibilitychange', async () => {
    if (document.visibilityState === 'visible') await window.requestWakeLock();
    else window.releaseWakeLock();
});

if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', (event) => {
        if (event.data && event.data.type === 'OPEN_CANTO' && event.data.canto_id) {
            const intentarAbrir = (cantos) => {
                const cantoPush = cantos.find(c => c.id == event.data.canto_id);
                if (cantoPush) {
                    window.location.hash = 'visor';
                    pdfEngine.abrirVisor(cantoPush, DOM.contenedorPdf, DOM.barraSuperior);
                    uiController.cerrarBanner('banner-vivo');
                    window.requestWakeLock();
                }
            };

            if (APP_STATE.cantos && APP_STATE.cantos.length > 0) {
                intentarAbrir(APP_STATE.cantos);
            } else {
                const unsubscribe = store.subscribe((state) => {
                    if (state.cantos && state.cantos.length > 0) {
                        intentarAbrir(state.cantos);
                        unsubscribe();
                    }
                });
            }
        }
    });
}

export const dashboardUI = {
    DOM,
    UI_API: {
        construirInterfaz,
        configurarEventosGlobales,
        manejarNuevoAviso,
        cargarCategoriaActual
    }
};
