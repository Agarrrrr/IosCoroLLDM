import { ArrowRight } from 'lucide-react'
import './styles.css'
import { APP_STORE, PLAY_STORE, assetUrl, routePath } from './app-config'
import { faqCopy, solutionCopy } from './content'
import { LegalLinks, LegalPage, ProductPage, ReleasePage, RoadmapPage } from './pages'
import { socialLinks } from './site-config'
import { CatalogPage } from './components/CatalogPage.jsx'
import { ContactPage } from './components/ContactPage.jsx'
import { HomePage } from './components/HomePage.jsx'
import { SiteFooter } from './components/SiteFooter.jsx'
import { SiteHeader } from './components/SiteHeader.jsx'
import { SolutionsPage } from './components/SolutionsPage.jsx'
import { useAppController } from './hooks/useAppController'

function App() {
  const app = useAppController()
  return (
    <div className={`${app.dark ? 'site dark' : 'site'} page-${app.page}`}>
      <a className="skip-link" href="#main-content" onClick={app.focusMain}>
        {app.t('skipToContent')}
      </a>
      <SiteHeader
        assetUrl={assetUrl}
        brandName={app.brandName}
        dark={app.dark}
        goTo={app.goTo}
        lang={app.lang}
        languageAnimating={app.languageAnimating}
        mobileOpen={app.mobileOpen}
        navToggleRef={app.navToggleRef}
        page={app.page}
        routePath={routePath}
        t={app.t}
        themeAnimating={app.themeAnimating}
        toggleLanguage={app.toggleLanguage}
        toggleTheme={app.toggleTheme}
        toggleMobileMenu={() => app.setMobileOpen((isOpen) => !isOpen)}
      />
      <main id="main-content" tabIndex="-1">
        {app.page === 'inicio' && <HomePage brandName={app.brandName} catalogStats={app.catalogStats} lang={app.lang} t={app.t} />}
        {app.page === 'producto' && <ProductPage t={app.t} lang={app.lang} faq={faqCopy} />}
        {app.page === 'novedades' && <ReleasePage t={app.t} lang={app.lang} />}
        {app.page === 'repertorio' && (
          <CatalogPage
            activeDemo={app.activeDemo}
            available={app.available}
            catalogError={app.catalogError}
            catalogLoading={app.catalogLoading}
            displayedSongs={app.displayedSongs}
            filter={app.filter}
            filteredSongs={app.filteredSongs}
            lang={app.lang}
            loadCatalog={app.loadCatalog}
            localizedSongs={app.localizedSongs}
            onChangeDemo={app.changeDemo}
            onLoadMore={() => {
              app.setVisibleCount((count) => count + 12)
              app.announce(app.t('moreScoresNotice'))
            }}
            onQueryChange={app.setQuery}
            onSetFilter={app.setFilter}
            onStopDemo={app.stopDemo}
            onToggleDemo={app.toggleDemo}
            pending={app.pending}
            previewForSong={app.previewForSong}
            query={app.query}
            t={app.t}
            visibleCount={app.visibleCount}
          />
        )}
        {app.page === 'soluciones' && (
          <SolutionsPage
            assetUrl={assetUrl}
            dark={app.dark}
            goTo={app.goTo}
            lang={app.lang}
            routePath={routePath}
            solutionCopy={solutionCopy}
            t={app.t}
          />
        )}
        {app.page === 'roadmap' && <RoadmapPage t={app.t} items={app.roadmapPending} loading={app.roadmapLoading} />}
        {app.page === 'contacto' && (
          <ContactPage
            contactEmail={app.contactEmail}
            contactMessage={app.contactMessage}
            contactMessageRef={app.contactMessageRef}
            contactName={app.contactName}
            contactTopic={app.contactTopic}
            onChooseTopic={app.chooseContactTopic}
            onSubmit={app.submitContact}
            setContactEmail={app.setContactEmail}
            setContactMessage={app.setContactMessage}
            setContactName={app.setContactName}
            t={app.t}
          />
        )}
        {['privacidad', 'terminos', 'atribuciones'].includes(app.page) && <LegalPage type={app.page} lang={app.lang} t={app.t} />}
        {app.page === 'not-found' && (
          <section className="not-found container">
            <span className="eyebrow">404</span>
            <h1>{app.t('notFoundTitle')}</h1>
            <p>{app.t('notFoundCopy')}</p>
            <a className="button primary" href={routePath('inicio')} onClick={app.goTo('inicio')}>
              {app.t('backHome')} <ArrowRight size={16} />
            </a>
          </section>
        )}
      </main>
      <LegalLinks lang={app.lang} routePath={routePath} t={app.t} />
      {app.feedback && (
        <div className="app-feedback" role="status" aria-live="polite">
          {app.feedback}
        </div>
      )}
      <SiteFooter
        appStore={APP_STORE}
        assetUrl={assetUrl}
        brandName={app.brandName}
        goTo={app.goTo}
        lang={app.lang}
        playStore={PLAY_STORE}
        routePath={routePath}
        socialLinks={socialLinks}
        t={app.t}
      />
    </div>
  )
}

export default App
