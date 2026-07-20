import { test, expect } from '@playwright/test';

test.describe('Autenticación', () => {
  test('debería mostrar la página de login', async ({ page }) => {
    await page.goto('/auth.html');
    
    // Verificar que el título real esté presente
    await expect(page).toHaveTitle(/Acceso | RepertorioBC/i);
    
    // Verificar que el formulario de login sea visible por defecto
    await expect(page.locator('#form-login')).toBeVisible();
    await expect(page.locator('h1')).toHaveText('Acceso de Miembros');
  });
});
