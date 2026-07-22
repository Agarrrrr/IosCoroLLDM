import './core/polyfills.js';
import { globalErrorHandler } from './core/globalErrorHandler.js';
globalErrorHandler.iniciar();

import { store } from './core/stateManager.js';
import { i18n } from './core/i18n.js';
import { appInitializer } from './app/appInitializer.js';
import { dashboardUI } from './features/dashboard/dashboardUI.js';

// QoL: Desactivar restauración automática del navegador para evitar conflictos con nuestra persistencia manual
if ('scrollRestoration' in history) {
    history.scrollRestoration = 'manual';
}

// MIGRACIÓN: El estado ahora vive en la Store central
const APP_STATE = store.getState();

// Suscribirse a cambios del store para mantener la UI sincronizada localmente
store.subscribe((state) => {
    Object.assign(APP_STATE, state);
});

// Inicializar UI traducciones
i18n.updateDOM();

// Arrancar la aplicación usando el nuevo inicializador
appInitializer.iniciar(APP_STATE, dashboardUI.DOM, dashboardUI.UI_API);

import { midiEngine } from './core/midiEngine.js';

// Pre-desbloqueo de AudioContext para iOS/Safari al primer gesto del usuario
const desbloquearAudioGlobal = () => {
    try {
        midiEngine.desbloquearAudioSync();
    } catch(err) {
        console.warn("Fallo en pre-desbloqueo de audio:", err);
    }
    window.removeEventListener('touchstart', desbloquearAudioGlobal, { capture: true });
    window.removeEventListener('click', desbloquearAudioGlobal, { capture: true });
};
window.addEventListener('touchstart', desbloquearAudioGlobal, { capture: true, passive: true });
window.addEventListener('click', desbloquearAudioGlobal, { capture: true, passive: true });

// Corrección de layout al volver del background
import { App } from '@capacitor/app';
App.addListener('appStateChange', ({ isActive }) => {
    if (isActive) {
        document.body.style.height = '';
        document.documentElement.style.setProperty('--vh', `${window.innerHeight * 0.01}px`);
        
        const vistaMenu = document.getElementById('vista-menu');
        const vistaVisor = document.getElementById('vista-visor');

        // Disparar evento resize global para que CSS recalcule el viewport completo en iOS
        window.dispatchEvent(new Event('resize'));

        if (vistaMenu) {
            // Remover cualquier clase de animación atascada por la pausa de WebKit al minimizar
            vistaMenu.classList.remove('anim-dashboard-out', 'anim-dashboard-in');
            
            if (vistaVisor && vistaVisor.style.display === 'block') {
                vistaMenu.style.display = 'none';
            } else {
                vistaMenu.style.display = 'flex';
                vistaMenu.style.opacity = '1';
                // Forzar reflow en WebKit para re-dibujar la vista al 100% de ancho
                void vistaMenu.offsetWidth;
            }
        }

        if (window.nativePdfBridge?.isNative && window.pdfEngine?._modoNativo) {
            window.nativePdfBridge._applyInitialInset();
        }
    }
});