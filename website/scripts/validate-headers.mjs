import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

const headersPath = fileURLToPath(new URL('../public/_headers', import.meta.url))
const headers = await readFile(headersPath, 'utf8')
const required = [
  'X-Content-Type-Options: nosniff',
  'X-Frame-Options: DENY',
  'Referrer-Policy:',
  'Permissions-Policy:',
  'Content-Security-Policy:',
  "default-src 'self'",
  "frame-ancestors 'none'",
  "object-src 'none'",
]
const missing = required.filter((header) => !headers.includes(header))
if (missing.length) throw new Error(`Missing security headers: ${missing.join(', ')}`)
console.log('Validated required static security headers.')
