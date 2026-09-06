import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  filterSongs,
  languageFromPath,
  pageFromPath,
  pageMetadata,
  previewSourcesFor,
  previewUrlFor,
  routePath,
} from '../src/site-utils.js'
import { preferredPreviewSource } from '../src/midi-demo.js'
import { mediaErrorKey } from '../src/midi-demo.js'
import { fetchJsonWithTimeout } from '../src/data-client.js'
import { copy, faqLabels } from '../src/content.js'
import { prerenderContentFor } from '../src/prerender-content.js'
import { buildStructuredData, seoForPage } from '../src/seo.js'

describe('site navigation and metadata', () => {
  it('resolves localized routes and the legacy roadmap alias', () => {
    assert.equal(pageFromPath('/en/repertorio'), 'repertorio')
    assert.equal(pageFromPath('/colabora'), 'roadmap')
    assert.equal(pageFromPath('/missing'), 'not-found')
    assert.equal(pageFromPath('/coro/en/repertorio', '', '/coro/'), 'repertorio')
    assert.equal(languageFromPath('/en/repertorio'), 'en')
    assert.equal(languageFromPath('/repertorio'), 'es')
    assert.equal(routePath('repertorio', 'en'), '/en/repertorio')
  })

  it('keeps shared UI copy keys in both languages', () => {
    assert.deepEqual(Object.keys(copy.es).sort(), Object.keys(copy.en).sort())
    assert.deepEqual(Object.keys(faqLabels.es).sort(), Object.keys(faqLabels.en).sort())
  })

  it('keeps localized metadata complete', () => {
    for (const language of ['es', 'en']) {
      for (const metadata of Object.values(pageMetadata[language])) {
        assert.ok(metadata.title)
        assert.ok(metadata.description)
      }
    }
  })

  it('builds one localized SEO source for prerendering and runtime', () => {
    const seo = seoForPage('producto', 'en')
    assert.equal(seo.url, 'https://lldmcoro.com/en/producto')
    assert.equal(seo.alternates.es, 'https://lldmcoro.com/producto')
    assert.equal(seo.image, 'https://lldmcoro.com/social-preview-en.png')
    const graph = buildStructuredData({ page: 'producto', lang: 'en', metadata: seo.metadata })['@graph']
    assert.ok(graph.some((entry) => entry['@type'] === 'FAQPage'))
  })

  it('derives prerendered editorial content from the shared page sources', () => {
    const product = prerenderContentFor('producto', 'en')
    const release = prerenderContentFor('novedades', 'es')
    assert.equal(product.h1, copy.en.capabilitiesTitle)
    assert.ok(product.faq.length > 0)
    assert.equal(release.h1, 'Versión 2.5.2')
    assert.ok(release.details.includes('Te Alabaré'))
  })
})

describe('catalog filtering and previews', () => {
  const songs = [
    { id: 'es-1', idioma: 'es', nombre: 'Canto de prueba', midi_archivo: 'demo.mid' },
    { id: 'es-2', idioma: 'es', nombre: 'Otro canto', midi_archivo: null },
    { id: 'en-1', idioma: 'en', nombre: 'Test song', midi_archivo: 'test.mid' },
  ]

  it('filters by language, search and audio state', () => {
    assert.equal(filterSongs(songs, { language: 'es', filter: 'audio' }).length, 1)
    assert.equal(filterSongs(songs, { language: 'es', query: 'OTRO', filter: 'pendientes' })[0].id, 'es-2')
  })

  it('creates an encoded preview URL or null', () => {
    assert.equal(
      previewUrlFor(songs[0], { 'demo.mid': 'demo piano.opus' }),
      'https://coro-lldm-previews.huritolentino.workers.dev/previews/demo%20piano.opus',
    )
    assert.equal(previewUrlFor(songs[1], {}), null)
  })

  it('accepts legacy and dual-format preview manifests', () => {
    assert.deepEqual(previewSourcesFor(songs[0], { 'demo.mid': 'legacy.opus' }), {
      opus: 'https://coro-lldm-previews.huritolentino.workers.dev/previews/legacy.opus',
    })
    assert.deepEqual(previewSourcesFor(songs[0], { 'demo.mid': { opus: 'demo.opus', aac: 'demo.m4a' } }), {
      opus: 'https://coro-lldm-previews.huritolentino.workers.dev/previews/demo.opus',
      aac: 'https://coro-lldm-previews.huritolentino.workers.dev/previews/demo.m4a',
    })
  })

  it('uses AAC on Apple mobile and Opus elsewhere when both formats exist', () => {
    const sources = { opus: 'https://example.test/demo.opus', aac: 'https://example.test/demo.m4a' }
    const supportsBoth = () => 'probably'
    assert.deepEqual(preferredPreviewSource(sources, { canPlayType: supportsBoth, appleMobile: true }), {
      format: 'aac',
      url: sources.aac,
    })
    assert.deepEqual(preferredPreviewSource(sources, { canPlayType: supportsBoth, appleMobile: false }), {
      format: 'opus',
      url: sources.opus,
    })
  })

  it('maps media errors to a specific accessible message key', () => {
    assert.equal(mediaErrorKey(2), 'audioPlaybackNetwork')
    assert.equal(mediaErrorKey(4), 'audioPlaybackUnsupported')
    assert.equal(mediaErrorKey(undefined), 'audioPlaybackError')
  })

  it('returns fallback after a timed-out optional JSON request', async () => {
    const result = await fetchJsonWithTimeout('https://example.test/catalog.json', {
      fallback: { items: [] },
      timeoutMs: 1,
      fetchImpl: (_url, { signal }) =>
        new Promise((_resolve, reject) => signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true })),
    })
    assert.deepEqual(result, { items: [] })
  })
})
