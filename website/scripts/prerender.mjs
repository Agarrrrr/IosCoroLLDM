import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { prerenderContentFor } from '../src/prerender-content.js'
import { brandNameFor, buildStructuredData, seoForPage } from '../src/seo.js'

const websiteDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const distDirectory = resolve(websiteDirectory, 'dist')
const index = await readFile(resolve(distDirectory, 'index.html'), 'utf8')
const pages = [
  '',
  'repertorio',
  'producto',
  'novedades',
  'soluciones',
  'roadmap',
  'contacto',
  'privacidad',
  'terminos',
  'atribuciones',
  '404',
]
const escapeHtml = (value = '') =>
  String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#039;')

const staticMain = (content, brandName, language) => {
  const homeHref = language === 'en' ? '/en/' : '/'
  const details = content.details?.length ? `<ul>${content.details.map((detail) => `<li>${escapeHtml(detail)}</li>`).join('')}</ul>` : ''
  const faq = content.faq?.length
    ? `<section aria-labelledby="faq-title"><h2 id="faq-title">${escapeHtml(content.h3)}</h2>${content.faq.map(([question, answer]) => `<details><summary>${escapeHtml(question)}</summary><p>${escapeHtml(answer)}</p></details>`).join('')}</section>`
    : ''
  return `<main><section class="static-page"><p>${escapeHtml(content.h2)}</p><h1>${escapeHtml(content.h1)}</h1><p>${escapeHtml(content.text)}</p><h2>${escapeHtml(content.h2)}</h2><h3>${escapeHtml(content.h3)}</h3>${details}${faq}<p><a href="${homeHref}">${escapeHtml(brandName)}</a></p></section></main>`
}

for (const language of ['es', 'en']) {
  for (const slug of pages) {
    const seoPage = slug === '404' ? 'not-found' : slug || 'inicio'
    const seo = seoForPage(seoPage, language)
    const brandName = brandNameFor(language)
    const content = prerenderContentFor(seoPage, language)
    const schema = JSON.stringify(buildStructuredData({ page: seoPage, lang: language, metadata: seo.metadata, url: seo.url, brandName }))
    const head = `<title>${escapeHtml(seo.metadata.title)}</title><meta name="description" content="${escapeHtml(seo.metadata.description)}"><meta name="robots" content="${seo.robots}"><link id="canonical-url" rel="canonical" href="${seo.url}"><link rel="alternate" data-seo-alternate="es" hreflang="es" href="${seo.alternates.es}"><link rel="alternate" data-seo-alternate="en" hreflang="en" href="${seo.alternates.en}"><link rel="alternate" data-seo-alternate="x-default" hreflang="x-default" href="${seo.alternates.default}"><meta property="og:type" content="website"><meta property="og:site_name" content="${brandName}"><meta property="og:locale" content="${seo.locale}"><meta property="og:locale:alternate" content="${language === 'en' ? 'es_MX' : 'en_US'}"><meta property="og:title" content="${escapeHtml(seo.metadata.title)}"><meta property="og:description" content="${escapeHtml(seo.metadata.description)}"><meta property="og:url" content="${seo.url}"><meta property="og:image" content="${seo.image}"><meta property="og:image:alt" content="${escapeHtml(seo.imageAlt)}"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${escapeHtml(seo.metadata.title)}"><meta name="twitter:description" content="${escapeHtml(seo.metadata.description)}"><meta name="twitter:image" content="${seo.image}"><meta name="twitter:image:alt" content="${escapeHtml(seo.imageAlt)}"><script id="page-structured-data" type="application/ld+json">${schema}</script>`
    const html = index
      .replace(/<meta property="og:image"[^>]*>\s*/g, '')
      .replace(/<meta property="og:image:[^"]+"[^>]*>\s*/g, '')
      .replace(/<title>[\s\S]*?<\/title>/, head)
      .replace(/<meta name="description"[^>]*>/, '')
      .replace('<div id="root"></div>', `<div id="root">${staticMain(content, brandName, language)}</div>`)
    const output =
      slug === '404' && language === 'es'
        ? resolve(distDirectory, '404.html')
        : language === 'en'
          ? slug
            ? resolve(distDirectory, 'en', slug, 'index.html')
            : resolve(distDirectory, 'en', 'index.html')
          : slug
            ? resolve(distDirectory, slug, 'index.html')
            : resolve(distDirectory, 'index.html')
    if (language === 'es' && !slug) await writeFile(resolve(distDirectory, 'index.html'), html)
    else if (language === 'es' && slug !== '404') await mkdir(dirname(output), { recursive: true }).then(() => writeFile(output, html))
    else if (language === 'en') await mkdir(dirname(output), { recursive: true }).then(() => writeFile(output, html))
    else await writeFile(output, html)
  }
}

console.log(`Prerendered ${pages.length} static pages.`)
