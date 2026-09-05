import { createDecipheriv, createHash } from 'node:crypto'
import { access, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { basename, dirname, resolve } from 'node:path'
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const websiteDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const appDirectory = resolve(websiteDirectory, '..')
const midiDirectory = resolve(appDirectory, 'assets', 'offline_assets', 'midis')
const outputDirectory = resolve(websiteDirectory, '.preview-output')
const previewsDirectory = resolve(outputDirectory, 'previews')
const manifestPath = resolve(websiteDirectory, 'public', 'preview-manifest.json')
const missingPath = resolve(outputDirectory, 'missing-previews.json')
const soundfont = resolve(appDirectory, 'assets', 'Piano.sf2')
const fluidsynth = process.env.FLUIDSYNTH_BIN || 'C:\\tools\\fluidsynth\\bin\\fluidsynth.exe'
const ffmpeg =
  process.env.FFMPEG_BIN ||
  'C:\\Users\\Huri_\\AppData\\Local\\Microsoft\\WinGet\\Packages\\Gyan.FFmpeg.Essentials_Microsoft.Winget.Source_8wekyb3d8bbwe\\ffmpeg-8.1.1-essentials_build\\bin\\ffmpeg.exe'
const limit = Number(process.argv.find((argument) => argument.startsWith('--limit='))?.split('=')[1] || 0)
const force = process.argv.includes('--force')
const only = process.argv.find((argument) => argument.startsWith('--only='))?.slice(7)
const localEnvironmentPath = resolve(websiteDirectory, '.env.preview.local')
const localEnvironment = await readFile(localEnvironmentPath, 'utf8').catch(() => '')
const localPreviewKey = localEnvironment.match(/^\s*MIDI_PREVIEW_KEY\s*=\s*["']?([^\r\n"']+)["']?\s*$/m)?.[1]?.trim()
const previewKey = process.env.MIDI_PREVIEW_KEY || localPreviewKey
const encryptionKey = previewKey ? createHash('sha256').update(previewKey).digest() : null

const run = (command, args) =>
  new Promise((resolveRun, reject) => {
    const child = spawn(command, args, { stdio: 'ignore' })
    child.on('error', reject)
    child.on('exit', (code) => (code === 0 ? resolveRun() : reject(new Error(`${basename(command)} exited with ${code}`))))
  })

function previewNames(key, pianoMidi) {
  // El contenido forma parte del nombre para que una nueva renderización no
  // reutilice una URL con caché immutable de un preview anterior.
  const version = createHash('sha256').update(key).update(pianoMidi).digest('hex').slice(0, 24)
  return { opus: `${version}.opus`, aac: `${version}.m4a` }
}

function decryptMidi(buffer) {
  if (buffer.subarray(0, 4).toString() === 'MThd') return buffer
  if (!encryptionKey) throw new Error('Set MIDI_PREVIEW_KEY before rendering encrypted previews.')
  const iv = buffer.subarray(0, 12)
  const ciphertext = buffer.subarray(12, -16)
  const tag = buffer.subarray(-16)
  const decipher = createDecipheriv('aes-256-gcm', encryptionKey, iv)
  decipher.setAuthTag(tag)
  return Buffer.concat([decipher.update(ciphertext), decipher.final()])
}

function readVariableLength(buffer, offset) {
  let value = 0
  let cursor = offset
  for (let index = 0; index < 4; index += 1) {
    const byte = buffer[cursor]
    if (byte === undefined) throw new Error('Invalid MIDI variable-length value.')
    value = (value << 7) | (byte & 0x7f)
    cursor += 1
    if ((byte & 0x80) === 0) return { value, cursor }
  }
  throw new Error('Invalid MIDI variable-length value.')
}

function normalizeMidiToPiano(buffer) {
  if (buffer.subarray(0, 4).toString() !== 'MThd') throw new Error('Decryption did not produce a MIDI file.')
  const pianoMidi = Buffer.from(buffer)
  let cursor = 8 + pianoMidi.readUInt32BE(4)

  while (cursor < pianoMidi.length) {
    if (pianoMidi.subarray(cursor, cursor + 4).toString() !== 'MTrk') throw new Error('Invalid MIDI track.')
    const length = pianoMidi.readUInt32BE(cursor + 4)
    cursor += 8
    const trackEnd = cursor + length
    let runningStatus = null

    while (cursor < trackEnd) {
      const delta = readVariableLength(pianoMidi, cursor)
      cursor = delta.cursor
      const firstByte = pianoMidi[cursor]
      const hasStatus = firstByte >= 0x80
      const status = hasStatus ? firstByte : runningStatus
      if (status === null || status === undefined) throw new Error('Invalid MIDI running status.')
      if (hasStatus) cursor += 1

      if (status >= 0x80 && status <= 0xef) {
        runningStatus = status
        if (hasStatus) pianoMidi[cursor - 1] = status & 0xf0
        const type = status & 0xf0
        if (type === 0xc0) pianoMidi[cursor] = 0
        cursor += type === 0xc0 || type === 0xd0 ? 1 : 2
        continue
      }

      runningStatus = null
      if (status === 0xff) {
        cursor += 1
        const metaLength = readVariableLength(pianoMidi, cursor)
        cursor = metaLength.cursor + metaLength.value
      } else if (status === 0xf0 || status === 0xf7) {
        const sysexLength = readVariableLength(pianoMidi, cursor)
        cursor = sysexLength.cursor + sysexLength.value
      } else {
        throw new Error(`Unsupported MIDI event: ${status.toString(16)}`)
      }
    }

    if (cursor !== trackEnd) throw new Error('Invalid MIDI track length.')
  }

  return pianoMidi
}

const catalogFiles = ['catalogo.json', 'catalogo_en.json']
const catalogs = await Promise.all(
  catalogFiles.map(async (file) => JSON.parse(await readFile(resolve(appDirectory, 'assets', file), 'utf8'))),
)
const midiKeys = [
  ...new Set(
    catalogs
      .flat()
      .map((song) => song.midi_archivo)
      .filter(Boolean),
  ),
].filter((key) => !only || key === only)
const existingManifest = await readFile(manifestPath, 'utf8')
  .then(JSON.parse)
  .catch(() => ({ previews: {} }))
const previews = { ...existingManifest.previews }
const missing = []

await mkdir(previewsDirectory, { recursive: true })
let processed = 0
let skipped = 0
for (const key of midiKeys) {
  if (limit && processed >= limit) break
  const normalized = key.replace(/\\/g, '/')
  if (normalized.includes('..')) throw new Error(`Unsafe MIDI path: ${key}`)
  const source = resolve(midiDirectory, normalized)
  if (
    !(await access(source)
      .then(() => true)
      .catch(() => false))
  ) {
    missing.push({ key, reason: 'source file missing locally' })
    console.warn(`Skipped missing source: ${key}`)
    continue
  }

  const tempBase = createHash('sha256').update(normalized).digest('hex')
  const tempMidi = resolve(outputDirectory, `${tempBase}.mid`)
  const tempWav = tempMidi.replace(/\.mid$/, '.wav')
  try {
    const pianoMidi = normalizeMidiToPiano(decryptMidi(await readFile(source)))
    const names = previewNames(normalized, pianoMidi)
    const opusOutput = resolve(previewsDirectory, names.opus)
    const aacOutput = resolve(previewsDirectory, names.aac)
    const alreadyRendered = await Promise.all(
      [opusOutput, aacOutput].map((output) =>
        access(output)
          .then(() => true)
          .catch(() => false),
      ),
    )
    if (!force && alreadyRendered.every(Boolean)) {
      previews[key] = names
      skipped += 1
      continue
    }

    await writeFile(tempMidi, pianoMidi)
    await run(fluidsynth, ['-ni', '-F', tempWav, '-r', '44100', soundfont, tempMidi])
    await Promise.all([
      run(ffmpeg, ['-y', '-i', tempWav, '-t', '90', '-c:a', 'libopus', '-b:a', '64k', opusOutput]),
      run(ffmpeg, ['-y', '-i', tempWav, '-t', '90', '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart', aacOutput]),
    ])
    previews[key] = names
    processed += 1
    console.log(`Rendered ${processed}: ${key}`)
  } catch (error) {
    missing.push({ key, reason: error.message })
    console.warn(`Skipped ${key}: ${error.message}`)
  } finally {
    await Promise.all([rm(tempMidi, { force: true }), rm(tempWav, { force: true })])
  }
}

await writeFile(missingPath, `${JSON.stringify({ missing }, null, 2)}\n`)
if (missing.length) {
  throw new Error(`Preview rendering did not complete: ${missing.length} source file(s) need attention. See ${missingPath}.`)
}
await writeFile(manifestPath, `${JSON.stringify({ version: 2, previews }, null, 2)}\n`)
console.log(`Done. Rendered ${processed}, skipped ${skipped}, missing ${missing.length}, mapped ${Object.keys(previews).length}.`)
