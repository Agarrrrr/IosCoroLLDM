import {
  Bell,
  BookOpen,
  CalendarDays,
  Check,
  ChevronDown,
  FileCheck2,
  Headphones,
  HeartHandshake,
  Search,
  Sparkles,
  Users,
  WifiOff,
  Music2,
} from 'lucide-react'
import { legalContent } from './legal-content'
import { releaseNotes } from './site-config'
import { Capability } from './components/ui'

export function ProductPage({ t, lang, faq }) {
  return (
    <>
      <section className="product-hero container">
        <span className="eyebrow">{t('capabilitiesEyebrow')}</span>
        <h1>{t('capabilitiesTitle')}</h1>
        <p className="hero-lead">{t('capabilitiesCopy')}</p>
      </section>
      <section className="capabilities-section product-capabilities">
        <div className="container">
          <div className="capability-grid">
            <Capability icon={<Search />} title={t('capabilitySearch')} text={t('capabilitySearchCopy')} />
            <Capability icon={<BookOpen />} title={t('capabilityViewer')} text={t('capabilityViewerCopy')} />
            <Capability icon={<Sparkles />} title={t('capabilityAnnotations')} text={t('capabilityAnnotationsCopy')} />
            <Capability icon={<WifiOff />} title={t('capabilityOffline')} text={t('capabilityOfflineCopy')} />
            <Capability icon={<Users />} title={t('capabilityOrganize')} text={t('capabilityOrganizeCopy')} />
            <Capability icon={<Music2 />} title={t('capabilityAudio')} text={t('capabilityAudioCopy')} />
            <Capability icon={<BookOpen />} title={t('capabilityDownloads')} text={t('capabilityDownloadsCopy')} />
            <Capability icon={<Check />} title={t('capabilityLanguages')} text={t('capabilityLanguagesCopy')} />
          </div>
          <div className="monetization-note">
            <span className="feature-icon">
              <HeartHandshake />
            </span>
            <div>
              <h2>{t('monetizationTitle')}</h2>
              <p>{t('monetizationCopy')}</p>
            </div>
          </div>
        </div>
      </section>
      <section className="faq-section section container" aria-labelledby="faq-title">
        <div className="section-intro">
          <span className="eyebrow">FAQ</span>
          <h2 id="faq-title">{t('faqTitle')}</h2>
          <p>{t('faqCopy')}</p>
        </div>
        <div className="faq-grid">
          {faq[lang].map(([question, answer]) => (
            <details className="faq-item" key={question}>
              <summary>
                {question}
                <ChevronDown size={17} />
              </summary>
              <p>{answer}</p>
            </details>
          ))}
        </div>
      </section>
    </>
  )
}

export function RoadmapPage({ t, items, loading }) {
  return (
    <section className="roadmap-page section container">
      <div className="roadmap-header">
        <span className="eyebrow">{t('collabEyebrow')}</span>
        <h1 className="page-title">
          {t('collabStart')} <em>{t('collabAccent')}</em>
        </h1>
        <p className="hero-lead">{t('collabCopy')}</p>
      </div>
      <div className="roadmap-pending">
        <div className="section-intro">
          <h2>{t('roadmapPending')}</h2>
          <p>{t('roadmapPendingCopy')}</p>
        </div>
        {loading ? (
          <div className="roadmap-pending-grid">
            {Array.from({ length: 6 }, (_, index) => (
              <div className="skeleton roadmap-skeleton" key={index} />
            ))}
          </div>
        ) : items.length ? (
          <ol className="roadmap-pending-grid">
            {items.map((song, index) => (
              <li key={song.id}>
                <span>{String(index + 1).padStart(2, '0')}</span>
                <strong>{song.name}</strong>
                <small>
                  {song.language === 'en' ? t('languageEnglish') : t('languageSpanish')}
                  {song.themes?.[0] ? ` · ${song.themes[0]}` : ''}
                </small>
              </li>
            ))}
          </ol>
        ) : (
          <p className="roadmap-empty">{t('pendingEmpty')}</p>
        )}
      </div>
    </section>
  )
}

export function LegalPage({ type, lang, t }) {
  const content = legalContent[lang][type]
  return (
    <section className="legal-page section container">
      <div className="legal-header">
        <span className="eyebrow">{t('legalInformation')}</span>
        <h1>{content.title}</h1>
        <p className="legal-updated">
          {t('lastUpdated')} {content.updated}
        </p>
        <p className="hero-lead">{content.intro}</p>
      </div>
      <div className="legal-sections">
        {content.sections.map(([title, text]) => (
          <section key={title}>
            <h2>{title}</h2>
            <p>{text}</p>
          </section>
        ))}
      </div>
    </section>
  )
}

export function LegalLinks({ lang, routePath, t }) {
  const links = [
    { type: 'privacidad', es: 'Privacidad', en: 'Privacy' },
    { type: 'terminos', es: 'Términos', en: 'Terms' },
    { type: 'atribuciones', es: 'Atribuciones', en: 'Attributions' },
  ]
  return (
    <nav className="legal-links container" aria-label={t('legalLinks')}>
      {links.map((link) => (
        <a key={link.type} href={routePath(link.type, lang)}>
          {lang === 'en' ? link.en : link.es}
        </a>
      ))}
    </nav>
  )
}

export function SolutionDetails({ content }) {
  return (
    <section className="solution-details section">
      <div className="container">
        <div className="solution-capabilities">
          <div className="section-intro">
            <span className="eyebrow">{content.capabilitiesEyebrow}</span>
            <h2>{content.capabilitiesTitle}</h2>
          </div>
          <div className="capability-grid">
            <SolutionCapability icon={<FileCheck2 />} title={content.controlTitle} text={content.controlCopy} />
            <SolutionCapability icon={<CalendarDays />} title={content.attendanceTitle} text={content.attendanceCopy} />
            <SolutionCapability icon={<Bell />} title={content.noticesTitle} text={content.noticesCopy} />
            <SolutionCapability icon={<BookOpen />} title={content.servicePlanTitle} text={content.servicePlanCopy} />
          </div>
        </div>
        <div className="solution-process">
          <div>
            <span className="eyebrow">{content.processEyebrow}</span>
            <h2>{content.processTitle}</h2>
            <p>{content.processCopy}</p>
          </div>
          <ol>
            {content.processSteps.map((step, index) => (
              <li key={step}>
                <span>0{index + 1}</span>
                <p>{step}</p>
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  )
}

function SolutionCapability({ icon, title, text }) {
  return (
    <article className="solution-capability">
      <div className="solution-capability-icon">{icon}</div>
      <div>
        <h3>{title}</h3>
        <p>{text}</p>
      </div>
    </article>
  )
}

export function ReleasePage({ t, lang }) {
  return (
    <section className="release-section section container release-page">
      <div className="release-list">
        {releaseNotes.map((release) => {
          const note = release[lang] || release.es
          return (
            <article className="release-item" key={release.version}>
              <div className="release-version">
                <strong>
                  {t('latestVersion')} {release.version}
                </strong>
                <span>{release.releasedAt || t('storeDatePending')}</span>
              </div>
              <div>
                {note.newScores?.length > 0 && <ReleaseHighlight icon={<BookOpen />} title={t('newSheetMusic')} items={note.newScores} />}
                {note.newAudio?.length > 0 && (
                  <ReleaseHighlight icon={<Headphones />} title={t('newRehearsalAudio')} items={note.newAudio} />
                )}
                <details className="release-changes">
                  <summary>{t('otherChanges')}</summary>
                  <ul>
                    {note.changes.map((change) => (
                      <li key={change}>{change}</li>
                    ))}
                  </ul>
                </details>
              </div>
            </article>
          )
        })}
      </div>
    </section>
  )
}

function ReleaseHighlight({ icon, title, items }) {
  return (
    <section className="release-highlight">
      <div className="release-highlight-heading">
        <span>{icon}</span>
        <h3>{title}</h3>
        <b>{items.length}</b>
      </div>
      <ul>
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </section>
  )
}
