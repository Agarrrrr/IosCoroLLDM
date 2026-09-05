export async function fetchJsonWithTimeout(
  url,
  { fallback = null, required = false, cache, timeoutMs = 12_000, fetchImpl = globalThis.fetch, onController } = {},
) {
  const controller = new globalThis.AbortController()
  const timeout = globalThis.setTimeout(() => controller.abort(), timeoutMs)
  onController?.(controller, true)
  try {
    const response = await fetchImpl(url, { signal: controller.signal, ...(cache ? { cache } : {}) })
    if (!response.ok) {
      if (required) throw new Error(`${url}: ${response.status}`)
      return fallback
    }
    return await response.json()
  } catch (error) {
    if (required) throw error
    return fallback
  } finally {
    globalThis.clearTimeout(timeout)
    onController?.(controller, false)
  }
}
