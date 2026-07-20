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

// Pre-desbloqueo de AudioContext para iOS/Safari al primer gesto del usuario
const desbloquearAudioGlobal = () => {
    import('./core/midiEngine.js').then(({ midiEngine }) => {
        midiEngine.desbloquearAudioSync();
    }).catch(err => console.warn("Fallo en pre-desbloqueo de audio:", err));
    
    window.removeEventListener('touchstart', desbloquearAudioGlobal);
    window.removeEventListener('click', desbloquearAudioGlobal);
};
window.addEventListener('touchstart', desbloquearAudioGlobal, { passive: true });
window.addEventListener('click', desbloquearAudioGlobal, { passive: true });

// Corrección de layout al volver del background
import { App } from '@capacitor/app';
App.addListener('appStateChange', ({ isActive }) => {
    if (isActive) {
        document.body.style.height = '';
        document.documentElement.style.setProperty('--vh', `${window.innerHeight * 0.01}px`);
        if (window.nativePdfBridge?.isNative && window.pdfEngine?._modoNativo) {
            window.nativePdfBridge._applyInitialInset();
        }
    }
});