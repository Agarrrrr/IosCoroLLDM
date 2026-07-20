import { test, expect } from '@playwright/test';

test.describe('Modo Offline PWA', () => {
  test('debería funcionar la carga básica incluso sin red (simulado)', async ({ page, context }) => {
    // Aumentar timeout para este test específico (PWA es lento en dev)
    test.setTimeout(60000);

    // 1. Cargar la página por primera vez para registrar el SW
    await page.goto('/auth.html');
    await expect(page.locator('h1')).toHaveText('Acceso de Miembros');

    // 2. Esperar a que el Service Worker esté registrado y activo
    await page.evaluate(async () => {
      // ready resuelve cuando hay un worker activo (tras install/activate)
      await navigator.serviceWorker.ready;
    });

    // 3. RECARGA DE CALENTAMIENTO (Warm-up):
    // Recargamos mientras estamos ONLINE. Al recargar, el SW ya activo tomará
    // el control de la página automáticamente, poblando el caché de runtime.
    await page.reload({ waitUntil: 'load' });
    
    // Verificar que el SW tiene el control real
    const isControlled = await page.evaluate(() => !!navigator.serviceWorker.controller);
    if (!isControlled) {
        // Si no tiene control, intentamos una espera corta por si acaso
        await page.waitForTimeout(2000);
    }

    await expect(page.locator('h1')).toHaveText('Acceso de Miembros');

    // Pausa breve para asegurar que la escritura en caché se complete
    await page.waitForTimeout(2000);

    // 4. Simular offline
    await context.setOffline(true);
    
    // 5. Recargar la página en modo OFFLINE
    await page.reload({ waitUntil: 'load' });

    // 6. Verificar que el contenido real sigue ahí (servido desde el caché por el SW)
    const h1 = page.locator('h1');
    await expect(h1).toBeVisible({ timeout: 15000 });
    await expect(h1).toHaveText('Acceso de Miembros');
    
    // 7. Verificar que el estado offline es detectado
    const isOffline = await page.evaluate(() => !navigator.onLine);
    expect(isOffline).toBe(true);
  });
});
