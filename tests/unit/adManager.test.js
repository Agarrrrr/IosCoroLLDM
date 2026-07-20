import { describe, it, expect, beforeEach, vi } from 'vitest';
import { adManager } from '../../src/core/adManager.js';
import { limitsManager } from '../../src/core/limitsManager.js';

// Mock del módulo de AdMob
vi.mock('@capacitor-community/admob', () => {
    return {
        AdMob: {
            initialize: vi.fn().mockResolvedValue(true),
            prepareInterstitial: vi.fn().mockResolvedValue(true),
            showInterstitial: vi.fn().mockResolvedValue(true),
            prepareRewardVideoAd: vi.fn().mockResolvedValue(true),
            showRewardVideoAd: vi.fn().mockResolvedValue(true),
            prepareAppOpenAd: vi.fn().mockResolvedValue(true),
            showAppOpenAd: vi.fn().mockResolvedValue(true),
            addListener: vi.fn().mockReturnValue({ remove: vi.fn() })
        },
        RewardAdPluginEvents: {
            Rewarded: 'rewarded',
            Dismissed: 'dismissed',
            FailedToLoad: 'failedToLoad',
            FailedToShow: 'failedToShow'
        }
    };
});

// Mock UI Controller
global.window = {
    uiController: {
        mostrarModalPremium: vi.fn()
    },
    Capacitor: { isNativePlatform: () => true }
};

describe('adManager', () => {
    beforeEach(() => {
        vi.clearAllMocks();
        // Reset state
        adManager._inicializado = false;
        adManager._interstitialCargado = false;
        adManager._rewardedCargado = false;
        
        // Mock localStorage for stats
        const mockStorage = {};
        global.localStorage = {
            getItem: (key) => mockStorage[key] || null,
            setItem: (key, val) => { mockStorage[key] = val.toString(); }
        };
        
        // Asegurarnos de que no es premium para que ejecute lógica de ads
        vi.spyOn(limitsManager, 'esPremium').mockReturnValue(false);
    });

    it('debe inicializar AdMob correctamente en plataformas nativas', async () => {
        await adManager.inicializar();
        expect(adManager._inicializado).toBe(true);
        // Debe pre-cargar intersticial
        expect(adManager._interstitialCargado).toBe(true);
    });

    it('mostrarAnuncioRecompensaMidi() debe resolver falso si no está cargado', async () => {
        adManager._inicializado = true;
        adManager._rewardedCargado = false; // Forzar error
        const result = await adManager.mostrarAnuncioRecompensaMidi();
        expect(result).toBe(false);
    });

});
