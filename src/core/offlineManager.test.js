import { describe, it, expect, vi, beforeEach } from 'vitest';
import { offlineManager } from './offlineManager.js';

describe('offlineManager', () => {
  let mockElement;

  beforeEach(() => {
    vi.clearAllMocks();
    
    mockElement = {
      style: {},
      textContent: '',
      innerHTML: '',
      classList: {
        add: vi.fn(),
        remove: vi.fn(),
      },
    };
  });

  it('resolverUrl debería retornar la url local', () => {
    const filename = 'canto.pdf';
    const url = offlineManager.resolverUrl(filename);
    expect(url).toBe('/offline_assets/pdfs/canto.pdf');
  });

  it('resolverUrlMidi debería retornar la url local', () => {
    const filename = 'canto.mid';
    const url = offlineManager.resolverUrlMidi(filename);
    expect(url).toBe('/offline_assets/midis/canto.mid');
  });

  it('actualizarContador debería mostrar disponible offline', async () => {
    const cantos = [{ archivo: '1.pdf' }];
    await offlineManager.actualizarContador(cantos, mockElement);

    expect(mockElement.style.display).toBe('inline-block');
    expect(mockElement.classList.add).toHaveBeenCalledWith('completado');
  });

  it('obtenerPorcentajeCache debería retornar 100', async () => {
    const percent = await offlineManager.obtenerPorcentajeCache();
    expect(percent).toBe(100);
  });
});
