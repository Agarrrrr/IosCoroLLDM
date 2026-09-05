import { SocialGlyph } from './ui.jsx'

const footerNavigation = [
  ['repertorio', 'catalog'],
  ['soluciones', 'solutions'],
  ['roadmap', 'collaborate'],
  ['contacto', 'contact'],
]

export function SiteFooter({ appStore, assetUrl, brandName, goTo, lang, playStore, routePath, socialLinks, t }) {
  return (
    <footer className="footer">
      <div className="container footer-top">
        <a className="brand" href={routePath('inicio')} onClick={goTo('inicio')}>
          <img src={assetUrl('logo.png')} alt="" width="32" height="32" />
          <span>{brandName}</span>
        </a>
        <div className="footer-links">
          {footerNavigation.map(([target, label]) => (
            <a key={target} href={routePath(target)} onClick={goTo(target)}>
              {t(label)}
            </a>
          ))}
        </div>
        <div className="store-links">
          <a href={playStore} target="_blank" rel="noreferrer">
            Google Play
          </a>
          <a href={appStore} target="_blank" rel="noreferrer">
            App Store
          </a>
        </div>
        <div className="social-links" aria-label={t('socialMedia')}>
          {socialLinks.map((social) =>
            social.href ? (
              <a key={social.id} href={social.href} target="_blank" rel="noreferrer" aria-label={social.label}>
                <SocialGlyph id={social.id} />
              </a>
            ) : (
              <span
                key={social.id}
                className="social-link planned"
                title={t('socialLinkPending').replace('{name}', social.label)}
                aria-label={t('socialLinkPending').replace('{name}', social.label)}
              >
                <SocialGlyph id={social.id} />
              </span>
            ),
          )}
        </div>
      </div>
      <div className="container footer-bottom">
        <span>© 2026 {brandName}</span>
        <span>{t('footerPurpose')}</span>
        <span className="developer">
          {t('developedBy')} <strong>Huri Tolentino</strong>
        </span>
      </div>
    </footer>
  )
}
