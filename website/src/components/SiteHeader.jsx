import { ArrowRight, BookOpen, Menu, MessageCircle, Moon, Music2, Sparkles, Sun, Users, X } from 'lucide-react'
import { MobileQuickNav } from './ui.jsx'

const navigation = [
  ['producto', 'product'],
  ['repertorio', 'catalog'],
  ['novedades', 'updates'],
  ['soluciones', 'solutions'],
  ['roadmap', 'collaborate'],
  ['contacto', 'contact'],
]
const quickNavigation = [
  ['producto', 'product', Music2],
  ['repertorio', 'catalog', BookOpen],
  ['novedades', 'updates', Sparkles],
  ['soluciones', 'solutions', Users],
  ['contacto', 'contact', MessageCircle],
]

export function SiteHeader({
  assetUrl,
  brandName,
  dark,
  goTo,
  lang,
  languageAnimating,
  mobileOpen,
  navToggleRef,
  page,
  routePath,
  t,
  themeAnimating,
  toggleLanguage,
  toggleTheme,
  toggleMobileMenu,
}) {
  const quickLinks = quickNavigation.map(([target, label, Icon]) => ({
    target,
    label: t(label),
    icon: <Icon size={16} />,
    href: routePath(target),
    onClick: goTo(target),
    active: page === target,
  }))
  return (
    <header className="nav-wrap">
      <nav className="nav container">
        <a className="brand" href={routePath('inicio')} onClick={goTo('inicio')}>
          <img src={assetUrl('logo.png')} alt={brandName} width="32" height="32" />
          <span>{brandName}</span>
        </a>
        <div id="primary-navigation" className={mobileOpen ? 'nav-links open' : 'nav-links'}>
          {navigation.map(([target, label]) => (
            <a key={target} href={routePath(target)} onClick={goTo(target)} aria-current={page === target ? 'page' : undefined}>
              {t(label)}
            </a>
          ))}
          <a className="nav-cta" href={routePath('inicio')} onClick={goTo('inicio')}>
            {t('download')} <ArrowRight size={15} />
          </a>
        </div>
        <div className="nav-controls">
          <button
            className={languageAnimating ? 'lang-toggle is-switching' : 'lang-toggle'}
            aria-label={lang === 'en' ? t('switchToSpanish') : t('switchToEnglish')}
            onClick={toggleLanguage}
          >
            <span>{lang === 'es' ? 'ES' : 'EN'}</span>
            <strong>{lang === 'es' ? 'EN' : 'ES'}</strong>
          </button>
          <button
            className={themeAnimating ? 'icon-btn theme-toggle is-switching' : 'icon-btn theme-toggle'}
            aria-label={t('theme')}
            onClick={toggleTheme}
          >
            {dark ? <Sun /> : <Moon />}
          </button>
        </div>
        <button
          className="icon-btn nav-toggle"
          ref={navToggleRef}
          aria-label={t('morePages')}
          aria-expanded={mobileOpen}
          aria-controls="primary-navigation"
          onClick={toggleMobileMenu}
        >
          {mobileOpen ? <X /> : <Menu />}
        </button>
      </nav>
      <MobileQuickNav ariaLabel={t('primaryNavigation')} items={quickLinks} />
    </header>
  )
}
