import { test, expect } from '@playwright/test';

test.describe('Visor E2E - Modo Dibujo', () => {
  test.beforeEach(async ({ page }) => {
    // Interceptar llamadas a Supabase para que arranque rápido y sin red real
    await page.route('**/*/rest/v1/eventos?*', async (route) => {
      await route.fulfill({ json: [] });
    });
    await page.route('**/*/rest/v1/cantos?*', async (route) => {
      await route.fulfill({ json: [] });
    });

    // Iniciar con un token falso para evitar redirigir a auth.html
    await page.addInitScript(() => {
        localStorage.setItem('eventos_permanentes', JSON.stringify(['test-folder']));
        localStorage.setItem('perfil_offline', JSON.stringify({ id: 'test', rol: 'superadmin' }));
        localStorage.setItem('sb-local-auth-token', JSON.stringify({
            access_token: 'fake',
            user: { id: 'test', email: 'test@test.com' }
        }));
        // Forzar modo offline para evitar colgar esperando sockets
        window.MODO_OFFLINE_FORZADO = true;
    });

    await page.goto('/?ev=test-folder', { waitUntil: 'networkidle' });
  });

  test('debe activar modo dibujo, trazar línea y permitir deshacer', async ({ page }) => {
    // Para interactuar con el visor, necesitamos abrir un PDF.
    // Como mockear todo el PDF.js en E2E es pesado, podemos simplemente 
    // evaluar un script en el navegador para que el uiController renderice el canvas directamente
    await page.evaluate(() => {
        // Mock de un visor abierto
        const visor = document.getElementById('vista-visor');
        if (visor) visor.style.display = 'block';

        const contenedor = document.getElementById('contenedor-pdf');
        if (contenedor) {
            contenedor.innerHTML = `
                <div class="pdf-page-wrapper" data-pagina="1" style="width: 800px; height: 1000px; position: relative;">
                    <canvas class="canvas-anotaciones" width="800" height="1000" style="position:absolute; top:0; left:0; width:100%; height:100%; z-index:5;"></canvas>
                </div>
            `;
            // Inyectar visor.js eventos
            window.dispatchEvent(new CustomEvent('cantoAbierto', { detail: { id: 'canto-1' } }));
        }
    });

    // En lugar de hacer click en botones (que tal vez estén ocultos si no hay PDF real), 
    // forzaremos el estado del engine para testear las colisiones de Playwright
    await page.evaluate(() => {
        return import('/src/core/pdfEngine.js').then((m) => {
            const pdfEngine = m.pdfEngine;
            pdfEngine.pdfActual = { cantoId: 'test-1' };
            pdfEngine.paginaActual = 1;
            pdfEngine.setModoDibujo(true);
            pdfEngine.herramientaDibujo = 'lapiz';
            
            const canvas = document.querySelector('.canvas-anotaciones');
            const ctx = canvas.getContext('2d');
            pdfEngine.bindEventosDibujo(canvas, ctx, 1, 800, 1000, 'test-1');
        });
    });

    // Esperar a que el canvas esté listo
    const canvas = page.locator('.canvas-anotaciones');
    await expect(canvas).toBeVisible();

    // Dibujar una línea usando eventos sintéticos para garantizar precisión matemática
    await page.evaluate(() => {
        const canvas = document.querySelector('.canvas-anotaciones');
        const rect = canvas.getBoundingClientRect();
        
        const eventStart = new MouseEvent('mousedown', { clientX: rect.left + 100, clientY: rect.top + 100 });
        const eventMove = new MouseEvent('mousemove', { clientX: rect.left + 200, clientY: rect.top + 200 });
        const eventEnd = new MouseEvent('mouseup', { clientX: rect.left + 200, clientY: rect.top + 200 });
        
        canvas.dispatchEvent(eventStart);
        canvas.dispatchEvent(eventMove);
        window.dispatchEvent(eventEnd);
    });

    // Verificar que se guardó en el engine
    const trazados = await page.evaluate(() => {
        return new Promise((resolve) => {
            import('/src/core/pdfEngine.js').then((m) => {
                const estado = m.pdfEngine.anotacionesEstado[1];
                resolve(estado ? estado.trazos.length : 0);
            });
        });
    });

    expect(trazados).toBe(1);

    // Ejecutar deshacer
    await page.evaluate(() => {
        return import('/src/core/pdfEngine.js').then((m) => {
            m.pdfEngine.deshacerAnotacion();
        });
    });

    // Verificar que bajó a 0
    const trazadosDespues = await page.evaluate(() => {
        return new Promise((resolve) => {
            import('/src/core/pdfEngine.js').then((m) => {
                const estado = m.pdfEngine.anotacionesEstado[1];
                resolve(estado ? estado.trazos.length : 0);
            });
        });
    });

    expect(trazadosDespues).toBe(0);
  });
});
