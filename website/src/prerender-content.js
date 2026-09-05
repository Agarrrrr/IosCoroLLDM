import { copy, faqCopy, solutionCopy } from './content.js'
import { legalContent } from './legal-content.js'
import { releaseNotes } from './site-config.js'

const localized = (lang, spanish, english) => (lang === 'en' ? english : spanish)
const heading = (...parts) => parts.filter(Boolean).join(' ')

export function prerenderContentFor(page, lang) {
  const t = copy[lang]
  const legal = legalContent[lang][page]
  if (legal) {
    return {
      h1: legal.title,
      h2: localized(lang, 'Información legal', 'Legal information'),
      h3: legal.updated,
      text: legal.intro,
      details: legal.sections.map(([title, body]) => `${title}: ${body}`),
    }
  }

  if (page === 'inicio') {
    return {
      h1: heading(t.heroStart, t.heroAccent),
      h2: t.featureTitle,
      h3: t.capabilitiesTitle,
      text: t.heroLead,
    }
  }
  if (page === 'repertorio') {
    return { h1: t.catalogTitle, h2: t.catalogEyebrow, h3: t.voiceAudio, text: t.catalogCopy }
  }
  if (page === 'producto') {
    return {
      h1: t.capabilitiesTitle,
      h2: t.capabilitiesEyebrow,
      h3: t.faqTitle,
      text: t.capabilitiesCopy,
      details: [
        t.capabilitySearch,
        t.capabilityViewer,
        t.capabilityAnnotations,
        t.capabilityOffline,
        t.capabilityOrganize,
        t.capabilityAudio,
        t.capabilityDownloads,
        t.capabilityLanguages,
      ],
      faq: faqCopy[lang],
    }
  }
  if (page === 'novedades') {
    const release = releaseNotes[0]?.[lang] || releaseNotes[0]?.es
    return {
      h1: heading(t.latestVersion, releaseNotes[0]?.version),
      h2: release.title,
      h3: localized(lang, 'Otros cambios', 'Other changes'),
      text: release.summary,
      details: [...release.newScores, ...release.newAudio, ...release.changes],
    }
  }
  if (page === 'soluciones') {
    const solution = solutionCopy[lang]
    return {
      h1: solution.processTitle,
      h2: solution.processEyebrow,
      h3: localized(lang, 'Proceso a medida', 'Custom process'),
      text: solution.processCopy,
      details: solution.processSteps,
    }
  }
  if (page === 'roadmap') {
    return {
      h1: heading(t.collabStart, t.collabAccent),
      h2: t.roadmapPending,
      h3: t.roadmapCurrent,
      text: t.collabCopy,
      details: t.roadmapCurrentItems,
    }
  }
  if (page === 'contacto') {
    return {
      h1: heading(t.contactStart, t.contactAccent),
      h2: t.contactEyebrow,
      h3: t.contactRoutes,
      text: t.contactCopy,
    }
  }
  return {
    h1: t.notFoundTitle,
    h2: localized(lang, 'Error 404', '404 error'),
    h3: t.backHome,
    text: t.notFoundCopy,
  }
}
