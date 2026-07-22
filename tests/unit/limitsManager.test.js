import { describe, it, expect, beforeEach, vi } from 'vitest';
import { limitsManager } from '../../src/core/limitsManager.js';

describe('limitsManager (Anti-Trampas y DRM)', () => {
    let mockStorage = {};
    
    beforeEach(() => {
        // Mock localStorage
        mockStorage = {};
        global.localStorage = {
            getItem: (key) => mockStorage[key] || null,
            setItem: (key, val) => { mockStorage[key] = val.toString(); },
            clear: () => { mockStorage = {}; }
        };
        
        // Mock global fetch
        global.fetch = vi.fn();
        
        // Mock Capacitor
        global.window = { Capacitor: { isNativePlatform: () => true } };
        
        vi.useFakeTimers();
    });
    
    afterEach(() => {
        vi.restoreAllMocks();
    });

    it('debe permitir solo MAX_AUDIOS_DIARIOS a un usuario gratis', () => {
        limitsManager.setPremium(false);
        const MAX = limitsManager.LIMITES.MAX_AUDIOS_DIARIOS;
        
        for (let i = 0; i < MAX; i++) {
            expect(limitsManager.puedeReproducirAudio()).toBe(true);
            limitsManager.registrarReproduccionAudio(`canto-${i}`);
        }
        
        expect(limitsManager.puedeReproducirAudio()).toBe(false);
        expect(limitsManager.registrarReproduccionAudio('canto-extra')).toBe(false);
    });

    it('no debe cobrar un audio si el canto reproducido es el mismo (sesión)', () => {
        limitsManager.setPremium(false);
        limitsManager.registrarReproduccionAudio('canto-1');
        const permitioRepetido = limitsManager.registrarReproduccionAudio('canto-1');
        
        expect(permitioRepetido).toBe(false); // Falso indica que no se descontó del saldo
        const estado = JSON.parse(mockStorage['limites_diarios']);
        expect(estado.audiosReproducidos).toBe(1);
    });

    it('debe bloquear reseteo si el reloj del dispositivo retrocede (Time-Travel)', () => {
        limitsManager.setPremium(false);
        
        // Simular que gastó los audios hoy (ej: año 2026)
        const date2026 = new Date('2026-06-19T10:00:00Z');
        vi.setSystemTime(date2026);
        for(let i = 0; i < limitsManager.LIMITES.MAX_AUDIOS_DIARIOS; i++) limitsManager.registrarReproduccionAudio(`c-${i}`);
        expect(limitsManager.puedeReproducirAudio()).toBe(false);
        
        // Usuario hace trampa y cambia su fecha a 2024 para evadir el pago
        const date2024 = new Date('2024-06-19T10:00:00Z');
        vi.setSystemTime(date2024);
        
        // limitsManager._obtenerEstadoHoy() debe detectar que Date.now() < estado.last_timestamp
        const puedeTramposo = limitsManager.puedeReproducirAudio();
        expect(puedeTramposo).toBe(false); // Sigue bloqueado
    });

    it('debe resetear los limites si avanzó un día normal', () => {
        limitsManager.setPremium(false);
        
        const hoy = new Date('2026-06-19T10:00:00Z');
        vi.setSystemTime(hoy);
        for(let i = 0; i < limitsManager.LIMITES.MAX_AUDIOS_DIARIOS; i++) limitsManager.registrarReproduccionAudio(`c-${i}`);
        expect(limitsManager.puedeReproducirAudio()).toBe(false);
        
        const manana = new Date('2026-06-20T10:00:00Z');
        vi.setSystemTime(manana);
        expect(limitsManager.puedeReproducirAudio()).toBe(true);
    });

    it('debe bloquear el reproductor (DRM) tras 3 días offline consecutivos', () => {
        limitsManager.setPremium(false);
        
        // Simular 3 saltos de día sin conectarse a internet
        let date = new Date('2026-06-10T10:00:00Z');
        vi.setSystemTime(date);
        limitsManager.puedeReproducirAudio(); // Crea el registro
        
        for (let j = 1; j <= 3; j++) {
            date.setDate(date.getDate() + 1);
            vi.setSystemTime(date);
            limitsManager.puedeReproducirAudio(); // Suma offline_resets_count
        }
        
        // El cuarto día (offline_resets_count = 3), debería activar bloqueo_drm
        date.setDate(date.getDate() + 1);
        vi.setSystemTime(date);
        
        expect(limitsManager.puedeReproducirAudio()).toBe(false);
        expect(limitsManager.estaBloqueadoPorDRM()).toBe(true);
    });
});
