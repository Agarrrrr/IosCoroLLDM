import { access, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const websiteDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const manifest = JSON.parse(await readFile(resolve(websiteDirectory, 'public', 'preview-manifest.json'), 'utf8'))
const previewDirectory = resolve(websiteDirectory, '.preview-output', 'previews')
const logPath = resolve(websiteDirectory, '.preview-output', 'upload-summary.json')
const format = process.argv.find((argument) => argument.startsWith('--format='))?.slice('--format='.length)
const concurrency = Number(process.argv.find((argument) => argument.startsWith('--concurrency='))?.slice('--concurrency='.length) || 1)
if (format && !['opus', 'aac'].includes(format)) throw new Error('Use --format=opus or --format=aac.')
if (!Number.isInteger(concurrency) || concurrency < 1 || concurrency > 8) throw new Error('Use a concurrency between 1 and 8.')
const names = [
  ...new Set(
    Object.values(manifest.previews).flatMap((preview) => (typeof preview === 'string' ? [preview] : Object.values(preview || {}))),
  ),
].filter((name) => !format || (format === 'aac' ? name.endsWith('.m4a') : name.endsWith('.opus')))
const wrangler = process.platform === 'win32' ? 'npx.cmd' : 'npx'

const run = (args) =>
  new Promise((resolveRun, reject) => {
    const child = spawn(wrangler, args, { stdio: 'ignore', shell: process.platform === 'win32' })
    child.on('error', reject)
    child.on('exit', (code) => (code === 0 ? resolveRun() : reject(new Error(`Wrangler exited with ${code}`))))
  })

const failures = []
let uploaded = 0
const uploadOne = async (name) => {
  if (!/^[a-z0-9][a-z0-9._-]*\.(opus|m4a)$/i.test(name)) {
    failures.push({ name, reason: 'Unsafe preview filename' })
    return
  }
  const file = resolve(previewDirectory, name)
  if (
    !(await access(file)
      .then(() => true)
      .catch(() => false))
  ) {
    failures.push({ name, reason: 'Preview missing locally' })
    return
  }
  try {
    await run(['wrangler', 'r2', 'object', 'put', `coro-lldm-previews/previews/${name}`, '--file', file, '--remote'])
    uploaded += 1
    console.log(`Uploaded ${uploaded}/${names.length}: ${name}`)
  } catch (error) {
    failures.push({ name, reason: error.message })
    console.warn(`Failed ${name}: ${error.message}`)
  }
}
let cursor = 0
await Promise.all(
  Array.from({ length: Math.min(concurrency, names.length) }, async () => {
    while (cursor < names.length) {
      const name = names[cursor]
      cursor += 1
      await uploadOne(name)
    }
  }),
)

await writeFile(
  logPath,
  `${JSON.stringify({ uploaded, expected: names.length, format: format || 'all', concurrency, failures }, null, 2)}\n`,
)
if (failures.length) throw new Error(`Preview upload did not complete: ${failures.length} file(s) failed. See ${logPath}.`)
console.log(`Done. Uploaded ${uploaded}/${names.length}, failures ${failures.length}.`)
