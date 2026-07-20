import { store } from '../core/stateManager.js';
import { uiController } from '../ui/uiController.js';
import { localDB } from '../api/localDB.js';
import { router } from './router.js';

export const appInitializer = {
    APP_STATE: null,
    DOM: null,
    UI_API: null,

    iniciar: async function(appState, dom, uiApi) {
        this.APP_STATE = appState;
        this.DOM = dom;
        this.UI_API = uiApi;

        await this.arrancarAplicacion();
    },

    arrancarAplicacion: async function() {
        // Inicializar Gestor de Ingresos y Verificación Premium
        try {
            const { limitsManager } = await import('../core/limitsManager.js');
            limitsManager.sincronizarConServidor().catch(() => {});

            const { revenueManager } = await import('../core/revenueManager.js');
            await revenueManager.inicializar();
            
            const { adManager } = await import('../core/adManager.js');
            window.adManager = adManager;
            await adManager.inicializar();
        } catch(e) {
            console.warn("No se pudo iniciar monetización o DRM:", e);
        }

        // Cálculo de VH real para navegadores móviles
        const updateVH = () => {
            let vh = window.innerHeight * 0.01;
            document.documentElement.style.setProperty('--vh', `${vh}px`);
        };
        window.addEventListener('resize', updateVH);
        updateVH();

        uiController.inicializarTema();

        try {
            const cantos = await localDB.getCantos();
            store.setState({ 
                cantos: cantos, 
                categoriaActiva: 'todos'
            });

            this.UI_API.construirInterfaz();
            this.UI_API.configurarEventosGlobales();
            
            await this.UI_API.cargarCategoriaActual();
            
            // Actualizar vista de elementos PRO (Sidebar, etc)
            uiController.actualizarEstadoPremiumUI();
            
            // Procesar parámetros de URL (si hay)
            await router.init(this.APP_STATE, this.DOM);

            // El anuncio de apertura fue removido por solicitud del usuario (mejor UX)

            // Interceptar el botón "Atrás" de Android
            try {
                const { App } = await import('@capacitor/app');
                App.addListener('backButton', ({ canGoBack }) => {
                    // 1. Si el visor PDF está abierto, ciérralo
                    if (document.getElementById('vista-visor') && document.getElementById('vista-visor').style.display === 'block') {
                        const btnCerrar = document.getElementById('btn-cerrar');
                        if (btnCerrar) {
                            btnCerrar.click();
                            return;
                        }
                    }

                    // 2. Si hay un modal abierto, ciérralo
                    const modalVisible = document.querySelector('.modal-sheet.visible');
                    if (modalVisible) {
                        const bg = document.getElementById('modal-bg');
                        if (bg && bg.style.display === 'block') bg.click();
                        else uiController.cerrarModal(modalVisible);
                        return;
                    }

                    // 3. Si hay búsqueda activa, limpiar
                    const buscador = document.getElementById('buscador');
                    if (buscador && buscador.value !== '') {
                        buscador.value = '';
                        buscador.dispatchEvent(new Event('input'));
                        return;
                    }

                    // 4. Si estamos en favoritos, volver a todos los cantos
                    if (store.getState().categoriaActiva !== 'todos') {
                        window.location.hash = ''; // Vuelve al inicio
                        store.setState({ categoriaActiva: 'todos', busqueda: '', temaSeleccionado: 'Todos' });
                        if (document.getElementById('buscador')) document.getElementById('buscador').value = '';
                        return;
                    }

                    // Si no estamos en ninguna de las anteriores y no hay historial web, salir de la app
                    if (!canGoBack) {
                        App.exitApp();
                    } else {
                        window.history.back();
                    }
                });
            } catch(e) {
                console.log("No se pudo cargar @capacitor/app", e);
            }
            
            // Ocultar Splash Screen y mostrar app
            const splash = document.getElementById('splash-nativo');
            if (splash) {
                splash.style.opacity = '0';
                splash.style.visibility = 'hidden';
                setTimeout(() => splash.remove(), 500);
            }
            const menu = document.getElementById('vista-menu');
            if (menu) menu.style.opacity = '1';

        } catch (err) {
            console.error("Fallo crítico en arranque:", err);
            const errorDiv = document.createElement('div');
            errorDiv.style.cssText = "display:flex; justify-content:center; align-items:center; height:100vh; flex-direction:column; background:white; color:red;";
            errorDiv.innerHTML = '<h2>ERROR INICIANDO CATÁLOGO</h2>';
            const errorMsg = document.createElement('p');
            errorMsg.textContent = err.message;
            errorDiv.appendChild(errorMsg);
            document.body.innerHTML = '';
            document.body.appendChild(errorDiv);
        }
    }
};
