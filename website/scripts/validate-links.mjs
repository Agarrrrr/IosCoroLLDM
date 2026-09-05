import { access, readdir, readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const dist = resolve(fileURLToPath(new URL('.', import.meta.url)), '../dist')
const errors = []
const collectHtml = async (directory) => {
  const entries = await readdir(directory, { withFileTypes: true })
  return (
    await Promise.all(
      entries.map((entry) => {
        const target = resolve(directory, entry.name)
        return entry.isDirectory() ? collectHtml(target) : entry.name.endsWith('.html') ? [target] : []
      }),
    )
  ).flat()
}
const exists = (path) =>
  access(path)
    .then(() => true)
    .catch(() => false)
const localTarget = (href) => {
  const pathname = href.split('#')[0].split('?')[0]
  if (!pathname || pathname === '/') return resolve(dist, 'index.html')
  if (pathname.endsWith('/')) return resolve(dist, pathname.slice(1), 'index.html')
  return resolve(dist, pathname.slice(1))
}

for (const file of await collectHtml(dist)) {
  const html = await readFile(file, 'utf8')
  const references = [...html.matchAll(/(?:href|src)="([^"]+)"/g)].map((match) => match[1])
  for (const href of references) {
    if (/^(https?:|mailto:|tel:|data:|#)/.test(href)) continue
    if (!(await exists(localTarget(href)))) errors.push(`${file}: missing local target ${href}`)
  }
}
if (errors.length) throw new Error(`Link validation failed:\n${errors.join('\n')}`)
console.log('Validated local links and assets in prerendered pages.')
