import { limitsManager } from './limitsManager.js';
import { i18n } from './i18n.js';

export const adManager = {
    _inicializado: false,
    _interstitialCargado: false,
    _rewardedCargado: false,
    _appOpenCargado: false,

    async inicializar() {
        console.log("[AdManager] Anuncios deshabilitados por configuración.");
    },

    async preCargarAppOpen() {},

    async mostrarBannerInferior() {},

    async ocultarBanner() {
        document.body.classList.remove('con-anuncios');
        document.documentElement.style.setProperty('--ad-banner-height', '0px');
    },

    async preCargarIntersticial() {},

    async mostrarIntersticial() {
        return false;
    },

    async preCargarAnuncioRecompensa() {},

    mostrarAnuncioRecompensaMidi() {
        return Promise.resolve(true);
    },

    _mostrarHouseAdBanner() {}
};

window.adManager = adManager;
