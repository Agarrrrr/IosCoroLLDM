import { ArrowRight, BookOpen, Headphones, Music2, Play, Search, Sparkles, Users, WifiOff } from 'lucide-react'
import { APP_STORE, PLAY_STORE } from '../app-config'
import { INTERACTIVE_DEMO_URL } from '../site-data'
import { demoPreviewRows, phonePreviewRows } from '../content/mockup'
import { AppleLogo, DemoRow, Feature, GooglePlayLogo, Metric, SectionIntro } from './ui.jsx'

export function HomePage({ brandName, catalogStats, lang, t }) {
  const locale = lang === 'es' ? 'es-MX' : 'en-US'
  return (
    <>
      <section className="hero container" id="inicio">
        <div className="hero-copy">
          <span className="eyebrow">
            <span className="eyebrow-dot" /> {t('heroEyebrow')}
          </span>
          <h1>
            {t('heroStart')} <em>{t('heroAccent')}</em>
          </h1>
          <p className="hero-lead">{t('heroLead')}</p>
          <div className="hero-actions">
            <div className="download-group" id="descargas">
              <span>{t('available')}</span>
              <div>
                <a className="button store-button apple-button" href={APP_STORE} target="_blank" rel="noreferrer">
                  <AppleLogo /> App Store <ArrowRight size={15} />
                </a>
                <a className="button store-button google-button" href={PLAY_STORE} target="_blank" rel="noreferrer">
                  <GooglePlayLogo /> Google Play <ArrowRight size={15} />
                </a>
              </div>
            </div>
            <a className="button text-action" href="#demo">
              <Play size={16} fill="currentColor" /> {t('explore')}
            </a>
          </div>
        </div>
        <div className="hero-visual" aria-label={t('appPreviewLabel')}>
          <div className="glow" />
          <div className="phone-card">
            <div className="phone-top">
              <span>9:41</span>
              <span>● ● ▰</span>
            </div>
            <div className="phone-title">
              <span>{t('phoneTitle')}</span>
              <Music2 size={19} />
            </div>
            <div className="phone-search">
              <Search size={15} /> {t('phoneSearch')}
            </div>
            {phonePreviewRows.map((song) => (
              <div className="phone-song" key={song.title}>
                <span className="song-accent" />
                <div>
                  <strong>{song.title}</strong>
                  <small>{song.category}</small>
                </div>
                <span className="music-mark">{song.marker}</span>
              </div>
            ))}
            <div className="phone-bottom">
              <span>⌂</span>
              <span className="active">♫</span>
              <span>⚙</span>
            </div>
          </div>
          <div className="floating-badge badge-a">
            <Headphones size={15} /> {t('voiceAudio')}
          </div>
          <div className="floating-badge badge-b">
            <WifiOff size={15} /> {t('offline')}
          </div>
        </div>
      </section>
      <section className="metrics container">
        <Metric value={catalogStats ? catalogStats[lang].total.toLocaleString(locale) : '—'} label={t('sheetMusic')} />
        <Metric value={t('languageValue')} label={t('languages')} />
        <Metric value={catalogStats ? catalogStats[lang].withPreview.toLocaleString(locale) : '—'} label={t('audioAvailable')} />
        <Metric value={t('offlineValue')} label={t('ready')} />
      </section>
      <section className="section container" id="funciones">
        <SectionIntro eyebrow={t('featureEyebrow')} title={t('featureTitle')} text={t('featureCopy')} />
        <div className="feature-grid">
          <Feature icon={<BookOpen />} number="01" title={t('f1')} text={t('f1c')} />
          <Feature icon={<Headphones />} number="02" title={t('f2')} text={t('f2c')} />
          <Feature icon={<WifiOff />} number="03" title={t('f3')} text={t('f3c')} />
          <Feature icon={<Users />} number="04" title={t('f4')} text={t('f4c')} />
        </div>
      </section>
      <section className="demo-band" id="demo">
        <div className="container demo-layout">
          <div>
            <span className="eyebrow light">
              <Sparkles size={14} /> {t('demoEyebrow')}
            </span>
            <h2>
              {t('demoStart')}
              <br />
              <em>{t('demoAccent')}</em>
            </h2>
            <p>{t('demoCopy')}</p>
            <a className="button light-button" href={INTERACTIVE_DEMO_URL} target="_blank" rel="noreferrer">
              {t('tryDemo')} <ArrowRight size={16} />
            </a>
          </div>
          <div className="demo-window">
            <div className="window-bar">
              <span />
              <span />
              <span />
              <small>coro-lldm.app</small>
            </div>
            <div className="demo-content">
              <div className="demo-input">
                <Search size={15} /> {t('searchRepertoire')}
              </div>
              <div className="demo-list">
                <div className="skeleton demo-skeleton" />
                {demoPreviewRows.map((title, index) => (
                  <DemoRow key={title} title={title} audio={index > 0} />
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>
    </>
  )
}
