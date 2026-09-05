import { ArrowRight, Clock3, FastForward, Headphones, Rewind, Search, X } from 'lucide-react'
import { formatDemoTime } from '../app-config'

export function CatalogPage({
  activeDemo,
  available,
  catalogError,
  catalogLoading,
  displayedSongs,
  filter,
  filteredSongs,
  lang,
  loadCatalog,
  localizedSongs,
  onChangeDemo,
  onLoadMore,
  onQueryChange,
  onSetFilter,
  onStopDemo,
  onToggleDemo,
  pending,
  previewForSong,
  query,
  t,
  visibleCount,
}) {
  return (
    <section className="section catalog-section container" id="catalogo">
      <div className="section-intro">
        <span className="eyebrow">{t('catalogEyebrow')}</span>
        <h1 className="page-title">{t('catalogTitle')}</h1>
        <p>{t('catalogCopy')}</p>
      </div>
      <div className="catalog-toolbar">
        <label className="catalog-search">
          <Search size={18} aria-hidden="true" />
          <span className="sr-only">{t('searchTitle')}</span>
          <input value={query} onChange={(event) => onQueryChange(event.target.value)} placeholder={t('searchTitle')} />
        </label>
        <div className="filter-tabs" aria-label={t('catalogFilters')}>
          <FilterButton active={filter === 'todos'} count={localizedSongs.length} label={t('all')} onClick={() => onSetFilter('todos')} />
          <FilterButton active={filter === 'audio'} count={available.length} label={t('withAudio')} onClick={() => onSetFilter('audio')} />
          <FilterButton
            active={filter === 'pendientes'}
            count={pending.length}
            label={t('pending')}
            onClick={() => onSetFilter('pendientes')}
          />
        </div>
      </div>
      {catalogError && !catalogLoading && !localizedSongs.length ? (
        <div className="catalog-empty" role="alert">
          <p>{t('catalogError')}</p>
          <button className="text-button" type="button" onClick={loadCatalog}>
            {t('retryCatalog')} <ArrowRight size={16} />
          </button>
        </div>
      ) : (
        <div className="song-grid">
          {catalogLoading || !localizedSongs.length ? (
            <CatalogSkeletons />
          ) : (
            displayedSongs.map((song) => (
              <SongCard
                activeDemo={activeDemo}
                key={`${song.id}-${song.idioma}`}
                lang={lang}
                onToggleDemo={onToggleDemo}
                preview={previewForSong(song)}
                song={song}
                t={t}
              />
            ))
          )}
        </div>
      )}
      {activeDemo && <DemoToast activeDemo={activeDemo} onChangeDemo={onChangeDemo} onStopDemo={onStopDemo} t={t} />}
      {visibleCount < filteredSongs.length && (
        <button className="text-button" type="button" onClick={onLoadMore}>
          {t('showMore')} <ArrowRight size={16} />
        </button>
      )}
    </section>
  )
}

function FilterButton({ active, count, label, onClick }) {
  return (
    <button className={active ? 'selected' : ''} type="button" onClick={onClick}>
      {label} <span>{count || '—'}</span>
    </button>
  )
}

function CatalogSkeletons() {
  return Array.from({ length: 6 }, (_, index) => (
    <div className="song-card loading-card" key={index}>
      <div className="skeleton line-lg" />
      <div className="skeleton line-sm" />
    </div>
  ))
}

function SongCard({ activeDemo, lang, onToggleDemo, preview, song, t }) {
  const notice = song.midi_archivo ? t('audioUnavailableNotice') : t('audioPendingNotice')
  return (
    <button
      type="button"
      className={preview ? `song-card has-audio${activeDemo?.id === song.id ? ' is-playing' : ''}` : 'song-card is-pending'}
      aria-label={preview ? song.nombre : `${song.nombre}. ${notice}`}
      onClick={() => onToggleDemo(song)}
    >
      <div className="song-card-title">
        <span className="song-dot" />
        <h3>{song.nombre}</h3>
        <span className="song-state" aria-label={preview ? t('audioReady') : t('comingSoon')}>
          {preview ? <Headphones size={15} /> : <Clock3 size={15} />}
        </span>
      </div>
      <div className="song-meta">
        <span>{song.idioma === 'en' ? t('languageEnglish') : t('languageSpanish')}</span>
        <span className="song-status">{preview ? t('audioReady') : t('comingSoon')}</span>
      </div>
    </button>
  )
}

function DemoToast({ activeDemo, onChangeDemo, onStopDemo, t }) {
  const percent = ((activeDemo.progress || 0) / (activeDemo.duration || 1)) * 100
  return (
    <div className="ensemble-demo" role="status" aria-live="polite">
      <span className={activeDemo.loading ? 'demo-wave loading' : 'demo-wave'} aria-hidden="true">
        <i />
        <i />
        <i />
        <i />
      </span>
      <div className="demo-toast-copy">
        <strong>{activeDemo.title}</strong>
        <span>{activeDemo.loading ? t('loadingDemo') : t('playingDemo')}</span>
        <div
          className="demo-progress"
          role="progressbar"
          aria-label={t('playbackProgress')}
          aria-valuemin="0"
          aria-valuemax={activeDemo.duration || 1}
          aria-valuenow={activeDemo.progress || 0}
        >
          <i style={{ width: `${percent}%` }} />
        </div>
        <small>
          {formatDemoTime(activeDemo.progress)} / {formatDemoTime(activeDemo.duration)}
        </small>
      </div>
      <div className="demo-controls">
        <button type="button" onClick={() => onChangeDemo(-1)} aria-label={t('previousDemo')} disabled={activeDemo.loading}>
          <Rewind size={16} aria-hidden="true" />
        </button>
        <button type="button" onClick={() => onChangeDemo(1)} aria-label={t('nextDemo')} disabled={activeDemo.loading}>
          <FastForward size={16} aria-hidden="true" />
        </button>
        <button type="button" onClick={onStopDemo} aria-label={t('stopDemo')}>
          <X size={16} aria-hidden="true" />
        </button>
      </div>
    </div>
  )
}
