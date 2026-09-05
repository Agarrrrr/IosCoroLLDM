import { useCallback, useEffect, useRef, useState } from 'react'
import { assetUrl } from '../app-config'
import { fetchJsonWithTimeout } from '../data-client'

const versionedAssetUrl = (name, version) => `${assetUrl(name)}${version ? `?v=${encodeURIComponent(version)}` : ''}`

export function useCatalogData(page) {
  const [songs, setSongs] = useState([])
  const [catalogStats, setCatalogStats] = useState(null)
  const [previewMap, setPreviewMap] = useState({})
  const [roadmapPending, setRoadmapPending] = useState([])
  const [roadmapLoading, setRoadmapLoading] = useState(false)
  const [catalogLoading, setCatalogLoading] = useState(false)
  const [catalogError, setCatalogError] = useState(false)
  const catalogLoaded = useRef(false)
  const roadmapLoaded = useRef(false)
  const catalogStatsLoaded = useRef(false)
  const catalogMeta = useRef(null)
  const catalogMetaRequest = useRef(null)
  const controllers = useRef(new Set())
  const fetchJson = useCallback(
    (url, { fallback = null, required = false, cache } = {}) =>
      fetchJsonWithTimeout(url, {
        fallback,
        required,
        cache,
        onController: (controller, active) => (active ? controllers.current.add(controller) : controllers.current.delete(controller)),
      }),
    [],
  )
  const getCatalogMeta = useCallback(() => {
    if (catalogMeta.current) return Promise.resolve(catalogMeta.current)
    if (catalogMetaRequest.current) return catalogMetaRequest.current
    catalogMetaRequest.current = fetchJson(assetUrl('catalog-meta.json'), { cache: 'no-cache' })
      .then((meta) => (catalogMeta.current = meta))
      .finally(() => {
        catalogMetaRequest.current = null
      })
    return catalogMetaRequest.current
  }, [fetchJson])
  const loadCatalog = useCallback(() => {
    if (catalogLoaded.current) return
    catalogLoaded.current = true
    setCatalogLoading(true)
    setCatalogError(false)
    const readJson = (name, fallback, required = false, version = '') => fetchJson(versionedAssetUrl(name, version), { fallback, required })
    getCatalogMeta()
      .then((meta) =>
        Promise.all([
          readJson('catalogo.json', [], true, meta?.catalogs?.es?.hash),
          readJson('catalogo_en.json', [], true, meta?.catalogs?.en?.hash),
          readJson('preview-manifest.json', { previews: {} }, false, meta?.version),
        ]),
      )
      .then(([spanish, english, manifest]) => {
        setSongs([...spanish, ...english])
        setPreviewMap(manifest.previews || {})
      })
      .catch(() => {
        catalogLoaded.current = false
        setCatalogError(true)
      })
      .finally(() => setCatalogLoading(false))
  }, [fetchJson, getCatalogMeta])
  const loadRoadmap = useCallback(() => {
    if (roadmapLoaded.current) return
    roadmapLoaded.current = true
    setRoadmapLoading(true)
    fetchJson(assetUrl('roadmap-pending.json'), { fallback: { items: [] } })
      .then((roadmap) => setRoadmapPending(roadmap.items || []))
      .catch(() => {
        roadmapLoaded.current = false
        setRoadmapPending([])
      })
      .finally(() => setRoadmapLoading(false))
  }, [fetchJson])
  useEffect(
    () => () => {
      controllers.current.forEach((controller) => controller.abort())
      controllers.current.clear()
    },
    [],
  )
  useEffect(() => {
    if (page === 'repertorio') loadCatalog()
    if (page === 'roadmap') loadRoadmap()
  }, [page, loadCatalog, loadRoadmap])
  useEffect(() => {
    if (page !== 'inicio' || catalogStatsLoaded.current) return
    catalogStatsLoaded.current = true
    getCatalogMeta()
      .then((meta) => fetchJson(versionedAssetUrl('catalog-stats.json', meta?.version)))
      .then(setCatalogStats)
      .catch(() => {
        catalogStatsLoaded.current = false
      })
  }, [page, fetchJson, getCatalogMeta])
  return { catalogError, catalogLoading, catalogStats, loadCatalog, previewMap, roadmapLoading, roadmapPending, songs }
}
