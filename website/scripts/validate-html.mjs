import { readFile } from 'node:fs/promises'
import { readdir } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { resolve } from 'node:path'

const dist = resolve(fileURLToPath(new URL('.', import.meta.url)), '../dist')
const collectHtmlFiles = async (directory) => {
  const entries = await readdir(directory, { withFileTypes: true })
  const nested = await Promise.all(
    entries.map((entry) => {
      const target = resolve(directory, entry.name)
      return entry.isDirectory() ? collectHtmlFiles(target) : entry.name.endsWith('.html') ? [target] : []
    }),
  )
  return nested.flat()
}
const files = await collectHtmlFiles(dist)
const errors = []
for (const file of files) {
  const html = await readFile(file, 'utf8')
  if (!/<title>[^<]+<\/title>/.test(html)) errors.push(`${file}: missing title`)
  if (!/<meta name="description" content="[^"]+">/.test(html)) errors.push(`${file}: missing description`)
  if ((html.match(/<h1\b/g) || []).length !== 1) errors.push(`${file}: expected exactly one h1`)
  if (!/<html[^>]+lang="(es|en)"/.test(html)) errors.push(`${file}: missing language declaration`)
  if ((html.match(/<link[^>]+rel="canonical"/g) || []).length !== 1) errors.push(`${file}: expected exactly one canonical link`)
  if ((html.match(/data-seo-alternate=/g) || []).length !== 3) errors.push(`${file}: expected three language alternates`)
  for (const selector of [
    'property="og:locale"',
    'name="twitter:card"',
    'name="twitter:title"',
    'name="twitter:description"',
    'name="twitter:image"',
  ]) {
    if ((html.match(new RegExp(selector, 'g')) || []).length !== 1) errors.push(`${file}: expected one ${selector} metadata tag`)
  }
  if (/<img\b(?![^>]*\balt=)[^>]*>/i.test(html)) errors.push(`${file}: image without alt attribute`)
  if (/<img\b(?![^>]*\bwidth=)[^>]*>/i.test(html) || /<img\b(?![^>]*\bheight=)[^>]*>/i.test(html))
    errors.push(`${file}: image without explicit dimensions`)
  if (/<button\b[^>]*>\s*<svg[^>]*>\s*<\/button>/i.test(html)) errors.push(`${file}: icon-only button without accessible name`)
  const structuredData = [...html.matchAll(/<script id="page-structured-data" type="application\/ld\+json">([\s\S]*?)<\/script>/g)]
  if (structuredData.length !== 1) errors.push(`${file}: expected exactly one structured-data block`)
  for (const [, json] of structuredData) {
    try {
      const value = JSON.parse(json)
      if (value['@context'] !== 'https://schema.org' || !Array.isArray(value['@graph'])) errors.push(`${file}: malformed structured data`)
    } catch {
      errors.push(`${file}: invalid JSON-LD`)
    }
  }
  if (file.endsWith('404.html') && !/name="robots" content="noindex, nofollow"/.test(html)) errors.push(`${file}: 404 must be noindex`)
}
if (errors.length) throw new Error(`HTML validation failed:\n${errors.join('\n')}`)
console.log(`Validated ${files.length} prerendered HTML pages.`)
