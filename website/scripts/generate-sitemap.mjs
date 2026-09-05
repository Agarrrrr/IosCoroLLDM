import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { SITE_ORIGIN } from '../src/site-data.js'
import { SEO_PAGES } from '../src/seo.js'

const websiteDirectory = resolve(fileURLToPath(new URL('..', import.meta.url)))
const publicDirectory = resolve(websiteDirectory, 'public')
const pages = SEO_PAGES.map((page) => (page === 'inicio' ? '' : page))
const generatedCatalogMeta = JSON.parse(await readFile(resolve(publicDirectory, 'catalog-meta.json'), 'utf8'))

const urlFor = (language, page) => `${SITE_ORIGIN}${language === 'en' ? '/en' : ''}${page ? `/${page}` : '/'}`
const alternateLinks = (page) => [
  `    <xhtml:link rel="alternate" hreflang="es" href="${urlFor('es', page)}" />`,
  `    <xhtml:link rel="alternate" hreflang="en" href="${urlFor('en', page)}" />`,
  `    <xhtml:link rel="alternate" hreflang="x-default" href="${urlFor('es', page)}" />`,
]

const entries = pages.flatMap((page) =>
  ['es', 'en'].map((language) => {
    const lastmod = page === 'repertorio' ? generatedCatalogMeta.generatedAt.slice(0, 10) : null
    return [
      '  <url>',
      `    <loc>${urlFor(language, page)}</loc>`,
      ...(lastmod ? [`    <lastmod>${lastmod}</lastmod>`] : []),
      ...alternateLinks(page),
      '  </url>',
    ].join('\n')
  }),
)

const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
${entries.join('\n')}
</urlset>
`

await mkdir(publicDirectory, { recursive: true })
await writeFile(resolve(publicDirectory, 'sitemap.xml'), sitemap)
console.log(`Sitemap generated with ${entries.length} localized URLs.`)
