import { access, copyFile, mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const websiteDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const previewDirectory = resolve(websiteDirectory, '.preview-output', 'previews')
const downloadDirectory = resolve(websiteDirectory, '.preview-output', 'downloaded-opus')
const manifestPath = resolve(websiteDirectory, 'public', 'preview-manifest.json')
const reportPath = resolve(websiteDirectory, '.preview-output', 'transcode-summary.json')
const previewOrigin = 'https://coro-lldm-previews.huritolentino.workers.dev/previews'
const ffmpeg =
  process.env.FFMPEG_BIN ||
  'C:\\Users\\Huri_\\AppData\\Local\\Microsoft\\WinGet\\Packages\\Gyan.FFmpeg.Essentials_Microsoft.Winget.Source_8wekyb3d8bbwe\\ffmpeg-8.1.1-essentials_build\\bin\\ffmpeg.exe'
const force = process.argv.includes('--force')

const exists = (file) =>
  access(file)
    .then(() => true)
    .catch(() => false)
const run = (command, args) =>
  new Promise((resolveRun, reject) => {
    const child = spawn(command, args, { stdio: 'ignore' })
    child.on('error', reject)
    child.on('exit', (code) => (code === 0 ? resolveRun() : reject(new Error(`ffmpeg exited with ${code}`))))
  })

const manifest = JSON.parse(await readFile(manifestPath, 'utf8'))
const nextPreviews = {}
const failures = []
let transcoded = 0
let downloaded = 0
let skipped = 0
await mkdir(previewDirectory, { recursive: true })
await mkdir(downloadDirectory, { recursive: true })

for (const [key, value] of Object.entries(manifest.previews || {})) {
  const sources = typeof value === 'string' ? { opus: value } : value
  if (!sources?.opus?.endsWith('.opus')) {
    failures.push({ key, reason: 'Missing or invalid Opus source in manifest' })
    continue
  }
  const aac = sources.aac || sources.opus.replace(/\.opus$/i, '.m4a')
  const output = resolve(previewDirectory, aac)
  let input = resolve(previewDirectory, sources.opus)
  try {
    if (!(await exists(input))) {
      input = resolve(downloadDirectory, sources.opus)
      if (!(await exists(input))) {
        const response = await fetch(`${previewOrigin}/${encodeURIComponent(sources.opus)}`)
        if (!response.ok) throw new Error(`Could not download existing Opus (${response.status})`)
        await writeFile(input, Buffer.from(await response.arrayBuffer()))
        downloaded += 1
      }
      await copyFile(input, resolve(previewDirectory, sources.opus))
      input = resolve(previewDirectory, sources.opus)
    }
    if (!force && (await exists(output))) {
      skipped += 1
    } else {
      await run(ffmpeg, ['-y', '-i', input, '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart', output])
      transcoded += 1
      console.log(`Transcoded ${transcoded}: ${key}`)
    }
    nextPreviews[key] = { opus: sources.opus, aac }
  } catch (error) {
    failures.push({ key, reason: error.message })
  }
}

await writeFile(
  reportPath,
  `${JSON.stringify({ transcoded, skipped, downloaded, expected: Object.keys(manifest.previews || {}).length, failures }, null, 2)}\n`,
)
if (failures.length) throw new Error(`Preview transcoding did not complete: ${failures.length} file(s) failed. See ${reportPath}.`)
await writeFile(manifestPath, `${JSON.stringify({ version: 2, previews: nextPreviews }, null, 2)}\n`)
console.log(`Done. Transcoded ${transcoded}, skipped ${skipped}, downloaded ${downloaded}, mapped ${Object.keys(nextPreviews).length}.`)
