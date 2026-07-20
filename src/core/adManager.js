import { AdMob, BannerAdSize, BannerAdPosition, RewardAdPluginEvents } from '@capacitor-community/admob';
import { limitsManager } from './limitsManager.js';
import { i18n } from './i18n.js';
import { App } from '@capacitor/app';

// IDs Oficiales de Producción
const AD_IDS = {
    APP_OPEN: 'ca-app-pub-1667188991926373/4859596502',
    BANNER: 'ca-app-pub-1667188991926373/7485759845',
    INTERSTITIAL: 'ca-app-pub-1667188991926373/7190512306',
    REWARDED: 'ca-app-pub-1667188991926373/5266790613'
};

// MODO REVISIÓN: Activar en true para evitar anuncios durante la revisión de Play Store/App Store
const MODO_REVISION_PLAYSTORE = false;

export const adManager = {
    _inicializado: false,
    _interstitialCargado: false,
    _rewardedCargado: false,
    _appOpenCargado: false,

    async inicializar() {
        if (MODO_REVISION_PLAYSTORE) return; // Bloquear AdMob para la revisión
        if (!window.Capacitor || !window.Capacitor.isNativePlatform()) return;
        if (limitsManager.esPremium()) return; // Si es premium, ni siquiera iniciar AdMob

        try {
            await AdMob.initialize({
                requestTrackingAuthorization: true,
                initializeForTesting: false
            });
            this._inicializado = true;

            // Pre-cargar Anuncios
            this.preCargarIntersticial();
            this.preCargarAnuncioRecompensa();
            this.preCargarAppOpen();

            // Escuchar cuando la app regresa del segundo plano (background)
            App.addListener('appStateChange', async ({ isActive }) => {
                if (isActive && this._appOpenCargado && !limitsManager.esPremium()) {
                    try {
                        await AdMob.showAppOpenAd();
                        this._appOpenCargado = false;
                        this.preCargarAppOpen(); // Pre-cargar el siguiente
                    } catch (err) {
                        console.warn("[AdManager] Error mostrando App Open Ad:", err);
                    }
                }
            });

        } catch(e) {
            console.warn("[AdManager] Error iniciando AdMob:", e);
        }
    },

    async preCargarAppOpen() {
        if (!this._inicializado || limitsManager.esPremium()) return;
        try {
            await AdMob.prepareAppOpenAd({
                adId: AD_IDS.APP_OPEN,
                isTesting: false
            });
            this._appOpenCargado = true;
        } catch (e) {
            console.warn("[AdManager] Fallo precarga de App Open Ad:", e);
        }
    },

    async mostrarBannerInferior() {
        if (!this._inicializado || limitsManager.esPremium()) return;

        try {
            await AdMob.showBanner({
                adId: AD_IDS.BANNER,
                adSize: BannerAdSize.ADAPTIVE_BANNER,
                position: BannerAdPosition.BOTTOM_CENTER,
                margin: 0,
                isTesting: false
            });
            
            // Ajustar el padding inferior de la app para que el banner no tape la lista
            document.documentElement.style.setProperty('--ad-banner-height', '80px');
            document.body.classList.add('con-anuncios');

        } catch (e) {
            console.warn("[AdManager] Error mostrando banner:", e);
            this._mostrarHouseAdBanner(); // Fallback a donación
        }
    },

    async ocultarBanner() {
        if (!this._inicializado) return;
        try {
            await AdMob.hideBanner();
        } catch (e) {}
        
        document.body.classList.remove('con-anuncios');
        document.documentElement.style.setProperty('--ad-banner-height', '0px');
        const houseAd = document.getElementById('house-ad-banner');
        if (houseAd) houseAd.remove();
    },

    async preCargarIntersticial() {
        if (!this._inicializado || limitsManager.esPremium()) return;
        try {
            await AdMob.prepareInterstitial({
                adId: AD_IDS.INTERSTITIAL,
                isTesting: false
            });
            this._interstitialCargado = true;
        } catch (e) {
            console.warn("[AdManager] Fallo precarga de intersticial:", e);
        }
    },

    async mostrarIntersticial() {
        if (!this._inicializado || limitsManager.esPremium() || !this._interstitialCargado) return false;
        
        return new Promise((resolve) => {
            let listenerDismissed;
            let listenerFailed;
            
            const cleanup = () => {
                if (listenerDismissed) listenerDismissed.remove();
                if (listenerFailed) listenerFailed.remove();
            };

            listenerDismissed = AdMob.addListener('interstitialAdDismissed', () => {
                cleanup();
                resolve(true);
            });

            listenerFailed = AdMob.addListener('interstitialAdFailedToShow', () => {
                cleanup();
                resolve(false);
            });

            AdMob.showInterstitial().then(() => {
                this._interstitialCargado = false;
                this.preCargarIntersticial();
                
                // Sugerir suscripción para quitar anuncios solo cada 5 veces, si no ha optado por ocultarlo
                let mostrados = parseInt(localStorage.getItem('stats_intersticiales') || '0') + 1;
                localStorage.setItem('stats_intersticiales', mostrados);
                
                if (mostrados % 5 === 0 && localStorage.getItem('ocultar_modal_pro_anuncios') !== 'true') {
                    if (window.uiController && typeof window.uiController.mostrarModalPremium === 'function') {
                        setTimeout(() => {
                            window.uiController.mostrarModalPremium('anuncios');
                        }, 500);
                    }
                }
            }).catch((e) => {
                console.warn("[AdManager] Error mostrando intersticial:", e);
                cleanup();
                resolve(false);
            });
        });
    },

    async preCargarAnuncioRecompensa() {
        if (!this._inicializado || limitsManager.esPremium()) return;
        try {
            await AdMob.prepareRewardVideoAd({
                adId: AD_IDS.REWARDED,
                isTesting: false
            });
            this._rewardedCargado = true;
        } catch (e) {
            console.warn("[AdManager] Fallo precarga de Rewarded Ad:", e);
        }
    },

    mostrarAnuncioRecompensaMidi() {
        return new Promise(async (resolve) => {
            if (!this._inicializado || limitsManager.esPremium() || !this._rewardedCargado) {
                return resolve(false);
            }

            let rewardObtenido = false;

            // Escuchar cuando el usuario recibe el premio
            const rewardListener = AdMob.addListener(RewardAdPluginEvents.Rewarded, () => {
                rewardObtenido = true;
            });

            // Escuchar cuando se cierra el anuncio
            const dismissListener = AdMob.addListener(RewardAdPluginEvents.Dismissed, () => {
                rewardListener.remove();
                dismissListener.remove();
                this._rewardedCargado = false;
                this.preCargarAnuncioRecompensa(); // Recargar para la próxima
                resolve(rewardObtenido);
            });

            try {
                await AdMob.showRewardVideoAd();
            } catch (e) {
                console.warn("[AdManager] Error mostrando Rewarded Ad:", e);
                rewardListener.remove();
                dismissListener.remove();
                resolve(false);
            }
        });
    },

    _mostrarHouseAdBanner() {
        // En caso de estar Offline o usar AdBlock
        // Inyectamos un banner pidiendo apoyo
        if (document.getElementById('house-ad-banner')) return;
        
        const houseAd = document.createElement('div');
        houseAd.id = 'house-ad-banner';
        houseAd.className = 'house-ad-banner';
        houseAd.innerHTML = `
            <div class="house-ad-content">
                <span>${i18n.t('premium.house_ad_mensaje')}</span>
                <button onclick="window.uiController.mostrarModalPremium()">${i18n.t('premium.house_ad_btn')}</button>
            </div>
        `;
        document.body.appendChild(houseAd);
        document.documentElement.style.setProperty('--ad-banner-height', '80px');
        document.body.classList.add('con-anuncios');
    }
};

window.adManager = adManager;
