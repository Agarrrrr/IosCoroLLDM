import { APP_STORE, PLAY_STORE, PREVIEW_AUDIO_URL } from './site-data'
import { buildStructuredData, seoForPage } from './seo.js'
import {
  languageFromPath,
  pageFromPath as resolvePageFromPath,
  pageMetadata,
  previewSourcesFor,
  previewUrlFor,
  routePath as makeRoutePath,
} from './site-utils'
import { locationParts } from './browser-runtime'

const SITE_BASE = import.meta.env.BASE_URL
const assetUrl = (name) => `${SITE_BASE}${name}`
const currentLanguage = ({ pathname } = locationParts()) => languageFromPath(pathname, SITE_BASE)
const pageFromPath = ({ pathname, search } = locationParts()) => resolvePageFromPath(pathname, search, SITE_BASE)
const routePath = (target, language = currentLanguage()) => makeRoutePath(target, language, SITE_BASE)
const formatDemoTime = (seconds = 0) => `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, '0')}`

export {
  APP_STORE,
  PLAY_STORE,
  PREVIEW_AUDIO_URL,
  SITE_BASE,
  assetUrl,
  buildStructuredData,
  currentLanguage,
  formatDemoTime,
  pageFromPath,
  pageMetadata,
  previewSourcesFor,
  previewUrlFor,
  routePath,
  seoForPage,
}
