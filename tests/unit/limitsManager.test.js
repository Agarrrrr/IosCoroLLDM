import { describe, it, expect } from 'vitest';
import { limitsManager } from '../../src/core/limitsManager.js';

describe('limitsManager (Modo Ilimitado)', () => {
    it('debe permitir reproducciones de audio ilimitadas por defecto', () => {
        expect(limitsManager.esPremium()).toBe(true);
        expect(limitsManager.puedeReproducirAudio()).toBe(true);
        expect(limitsManager.estaBloqueadoPorDRM()).toBe(false);
        expect(limitsManager.obtenerAudiosRestantes()).toBe('Ilimitado');
    });

    it('debe permitir reproducciones consecutivas sin aplicar cobros ni bloqueos', () => {
        for (let i = 0; i < 20; i++) {
            expect(limitsManager.puedeReproducirAudio()).toBe(true);
            limitsManager.registrarReproduccionAudio(`canto-${i}`);
        }
        expect(limitsManager.puedeReproducirAudio()).toBe(true);
        expect(limitsManager.estaBloqueadoPorDRM()).toBe(false);
    });
});
