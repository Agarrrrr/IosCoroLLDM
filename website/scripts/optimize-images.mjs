import { existsSync } from 'node:fs'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import sharp from 'sharp'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const publicDirectory = resolve(scriptDirectory, '..', 'public')
const sourceFor = (optimized, original) => resolve(publicDirectory, existsSync(resolve(publicDirectory, optimized)) ? optimized : original)

const render = async ({ original, output, options }) => {
  const target = resolve(publicDirectory, output)
  const input = await readFile(sourceFor(output, original))
  const image = sharp(input).rotate()
  const buffer = await options(image).toBuffer()
  await mkdir(dirname(target), { recursive: true })
  await writeFile(target, buffer)
  console.log(`${output}: ${(buffer.byteLength / 1024).toFixed(1)} KB`)
}

await Promise.all([
  render({ original: 'logo.png', output: 'logo-header.webp', options: (image) => image.resize(96, 96).webp({ quality: 90, effort: 6 }) }),
  render({
    original: '404-repair.png',
    output: '404-repair.webp',
    options: (image) => image.resize(768, 768).webp({ quality: 84, effort: 6 }),
  }),
  render({
    original: 'social-preview.png',
    output: 'social-preview.jpg',
    options: (image) => image.resize(1200, 630).jpeg({ quality: 84, mozjpeg: true }),
  }),
  render({
    original: 'social-preview-en.png',
    output: 'social-preview-en.jpg',
    options: (image) => image.resize(1200, 630).jpeg({ quality: 84, mozjpeg: true }),
  }),
  render({
    original: 'bc-logo-blue.png',
    output: 'bc-logo-blue.webp',
    options: (image) => image.resize(512, 512).webp({ quality: 90, effort: 6 }),
  }),
  render({
    original: 'bc-logo-white.png',
    output: 'bc-logo-white.webp',
    options: (image) => image.resize(512, 512).webp({ quality: 90, effort: 6 }),
  }),
  ...['coro-lldm', 'tlotw-choir'].flatMap((brand) => [
    render({
      original: `social-kit/${brand}-promo.png`,
      output: `social-kit/${brand}-promo.jpg`,
      options: (image) => image.resize(1080, 1350).jpeg({ quality: 84, mozjpeg: true }),
    }),
    render({
      original: `social-kit/${brand}-banner.png`,
      output: `social-kit/${brand}-banner.jpg`,
      options: (image) => image.resize(1500, 500).jpeg({ quality: 84, mozjpeg: true }),
    }),
  ]),
])
