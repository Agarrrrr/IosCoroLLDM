import { mkdir } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import sharp from 'sharp'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const publicDirectory = resolve(scriptDirectory, '..', 'public')
const sourceDirectory = resolve(publicDirectory, 'social-kit')
const targetDirectory = resolve(publicDirectory, 'site-media')

const assets = [
  { source: 'coro-lldm-promo.jpg', output: 'hero-coro-lldm', width: 1080, height: 1350 },
  { source: 'tlotw-choir-promo.jpg', output: 'hero-tlotw-choir', width: 1080, height: 1350 },
  { source: 'coro-lldm-01-catalogo.jpg', output: 'feature-catalog', width: 1080, height: 1350 },
  { source: 'coro-lldm-02-temas.jpg', output: 'feature-topics', width: 1080, height: 1350 },
  { source: 'coro-lldm-03-partitura.jpg', output: 'feature-score', width: 1080, height: 1350 },
  { source: 'coro-lldm-promo-voces.jpg', output: 'feature-voices', width: 1080, height: 1350 },
  { source: 'coro-lldm-05-anotaciones.jpg', output: 'feature-annotations', width: 1080, height: 1350 },
]

const render = async ({ source, output }, size) => {
  const target = resolve(targetDirectory, `${output}-${size}.webp`)
  const image = sharp(resolve(sourceDirectory, source)).rotate()
  await image
    .resize({ width: size, withoutEnlargement: true })
    .webp({ quality: size < 700 ? 80 : 84, effort: 6 })
    .toFile(target)
}

await mkdir(targetDirectory, { recursive: true })
await Promise.all(assets.flatMap((asset) => [render(asset, 480), render(asset, 960)]))

await sharp(resolve(sourceDirectory, 'coro-lldm-app-icon-rounded.png'))
  .rotate()
  .resize(192, 192)
  .webp({ quality: 90, effort: 6 })
  .toFile(resolve(targetDirectory, 'brand-mark.webp'))

await Promise.all(
  [480, 960].map((size) =>
    sharp(resolve(sourceDirectory, 'coro-lldm-emblema-transparente.png'))
      .rotate()
      .resize(size, size, { fit: 'contain', withoutEnlargement: true })
      .webp({ quality: 90, effort: 6 })
      .toFile(resolve(targetDirectory, `hero-emblem-${size}.webp`)),
  ),
)

await Promise.all([
  sharp(resolve(sourceDirectory, 'coro-lldm-social-preview.jpg'))
    .rotate()
    .resize(1200, 630, { fit: 'cover', position: 'centre' })
    .jpeg({ quality: 86, mozjpeg: true })
    .toFile(resolve(targetDirectory, 'social-preview-es.jpg')),
  sharp(resolve(sourceDirectory, 'tlotw-choir-social-preview.jpg'))
    .rotate()
    .resize(1200, 630, { fit: 'cover', position: 'centre' })
    .jpeg({ quality: 86, mozjpeg: true })
    .toFile(resolve(targetDirectory, 'social-preview-en.jpg')),
])

console.log(`Prepared ${assets.length * 2 + 3} web assets in ${targetDirectory}`)
