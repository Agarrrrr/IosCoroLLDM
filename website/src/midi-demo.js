let currentAudio = null

const PREVIEW_GAIN_DB = 5
const PREVIEW_GAIN = 10 ** (PREVIEW_GAIN_DB / 20)
let audioContext = null

export const mediaErrorKey = (code) => {
  if (code === 1) return 'audioPlaybackAborted'
  if (code === 2) return 'audioPlaybackNetwork'
  if (code === 3) return 'audioPlaybackDecode'
  if (code === 4) return 'audioPlaybackUnsupported'
  return 'audioPlaybackError'
}

const isAppleMobile = () =>
  typeof globalThis.navigator !== 'undefined' &&
  (/iPad|iPhone|iPod/.test(globalThis.navigator.userAgent) ||
    (globalThis.navigator.platform === 'MacIntel' && globalThis.navigator.maxTouchPoints > 1))

export function preferredPreviewSource(sources, { canPlayType, appleMobile = isAppleMobile() } = {}) {
  const supports = canPlayType || ((type) => globalThis.document?.createElement('audio').canPlayType(type) || '')
  const canPlayAac = Boolean(sources?.aac && supports('audio/mp4; codecs="mp4a.40.2"'))
  const canPlayOpus = Boolean(sources?.opus && supports('audio/ogg; codecs="opus"'))

  // AAC/M4A es la ruta conservadora para Safari/iOS. En los demás navegadores
  // se prioriza Opus por su tamaño menor y se conserva AAC como fallback.
  if (appleMobile && canPlayAac) return { format: 'aac', url: sources.aac }
  if (canPlayOpus) return { format: 'opus', url: sources.opus }
  if (canPlayAac) return { format: 'aac', url: sources.aac }
  return null
}

function getAudioContext(runtime = globalThis) {
  if (!audioContext) {
    const AudioContextClass = runtime.AudioContext || runtime.webkitAudioContext
    if (!AudioContextClass) return null
    audioContext = new AudioContextClass()
  }
  return audioContext
}

export async function playEnsembleDemo(
  url,
  { onEnd, onError, onProgress, audioFactory = () => new globalThis.Audio(), runtime = globalThis } = {},
) {
  stopEnsembleDemo()

  const audio = audioFactory()
  const nativePlayback = isAppleMobile()
  // Safari/iOS reproduce AAC de forma más fiable usando el elemento nativo.
  // Solo pedimos CORS cuando necesitamos inyectarlo en Web Audio para ganancia.
  if (!nativePlayback) audio.crossOrigin = 'anonymous'
  audio.src = url
  audio.preload = 'metadata'
  audio.playsInline = true
  audio.volume = 1

  // HTMLMediaElement.volume no puede superar 1. Web Audio permite aplicar
  // la ganancia adicional sin modificar ni volver a renderizar los previews.
  // En Safari/iOS se prefiere la ruta nativa para no perder la activación táctil.
  const context = nativePlayback ? null : getAudioContext(runtime)
  let source = null
  let gainNode = null
  try {
    source = context?.createMediaElementSource(audio) ?? null
    gainNode = context?.createGain() ?? null
    if (source && gainNode) {
      gainNode.gain.value = PREVIEW_GAIN
      source.connect(gainNode)
      gainNode.connect(context.destination)
    }
  } catch {
    // Si el navegador bloquea Web Audio para este origen, el audio HTML
    // sigue siendo reproducible a volumen normal en lugar de quedar mudo.
    source = null
    gainNode = null
  }

  let startupTimeout = null
  const clearStartupTimeout = () => {
    if (startupTimeout !== null) runtime.clearTimeout(startupTimeout)
    startupTimeout = null
  }
  const cleanup = () => {
    clearStartupTimeout()
    source?.disconnect()
    gainNode?.disconnect()
  }
  let errorReported = false
  const reportError = () => {
    if (errorReported) return
    errorReported = true
    cleanup()
    if (currentAudio?.audio === audio) currentAudio = null
    onError?.(mediaErrorKey(audio.error?.code))
  }
  currentAudio = { audio, cleanup }

  const updateProgress = () => {
    onProgress?.(audio.currentTime, Number.isFinite(audio.duration) ? audio.duration : 30)
  }

  audio.addEventListener('timeupdate', updateProgress)
  audio.addEventListener('loadedmetadata', updateProgress)
  audio.addEventListener('playing', clearStartupTimeout, { once: true })
  audio.addEventListener('error', reportError, { once: true })
  audio.addEventListener(
    'ended',
    () => {
      audio.removeEventListener('timeupdate', updateProgress)
      audio.removeEventListener('error', reportError)
      cleanup()
      if (currentAudio?.audio === audio) currentAudio = null
      onEnd?.()
    },
    { once: true },
  )

  if (context?.state === 'suspended') await context.resume()
  startupTimeout = runtime.setTimeout(() => {
    audio.pause()
    reportError()
  }, 12_000)
  try {
    await audio.play()
  } catch (error) {
    reportError()
    throw error
  }

  return {
    duration: Number.isFinite(audio.duration) ? audio.duration : 30,
    seekBy: (seconds) => {
      const duration = Number.isFinite(audio.duration) ? audio.duration : 0
      audio.currentTime = Math.max(0, Math.min(duration, audio.currentTime + seconds))
      updateProgress()
    },
    stop: () => {
      audio.pause()
      audio.currentTime = 0
      audio.removeEventListener('timeupdate', updateProgress)
      audio.removeEventListener('error', reportError)
      cleanup()
      if (currentAudio?.audio === audio) currentAudio = null
    },
  }
}

export function stopEnsembleDemo() {
  currentAudio?.audio.pause()
  if (currentAudio) {
    currentAudio.audio.currentTime = 0
    currentAudio.cleanup()
  }
  currentAudio = null
}
