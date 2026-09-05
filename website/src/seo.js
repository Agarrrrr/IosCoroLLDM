import { faqCopy } from './content/faq.js'
import { APP_STORE, PLAY_STORE, SITE_ORIGIN } from './site-data.js'

export const SEO_PAGES = [
  'inicio',
  'repertorio',
  'producto',
  'novedades',
  'soluciones',
  'roadmap',
  'contacto',
  'privacidad',
  'terminos',
  'atribuciones',
]

export const pageMetadata = {
  es: {
    inicio: {
      title: 'Coro LLDM | Partituras y ensayos para coros',
      description: 'Coro LLDM reúne partituras y audios de ensayo para preparar mejor a cada coro.',
    },
    repertorio: {
      title: 'Repertorio | Coro LLDM',
      description: 'Explora el repertorio de Coro LLDM: partituras, estado de audios de ensayo y demos de piano.',
    },
    producto: {
      title: 'La aplicación | Coro LLDM',
      description: 'Conoce las funciones de Coro LLDM: partituras, visor PDF, anotaciones, favoritos, trabajo offline y audio de ensayo.',
    },
    novedades: { title: 'Novedades | Coro LLDM', description: 'Consulta las notas de versión y los avances de la aplicación Coro LLDM.' },
    soluciones: {
      title: 'Apps para coros | Coro LLDM',
      description: 'Conoce cómo Coro LLDM y Repertorio BC inspiran aplicaciones hechas a la medida de cada coro.',
    },
    roadmap: { title: 'Roadmap | Coro LLDM', description: 'Conoce los próximos audios y mejoras confirmadas para Coro LLDM.' },
    contacto: {
      title: 'Contacto | Coro LLDM',
      description: 'Ponte en contacto con Coro LLDM para una app para tu coro, colaboración o preguntas.',
    },
    privacidad: {
      title: 'Política de Privacidad | Coro LLDM',
      description: 'Consulta cómo Coro LLDM maneja la información de la aplicación y el sitio web.',
    },
    terminos: { title: 'Términos de Uso | Coro LLDM', description: 'Conoce las condiciones de uso de la aplicación y sus materiales.' },
    atribuciones: {
      title: 'Atribuciones | Coro LLDM',
      description: 'Consulta las herramientas, servicios y titulares relacionados con Coro LLDM.',
    },
    'not-found': { title: 'Página no encontrada | Coro LLDM', description: 'La página que buscas no existe o fue movida.' },
  },
  en: {
    inicio: {
      title: 'TLOTW Choir | Scores and rehearsal tools for choirs',
      description: 'TLOTW Choir brings scores and rehearsal audio together to help every choir prepare with clarity.',
    },
    repertorio: {
      title: 'Repertoire | TLOTW Choir',
      description: 'Explore the TLOTW Choir repertoire, including scores, rehearsal audio status and piano demos.',
    },
    producto: {
      title: 'The app | TLOTW Choir',
      description: 'Explore TLOTW Choir features: scores, PDF viewer, annotations, favorites, offline work and rehearsal audio.',
    },
    novedades: {
      title: 'Updates | TLOTW Choir',
      description: 'Read release notes and follow the progress of the TLOTW Choir application.',
    },
    soluciones: {
      title: 'Choir apps | TLOTW Choir',
      description: 'Discover how TLOTW Choir and Repertorio BC inspire custom applications built around each choir.',
    },
    roadmap: {
      title: 'Roadmap | TLOTW Choir',
      description: 'Explore upcoming rehearsal audio and confirmed improvements for TLOTW Choir.',
    },
    contacto: {
      title: 'Contact | TLOTW Choir',
      description: 'Contact TLOTW Choir about a choir app, collaboration or any question about the project.',
    },
    privacidad: { title: 'Privacy Policy | TLOTW Choir', description: 'Learn how TLOTW Choir handles information in the app and website.' },
    terminos: { title: 'Terms of Use | TLOTW Choir', description: 'Read the terms that apply to the app and its materials.' },
    atribuciones: {
      title: 'Attributions | TLOTW Choir',
      description: 'See the tools, services and rights holders connected with TLOTW Choir.',
    },
    'not-found': { title: 'Page not found | TLOTW Choir', description: 'The page you are looking for does not exist or has been moved.' },
  },
}

const normalizedPage = (page) => (page === 'colabora' ? 'roadmap' : page)
const pagePath = (page, lang) => `${lang === 'en' ? '/en' : ''}${page === 'inicio' ? '/' : `/${normalizedPage(page)}`}`

export const brandNameFor = (lang) => (lang === 'en' ? 'TLOTW Choir' : 'Coro LLDM')
export const canonicalUrlFor = (page, lang) => `${SITE_ORIGIN}${pagePath(page, lang)}`
export const alternateUrlsFor = (page) => ({
  es: canonicalUrlFor(page, 'es'),
  en: canonicalUrlFor(page, 'en'),
  default: canonicalUrlFor(page, 'es'),
})
export const socialImageUrlFor = (lang) => `${SITE_ORIGIN}/${lang === 'en' ? 'social-preview-en.png' : 'social-preview.png'}`
export const socialImageAltFor = (lang) =>
  lang === 'en' ? 'TLOTW Choir: scores and rehearsals for choirs' : 'Coro LLDM: partituras y ensayos para coros'
export const localeFor = (lang) => (lang === 'en' ? 'en_US' : 'es_MX')

export const seoForPage = (page, lang) => {
  const normalized = normalizedPage(page)
  const metadata = pageMetadata[lang][normalized] || pageMetadata[lang]['not-found']
  return {
    metadata,
    url: canonicalUrlFor(normalized, lang),
    alternates: alternateUrlsFor(normalized),
    robots: normalized === 'not-found' ? 'noindex, nofollow' : 'index, follow',
    image: socialImageUrlFor(lang),
    imageAlt: socialImageAltFor(lang),
    locale: localeFor(lang),
  }
}

export function buildStructuredData({ page, lang, metadata, url = canonicalUrlFor(page, lang), brandName = brandNameFor(lang) }) {
  const pageType =
    page === 'repertorio' ? 'CollectionPage' : page === 'soluciones' ? 'Service' : page === 'contacto' ? 'ContactPage' : 'WebPage'
  const graph = [
    { '@type': 'WebSite', name: brandName, url: canonicalUrlFor('inicio', lang), inLanguage: lang },
    {
      '@type': pageType,
      inLanguage: lang,
      name: metadata.title,
      description: metadata.description,
      url,
      isPartOf: { '@type': 'WebSite', name: brandName, url: canonicalUrlFor('inicio', lang) },
    },
    {
      '@type': 'SoftwareApplication',
      name: brandName,
      applicationCategory: 'MusicApplication',
      operatingSystem: 'Android, iOS',
      description:
        lang === 'en'
          ? 'App for browsing scores and preparing choir rehearsals.'
          : 'Aplicación para consultar partituras y preparar ensayos de coro.',
      url: canonicalUrlFor('inicio', lang),
      downloadUrl: [PLAY_STORE, APP_STORE],
      author: { '@type': 'Person', name: 'Huri Tolentino', url: canonicalUrlFor('contacto', lang) },
      provider: { '@type': 'Person', name: 'Huri Tolentino' },
    },
    {
      '@type': 'Person',
      name: 'Huri Tolentino',
      jobTitle: lang === 'en' ? 'Developer' : 'Desarrollador',
      url: canonicalUrlFor('contacto', lang),
      knowsAbout: ['React', 'Flutter', 'Choir software', 'Music technology'],
    },
  ]
  if (page === 'soluciones') {
    graph.push({
      '@type': 'Service',
      name: lang === 'en' ? 'Custom choir applications' : 'Aplicaciones a medida para coros',
      serviceType: lang === 'en' ? 'Custom software development for choirs' : 'Desarrollo de software a medida para coros',
      provider: { '@type': 'Person', name: 'Huri Tolentino' },
      description:
        lang === 'en'
          ? 'Design and development of digital tools shaped around each choir’s workflow, repertoire and rehearsal needs.'
          : 'Diseño y desarrollo de herramientas digitales adaptadas al flujo de trabajo, repertorio y necesidades de ensayo de cada coro.',
    })
  }
  if (page === 'producto') {
    graph.push({
      '@type': 'FAQPage',
      mainEntity: faqCopy[lang].map(([question, answer]) => ({
        '@type': 'Question',
        name: question,
        acceptedAnswer: { '@type': 'Answer', text: answer },
      })),
    })
  }
  return { '@context': 'https://schema.org', '@graph': graph }
}
