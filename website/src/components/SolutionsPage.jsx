import { ArrowRight } from 'lucide-react'
import { ServiceCard } from './ui.jsx'
import { SolutionDetails } from '../pages'

export function SolutionsPage({ assetUrl, dark, goTo, lang, routePath, solutionCopy, t }) {
  return (
    <>
      <section className="bc-section">
        <div className="container bc-layout">
          <div className="bc-mark">
            <img
              src={assetUrl(dark ? 'bc-logo-white.png' : 'bc-logo-blue.png')}
              alt="Repertorio BC"
              width="160"
              height="160"
              loading="lazy"
              decoding="async"
            />
          </div>
          <div>
            <span className="eyebrow">{t('customEyebrow')}</span>
            <h1 className="page-title">
              {t('bcStart')}
              <br />
              <em>{t('bcAccent')}</em>
            </h1>
            <p>{t('bcCopy')}</p>
            <div className="bc-stats">
              <div>
                <strong>{t('director')}</strong>
                <span>{t('repertoireControl')}</span>
              </div>
              <div>
                <strong>{t('oneViewer')}</strong>
                <span>{t('accessibleScores')}</span>
              </div>
            </div>
            <a className="button panel-button" href={routePath('contacto')} onClick={goTo('contacto')}>
              {t('designApp')} <ArrowRight size={16} />
            </a>
          </div>
        </div>
      </section>
      <SolutionDetails content={solutionCopy[lang]} />
      <section className="services-section">
        <div className="container services-layout">
          <div>
            <span className="eyebrow">{t('servicesEyebrow')}</span>
            <h2>
              {t('serviceStart')} <em>{t('serviceAccent')}</em>
            </h2>
            <p>{t('serviceCopy')}</p>
            <a className="button primary" href={routePath('contacto')} onClick={goTo('contacto')}>
              {t('tellProject')} <ArrowRight size={16} />
            </a>
          </div>
          <div className="service-cards">
            <ServiceCard number="01" title={t('service1')} text={t('service1c')} />
            <ServiceCard number="02" title={t('service2')} text={t('service2c')} />
            <ServiceCard number="03" title={t('service3')} text={t('service3c')} />
          </div>
        </div>
      </section>
    </>
  )
}
