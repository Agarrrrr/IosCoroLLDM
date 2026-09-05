import { PREVIEW_AUDIO_URL } from './site-data.js'

export { pageMetadata } from './seo.js'

export const PAGES = new Set([
  'inicio',
  'producto',
  'novedades',
  'repertorio',
  'soluciones',
  'roadmap',
  'colabora',
  'contacto',
  'privacidad',
  'terminos',
  'atribuciones',
])

export const languageFromPath = (pathname, base = '/') => {
  const normalizedBase = base.endsWith('/') ? base : `${base}/`
  const relativePath = pathname.startsWith(normalizedBase) ? pathname.slice(normalizedBase.length) : pathname
  return relativePath.split('/').filter(Boolean)[0] === 'en' ? 'en' : 'es'
}

export const pageFromPath = (pathname, search = '', base = '/') => {
  const normalizedBase = base.endsWith('/') ? base : `${base}/`
  const relativePath = pathname.startsWith(normalizedBase) ? pathname.slice(normalizedBase.length) : pathname
  const parts = relativePath.split('/').filter(Boolean)
  const queryPage = new URLSearchParams(search).get('p')
  const pathPage = parts[0] === 'en' ? parts[1] : parts[0]
  if (!pathPage && !queryPage) return 'inicio'
  const requestedPage = queryPage || pathPage
  if (requestedPage === 'colabora') return 'roadmap'
  return PAGES.has(requestedPage) ? requestedPage : 'not-found'
}

export const routePath = (target, language = 'es', base = '/') => {
  const prefix = base.endsWith('/') ? base : `${base}/`
  return `${prefix}${language === 'en' ? 'en/' : ''}${target === 'inicio' ? '' : target}`
}

export const previewSourcesFor = (song, previewMap, previewBase = PREVIEW_AUDIO_URL) => {
  const preview = song?.midi_archivo ? previewMap?.[song.midi_archivo] : null
  const files = typeof preview === 'string' ? { opus: preview } : preview
  if (!files || typeof files !== 'object') return {}
  return Object.fromEntries(
    Object.entries(files)
      .filter(([format, file]) => ['opus', 'aac'].includes(format) && typeof file === 'string' && file)
      .map(([format, file]) => [format, `${previewBase}/${encodeURIComponent(file)}`]),
  )
}

export const previewUrlFor = (song, previewMap, previewBase) => {
  const sources = previewSourcesFor(song, previewMap, previewBase)
  return sources.opus || sources.aac || null
}

export const filterSongs = (songs, { language = 'es', query = '', filter = 'todos' } = {}) => {
  const normalizedQuery = query.trim().toLocaleLowerCase()
  return songs.filter((song) => {
    if (song.idioma !== language || !song.nombre?.toLocaleLowerCase().includes(normalizedQuery)) return false
    return filter === 'todos' || (filter === 'audio' ? Boolean(song.midi_archivo) : !song.midi_archivo)
  })
}
