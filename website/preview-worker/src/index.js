const baseCors = {
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Range',
  'Access-Control-Expose-Headers': 'Accept-Ranges, Content-Length, Content-Range',
}

const allowedOrigins = (origin) =>
  origin === 'https://lldmcoro.com' ||
  origin === 'https://www.lldmcoro.com' ||
  origin === 'https://coro-lldm.pages.dev' ||
  /^https:\/\/[a-z0-9-]+\.coro-lldm\.pages\.dev$/i.test(origin || '') ||
  /^https?:\/\/(?:localhost|127\.0\.0\.1)(?::\d+)?$/i.test(origin || '')
const corsFor = (request) => {
  const headers = new Headers(baseCors)
  const origin = request.headers.get('Origin')
  headers.set('Vary', 'Origin')
  if (allowedOrigins(origin)) headers.set('Access-Control-Allow-Origin', origin)
  return headers
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: corsFor(request) })
    const url = new URL(request.url)
    const match = url.pathname.match(/^\/previews\/([a-z0-9][a-z0-9._-]*\.(opus|m4a))$/i)
    if (!['GET', 'HEAD'].includes(request.method) || !match) return new Response('Not found', { status: 404, headers: corsFor(request) })
    const rangeHeader = request.headers.get('Range')
    const rangeMatch = rangeHeader?.match(/^bytes=(\d+)-(\d*)$/)
    const start = rangeMatch ? Number(rangeMatch[1]) : null
    const end = rangeMatch?.[2] ? Number(rangeMatch[2]) : null
    if (
      rangeHeader &&
      (!rangeMatch || !Number.isSafeInteger(start) || start < 0 || (end !== null && (!Number.isSafeInteger(end) || end < start)))
    )
      return new Response('Invalid range', { status: 416, headers: corsFor(request) })
    const range = rangeMatch
      ? {
          offset: start,
          length: end !== null ? end - start + 1 : undefined,
        }
      : undefined
    const object = await env.PREVIEWS.get(`previews/${match[1]}`, range ? { range } : undefined)
    if (!object) return new Response('Not found', { status: 404, headers: corsFor(request) })
    const headers = corsFor(request)
    headers.set('Content-Type', match[2].toLowerCase() === 'm4a' ? 'audio/mp4; codecs=mp4a.40.2' : 'audio/ogg; codecs=opus')
    headers.set('Cache-Control', 'public, max-age=31536000, immutable')
    headers.set('Accept-Ranges', 'bytes')
    headers.set('ETag', object.httpEtag)
    const responseRange = object.range
    const responseLength = responseRange?.length || object.size
    headers.set('Content-Length', responseLength.toString())
    if (responseRange)
      headers.set('Content-Range', `bytes ${responseRange.offset}-${responseRange.offset + responseLength - 1}/${object.size}`)
    return new Response(request.method === 'HEAD' ? null : object.body, { headers, status: responseRange ? 206 : 200 })
  },
}
