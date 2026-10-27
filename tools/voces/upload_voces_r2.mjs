import { readFile, writeFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { resolve } from 'node:path'
import { spawn } from 'node:child_process'

const ESP_DIR = 'E:\\Respaldo\\Voces Cantadas'
const ENG_DIR = 'E:\\Respaldo\\Voces Cantadas (English)'
const MANIFEST_PATH = resolve('assets', 'voces_manifest.json')
const STATE_PATH = 'E:\\Respaldo\\uploaded_to_r2.json'
const WRANGLER_BIN = resolve('website', 'node_modules', '.bin', 'wrangler.cmd')
const CONCURRENCY = 6

let state = {}
if (existsSync(STATE_PATH)) {
  try {
    state = JSON.parse(await readFile(STATE_PATH, 'utf8'))
  } catch (e) {
    console.warn('Could not parse existing state, starting fresh.')
  }
}

const manifest = JSON.parse(await readFile(MANIFEST_PATH, 'utf8'))

const queue = []

// Collect Spanish
for (const canto of manifest.idiomas.es.cantos) {
  for (const [voz, info] of Object.entries(canto.voces || {})) {
    const localFile = resolve(ESP_DIR, canto.carpeta, info.archivo)
    queue.push({
      lang: 'es',
      canto: canto.canto,
      voz,
      r2Path: `coro-lldm-previews/audio/${info.r2_path}`,
      localFile,
      key: info.r2_path,
      size: info.size_bytes
    })
  }
}

// Collect English
for (const canto of manifest.idiomas.en.cantos) {
  for (const [voz, info] of Object.entries(canto.voces || {})) {
    const localFile = resolve(ENG_DIR, canto.carpeta, info.archivo)
    queue.push({
      lang: 'en',
      canto: canto.canto,
      voz,
      r2Path: `coro-lldm-previews/audio/${info.r2_path}`,
      localFile,
      key: info.r2_path,
      size: info.size_bytes
    })
  }
}

console.log(`Total MP3 files in manifest: ${queue.length}`)
const pending = queue.filter(item => !state[item.key])
console.log(`Already uploaded: ${queue.length - pending.length}. Pending to upload: ${pending.length}`)

let uploadedCount = queue.length - pending.length
let errorCount = 0

function runWrangler(r2Destination, localFilePath) {
  return new Promise((resolveRun, reject) => {
    const command = `"${WRANGLER_BIN}" r2 object put "${r2Destination}" --file "${localFilePath}" --remote`
    const child = spawn('cmd.exe', ['/d', '/s', '/c', `"${command}"`], {
      windowsVerbatimArguments: true,
      stdio: ['ignore', 'ignore', 'pipe']
    })
    let stderr = ''
    child.stderr?.on('data', d => { stderr += d.toString() })
    child.on('error', reject)
    child.on('exit', (code) => {
      if (code === 0) resolveRun()
      else reject(new Error(stderr || `Wrangler exited with ${code}`))
    })
  })
}

async function saveState() {
  await writeFile(STATE_PATH, JSON.stringify(state, null, 2), 'utf8')
}

let idx = 0
async function worker(workerId) {
  while (idx < pending.length) {
    const current = pending[idx++]
    if (!current) break
    
    if (!existsSync(current.localFile)) {
      console.warn(`[Worker ${workerId}] Local file not found: ${current.localFile}`)
      errorCount++
      continue
    }

    let attempts = 0
    let success = false
    while (attempts < 3 && !success) {
      attempts++
      try {
        await runWrangler(current.r2Path, current.localFile)
        success = true
        state[current.key] = {
          uploaded_at: new Date().toISOString(),
          size: current.size
        }
        uploadedCount++
        console.log(`[Worker ${workerId}][${uploadedCount}/${queue.length}] OK: ${current.key}`)
      } catch (err) {
        console.warn(`[Worker ${workerId}] Attempt ${attempts} failed for ${current.key}: ${err.message}`)
        if (attempts >= 3) {
          errorCount++
        }
      }
    }

    if (uploadedCount % 10 === 0) {
      await saveState()
    }
  }
}

console.log(`Starting ${CONCURRENCY} workers...`)
const workers = Array.from({ length: CONCURRENCY }, (_, i) => worker(i + 1))
await Promise.all(workers)
await saveState()

// Sincronizar manifiestos y catálogos OTA en R2 para entrega instantánea en la app
const otaFiles = [
  { r2: 'coro-lldm-previews/audio/voces_manifest.json', local: resolve('assets', 'voces_manifest.json') },
  { r2: 'coro-lldm-previews/audio/catalogo.json', local: resolve('assets', 'catalogo.json') },
  { r2: 'coro-lldm-previews/audio/catalogo_en.json', local: resolve('assets', 'catalogo_en.json') },
]
for (const item of otaFiles) {
  if (existsSync(item.local)) {
    try {
      await runWrangler(item.r2, item.local)
      console.log(`[OTA Sync] OK: ${item.r2}`)
    } catch (err) {
      console.warn(`[OTA Sync] Error uploading ${item.r2}: ${err.message}`)
    }
  }
}

console.log(`Upload process finished! Total uploaded: ${uploadedCount}, Errors: ${errorCount}`)
