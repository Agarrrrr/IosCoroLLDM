import { limitsManager } from './limitsManager.js';

// Stub de RevenueCat (Deshabilitado temporalmente)
const Purchases = null;

export const revenueManager = {
    precioMensual: "$49.00 MXN",
    precioAnual: "$299.00 MXN",
    paqueteMensual: null,
    paqueteAnual: null,

    async inicializar() {
        console.log("[RevenueCat] Módulo deshabilitado temporalmente.");
    },

    _actualizarEstadoDesdeInfo(info) {
        if (info && info.entitlements && info.entitlements.active['premium']) {
            limitsManager.setPremium(true);
        } else {
            limitsManager.setPremium(false);
        }
    },

    async comprarPremium(tipo = 'anual') {
        if (window.uiController && typeof window.uiController.mostrarToast === 'function') {
            window.uiController.mostrarToast("Las compras están deshabilitadas temporalmente.", "info");
        }
    },

    async restaurarCompras() {
        if (window.uiController && typeof window.uiController.mostrarToast === 'function') {
            window.uiController.mostrarToast("No hay compras para restaurar.", "info");
        }
    }
};

window.revenueManager = revenueManager;
