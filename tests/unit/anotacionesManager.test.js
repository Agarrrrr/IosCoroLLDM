import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { anotacionesManager } from '../../src/core/anotacionesManager.js';

// Mock dependencias
vi.mock('../../src/api/supabase.js', () => ({
    supabase: {
        from: vi.fn(() => ({
            select: vi.fn().mockReturnThis(),
            eq: vi.fn().mockReturnThis(),
            upsert: vi.fn()
        }))
    }
}));

vi.mock('../../src/core/stateManager.js', () => ({
    store: {
        getState: vi.fn(() => ({
            perfil: { id: 'user-123' },
            online: true
        }))
    }
}));

describe('anotacionesManager', () => {
    beforeEach(() => {
        // Limpiar mocks y localStorage antes de cada prueba
        vi.clearAllMocks();
        localStorage.clear();
        vi.useFakeTimers();
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('debe devolver la clave correcta para localStorage', () => {
        const key = anotacionesManager._getKey('canto-1', 2);
        expect(key).toBe('anotaciones_canto-1_2');
    });

    it('debe guardar trazos en localStorage y programar sincronización', () => {
        const programarSpy = vi.spyOn(anotacionesManager, 'programarSincronizacion');
        const trazos = [{ herramienta: 'lapiz', puntos: [] }];
        
        anotacionesManager.guardarTrazoLocal('canto-1', 1, trazos);
        
        const guardado = JSON.parse(localStorage.getItem('anotaciones_canto-1_1'));
        expect(guardado.canto_id).toBe('canto-1');
        expect(guardado.pagina).toBe(1);
        expect(guardado.trazos).toEqual(trazos);
        expect(guardado.sync_status).toBe('synced');
    });

    it('debe obtener los trazos locales si existen', () => {
        const trazos = [{ herramienta: 'texto', texto: 'Hola' }];
        localStorage.setItem('anotaciones_canto-2_1', JSON.stringify({
            trazos: trazos
        }));

        const obtenidos = anotacionesManager.obtenerTrazosLocal('canto-2', 1);
        expect(obtenidos).toEqual(trazos);
    });

    it('debe devolver un arreglo vacío si no hay trazos locales', () => {
        const obtenidos = anotacionesManager.obtenerTrazosLocal('canto-99', 1);
        expect(obtenidos).toEqual([]);
    });

    it('debe devolver un arreglo vacío si el JSON es inválido', () => {
        localStorage.setItem('anotaciones_canto-3_1', 'no-es-json');
        const obtenidos = anotacionesManager.obtenerTrazosLocal('canto-3', 1);
        expect(obtenidos).toEqual([]);
    });
});
