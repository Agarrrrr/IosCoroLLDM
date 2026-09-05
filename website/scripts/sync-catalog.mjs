import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const websiteDirectory = resolve(scriptDirectory, '..')
const appDirectory = resolve(websiteDirectory, '..')
const catalogFiles = ['catalogo.json', 'catalogo_en.json']

await mkdir(resolve(websiteDirectory, 'public'), { recursive: true })
await mkdir(resolve(websiteDirectory, '.reports'), { recursive: true })
await Promise.all(catalogFiles.map((file) => cp(resolve(appDirectory, 'assets', file), resolve(websiteDirectory, 'public', file))))

const stats = {}
const catalogs = {}
const catalogRaw = {}
const validation = {
  generatedAt: new Date().toISOString(),
  files: { local: [], remote: [], encrypted: [] },
  languageLinks: { dangling: [], nonReciprocal: [] },
  warnings: [],
}
const blockingErrors = []
const filePathFor = (value, type) => {
  const directory = type === 'score' ? 'pdfs' : 'midis'
  const relativePath = value.startsWith('global/') ? value : value.includes('/') ? value.split('/').pop() : value
  return resolve(appDirectory, 'assets', 'offline_assets', directory, relativePath)
}
const inspectAsset = (value, type, song, language) => {
  if (!value) return { status: 'absent' }
  if (/^https?:\/\//i.test(value)) {
    validation.files.remote.push({ language, id: song.id, type, value, status: 'remote-unverified' })
    return { status: 'remote-unverified' }
  }
  const encrypted = value.endsWith('.enc') || value.startsWith('global/')
  const path = filePathFor(value, type)
  const exists = existsSync(path)
  const result = { language, id: song.id, type, value, status: exists ? 'valid' : encrypted ? 'encrypted-unverified' : 'missing' }
  validation.files[encrypted ? 'encrypted' : 'local'].push(result)
  if (!exists && !encrypted) blockingErrors.push(`${language}/${song.id}: missing local ${type} file (${value})`)
  if (!exists && encrypted)
    validation.warnings.push(
      `${language}/${song.id}: encrypted ${type} asset was not found in offline_assets; verify it against the remote service (${value})`,
    )
  return { status: result.status }
}
for (const [language, file] of [
  ['es', 'catalogo.json'],
  ['en', 'catalogo_en.json'],
]) {
  const raw = await readFile(resolve(appDirectory, 'assets', file), 'utf8')
  const catalog = JSON.parse(raw)
  catalogRaw[language] = raw
  catalogs[language] = catalog
  const incomplete = catalog.filter((song) => !song.id || !song.nombre || !song.archivo || song.idioma !== language)
  if (incomplete.length) throw new Error(`${file}: ${incomplete.length} incomplete records`)
  const ids = catalog.map((song) => song.id)
  const duplicateIds = ids.filter((id, index) => ids.indexOf(id) !== index)
  if (duplicateIds.length) throw new Error(`${file}: duplicate ids (${[...new Set(duplicateIds)].join(', ')})`)
  const names = catalog.map((song) => song.nombre.trim().toLocaleLowerCase())
  const duplicateNames = names.filter((name, index) => names.indexOf(name) !== index)
  if (duplicateNames.length) {
    const message = `${file}: duplicate names detected (${[...new Set(duplicateNames)].slice(0, 5).join(', ')})`
    console.warn(message)
    validation.warnings.push(message)
  }
  catalog.forEach((song) => {
    inspectAsset(song.archivo, 'score', song, language)
    inspectAsset(song.midi_archivo, 'midi', song, language)
  })
}
const byId = Object.fromEntries(
  Object.entries(catalogs).map(([language, catalog]) => [language, new Map(catalog.map((song) => [song.id, song]))]),
)
for (const [language, oppositeLanguage] of [
  ['es', 'en'],
  ['en', 'es'],
]) {
  for (const song of catalogs[language]) {
    if (!song.vinculo_idioma) continue
    const counterpart = byId[oppositeLanguage].get(song.vinculo_idioma)
    if (!counterpart) {
      validation.languageLinks.dangling.push({ language, id: song.id, name: song.nombre, linkedId: song.vinculo_idioma })
      continue
    }
    if (counterpart.vinculo_idioma !== song.id) {
      validation.languageLinks.nonReciprocal.push({ language, id: song.id, linkedId: counterpart.id })
    }
  }
}
if (validation.languageLinks.dangling.length)
  validation.warnings.push(
    `${validation.languageLinks.dangling.length} language links point to records that are not present in the opposite catalog`,
  )
if (validation.languageLinks.nonReciprocal.length)
  validation.warnings.push(`${validation.languageLinks.nonReciprocal.length} language links are not reciprocal`)
validation.ok = blockingErrors.length === 0
validation.blockingErrors = blockingErrors
await writeFile(resolve(websiteDirectory, '.reports', 'catalog-validation.json'), `${JSON.stringify(validation, null, 2)}\n`)
await rm(resolve(websiteDirectory, 'public', 'catalog-validation.json'), { force: true })
if (blockingErrors.length) throw new Error(`Catalog validation failed:\n${blockingErrors.join('\n')}`)

const readJsonIfPresent = async (file) => {
  try {
    return JSON.parse(await readFile(file, 'utf8'))
  } catch {
    return null
  }
}
const previewManifest = await readJsonIfPresent(resolve(websiteDirectory, 'public', 'preview-manifest.json'))
const previewMap = previewManifest?.previews || {}
const previewExistsFor = (song) => {
  const entry = song.midi_archivo ? previewMap[song.midi_archivo] : null
  return typeof entry === 'string' || Boolean(entry?.opus || entry?.aac)
}
for (const [language, catalog] of Object.entries(catalogs)) {
  stats[language] = {
    total: catalog.length,
    withMidi: catalog.filter((song) => song.midi_archivo).length,
    withPreview: catalog.filter(previewExistsFor).length,
  }
}
await writeFile(resolve(websiteDirectory, 'public', 'catalog-stats.json'), `${JSON.stringify(stats, null, 2)}\n`)
const catalogHashes = Object.fromEntries(
  ['es', 'en'].map((language) => [language, createHash('sha256').update(catalogRaw[language]).digest('hex')]),
)
const previousCatalogMeta = await readJsonIfPresent(resolve(websiteDirectory, 'public', 'catalog-meta.json'))
const catalogsChanged = ['es', 'en'].some((language) => previousCatalogMeta?.catalogs?.[language]?.hash !== catalogHashes[language])
const catalogMeta = {
  generatedAt: catalogsChanged || !previousCatalogMeta?.generatedAt ? new Date().toISOString() : previousCatalogMeta.generatedAt,
  version: createHash('sha256').update(catalogRaw.es).update(catalogRaw.en).digest('hex').slice(0, 16),
  dateMeaning: 'last-sync-from-application-assets',
  source: 'application-assets',
  languages: ['es', 'en'],
  catalogs: Object.fromEntries(
    ['es', 'en'].map((language) => [
      language,
      {
        hash: catalogHashes[language],
        ...stats[language],
      },
    ]),
  ),
}
await writeFile(resolve(websiteDirectory, 'public', 'catalog-meta.json'), `${JSON.stringify(catalogMeta, null, 2)}\n`)

// La selección debe ser estable entre recargas y regenerarse únicamente cuando
// cambie el contenido real de los catálogos de la aplicación.
const selectionSeed = createHash('sha256').update(catalogRaw.es).update(catalogRaw.en).digest('hex')
const seededValue = (value) => {
  const hash = createHash('sha256').update(`${selectionSeed}:${value}`).digest('hex')
  return Number.parseInt(hash.slice(0, 12), 16)
}
const shuffled = (items) => [...items].sort((left, right) => seededValue(left.id) - seededValue(right.id))
const pendingSpanish = shuffled(catalogs.es.filter((song) => !song.midi_archivo)).slice(0, 18)
const selectedSpanishIds = new Set(pendingSpanish.map((song) => song.id))
const pendingEnglish = shuffled(catalogs.en.filter((song) => !song.midi_archivo && !selectedSpanishIds.has(song.vinculo_idioma)))
  .filter(
    (song, index, items) =>
      items.findIndex((candidate) => (candidate.vinculo_idioma || candidate.id) === (song.vinculo_idioma || song.id)) === index,
  )
  .slice(0, 2)
const pendingSelection = shuffled([...pendingSpanish, ...pendingEnglish]).map((song) => ({
  id: song.id,
  name: song.nombre,
  language: song.idioma,
  themes: song.temas || [],
}))
const previousRoadmap = await readJsonIfPresent(resolve(websiteDirectory, 'public', 'roadmap-pending.json'))
const samePendingSelection = JSON.stringify(previousRoadmap?.items || []) === JSON.stringify(pendingSelection)
await writeFile(
  resolve(websiteDirectory, 'public', 'roadmap-pending.json'),
  `${JSON.stringify(
    {
      generatedAt: samePendingSelection && previousRoadmap?.generatedAt ? previousRoadmap.generatedAt : new Date().toISOString(),
      items: pendingSelection,
    },
    null,
    2,
  )}\n`,
)

console.log('Catalog synced from the application assets. MIDI demos stream from Cloudflare.')
