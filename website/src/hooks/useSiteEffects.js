import { useEffect } from 'react'
import { pageDocument, pageWindow } from '../browser-runtime'
import { buildStructuredData, seoForPage } from '../app-config'

const ensureMeta = (document, selector, attributes) => {
  let element = document.querySelector(selector)
  if (!element) {
    element = document.createElement('meta')
    document.head.append(element)
  }
  Object.entries(attributes).forEach(([name, value]) => element.setAttribute(name, value))
  return element
}

const ensureLink = (document, selector, attributes) => {
  let element = document.querySelector(selector)
  if (!element) {
    element = document.createElement('link')
    document.head.append(element)
  }
  Object.entries(attributes).forEach(([name, value]) => element.setAttribute(name, value))
  return element
}

export function useDocumentMetadata({ brandName, dark, lang, page }) {
  useEffect(() => {
    const document = pageDocument()
    if (!document) return
    document.documentElement.lang = lang
    document.documentElement.dataset.theme = dark ? 'dark' : 'light'
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', dark ? '#16211f' : '#f7f5ef')
  }, [dark, lang])

  useEffect(() => {
    const document = pageDocument()
    if (!document) return
    const seo = seoForPage(page, lang)
    const { metadata } = seo
    document.title = metadata.title
    ensureMeta(document, 'meta[name="description"]', { name: 'description', content: metadata.description })
    ensureMeta(document, 'meta[name="robots"]', { name: 'robots', content: seo.robots })
    ensureLink(document, 'link[rel="canonical"]', { rel: 'canonical', href: seo.url })
    const openGraph = {
      'og:title': metadata.title,
      'og:description': metadata.description,
      'og:url': seo.url,
      'og:image': seo.image,
      'og:image:alt': seo.imageAlt,
      'og:image:width': '1200',
      'og:image:height': '630',
      'og:locale': seo.locale,
      'og:locale:alternate': lang === 'en' ? 'es_MX' : 'en_US',
    }
    Object.entries(openGraph).forEach(([property, content]) => ensureMeta(document, `meta[property="${property}"]`, { property, content }))
    const twitter = {
      'twitter:card': 'summary_large_image',
      'twitter:title': metadata.title,
      'twitter:description': metadata.description,
      'twitter:image': seo.image,
      'twitter:image:alt': seo.imageAlt,
    }
    Object.entries(twitter).forEach(([name, content]) => ensureMeta(document, `meta[name="${name}"]`, { name, content }))
    Object.entries(seo.alternates).forEach(([language, href]) => {
      const hreflang = language === 'default' ? 'x-default' : language
      ensureLink(document, `link[data-seo-alternate="${hreflang}"]`, { rel: 'alternate', hreflang, href, 'data-seo-alternate': hreflang })
    })
    let schema = document.getElementById('page-structured-data')
    if (!schema) {
      schema = document.createElement('script')
      schema.id = 'page-structured-data'
      schema.type = 'application/ld+json'
      document.head.append(schema)
    }
    schema.textContent = JSON.stringify(buildStructuredData({ page, lang, metadata, url: seo.url, brandName }))
  }, [brandName, lang, page])
}

export function useRevealSections(page) {
  useEffect(() => {
    const document = pageDocument()
    const Observer = pageWindow()?.IntersectionObserver
    if (!document || !Observer) return undefined
    const sections = [...document.querySelectorAll('main > section')]
    const observer = new Observer(
      (entries) =>
        entries.forEach((entry) => entry.isIntersecting && (entry.target.classList.add('is-visible'), observer.unobserve(entry.target))),
      { threshold: 0.12 },
    )
    sections.forEach((section) => observer.observe(section))
    return () => observer.disconnect()
  }, [page])
}
