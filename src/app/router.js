import { uiController } from '../ui/uiController.js';
import { store } from '../core/stateManager.js';
import { pdfEngine } from '../core/pdfEngine.js';

export const router = {
    init: async function(APP_STATE, DOM) {
        this.manejarLinkCanto(APP_STATE, DOM);
    },

    manejarLinkCanto: function(APP_STATE, DOM) {
        const urlParams = new URLSearchParams(window.location.search);
        const idCantoLink = urlParams.get('canto');
        
        if (idCantoLink) {
            const intentarAbrir = (cantos) => {
                const cantoPush = cantos.find(c => c.id == idCantoLink);
                if (cantoPush) {
                    window.location.hash = 'visor';
                    pdfEngine.abrirVisor(cantoPush, DOM.contenedorPdf, DOM.barraSuperior);
                    uiController.cerrarBanner('banner-vivo');
                }
                const cleanUrl = window.location.origin + window.location.pathname;
                window.history.replaceState({}, document.title, cleanUrl);
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
    }
};
