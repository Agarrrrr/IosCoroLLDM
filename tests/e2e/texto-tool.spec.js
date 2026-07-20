import { test, expect } from '@playwright/test';

test.describe('Visor E2E - Herramienta de Texto', () => {
  test.beforeEach(async ({ page }) => {
    await page.route('**/*/rest/v1/*?*', async (route) => {
      await route.fulfill({ json: [] });
    });

    await page.addInitScript(() => {
        localStorage.setItem('eventos_permanentes', JSON.stringify(['test-folder']));
        localStorage.setItem('perfil_offline', JSON.stringify({ id: 'test', rol: 'superadmin' }));
        localStorage.setItem('sb-local-auth-token', JSON.stringify({
            access_token: 'fake',
            user: { id: 'test' }
        }));
        window.MODO_OFFLINE_FORZADO = true;
    });

    await page.goto('/?ev=test-folder', { waitUntil: 'networkidle' });
  });

  test('debe abrir un input nativo al tocar con herramienta T y crear texto en canvas al perder foco', async ({ page }) => {
    // Inyectamos el canvas mockeado y activamos modo texto
    await page.evaluate(() => {
        const visor = document.getElementById('vista-visor');
        if (visor) visor.style.display = 'block';
        
        const contenedor = document.getElementById('contenedor-pdf');
        if (contenedor) {
            contenedor.innerHTML = `
                <div class="pdf-page-wrapper" data-pagina="1" style="width: 800px; height: 1000px; position: relative;">
                    <canvas class="canvas-anotaciones" width="800" height="1000" style="position:absolute; top:0; left:0; width:100%; height:100%; z-index:5;"></canvas>
                </div>
            `;
        }
    });

    await page.evaluate(() => {
        return import('/src/core/pdfEngine.js').then((m) => {
            const pdfEngine = m.pdfEngine;
            pdfEngine.pdfActual = { cantoId: 'test-2' };
            pdfEngine.paginaActual = 1;
            pdfEngine.setModoDibujo(true);
            pdfEngine.herramientaDibujo = 'texto';
            
            const canvas = document.querySelector('.canvas-anotaciones');
            const ctx = canvas.getContext('2d');
            pdfEngine.bindEventosDibujo(canvas, ctx, 1, 800, 1000, 'test-2');
        });
    });

    const canvas = page.locator('.canvas-anotaciones');
    await expect(canvas).toBeVisible();

    // Hacemos click en el canvas mediante un evento sintético para evitar problemas de mouse de Playwright
    await page.evaluate(() => {
        const canvas = document.querySelector('.canvas-anotaciones');
        const rect = canvas.getBoundingClientRect();
        const eventStart = new MouseEvent('mousedown', { clientX: rect.left + 150, clientY: rect.top + 150 });
        const eventEnd = new MouseEvent('mouseup', { clientX: rect.left + 150, clientY: rect.top + 150 });
        canvas.dispatchEvent(eventStart);
        window.dispatchEvent(eventEnd);
    });

    // Debería aparecer un input
    const inputFlotante = page.locator('.pdf-page-wrapper input[type="text"]');
    await expect(inputFlotante).toBeVisible();
    
    // Escribimos algo en el input
    await inputFlotante.fill('Coro Sopranos');
    
    // Presionamos Enter
    await inputFlotante.press('Enter');

    // El input debe desaparecer
    await expect(inputFlotante).toBeHidden();

    // Comprobamos que el engine haya guardado el texto
    const estadoTrazos = await page.evaluate(() => {
        return new Promise((resolve) => {
            import('/src/core/pdfEngine.js').then((m) => {
                const estado = m.pdfEngine.anotacionesEstado[1];
                resolve(estado ? estado.trazos : []);
            });
        });
    });

    expect(estadoTrazos.length).toBe(1);
    expect(estadoTrazos[0].herramienta).toBe('texto');
    expect(estadoTrazos[0].texto).toBe('Coro Sopranos');
  });
});
