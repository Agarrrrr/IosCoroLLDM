import { ArrowRight, BriefcaseBusiness, HeartHandshake, Mail, MessageCircle } from 'lucide-react'
import { ContactRoute } from './ui.jsx'

export function ContactPage({ contactTopic, onChooseTopic, t }) {
  const subject = contactTopic ? t(`contactSubject${contactTopic[0].toUpperCase()}${contactTopic.slice(1)}`) : t('contactSubject')
  const href = `mailto:contacto@lldmcoro.com?subject=${encodeURIComponent(subject)}`
  return (
    <section className="contact-section container" id="contacto">
      <div className={contactTopic ? 'contact-card has-topic' : 'contact-card choosing-topic'}>
        <div className="contact-intro">
          <span className="eyebrow">{t('contactEyebrow')}</span>
          <h1 className="page-title">
            {t('contactStart')}
            <br />
            <em>{t('contactAccent')}</em>
          </h1>
          <p>{t('contactCopy')}</p>
          <div className="contact-routes">
            <span>{t('contactRoutes')}</span>
            <ContactRoute
              active={contactTopic === 'project'}
              icon={<BriefcaseBusiness size={17} />}
              title={t('projectRoute')}
              text={t('projectRouteCopy')}
              onClick={() => onChooseTopic('project')}
            />
            <ContactRoute
              active={contactTopic === 'collab'}
              icon={<HeartHandshake size={17} />}
              title={t('collabRoute')}
              text={t('collabRouteCopy')}
              onClick={() => onChooseTopic('collab')}
            />
            <ContactRoute
              active={contactTopic === 'support'}
              icon={<MessageCircle size={17} />}
              title={t('supportRoute')}
              text={t('supportRouteCopy')}
              onClick={() => onChooseTopic('support')}
            />
          </div>
          {!contactTopic && <p className="contact-choose">{t('contactChoose')}</p>}
        </div>
        <div className="contact-direct">
          <Mail size={19} aria-hidden="true" />
          <p>{t('contactDirect')}</p>
          <a href="mailto:contacto@lldmcoro.com">contacto@lldmcoro.com</a>
          <a className="button primary" href={href}>
            {t('contactEmailAction')} <ArrowRight size={16} />
          </a>
        </div>
      </div>
    </section>
  )
}
