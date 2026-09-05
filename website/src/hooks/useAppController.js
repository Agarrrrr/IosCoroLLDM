import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { playEnsembleDemo, preferredPreviewSource, stopEnsembleDemo } from '../midi-demo'
import {
  cancelSchedule,
  getStoredTheme,
  listen,
  mainContent,
  pageDocument,
  pageWindow,
  requestFrame,
  schedule,
  scrollToTop,
  storeTheme,
  updateHistory,
} from '../browser-runtime'
import { currentLanguage, pageFromPath, previewSourcesFor, routePath } from '../app-config'
import { copy, faqLabels } from '../content'
import { useDocumentMetadata, useRevealSections } from './useSiteEffects'
import { useCatalogData } from './useCatalogData'

export function useAppController() {
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState('todos')
  const [visibleCount, setVisibleCount] = useState(12)
  const [page, setPage] = useState(pageFromPath)
  const { catalogError, catalogLoading, catalogStats, loadCatalog, previewMap, roadmapLoading, roadmapPending, songs } =
    useCatalogData(page)
  const [activeDemo, setActiveDemo] = useState(null)
  const [dark, setDark] = useState(getStoredTheme)
  const [lang, setLang] = useState(currentLanguage)
  const [themeAnimating, setThemeAnimating] = useState(false)
  const [languageAnimating, setLanguageAnimating] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [contactTopic, setContactTopic] = useState(null)
  const [contactName, setContactName] = useState('')
  const [contactEmail, setContactEmail] = useState('')
  const [contactMessage, setContactMessage] = useState('')
  const [feedback, setFeedback] = useState('')
  const demoRequest = useRef(0)
  const demoPlayer = useRef(null)
  const contactMessageRef = useRef(null)
  const feedbackTimer = useRef(null)
  const navToggleRef = useRef(null)
  const timers = useRef(new Set())
  const brandName = lang === 'en' ? 'TLOTW Choir' : 'Coro LLDM'
  const t = (key) => {
    const value = copy[lang][key] ?? faqLabels[lang][key] ?? key
    return typeof value === 'string' ? value.replaceAll('Coro LLDM', brandName) : value
  }
  const stopDemo = useCallback(() => {
    demoRequest.current += 1
    demoPlayer.current?.stop()
    demoPlayer.current = null
    stopEnsembleDemo()
    setActiveDemo(null)
  }, [])
  const later = useCallback((callback, delay) => {
    const id = schedule(() => {
      timers.current.delete(id)
      callback()
    }, delay)
    timers.current.add(id)
    return id
  }, [])

  useDocumentMetadata({ brandName, dark, lang, page })
  useRevealSections(page)
  useEffect(
    () => () => {
      timers.current.forEach(cancelSchedule)
      cancelSchedule(feedbackTimer.current)
      stopEnsembleDemo()
    },
    [],
  )
  const localizedSongs = useMemo(() => songs.filter((song) => song.idioma === lang), [songs, lang])
  const previewForSong = useCallback((song) => preferredPreviewSource(previewSourcesFor(song, previewMap)), [previewMap])
  const available = useMemo(() => localizedSongs.filter((song) => previewForSong(song)), [localizedSongs, previewForSong])
  const pending = useMemo(() => localizedSongs.filter((song) => !previewForSong(song)), [localizedSongs, previewForSong])
  const filteredSongs = useMemo(
    () =>
      localizedSongs.filter(
        (song) =>
          song.nombre?.toLowerCase().includes(query.toLowerCase()) &&
          (filter === 'todos' || (filter === 'audio' ? Boolean(previewForSong(song)) : !previewForSong(song))),
      ),
    [localizedSongs, query, filter, previewForSong],
  )
  const displayedSongs = useMemo(() => filteredSongs.slice(0, visibleCount), [filteredSongs, visibleCount])
  useEffect(() => {
    setVisibleCount(12)
    setQuery('')
    setFilter('todos')
    stopDemo()
  }, [lang, stopDemo])
  useEffect(() => setVisibleCount(12), [query, filter])
  useEffect(() => listen(pageWindow(), 'popstate', () => setPage(pageFromPath())), [])
  useEffect(() => listen(pageDocument(), 'visibilitychange', () => pageDocument()?.hidden && stopDemo()), [stopDemo])
  useEffect(() => {
    if (page !== 'repertorio') stopDemo()
  }, [page, stopDemo])
  useEffect(
    () =>
      listen(pageWindow(), 'keydown', (event) => {
        if (event.key === 'Escape' && mobileOpen) {
          setMobileOpen(false)
          navToggleRef.current?.focus()
        }
      }),
    [mobileOpen],
  )
  const announce = useCallback(
    (message) => {
      setFeedback(message)
      cancelSchedule(feedbackTimer.current)
      feedbackTimer.current = later(() => setFeedback(''), 3500)
    },
    [later],
  )
  const toggleTheme = () => {
    setThemeAnimating(true)
    setDark((value) => {
      const next = !value
      storeTheme(next)
      return next
    })
    later(() => setThemeAnimating(false), 560)
  }
  const toggleLanguage = () => {
    setLanguageAnimating(true)
    setLang((value) => {
      const next = value === 'es' ? 'en' : 'es'
      updateHistory('replaceState', routePath(page, next))
      return next
    })
    later(() => setLanguageAnimating(false), 420)
  }
  const chooseContactTopic = (topic) => {
    setContactTopic(topic)
    requestFrame(() => contactMessageRef.current?.focus())
  }
  const submitContact = (event) => {
    event.preventDefault()
    announce(contactName.trim() && contactEmail.trim() && contactMessage.trim() ? t('contactDeliveryPending') : t('contactIncomplete'))
  }
  const goTo = (target) => (event) => {
    event.preventDefault()
    stopDemo()
    updateHistory('pushState', routePath(target, lang))
    setPage(target)
    setMobileOpen(false)
    scrollToTop()
    requestFrame(() => mainContent()?.focus())
  }
  const focusMain = (event) => {
    event.preventDefault()
    requestFrame(() => mainContent()?.focus())
  }
  const toggleDemo = async (song) => {
    if (activeDemo?.id === song.id) return stopDemo()
    const request = ++demoRequest.current
    const preview = previewForSong(song)
    if (!preview) return announce(song.midi_archivo ? t('audioUnavailableNotice') : t('audioPendingNotice'))
    stopEnsembleDemo()
    setActiveDemo({ id: song.id, title: song.nombre, loading: true })
    try {
      const playback = await playEnsembleDemo(preview.url, {
        onError: (key) => {
          if (request !== demoRequest.current) return
          demoPlayer.current = null
          setActiveDemo(null)
          announce(t(key))
        },
        onEnd: () => {
          demoPlayer.current = null
          setActiveDemo(null)
        },
        onProgress: (progress, duration) =>
          setActiveDemo((current) => (current?.id === song.id ? { ...current, progress, duration } : current)),
      })
      if (request !== demoRequest.current) return playback.stop()
      demoPlayer.current = playback
      setActiveDemo((current) => ({ ...current, loading: false, duration: playback.duration, progress: current?.progress || 0 }))
    } catch {
      if (request === demoRequest.current) {
        setActiveDemo(null)
        demoPlayer.current = null
      }
    }
  }
  const changeDemo = (direction) => {
    const playable = localizedSongs.filter(previewForSong)
    const next = playable[playable.findIndex((song) => song.id === activeDemo?.id) + direction]
    if (next) toggleDemo(next)
  }
  return {
    activeDemo,
    available,
    brandName,
    catalogError,
    catalogLoading,
    catalogStats,
    changeDemo,
    chooseContactTopic,
    contactEmail,
    contactMessage,
    contactMessageRef,
    contactName,
    contactTopic,
    dark,
    displayedSongs,
    feedback,
    focusMain,
    filter,
    filteredSongs,
    goTo,
    lang,
    languageAnimating,
    loadCatalog,
    localizedSongs,
    mobileOpen,
    navToggleRef,
    page,
    pending,
    previewForSong,
    query,
    roadmapLoading,
    roadmapPending,
    setContactEmail,
    setContactMessage,
    setContactName,
    setFilter,
    setMobileOpen,
    setQuery,
    setVisibleCount,
    stopDemo,
    submitContact,
    t,
    themeAnimating,
    toggleDemo,
    toggleLanguage,
    toggleTheme,
    visibleCount,
    announce,
  }
}
