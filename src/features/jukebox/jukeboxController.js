import { midiEngine } from '../../core/midiEngine.js';
import { jukeboxUI } from './jukeboxUI.js';
import { i18n } from '../../core/i18n.js';
import { localDB } from '../../api/localDB.js';


export const jukeboxController = {
    playlist: [],
    originalPlaylist: [],
    currentIndex: -1,
    isPlaying: false,
    isShuffle: false,
    isRepeat: false,
    originalMetronomeState: false,
    progresoInterval: null,
    _audioCount: 0,
    
    inicializar() {
        jukeboxUI.inicializar();
        
        // Hook al fin de pista del engine
        midiEngine.onTrackEnd = () => {
            if (this.isPlaying) {
                this.nextTrack(true); // Auto-next
            }
        };

        // Escuchar interrupciones del AudioContext (llamadas, Siri, etc.)
        window.addEventListener('audio-context-state', (e) => {
            if (e.detail.state === 'suspended' || e.detail.state === 'interrupted') {
                if (this.isPlaying) {
                    jukeboxUI.mostrarIndicadorReanudar();
                }
            } else if (e.detail.state === 'running') {
                jukeboxUI.ocultarIndicadorReanudar();
            }
        });
    },

    abrirConCatalogo(catalogoEntero) {
        // Filtrar solo los que tengan MIDI
        const cantosConMidi = catalogoEntero.filter(c => c.midi_archivo || c.midi_url);
        
        if (cantosConMidi.length === 0) {
            alert(i18n.t("jukebox.sin_midi"));
            return;
        }

        this.originalPlaylist = [...cantosConMidi];
        this.playlist = [...this.originalPlaylist];
        
        if (this.isShuffle) {
            this.shuffleArray(this.playlist);
        }

        this.currentIndex = 0;
        jukeboxUI.abrir();
        jukeboxUI.renderizarPlaylist(this.playlist, this.currentIndex);
        this.cargarYReproducirActual();
    },

    shuffleArray(array) {
        for (let i = array.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [array[i], array[j]] = [array[j], array[i]];
        }
    },

    toggleShuffle() {
        this.isShuffle = !this.isShuffle;
        if (this.isShuffle) {
            const currentCanto = this.playlist[this.currentIndex];
            this.shuffleArray(this.playlist);
            // Mantener el actual en la posición 0
            const newIndex = this.playlist.findIndex(c => c.id === currentCanto.id);
            if (newIndex > 0) {
                [this.playlist[0], this.playlist[newIndex]] = [this.playlist[newIndex], this.playlist[0]];
            }
            this.currentIndex = 0;
        } else {
            const currentCanto = this.playlist[this.currentIndex];
            this.playlist = [...this.originalPlaylist];
            this.currentIndex = this.playlist.findIndex(c => c.id === currentCanto.id);
        }
        jukeboxUI.renderizarPlaylist(this.playlist, this.currentIndex);
    },

    filtrarLista(texto) {
        texto = texto.toLowerCase().trim();
        const items = document.querySelectorAll('.jukebox-lista-item');
        
        this.playlist.forEach((canto, idx) => {
            const titulo = (canto.titulo || canto.nombre).toLowerCase();
            const temas = (canto.temas && canto.temas.length > 0) ? canto.temas.join(' ').toLowerCase() : '';
            
            const match = titulo.includes(texto) || temas.includes(texto);
            if (items[idx]) {
                items[idx].style.display = match ? 'flex' : 'none';
            }
        });
    },

    playTrackByIndex(index) {
        if (index >= 0 && index < this.playlist.length) {
            this.currentIndex = index;
            jukeboxUI.renderizarPlaylist(this.playlist, this.currentIndex);
            
            // Forzar desbloqueo de audio de forma SÍNCRONA con el click del usuario
            if (midiEngine.desbloquearAudioSync) {
                midiEngine.desbloquearAudioSync().catch(() => {});
            }
            
            this.cargarYReproducirActual();
        }
    },

    toggleRepeat() {
        this.isRepeat = !this.isRepeat;
    },

    async cargarYReproducirActual() {
        if (this.currentIndex < 0 || this.currentIndex >= this.playlist.length) {
            this.stop();
            return;
        }

        const canto = this.playlist[this.currentIndex];
        jukeboxUI.actualizarMetadatos(canto);
        this.actualizarMediaSession(canto);
        
        this.detenerProgreso();
        jukeboxUI.actualizarProgreso(0, '0:00', '-:--');
        
        try {
            await midiEngine.inicializar();
            // Activar modo background: NO silenciar audio al perder visibilidad
            midiEngine._modoBackground = true;
            // Evitar que el metronomo de las partituras suene en la Jukebox
            midiEngine.toggleMetronomo(false);

            // Forzar ensamble completo: la Jukebox siempre reproduce TODAS las voces.
            // Esto evita heredar la selección de voz individual que el usuario pudo haber
            // configurado en el visor de partituras. Los ajustes del visor permanecen
            // intactos en localStorage y se restauran al volver a abrir esa partitura.
            this._resetMixerParaJukebox();
            
            let url = canto.midi_url || canto.midi_archivo;
            url = localDB.resolverUrlMidi(url);

            await midiEngine.cargarCancion(url, null, canto.id);
            // Incrementar contador de audios para Jukebox y lanzar anuncio cada 3 pistas
            this._audioCount++;
            if (this._audioCount > 0 && this._audioCount % 3 === 0) {
                // Esperar a que el usuario cierre el anuncio antes de continuar
                const { adManager } = await import('../../core/adManager.js');
                await adManager.mostrarIntersticial();
            }
            
            // Re-aplicar ensamble tras la carga (o tras cerrar el anuncio)
            this._resetMixerParaJukebox();
            this.resume();
            
        } catch (e) {
            console.error("Error al cargar MIDI en Jukebox:", e);
            // Skip al siguiente si falla
            setTimeout(() => this.nextTrack(true), 1000);
        }
    },

    resume() {
        if (midiEngine.desbloquearAudioSync) {
            midiEngine.desbloquearAudioSync().catch(() => {});
        }
        midiEngine.play();
        this.isPlaying = true;
        jukeboxUI.setPlayingState(true);
        this.iniciarProgreso();
        if (navigator.mediaSession) {
            navigator.mediaSession.playbackState = 'playing';
            const estado = midiEngine.getEstadoParaMediaSession();
            if (estado && isFinite(estado.duration) && estado.duration > 0) {
                try { navigator.mediaSession.setPositionState(estado); } catch(e) {}
            }
        }
    },

    pause() {
        midiEngine.pause();
        this.isPlaying = false;
        jukeboxUI.setPlayingState(false);
        this.detenerProgreso();
        if (navigator.mediaSession) {
            navigator.mediaSession.playbackState = 'paused';
            const estado = midiEngine.getEstadoParaMediaSession();
            if (estado && isFinite(estado.duration) && estado.duration > 0) {
                try { navigator.mediaSession.setPositionState(estado); } catch(e) {}
            }
        }
    },

    stop() {
        midiEngine.stop();
        this.isPlaying = false;
        jukeboxUI.setPlayingState(false);
        this.detenerProgreso();
    },

    nextTrack(auto = false) {
        if (this.playlist.length === 0) return;
        
        this.currentIndex++;
        if (this.currentIndex >= this.playlist.length) {
            if (this.isRepeat || auto) {
                this.currentIndex = 0; // Loop playlist
            } else {
                this.currentIndex = this.playlist.length - 1;
                this.stop();
                jukeboxUI.renderizarPlaylist(this.playlist, this.currentIndex);
                return;
            }
        }
        
        jukeboxUI.renderizarPlaylist(this.playlist, this.currentIndex);
        
        if (auto) {
            // Suavizar transición automática con pausa de 1.5s entre canciones
            setTimeout(() => {
                // Validar que el usuario no pausó en este intermedio
                if (this.isPlaying) this.cargarYReproducirActual();
            }, 1500);
        } else {
            this.cargarYReproducirActual();
        }
    },

    prevTrack() {
        if (this.playlist.length === 0) return;
        
        const prog = midiEngine.getProgreso();
        if (prog > 10) {
            // Si ya pasaron 10% del track, prevTrack solo reinicia la canción
            this.seek(0);
            return;
        }

        this.currentIndex--;
        if (this.currentIndex < 0) {
            this.currentIndex = this.playlist.length - 1;
        }
        
        jukeboxUI.renderizarPlaylist(this.playlist, this.currentIndex);
        this.cargarYReproducirActual();
    },

    seek(percent) {
        if (!midiEngine.midiData) return;
        midiEngine.saltarA(percent);
        
        // Actualizar UI inmediatamente para feedback instantáneo
        const totalTicks = midiEngine.midiData.durationTicks;
        const targetTicks = Math.floor((percent / 100) * totalTicks);
        jukeboxUI.actualizarProgreso(percent, midiEngine.ticksToSeconds(targetTicks).toFixed(0), null);

        // Sincronizar posición con el reproductor del sistema operativo
        if ('mediaSession' in navigator) {
            const estado = midiEngine.getEstadoParaMediaSession();
            if (estado && isFinite(estado.duration) && estado.duration > 0) {
                try { navigator.mediaSession.setPositionState(estado); } catch(e) {}
            }
        }
    },

    iniciarProgreso() {
        this.detenerProgreso();
        this.progresoInterval = setInterval(() => {
            if (!this.isPlaying) return;
            const percent = midiEngine.getProgreso();
            const tiempos = midiEngine.getTiempos();
            
            const formatTime = (secs) => {
                const m = Math.floor(secs / 60);
                const s = Math.floor(secs % 60);
                return `${m}:${s.toString().padStart(2, '0')}`;
            };
            
            jukeboxUI.actualizarProgreso(percent, formatTime(tiempos.actual), formatTime(tiempos.total));
        }, 500);
    },

    detenerProgreso() {
        if (this.progresoInterval) {
            clearInterval(this.progresoInterval);
            this.progresoInterval = null;
        }
    },

    actualizarMediaSession(canto) {
        if (!('mediaSession' in navigator)) return;

        navigator.mediaSession.metadata = new MediaMetadata({
            title: canto.titulo || canto.nombre,
            artist: (canto.temas && canto.temas.length > 0) ? canto.temas.join(', ') : 'Repertorio BC',
            album: 'Catálogo de Coro',
            artwork: [
                { src: '/store_icon.png', sizes: '512x512', type: 'image/png' }
            ]
        });

        navigator.mediaSession.setActionHandler('play', async () => {
            try {
                navigator.mediaSession.playbackState = 'playing';
                this.resume();
            } catch(e) { console.warn('[Jukebox] MediaSession play error:', e); }
        });
        navigator.mediaSession.setActionHandler('pause', () => {
            try {
                navigator.mediaSession.playbackState = 'paused';
                this.pause();
            } catch(e) { console.warn('[Jukebox] MediaSession pause error:', e); }
        });
        navigator.mediaSession.setActionHandler('previoustrack', async () => {
            try {
                navigator.mediaSession.playbackState = 'playing';
                this.prevTrack();
            } catch(e) { console.warn('[Jukebox] MediaSession prev error:', e); }
        });
        navigator.mediaSession.setActionHandler('nexttrack', async () => {
            try {
                navigator.mediaSession.playbackState = 'playing';
                this.nextTrack();
            } catch(e) { console.warn('[Jukebox] MediaSession next error:', e); }
        });

        // seekbackward / seekforward (Android los usa desde la notificación)
        navigator.mediaSession.setActionHandler('seekbackward', (details) => {
            const tiempos = midiEngine.getTiempos();
            const skip = details.seekOffset ?? 10;
            const nuevoPct = Math.max(0, ((tiempos.actual - skip) / tiempos.total) * 100);
            this.seek(nuevoPct);
        });

        navigator.mediaSession.setActionHandler('seekforward', (details) => {
            const tiempos = midiEngine.getTiempos();
            const skip = details.seekOffset ?? 10;
            const nuevoPct = Math.min(100, ((tiempos.actual + skip) / tiempos.total) * 100);
            this.seek(nuevoPct);
        });

        // seekto: iOS 15+ lo necesita para que la barra de progreso sea interactiva
        try {
            navigator.mediaSession.setActionHandler('seekto', (details) => {
                if (details.seekTime != null && midiEngine.getTiempos().total > 0) {
                    const pct = (details.seekTime / midiEngine.getTiempos().total) * 100;
                    this.seek(pct);
                }
            });
        } catch(e) { /* navegadores viejos no soportan seekto */ }
    },

    /**
     * Fuerza MIXER_STATE a ensamble completo (todas las pistas a 1.0).
     * La Jukebox SIEMPRE debe sonar con el ensamble; la selección de voz
     * individual es un ajuste exclusivo del visor de partituras.
     *
     * No modifica localStorage — los ajustes del usuario (voz-preferida)
     * permanecen intactos y se recuperan la próxima vez que abra el visor.
     */
    _resetMixerParaJukebox() {
        if (!window.MIXER_STATE) window.MIXER_STATE = {};

        // Calcular cuántas pistas tiene el archivo actual (o usar 16 como límite seguro)
        const totalTracks = (midiEngine.midiData && midiEngine.midiData.tracks)
            ? midiEngine.midiData.tracks.length
            : 16;

        for (let i = 0; i < totalTracks; i++) {
            window.MIXER_STATE[i] = 1.0;
        }
    },

    cerrar() {
        // Desactivar modo background: volver al comportamiento normal (silenciar al salir)
        midiEngine._modoBackground = false;
        this.isPlaying = false;
        this.detenerProgreso();
        midiEngine.pause(); // pause() ya llama a _liberarWakeLock() internamente
        // Restaurar metrónomo tal y como el usuario lo tenía en su visor
        midiEngine.toggleMetronomo(this.originalMetronomeState);
        
        if ('mediaSession' in navigator) {
            navigator.mediaSession.metadata = null;
            navigator.mediaSession.playbackState = 'none';
        }
        
        // Lanzar anuncio al salir del Jukebox
        import('../../core/adManager.js').then(({ adManager }) => {
            adManager.mostrarIntersticial();
        }).catch(err => console.error(err));
    }
};
