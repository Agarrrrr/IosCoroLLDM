import { ArrowRight, BriefcaseBusiness, HeartHandshake, MessageCircle } from 'lucide-react'
import { ContactRoute } from './ui.jsx'

export function ContactPage({
  contactEmail,
  contactMessage,
  contactMessageRef,
  contactName,
  contactTopic,
  onChooseTopic,
  onSubmit,
  setContactEmail,
  setContactMessage,
  setContactName,
  t,
}) {
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
        {contactTopic && (
          <div className="contact-form-wrap">
            <p className="contact-next">{t('contactNext')}</p>
            <form onSubmit={onSubmit}>
              <label>
                {t('name')}
                <input
                  value={contactName}
                  onChange={(event) => setContactName(event.target.value)}
                  placeholder={t('namePlaceholder')}
                  autoComplete="name"
                  required
                />
              </label>
              <label>
                {t('email')}
                <input
                  type="email"
                  value={contactEmail}
                  onChange={(event) => setContactEmail(event.target.value)}
                  placeholder={t('emailPlaceholder')}
                  autoComplete="email"
                  required
                />
              </label>
              <label>
                {t('message')}
                <textarea
                  ref={contactMessageRef}
                  value={contactMessage}
                  onChange={(event) => setContactMessage(event.target.value)}
                  placeholder={t('messagePlaceholder')}
                  rows="5"
                  required
                />
              </label>
              <button className="button primary" type="submit">
                {t('send')} <ArrowRight size={16} />
              </button>
            </form>
          </div>
        )}
      </div>
    </section>
  )
}
