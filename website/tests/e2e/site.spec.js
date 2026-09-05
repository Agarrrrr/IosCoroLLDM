import { expect, test } from '@playwright/test'

const paths = ['/', '/producto', '/repertorio', '/soluciones', '/roadmap', '/contacto', '/en/', '/en/producto', '/en/repertorio']

test.describe('public navigation', () => {
  for (const path of paths) {
    test(`${path} renders one primary heading without runtime errors`, async ({ page }) => {
      const errors = []
      page.on('pageerror', (error) => errors.push(error.message))
      page.on('console', (message) => {
        const expectedExternalFontFailure = /fonts\.googleapis\.com|ERR_NETWORK_ACCESS_DENIED/.test(message.text())
        if (message.type() === 'error' && !expectedExternalFontFailure) errors.push(message.text())
      })
      await page.goto(path)
      await expect(page.locator('h1')).toHaveCount(1)
      await page.waitForTimeout(150)
      expect(errors).toEqual([])
    })
  }

  test('theme, language and mobile navigation give visible feedback', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto('/')
    await page.getByLabel(/cambiar tema|change theme/i).click()
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
    await page.getByLabel(/cambiar idioma a inglés|change language to english/i).click()
    await expect(page).toHaveURL(/\/en\/?$/)
    await page.getByLabel(/open menu|abrir menú|more pages|más páginas/i).click()
    await expect(page.getByRole('navigation', { name: /primary navigation|navegación principal/i })).toBeVisible()
  })

  test('keyboard navigation reaches content and closes the mobile menu', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto('/')
    const skipLink = page.getByRole('link', { name: /skip to content|saltar al contenido/i })
    await skipLink.focus()
    await expect(skipLink).toBeFocused()
    await page.keyboard.press('Enter')
    await expect(page.locator('#main-content')).toBeFocused()
    const menu = page.getByLabel(/open menu|abrir menú|more pages|más páginas|más secciones/i)
    await menu.click()
    await expect(menu).toHaveAttribute('aria-expanded', 'true')
    await page.keyboard.press('Escape')
    await expect(menu).toHaveAttribute('aria-expanded', 'false')
    await expect(menu).toBeFocused()
  })
})
