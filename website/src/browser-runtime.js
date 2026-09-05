const browserWindow = () => (typeof globalThis.window === 'undefined' ? null : globalThis.window)
const browserDocument = () => (typeof globalThis.document === 'undefined' ? null : globalThis.document)

export const getStoredTheme = () => {
  try {
    return browserWindow()?.localStorage?.getItem('coro-lldm-theme') === 'dark'
  } catch {
    return false
  }
}

export const storeTheme = (dark) => {
  try {
    browserWindow()?.localStorage?.setItem('coro-lldm-theme', dark ? 'dark' : 'light')
  } catch {
    // Storage can be disabled without affecting the site.
  }
}

export const locationParts = () => {
  const location = browserWindow()?.location
  return { pathname: location?.pathname || '/', search: location?.search || '' }
}

export const updateHistory = (method, url) => browserWindow()?.history?.[method]?.({}, '', url)
export const listen = (target, event, callback) => {
  target?.addEventListener?.(event, callback)
  return () => target?.removeEventListener?.(event, callback)
}
export const requestFrame = (callback) => browserWindow()?.requestAnimationFrame?.(callback) ?? globalThis.setTimeout(callback, 0)
export const cancelFrame = (id) => {
  const runtime = browserWindow()
  if (runtime?.cancelAnimationFrame) runtime.cancelAnimationFrame(id)
  else globalThis.clearTimeout(id)
}
export const schedule = (callback, delay) => browserWindow()?.setTimeout?.(callback, delay) ?? globalThis.setTimeout(callback, delay)
export const cancelSchedule = (id) => {
  const runtime = browserWindow()
  if (runtime?.clearTimeout) runtime.clearTimeout(id)
  else globalThis.clearTimeout(id)
}
export const scrollToTop = () => browserWindow()?.scrollTo?.({ top: 0, behavior: 'smooth' })
export const mainContent = () => browserDocument()?.getElementById('main-content')
export const pageDocument = () => browserDocument()
export const pageWindow = () => browserWindow()
