import { describe, it, expect, beforeEach, vi } from 'vitest';
import { pdfEngine } from '../../src/core/pdfEngine.js';
import { anotacionesManager } from '../../src/core/anotacionesManager.js';

// Mock anotacionesManager
vi.mock('../../src/core/anotacionesManager.js', () => ({
    anotacionesManager: {
        guardarTrazoLocal: vi.fn(),
        obtenerTrazosLocal: vi.fn(() => [])
    }
}));

// Mock del entorno DOM para que pdfEngine no falle al buscar '.pdf-page-wrapper'
beforeEach(() => {
    HTMLCanvasElement.prototype.getContext = vi.fn(() => ({
        clearRect: vi.fn(),
        beginPath: vi.fn(),
        moveTo: vi.fn(),
        lineTo: vi.fn(),
        stroke: vi.fn(),
        fillText: vi.fn(),
        measureText: vi.fn(() => ({ width: 10 })),
        resetTransform: vi.fn(),
        setTransform: vi.fn(),
        scale: vi.fn(),
        canvas: { width: 800, height: 1000 }
    }));

    document.body.innerHTML = `
        <div class="pdf-page-wrapper" data-pagina="1">
            <canvas class="canvas-anotaciones" width="800" height="1000"></canvas>
        </div>
    `;
    
    // Configuración base de pdfEngine para tests
    pdfEngine.paginaActual = 1;
    pdfEngine.pdfActual = { cantoId: 'canto-test' };
    pdfEngine.anotacionesEstado = {
        1: {
            cantoId: 'canto-test',
            trazos: [],
            redoStack: []
        }
    };
    
    vi.clearAllMocks();
});

describe('pdfEngine Historial de Anotaciones', () => {
    
    it('deshacerAnotacion debe mover el último trazo al redoStack y guardar', () => {
        const trazo1 = { herramienta: 'lapiz', puntos: [{x:0, y:0}, {x:1, y:1}] };
        const trazo2 = { herramienta: 'lapiz', puntos: [{x:2, y:2}, {x:3, y:3}] };
        
        pdfEngine.anotacionesEstado[1].trazos = [trazo1, trazo2];
        
        pdfEngine.deshacerAnotacion();
        
        const estado = pdfEngine.anotacionesEstado[1];
        expect(estado.trazos.length).toBe(1);
        expect(estado.trazos[0]).toEqual(trazo1);
        expect(estado.redoStack.length).toBe(1);
        expect(estado.redoStack[0]).toEqual(trazo2);
        
        expect(anotacionesManager.guardarTrazoLocal).toHaveBeenCalledWith('canto-test', 1, estado.trazos);
    });

    it('deshacerAnotacion no debe hacer nada si no hay trazos', () => {
        pdfEngine.deshacerAnotacion();
        
        const estado = pdfEngine.anotacionesEstado[1];
        expect(estado.trazos.length).toBe(0);
        expect(estado.redoStack.length).toBe(0);
        expect(anotacionesManager.guardarTrazoLocal).not.toHaveBeenCalled();
    });

    it('rehacerAnotacion debe mover del redoStack a trazos y guardar', () => {
        const trazo = { herramienta: 'texto', texto: 'Hola', pos: { x: 0, y: 0 } };
        pdfEngine.anotacionesEstado[1].redoStack = [trazo];
        
        pdfEngine.rehacerAnotacion();
        
        const estado = pdfEngine.anotacionesEstado[1];
        expect(estado.trazos.length).toBe(1);
        expect(estado.trazos[0]).toEqual(trazo);
        expect(estado.redoStack.length).toBe(0);
        
        expect(anotacionesManager.guardarTrazoLocal).toHaveBeenCalledWith('canto-test', 1, estado.trazos);
    });

    it('borrarAnotaciones debe vaciar trazos y mover todo al inicio del redoStack', () => {
        const trazo1 = { id: 1 };
        const trazo2 = { id: 2 };
        const redo1 = { id: 3 };
        
        pdfEngine.anotacionesEstado[1].trazos = [trazo1, trazo2];
        pdfEngine.anotacionesEstado[1].redoStack = [redo1];
        
        pdfEngine.borrarAnotaciones();
        
        const estado = pdfEngine.anotacionesEstado[1];
        expect(estado.trazos.length).toBe(0);
        // Al borrar todo, los trazos borrados pasan al redoStack de forma inversa
        // Para que si hacemos deshacer (o rehacer? Wait. No hay deshacer de borrar todo, pero si tuvieramos "rehacer", recuperaría el array).
        // Actualmente borrarAnotaciones hace: estado.redoStack = [...estado.trazos].reverse().concat(estado.redoStack);
        expect(estado.redoStack).toEqual([trazo2, trazo1, redo1]);
        
        expect(anotacionesManager.guardarTrazoLocal).toHaveBeenCalledWith('canto-test', '1', []);
    });
});
