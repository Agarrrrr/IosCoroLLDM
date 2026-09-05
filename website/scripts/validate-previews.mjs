import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const websiteDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const manifestPath = resolve(websiteDirectory, 'public', 'preview-manifest.json')
const reportDirectory = resolve(websiteDirectory, '.reports')
const reportPath = resolve(reportDirectory, 'preview-validation.json')
const previewOrigin = 'https://coro-lldm-previews.huritolentino.workers.dev/previews'
const siteOrigin = 'https://coro-lldm.pages.dev'
const concurrency = 12

const manifest = JSON.parse(await readFile(manifestPath, 'utf8'))
const checks = Object.entries(manifest.previews || {}).flatMap(([key, value]) => {
  const sources = typeof value === 'string' ? { opus: value } : value
  return [
    { key, format: 'opus', file: sources?.opus, contentType: 'audio/ogg' },
    { key, format: 'aac', file: sources?.aac, contentType: 'audio/mp4' },
  ]
})
const failures = []
const inspect = async (check) => {
  if (!check.file) {
    failures.push({ ...check, reason: 'Missing manifest entry' })
    return
  }
  const controller = new globalThis.AbortController()
  const timeout = globalThis.setTimeout(() => controller.abort(), 12_000)
  try {
    const response = await fetch(`${previewOrigin}/${encodeURIComponent(check.file)}`, {
      method: 'HEAD',
      headers: { Origin: siteOrigin },
      signal: controller.signal,
    })
    const type = response.headers.get('content-type') || ''
    const cors = response.headers.get('access-control-allow-origin')
    if (!response.ok || !type.includes(check.contentType) || cors !== siteOrigin) {
      failures.push({ ...check, status: response.status, contentType: type, cors, reason: 'Unexpected public response' })
    }
  } catch (error) {
    failures.push({ ...check, reason: error.name === 'AbortError' ? 'Timeout' : error.message })
  } finally {
    globalThis.clearTimeout(timeout)
  }
}

let cursor = 0
await Promise.all(
  Array.from({ length: Math.min(concurrency, checks.length) }, async () => {
    while (cursor < checks.length) {
      const check = checks[cursor]
      cursor += 1
      await inspect(check)
    }
  }),
)

let publishedManifest = null
try {
  const response = await fetch(`${siteOrigin}/preview-manifest.json`, { headers: { 'Cache-Control': 'no-cache' } })
  publishedManifest = response.ok ? await response.json() : { status: response.status }
} catch (error) {
  publishedManifest = { error: error.message }
}
const publishedReady =
  publishedManifest?.version === 2 &&
  Object.keys(publishedManifest?.previews || {}).length === Object.keys(manifest.previews || {}).length &&
  Object.values(publishedManifest?.previews || {}).every((value) => value?.opus && value?.aac)
if (!publishedReady) failures.push({ reason: 'Pages does not expose the expected v2 manifest', publishedManifest })

const report = {
  checkedAt: new Date().toISOString(),
  expected: checks.length,
  passed: checks.length - failures.filter((failure) => failure.file).length,
  publishedManifest: { version: publishedManifest?.version ?? null, entries: Object.keys(publishedManifest?.previews || {}).length },
  failures,
}
await mkdir(reportDirectory, { recursive: true })
await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`)
if (failures.length) throw new Error(`Preview validation failed: ${failures.length} issue(s). See ${reportPath}.`)
console.log(`Validated ${checks.length} public preview files and the Pages manifest.`)
