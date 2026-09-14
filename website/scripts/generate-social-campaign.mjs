import path from 'node:path'
import { fileURLToPath } from 'node:url'
import sharp from 'sharp'

const here = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(here, '..')
const capture = (name) => path.join(root, 'public', 'Capturas', name)
const output = (name) => path.join(root, 'public', name)

const svg = (width, height, content) => Buffer.from(
  `<svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">${content}</svg>`,
)
const title = (x, y, value, size, fill = '#e6c56e') =>
  `<text x="${x}" y="${y}" fill="${fill}" font-family="Georgia, Times New Roman, serif" font-size="${size}" font-weight="700">${value}</text>`
const copy = (x, y, value, size = 25, fill = '#f5f0df') =>
  `<text x="${x}" y="${y}" fill="${fill}" font-family="Arial, Helvetica, sans-serif" font-size="${size}">${value}</text>`
const wrap = (x, y, lines, size = 25, gap = 37, fill = '#f5f0df') =>
  lines.map((line, index) => copy(x, y + index * gap, line, size, fill)).join('')

const shell = (width, height, content) => `
  <rect width="${width}" height="${height}" fill="#0c2d24" />
  <path d="M${width * 0.66} 0 H${width} V${height} H${width * 0.91} C${width * 0.78} ${height * 0.74}, ${width * 0.93} ${height * 0.3}, ${width * 0.66} 0Z" fill="#ead9a8" />
  <path d="M0 ${height * 0.9} C${width * 0.28} ${height * 0.73}, ${width * 0.58} ${height * 1.07}, ${width} ${height * 0.77}" fill="none" stroke="#d2a842" stroke-width="11" opacity=".9" />
  <path d="M0 ${height * 0.93} C${width * 0.29} ${height * 0.77}, ${width * 0.59} ${height * 1.1}, ${width} ${height * 0.8}" fill="none" stroke="#e6c56e" stroke-width="2" opacity=".75" />
  <g opacity=".18" stroke="#e6c56e" fill="none" stroke-width="2">
    <path d="M45 165 C180 120 270 215 410 164" /><path d="M45 180 C180 135 270 230 410 179" />
    <path d="M45 195 C180 150 270 245 410 194" /><path d="M45 210 C180 165 270 260 410 209" />
  </g>${content}`

async function phone(imagePath, width, height, radius = 58) {
  const inset = 13
  const screen = await sharp(imagePath).resize(width - inset * 2, height - inset * 2, { fit: 'cover', position: 'top' }).png().toBuffer()
  return sharp({ create: { width, height, channels: 4, background: '#08100d' } })
    .composite([
      { input: screen, left: inset, top: inset },
      { input: svg(width, height, `<rect x="1" y="1" width="${width - 2}" height="${height - 2}" rx="${radius}" fill="none" stroke="#161616" stroke-width="12" />`) },
      { input: svg(width, height, `<rect width="${width}" height="${height}" rx="${radius}" fill="#fff" />`), blend: 'dest-in' },
    ]).png().toBuffer()
}

async function annotatedSheet() {
  const meta = await sharp(capture('5.jpeg')).metadata()
  return sharp(capture('5.jpeg')).composite([{ input: svg(meta.width, meta.height, `
    <path d="M110 630 C190 608 264 638 338 616" fill="none" stroke="#d8b94a" stroke-width="13" stroke-linecap="round" opacity=".72" />
    <ellipse cx="353" cy="787" rx="62" ry="39" fill="none" stroke="#c99b32" stroke-width="8" opacity=".82" />
    <path d="M235 885 C284 850 308 826 340 802" fill="none" stroke="#c99b32" stroke-width="7" stroke-linecap="round" />
    <text x="110" y="916" fill="#85661c" font-family="cursive" font-size="42" font-style="italic" transform="rotate(-6 110 916)">respirar</text>`), }]).png().toBuffer()
}

async function carouselSlide({ file, source, number, heading, body, annotated = false }) {
  const width = 1080
  const height = 1350
  const device = await phone(annotated ? await annotatedSheet() : source, 460, 1000)
  const art = svg(width, height, shell(width, height, `
    ${copy(72, 82, `${number} / 05`, 19, '#e6c56e')}${title(72, 180, heading, 54)}
    ${wrap(72, 242, body, 25)}<line x1="72" y1="315" x2="370" y2="315" stroke="#d2a842" stroke-width="3" />
    ${copy(72, 1225, 'Coro LLDM', 30, '#e6c56e')}${copy(72, 1266, 'Android y iPhone · lldmcoro.com', 20)}`))
  await sharp(art).composite([{ input: device, left: 560, top: 210 }]).jpeg({ quality: 88, progressive: true }).toFile(output(`social-kit/${file}`))
}

async function generateCarousel() {
  await Promise.all([
    carouselSlide({ file: 'coro-lldm-01-catalogo.jpg', source: capture('1.jpeg'), number: '01', heading: 'Encuentra tu canto.', body: ['Un catálogo claro para', 'llevar el material oficial', 'siempre contigo.'] }),
    carouselSlide({ file: 'coro-lldm-02-temas.jpg', source: capture('2.jpeg'), number: '02', heading: 'Organiza tu ensayo.', body: ['Explora por temas, guarda', 'favoritos y vuelve a lo que', 'necesitas preparar.'] }),
    carouselSlide({ file: 'coro-lldm-03-partitura.jpg', source: capture('3.jpeg'), number: '03', heading: 'Abre y ensaya.', body: ['Partitura y piano', 'por voces, juntos', 'en un mismo lugar.'] }),
    carouselSlide({ file: 'coro-lldm-04-compartir.jpg', source: capture('4.jpeg'), number: '04', heading: 'Comparte el material.', body: ['Comparte PDF, voces', 'o ensamble en MP3.', 'Tú eliges el canal.'] }),
    carouselSlide({ file: 'coro-lldm-05-anotaciones.jpg', source: capture('5.jpeg'), number: '05', heading: 'Hazla tuya.', body: ['Marca una entrada, escribe', 'una indicación y prepara', 'tu lectura con claridad.'], annotated: true }),
  ])
}

async function generateCover() {
  const width = 1080
  const height = 1350
  const device = await phone(capture('1.jpeg'), 460, 1000)
  await sharp(svg(width, height, shell(width, height, `${title(72, 172, 'Coro LLDM', 75)}${wrap(72, 252, ['Partituras y ensayos,', 'en un mismo lugar.'], 35, 48)}${copy(72, 1220, 'Disponible para Android y iPhone', 22, '#e6c56e')}${copy(72, 1262, 'lldmcoro.com', 25)}`)))
    .composite([{ input: device, left: 558, top: 188 }]).jpeg({ quality: 88, progressive: true }).toFile(output('social-kit/coro-lldm-promo.jpg'))
}

async function generateBanner() {
  const width = 1500
  const height = 500
  const device = await phone(capture('4.jpeg'), 255, 460, 36)
  await sharp(svg(width, height, shell(width, height, `${title(70, 156, 'Coro LLDM', 62)}${wrap(70, 226, ['Tu partitura no se queda en pantalla.', 'Compártela en PDF o exporta voces en MP3.'], 27, 41)}${copy(70, 424, 'Android y iPhone · lldmcoro.com', 22, '#e6c56e')}`)))
    .composite([{ input: device, left: 1104, top: 22 }]).jpeg({ quality: 88, progressive: true }).toFile(output('social-kit/coro-lldm-banner.jpg'))
}

async function generateSocialPreview() {
  const width = 1200
  const height = 630
  const device = await phone(capture('4.jpeg'), 290, 540, 42)
  await sharp(svg(width, height, shell(width, height, `${title(68, 170, 'Coro LLDM', 67)}${wrap(68, 248, ['Partituras, piano por voces', 'y material listo para compartir.'], 31, 43)}${copy(68, 520, 'Android y iPhone · lldmcoro.com', 22, '#e6c56e')}`)))
    .composite([{ input: device, left: 844, top: 44 }]).jpeg({ quality: 88, progressive: true }).toFile(output('social-preview.jpg'))
}

await Promise.all([generateCarousel(), generateCover(), generateBanner(), generateSocialPreview()])
