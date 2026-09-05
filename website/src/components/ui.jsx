import { ArrowRight, Check, ChevronDown, Music2 } from 'lucide-react'

export function Metric({ value, label }) {
  return (
    <div className="metric">
      <strong>{value}</strong>
      <span>{label}</span>
    </div>
  )
}
export function SectionIntro({ eyebrow, title, text }) {
  return (
    <div className="section-intro">
      <span className="eyebrow">{eyebrow}</span>
      <h2>{title}</h2>
      <p>{text}</p>
    </div>
  )
}
export function Feature({ icon, number, title, text }) {
  return (
    <article className="feature">
      <div className="feature-icon">{icon}</div>
      <span className="feature-number">{number}</span>
      <h3>{title}</h3>
      <p>{text}</p>
    </article>
  )
}
export function Capability({ icon, title, text }) {
  return (
    <article className="capability">
      <div className="feature-icon">{icon}</div>
      <div>
        <h3>{title}</h3>
        <p>{text}</p>
      </div>
    </article>
  )
}
export function ServiceCard({ number, title, text }) {
  return (
    <article className="service-card">
      <span>{number}</span>
      <div>
        <h3>{title}</h3>
        <p>{text}</p>
      </div>
      <ArrowRight size={17} />
    </article>
  )
}
export function UseCase({ title, text, icon }) {
  return (
    <article className="use-case">
      <div className="feature-icon">{icon}</div>
      <h3>{title}</h3>
      <p>{text}</p>
    </article>
  )
}
export function CollabItem({ title, text }) {
  return (
    <div className="collab-item">
      <span className="collab-check">
        <Check size={15} />
      </span>
      <div>
        <strong>{title}</strong>
        <p>{text}</p>
      </div>
      <ChevronDown size={16} />
    </div>
  )
}
export function ContactRoute({ active, icon, title, text, onClick }) {
  return (
    <button type="button" className={active ? 'contact-route active' : 'contact-route'} onClick={onClick}>
      <span>{icon}</span>
      <div>
        <strong>{title}</strong>
        <small>{text}</small>
      </div>
      <ArrowRight size={15} />
    </button>
  )
}
export function DemoRow({ title, audio }) {
  return (
    <div className="demo-row">
      <b>
        {title} {audio && <Music2 size={16} />}
      </b>
      <small>♡</small>
    </div>
  )
}

export function MobileQuickNav({ ariaLabel, items }) {
  return (
    <nav className="mobile-primary-nav container" aria-label={ariaLabel}>
      {items.map(({ active, href, icon, label, onClick }) => (
        <a
          key={href}
          className={active ? 'mobile-nav-link active' : 'mobile-nav-link'}
          href={href}
          onClick={onClick}
          aria-current={active ? 'page' : undefined}
        >
          {icon}
          <span>{label}</span>
        </a>
      ))}
    </nav>
  )
}

export function SocialGlyph({ id }) {
  const common = { className: `social-glyph social-${id}`, viewBox: '0 0 24 24', fill: 'currentColor', 'aria-hidden': 'true' }
  if (id === 'facebook')
    return (
      <svg {...common}>
        <path d="M14 8h3V4h-3c-2.8 0-5 2.2-5 5v3H6v4h3v4h4v-4h3l1-4h-4V9c0-.6.4-1 1-1Z" />
      </svg>
    )
  if (id === 'instagram')
    return (
      <svg {...common}>
        <rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="currentColor" strokeWidth="2" />
        <circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" strokeWidth="2" />
        <circle cx="17.5" cy="6.5" r="1.2" />
      </svg>
    )
  if (id === 'youtube')
    return (
      <svg {...common}>
        <path d="M21.6 7.2a2.8 2.8 0 0 0-2-2C17.8 4.7 12 4.7 12 4.7s-5.8 0-7.6.5a2.8 2.8 0 0 0-2 2A29 29 0 0 0 2 12a29 29 0 0 0 .4 4.8 2.8 2.8 0 0 0 2 2c1.8.5 7.6.5 7.6.5s5.8 0 7.6-.5a2.8 2.8 0 0 0 2-2A29 29 0 0 0 22 12a29 29 0 0 0-.4-4.8Z" />
        <path d="m10 15.5 5-3.5-5-3.5v7Z" fill="var(--brand)" />
      </svg>
    )
  return (
    <svg {...common}>
      <path d="M14.5 4v10.2a3.8 3.8 0 1 1-3-3.7v3.2a1.5 1.5 0 1 0 1.7 1.5V4h3.1c.3 1.7 1.3 2.8 2.7 3.4v3a7 7 0 0 1-2.7-1.2v5.3a4.8 4.8 0 1 1-4.8-4.8V4h3Z" />
    </svg>
  )
}

export function AppleLogo() {
  return (
    <svg className="store-logo" viewBox="0 0 24 24" aria-hidden="true">
      <path
        fill="currentColor"
        d="M17.1 12.7c0-2.1 1.7-3.1 1.8-3.2-1-1.5-2.6-1.7-3.2-1.7-1.4-.1-2.7.8-3.4.8-.7 0-1.8-.8-3-.8-1.5 0-2.9.9-3.7 2.3-1.6 2.8-.4 7 1.1 9.3.8 1.1 1.6 2.4 2.8 2.3 1.1 0 1.6-.7 3-.7s1.8.7 3 .7c1.2 0 2-1.1 2.7-2.3.9-1.3 1.2-2.6 1.2-2.7-.1 0-2.3-.9-2.3-4zm-2.2-6.3c.6-.8 1-1.9.9-3-.9 0-2.1.6-2.8 1.4-.6.7-1.1 1.8-1 2.9 1 .1 2.1-.5 2.9-1.3z"
      />
    </svg>
  )
}
export function GooglePlayLogo() {
  return (
    <svg className="store-logo google-logo" viewBox="0 0 24 24" aria-hidden="true">
      <path fill="#00a0ff" d="M3.61 1.81c-.3.3-.48.74-.48 1.27v17.84c0 .53.18.97.48 1.27l.08.07 9.99-9.99v-.23L3.69 1.75l-.08.06z" />
      <path fill="#ff3a44" d="m17.03 8.76-3.36 3.36v.23l3.36 3.36.07-.04 3.9-2.21c1.11-.63 1.11-1.67 0-2.3l-3.9-2.21-.07-.04z" />
      <path fill="#ffe000" d="m17.03 15.28-3.36-3.36-9.99 9.99c.3.31.76.36 1.33.04l12.02-6.67z" />
      <path fill="#00d6a3" d="M17.03 8.76 5.02 2.09c-.57-.32-1.03-.27-1.33.04l9.98 9.99 3.36-3.36z" />
    </svg>
  )
}
