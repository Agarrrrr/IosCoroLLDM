/**
 * MIDI ENGINE - v4.0.0 (Hardware Scheduling API)
 * Refactorización total a @tonejs/midi + Tone.Transport para erradicación de latencia.
 */
import { limitsManager } from './limitsManager.js';
import { decryptFileFromUrl } from './decryptor.js';
import { i18n } from './i18n.js';

// Importación dinámica (Lazy Loading) de @tonejs/midi en la función cargarCancion()
// para evitar bloquear la carga inicial del sitio y simplificar arquitectura (0-overhead)
// Lazy Loading: Se cargarán dinámicamente para evitar el Autoplay Policy Warning
let Tone = null;

let pianoInstrument = null;
let masterGainNode = null;
let masterVolumeNode = null;
let metroHi = null;  // Player: woodblock tiempo fuerte
let metroLo = null;  // Player: woodblock tiempos débiles
let metronomoPart = null;

let _nativeAudioPlugin = null;
function getNativeAudioPlugin() {
    return null; // Audios nativos desactivados
}

export const midiEngine = {
    cargando: false,
    instrumentoCargado: false,
    volumenMaestro: 1.0,
    baseTempo: 120,
    initPromise: null,
    speed: 1.0, 
    _isJumping: false,
    _loadSessionId: 0,
    _loadingUrl: null,
    _silentAudio: null, 
    _pendingPlay: false, 
    metronomoActivo: false,
    _tempoEventId: [],
    currentBuffer: null,
    midiData: null,
    parts: [],
    _visibilityListenerRegistered: false,
    _burstCount: 0,
    _lastBurstTime: 0,
    _modoBackground: false, // true cuando la Jukebox está activa (no silenciar al perder visibilidad)
    onTrackEnd: null, // Callback inyectado por el reproductor (Jukebox)
    repetirTrack: false, // Estado de repetición del track actual
    
    // --- LRU CACHE (MAX 5 CANCIONES) ---
    _lruCacheMidi: new Map(), // key: url, value: parsedMidiJSON

    /**
     * Inicialización Singleton con importaciones dinámicas.
     */
    async inicializar() {
        if (this.instrumentoCargado) return;
        
        if (this.initPromise) {
            await this.initPromise;
            return;
        }

        this.cargando = true;
        this.initPromise = (async () => {
            const currentSession = this._loadSessionId;
            try {
                if (!Tone) {
                    const m = await import('tone');
                    Tone = m.default || m;
                }

                // Si estamos corriendo en la App Nativa de iOS (Capacitor), usar el motor de audio Swift Nativo
                const nativeAudio = getNativeAudioPlugin();
                if (nativeAudio) {
                    try {
                        await nativeAudio.initEngine();
                        console.log("🎹 [MIDI] NativeAudio engine nativo en Swift inicializado con éxito.");
                    } catch(nativeErr) {
                        console.warn("⚠️ [MIDI] Error inicializando NativeAudio nativo:", nativeErr);
                    }
                    this.instrumentoCargado = true;
                    this.cargando = false;
                    return;
                }

                if (!masterVolumeNode) masterVolumeNode = new Tone.Volume(0).toDestination();

                // Válvula de ganancia conectada directamente al volumen maestro
                if (!masterGainNode) masterGainNode = new Tone.Gain(1).connect(masterVolumeNode);

                // Override supportsType for blob URLs in Tone.js to bypass extension check for Players
                const overrideSupports = (TargetClass) => {
                    if (TargetClass && typeof TargetClass.supportsType === 'function') {
                        const originalSupport = TargetClass.supportsType;
                        TargetClass.supportsType = function(url) {
                            if (typeof url === 'string' && url.startsWith('blob:')) {
                                return true;
                            }
                            return originalSupport.call(TargetClass, url);
                        };
                    }
                };
                overrideSupports(Tone.ToneAudioBuffer);
                overrideSupports(Tone.Buffer);

                // Helper para cargar y decodificar audio usando OfflineAudioContext.
                // OfflineAudioContext ignora el estado "suspended" de la API WebAudio en iOS,
                // permitiendo decodificar los buffers en segundo plano sin requerir gesto previo del usuario.
                const loadAndDecodeToneBuffer = async (url) => {
                    const response = await fetch(url);
                    if (!response.ok) throw new Error(`HTTP ${response.status} en ${url}`);
                    const arrayBuffer = await response.arrayBuffer();
                    const OfflineCtxClass = window.OfflineAudioContext || window.webkitOfflineAudioContext;
                    const offlineCtx = new OfflineCtxClass(1, 1, 44100);
                    const nativeBuffer = await offlineCtx.decodeAudioData(arrayBuffer);
                    return new Tone.ToneAudioBuffer(nativeBuffer);
                };

                // Metrónomo de madera — Tone.Player con samples reales
                try {
                    if (!metroHi) {
                        const buffer = await loadAndDecodeToneBuffer('audio/metro/wood-hi.mp3');
                        metroHi = new Tone.Player(buffer).connect(masterVolumeNode);
                        metroHi.volume.value = -6;
                    }
                    if (!metroLo) {
                        const buffer = await loadAndDecodeToneBuffer('audio/metro/wood-lo.mp3');
                        metroLo = new Tone.Player(buffer).connect(masterVolumeNode);
                        metroLo.volume.value = -8;
                    }
                } catch (metroErr) {
                    console.warn("⚠️ [MIDI] Error cargando metrónomo:", metroErr);
                }

                if (!pianoInstrument) {
                    const sampleFiles = {
                        "A0": "A0.mp3", "C1": "C1.mp3", "D#1": "Ds1.mp3", "F#1": "Fs1.mp3",
                        "A1": "A1.mp3", "C2": "C2.mp3", "D#2": "Ds2.mp3", "F#2": "Fs2.mp3",
                        "A2": "A2.mp3", "C3": "C3.mp3", "D#3": "Ds3.mp3", "F#3": "Fs3.mp3",
                        "A3": "A3.mp3", "C4": "C4.mp3", "D#4": "Ds4.mp3", "F#4": "Fs4.mp3",
                        "A4": "A4.mp3", "C5": "C5.mp3", "D#5": "Ds5.mp3", "F#5": "Fs5.mp3",
                        "A5": "A5.mp3", "C6": "C6.mp3", "D#6": "Ds6.mp3", "F#6": "Fs6.mp3",
                        "A6": "A6.mp3", "C7": "C7.mp3", "D#7": "Ds7.mp3", "F#7": "Fs7.mp3", "C8": "C8.mp3"
                    };

                    const decodedBuffers = {};
                    console.log("🎹 [MIDI] Decodificando muestras manualmente en ToneAudioBuffers...");
                    
                    for (const note of Object.keys(sampleFiles)) {
                        const fileName = sampleFiles[note];
                        try {
                            decodedBuffers[note] = await loadAndDecodeToneBuffer(`audio/piano/${fileName}`);
                        } catch (err) {
                            console.error(`❌ [MIDI] Error cargando muestra ${note}:`, err);
                        }
                    }

                    pianoInstrument = new Tone.Sampler({
                        urls: decodedBuffers,
                        attack: 0,
                        release: 0.6,
                        maxPolyphony: 64,
                        onload: () => {
                            try {
                                const ctx = Tone.context.rawContext || Tone.context._context;
                                if (ctx && ctx.state === 'running') {
                                    const now = Tone.now();
                                    const g = 0.0001; 
                                    pianoInstrument.triggerAttack("C3", now, g);
                                    pianoInstrument.triggerAttack("C5", now, g);
                                    pianoInstrument.triggerRelease("C3", now + 0.005);
                                    pianoInstrument.triggerRelease("C5", now + 0.005);
                                    console.log("🔥 [MIDI] Warm-up silencioso completado.");
                                } else {
                                    console.log("⏳ [MIDI] Warm-up pospuesto hasta la interacción del usuario.");
                                }
                            } catch(e) {
                                console.warn("⚠️ [MIDI] Warm-up omitido:", e.message);
                            }
                        }
                    });
                    pianoInstrument.connect(masterGainNode);
                }

                console.log("🎹 [MIDI] Cargando Sampler Local...");
                const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error("Timeout cargando Sampler MIDI (15s)")), 15000));
                await Promise.race([Tone.loaded(), timeoutPromise]);
                this.instrumentoCargado = true;
                console.log("🎹 [MIDI] Sampler listo.");

                if (!this._visibilityListenerRegistered) {
                    this._visibilityListenerRegistered = true;
                    document.addEventListener('visibilitychange', () => {
                        this.manejarCambioVisibilidad(document.visibilityState === 'visible');
                    });

                    // Detectar interrupciones del OS (llamadas, Siri, etc.)
                    const rawCtx = Tone.context.rawContext || Tone.context._context;
                    if (rawCtx) {
                        rawCtx.onstatechange = () => {
                            console.log(`🔊 [MIDI] AudioContext state → ${rawCtx.state}`);
                            window.dispatchEvent(new CustomEvent('audio-context-state', {
                                detail: { state: rawCtx.state }
                            }));
                        };
                    }
                }
            } catch (err) {
                console.error("❌ [MIDI] Error inicializando audio:", err);
                if (window.uiController && this._loadSessionId === currentSession) {
                    window.uiController.mostrarToast("Init err: " + (err.message || err).substring(0, 50), "error");
                }
                this.initPromise = null;
                throw err;
            } finally {
                this.cargando = false;
            }
        })();

        await this.initPromise;
    },

    destruirSesion() {
        this._loadSessionId++;
        this._loadingUrl = null;

        if (masterGainNode && Tone) {
            try {
                const now = Tone.now();
                masterGainNode.gain.cancelScheduledValues(now);
                masterGainNode.gain.setTargetAtTime(0, now, 0.015);
            } catch (e) {}
        }

        this.liberarNotas();
        // Arquitectura 3: destruir el Wake Lock completamente
        this._liberarWakeLock();
        this.midiData = null;
        
        if ('mediaSession' in navigator) {
            navigator.mediaSession.metadata = null;
            navigator.mediaSession.playbackState = 'none';
        }
    },

    getTracksConNotas() {
        if (!this.midiData || !this.midiData.tracks) return [];
        const tracksValidos = [];
        this.midiData.tracks.forEach((track, index) => {
            // Ignorar pistas de percusión explícitamente
            if (track.instrument.percussion) return;
            if (track.notes.length > 0) {
                let nombre = track.name;
                
                // Propagación de nombres: si el track actual no tiene nombre o es genérico,
                // buscamos hacia atrás el nombre del track/staff que no tiene notas (ej. exportaciones de MuseScore)
                if (!nombre || nombre.toLowerCase().startsWith('pista') || nombre.toLowerCase().startsWith('track')) {
                    for (let j = index - 1; j >= 0; j--) {
                        const prevTrack = this.midiData.tracks[j];
                        if (prevTrack && prevTrack.notes.length === 0 && prevTrack.name && !prevTrack.name.toLowerCase().startsWith('pista') && !prevTrack.name.toLowerCase().startsWith('track')) {
                            nombre = prevTrack.name;
                            break;
                        }
                        // Detener si encontramos otro track con notas para evitar propagación cruzada incorrecta
                        if (prevTrack && prevTrack.notes.length > 0) {
                            break;
                        }
                    }
                }
                
                tracksValidos.push({ index, nombre: nombre || `Pista ${index + 1}` });
            }
        });

        // Heurística de voces avanzada
        // 1. Abreviaturas, formateo y normalización (soporta español e inglés con números arábigos o romanos)
        tracksValidos.forEach(track => {
            const n = track.nombre || "";
            if (/\b(soprano\s*(2|ii\b)|s2\b)/i.test(n)) track.nombre = 'S2';
            else if (/\b(soprano\s*(1|i\b)|s1\b)/i.test(n)) track.nombre = 'S1';
            else if (/\b(alto\s*(2|ii\b)|contralto\s*(2|ii\b)|a2\b)/i.test(n)) track.nombre = 'A2';
            else if (/\b(alto\s*(1|i\b)|contralto\s*(1|i\b)|a1\b)/i.test(n)) track.nombre = 'A1';
            else if (/\b(tenor\s*(2|ii\b)|t2\b)/i.test(n)) track.nombre = 'T2';
            else if (/\b(tenor\s*(1|i\b)|t1\b)/i.test(n)) track.nombre = 'T1';
            else if (/\b(bajo\s*(2|ii\b)|bass\s*(2|ii\b)|b2\b)/i.test(n)) track.nombre = 'B2';
            else if (/\b(bajo\s*(1|i\b)|bass\s*(1|i\b)|b1\b)/i.test(n)) track.nombre = 'B1';
            else if (/baritono|barítono/i.test(n)) track.nombre = 'Barítono';
        });

        // 1.5. Inferir Soprano o Solista si hay exactamente un track sin clasificar/vacío
        const emptyTracks = tracksValidos.filter(t => {
            const n = (t.nombre || "").toLowerCase();
            return n === '' || n.startsWith('pista') || n.startsWith('track') || n.includes('piano') || n.includes('instrument');
        });
        
        if (emptyTracks.length === 1) {
            const empty = emptyTracks[0];
            const hasSoprano = tracksValidos.some(t => /sop|s1|s2/i.test(t.nombre));
            const hasAlto = tracksValidos.some(t => /alt|contr|a1|a2/i.test(t.nombre));
            const hasTenor = tracksValidos.some(t => /ten|t1|t2/i.test(t.nombre));
            const hasBajo = tracksValidos.some(t => /baj|bas|b1|b2|bar/i.test(t.nombre));
            
            if (!hasSoprano && hasAlto && hasTenor && hasBajo) {
                empty.nombre = "Soprano";
            } else if (hasSoprano && hasAlto && hasTenor && hasBajo && empty === tracksValidos[0]) {
                empty.nombre = "Solista";
            }
        }

        // 2. Inferencia de Soprano y Tenor si Alto y Bajo están presentes (y asunción SATB total)
        if (tracksValidos.length >= 4) {
            const t1 = tracksValidos[0], t2 = tracksValidos[1], t3 = tracksValidos[2], t4 = tracksValidos[3];
            const name1 = (t1.nombre || "").toLowerCase();
            const name2 = (t2.nombre || "").toLowerCase();
            const name3 = (t3.nombre || "").toLowerCase();
            const name4 = (t4.nombre || "").toLowerCase();

            const isAlto = name2.includes('alto') || name2 === 'a';
            const isBajo = name4.includes('bajo') || name4 === 'b';
            
            const isGeneric = (n) => n === '' || n.startsWith('pista') || n.includes('piano');
            const isT1Empty = isGeneric(name1);
            const isT2Empty = isGeneric(name2);
            const isT3Empty = isGeneric(name3);
            const isT4Empty = isGeneric(name4);

            // Si todo está vacío, SATB directo
            if (isT1Empty && isT2Empty && isT3Empty && isT4Empty && tracksValidos.length === 4) {
                t1.nombre = "Soprano"; t2.nombre = "Alto"; t3.nombre = "Tenor"; t4.nombre = "Bajo";
            } 
            // Si la 2 es Alto y la 4 es Bajo, rellenar 1 y 3
            else if (isAlto && isBajo) {
                if (isT1Empty) t1.nombre = "Soprano";
                if (isT3Empty) t3.nombre = "Tenor";
            }
        }

        // 3. Heurística de 5 pistas (Solista + SATB) si todas están vacías
        if (tracksValidos.length === 5) {
            const hasBaritone = tracksValidos.some(t => t.nombre === 'Barítono');
            const allEmpty = tracksValidos.every(t => {
                const n = (t.nombre || "").toLowerCase();
                return n === '' || n.startsWith('pista') || n.includes('piano');
            });
            if (!hasBaritone && allEmpty) {
                const nombres = ["Solista", "Soprano", "Alto", "Tenor", "Bajo"];
                tracksValidos.forEach((track, i) => { track.nombre = nombres[i]; });
            }
        }

        // 4. Heurística de 8 pistas (Doble Coro o División S2/A2/T2/B2) si todas están vacías o son Piano
        if (tracksValidos.length === 8) {
            const allEmpty = tracksValidos.every(t => {
                const n = (t.nombre || "").toLowerCase();
                return n === '' || n.startsWith('pista') || n.includes('piano');
            });
            if (allEmpty) {
                const nombres = ["Soprano", "Alto", "Tenor", "Bajo", "S2", "A2", "T2", "B2"];
                tracksValidos.forEach((track, i) => { track.nombre = nombres[i]; });
            }
        }

        return tracksValidos;
    },

    /**
     * Arquitectura 3: Activa el Wake Lock del OS SOLO cuando hay audio sonando.
     * Crea el elemento de audio silencioso en ese momento y lo destruye al pararlo.
     * Esto evita el consumo permanente de CPU/batería.
     */
    _activarWakeLock() {
        if (this._silentAudio) return; // Ya activo
        try {
            this._silentAudio = new Audio();
            this._silentAudio.playsInline = true;
            this._silentAudio.setAttribute('playsinline', '');
            this._silentAudio.style.cssText = 'position:absolute;width:1px;height:1px;opacity:0;pointer-events:none;left:-9999px;';
            document.body.appendChild(this._silentAudio);
            this._silentAudio.src = 'data:audio/mp3;base64,SUQzBAAAAAAAI1RTU0UAAAAPAAADTGF2ZjU2LjM2LjEwMAAAAAAAAAAAAAAA//OEAAAAAAAAAAAAAAAAAAAAAAAASW5mbwAAAA8AAAAEAAABIADAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV6urq6urq6urq6urq6urq6urq6urq6urq6v////////////////////////////////8AAAAATGF2YzU2LjQxAAAAAAAAAAAAAAAAJAAAAAAAAAAAASDs90hvAAAAAAAAAAAAAAAAAAAA//MUZAAAAAGkAAAAAAAAA0gAAAAATEFN//MUZAMAAAGkAAAAAAAAA0gAAAAARTMu//MUZAYAAAGkAAAAAAAAA0gAAAAAOTku//MUZAkAAAGkAAAAAAAAA0gAAAAANVVV';
            this._silentAudio.loop = true;
            this._silentAudio.play().catch(() => { this._liberarWakeLock(); });
            console.log('[MIDI] Wake Lock activado.');
        } catch (e) {
            console.warn('[MIDI] No se pudo activar el Wake Lock:', e);
            this._silentAudio = null;
        }
    },

    /**
     * Destruye completamente el elemento de audio silencioso y suspende el
     * AudioContext. Libera CPU y batería inmediatamente.
     */
    _liberarWakeLock() {
        if (this._silentAudio) {
            try {
                this._silentAudio.pause();
                this._silentAudio.src = '';
                if (this._silentAudio.parentNode) {
                    this._silentAudio.parentNode.removeChild(this._silentAudio);
                }
            } catch(e) {}
            this._silentAudio = null;
            console.log('[MIDI] Wake Lock liberado.');
        }
        // NOTA: No llamamos rawCtx.suspend() aquí intencionalmente.
        // En iOS/iPadOS, un AudioContext suspendido via código asíncrono
        // no puede reanudarse fuera del handler de gesto del usuario (trust boundary),
        // lo que deja el reproductor permanentemente mudo.
        // Destruir el WAV silencioso es suficiente: sin el loop activo, el OS
        // duerme el proceso de audio por su cuenta según su propio ciclo de vida.
    },

    /**
     * Reanuda o inicia el contexto de audio tras un gesto del usuario.
     * También carga Tone.js si no estaba cargado.
     */
    desbloquearAudioSync() {
        // Señal al OS de iOS 16.4+ de que este es un reproductor de música
        if ('audioSession' in navigator) {
            try { navigator.audioSession.type = 'playback'; } catch(e) {}
        }
        if (Tone && Tone.context) {
            const rawCtx = Tone.context.rawContext || Tone.context._context;
            if (rawCtx && rawCtx.state === 'suspended') {
                try {
                    rawCtx.resume();
                    console.log('[MIDI] rawCtx.resume() ejecutado síncronamente.');
                } catch (resumeErr) {
                    console.error('[MIDI] rawCtx.resume() falló:', resumeErr);
                }
            }
            try {
                Tone.start();
                console.log('[MIDI] Tone.start() ejecutado síncronamente.');
            } catch (startErr) {
                console.error('[MIDI] Tone.start() falló:', startErr);
            }
        }
    },

    async cargarCancion(url, onEvent, cantoId = null) {
        this.cantoActualId = cantoId;
        if (this._loadingUrl === url && (this.cargando || (this.midiData && this._activeLoadPromise))) {
            console.log("🎹 [MIDI] Carga compartida detectada para:", url);
            return this._activeLoadPromise; 
        }

        const currentSession = ++this._loadSessionId;
        this._loadingUrl = url;
        this.cargando = true;

        this.liberarNotas(false); 
        this.midiData = null; // Prevenir race condition en play()
        this._isJumping = false;
        this._activeLoadPromise = null;

        this._activeLoadPromise = (async () => {
            try {
                await this.inicializar();

                let parsedMidiJSON;

                // 1. Revisar Caché LRU
                if (this._lruCacheMidi.has(url)) {
                    parsedMidiJSON = this._lruCacheMidi.get(url);
                    // Actualizar posición LRU (mover al final para que sea el más reciente)
                    this._lruCacheMidi.delete(url);
                    this._lruCacheMidi.set(url, parsedMidiJSON);
                    if (this._loadSessionId !== currentSession) return;
                } else {
                    // 2. Descargar y Desencriptar
                    const arrayBuffer = await decryptFileFromUrl(url);
                    if (this._loadSessionId !== currentSession) return;
                    this.currentBuffer = arrayBuffer.slice(0);
                    
                    // 3. Procesamiento Nativo síncrono con Lazy Import (@tonejs/midi)
                    // Elimina overhead de WebWorker y serialización.
                    const midiModule = await import('@tonejs/midi');
                    const Midi = midiModule.Midi || midiModule.default?.Midi || midiModule.default;
                    const parsedData = new Midi(arrayBuffer);
                    parsedMidiJSON = parsedData.toJSON();
                    parsedMidiJSON.duration = parsedData.duration;
                    parsedMidiJSON.durationTicks = parsedData.durationTicks;

                    // 4. Guardar en Caché LRU y mantener límite de 5 canciones
                    this._lruCacheMidi.set(url, parsedMidiJSON);
                    if (this._lruCacheMidi.size > 5) {
                        const oldestKey = this._lruCacheMidi.keys().next().value;
                        this._lruCacheMidi.delete(oldestKey);
                    }
                }
                
                this.midiData = parsedMidiJSON;
                
                // Configurar el mapa de BPM completo antes de agendar las partes
                this.aplicarMapaTempo();

                // Agendar todas las notas usando la API de hardware
                this.agendarPartes();

                if (this._pendingPlay && this._loadSessionId === currentSession) {
                    this._pendingPlay = false;
                    this.play();
                }

                this.cargando = false;
                return { tempo: this.baseTempo };
            } catch (err) {
                if (this._loadSessionId === currentSession) {
                    this.cargando = false;
                    this._loadingUrl = null;
                    console.error("❌ [MIDI] Error cargando canción:", err);
                }
                throw err;
            }
        })();

        return this._activeLoadPromise;
    },

    agendarPartes() {
        if (!this.midiData) return;
        
        if (this.parts) {
            this.parts.forEach(p => p.dispose());
        }
        this.parts = [];

        // Detener explícitamente el transporte antes de agendar para evitar auto-arranque
        if (Tone && Tone.Transport.state !== 'stopped') {
            Tone.Transport.stop();
        }
        
        // Limpiar eventos anteriores agendados en el Transport (como time signatures y track end)
        Tone.Transport.cancel(0);

        // Configurar la resolución del transporte para que coincida con el MIDI
        Tone.Transport.PPQ = this.midiData.header.ppq;

        // CRÍTICO: Re-programar el mapa de tempos después del cancel(),
        // ya que cancel(0) elimina también los eventos de tempo del Transport.
        this.aplicarMapaTempo();

        const masterEventsMap = new Map();

        this.midiData.tracks.forEach((track, index) => {
            if (track.instrument.percussion) return;

            // Transformar las notas agrupando unísonos en el mismo Tick
            track.notes.forEach(note => {
                const key = `${note.ticks}-${note.name}`;
                if (!masterEventsMap.has(key)) {
                    masterEventsMap.set(key, {
                        time: note.ticks + "i",
                        noteName: note.name,
                        durationTicks: note.durationTicks,
                        duration: note.durationTicks + "i",
                        trackVelocities: {}
                    });
                }
                
                const event = masterEventsMap.get(key);
                event.trackVelocities[index] = note.velocity;
                
                // Si esta voz sostiene la nota más tiempo, extender la duración del unísono
                if (note.durationTicks > event.durationTicks) {
                    event.durationTicks = note.durationTicks;
                    event.duration = note.durationTicks + "i";
                }
            });
        });

        // Crear una única Part Maestra
        const masterEventsArray = Array.from(masterEventsMap.values());
        
        const part = new Tone.Part((time, value) => {
            if (!pianoInstrument || !this.instrumentoCargado) return;
            
            // Limitador Inteligente: Evaluar volumen máximo en tiempo real
            let maxRealVelocity = 0;
            for (const trackIndexStr in value.trackVelocities) {
                const trackIndex = parseInt(trackIndexStr, 10);
                const rawVelocity = value.trackVelocities[trackIndexStr];
                const trackVol = (window.MIXER_STATE && window.MIXER_STATE[trackIndex] !== undefined) ? window.MIXER_STATE[trackIndex] : 1.0;
                
                const currentVol = rawVelocity * trackVol;
                if (currentVol > maxRealVelocity) maxRealVelocity = currentVol;
            }
            
            const velocityReal = Math.min(1, Math.max(0, maxRealVelocity * this.volumenMaestro));
            
            if (velocityReal > 0.01) {
                // Filtro Anti-Ráfagas: Límite de 12 notas simultáneas
                // FIX: Usamos 'time' (tiempo de AudioContext) en lugar de performance.now()
                // ya que Tone.js agendaba notas en batch (CPU) y disparaba falsos positivos, enmudeciendo notas aleatorias.
                if (Math.abs(time - this._lastBurstTime) > 0.05) { // 50ms de ventana en segundos de AudioContext
                    this._burstCount = 0;
                    this._lastBurstTime = time;
                }
                this._burstCount++;
                
                if (this._burstCount <= 12) {
                    try {
                        // Suavizamos ligeramente la curva de velocidad para que no golpee el limitador al 100% cuando no hay dinámicas
                        const velocitySuavizada = velocityReal * 0.75;
                        const nativeAudio = getNativeAudioPlugin();
                        if (nativeAudio) {
                            const midiNum = Tone.Frequency ? Tone.Frequency(value.noteName).toMidi() : 60;
                            nativeAudio.playNote({
                                note: midiNum,
                                velocity: Math.round(velocitySuavizada * 127)
                            });
                        } else if (pianoInstrument) {
                            pianoInstrument.triggerAttackRelease(value.noteName, value.duration, time, velocitySuavizada);
                        }
                    } catch(e) {
                        // Prevención de crash
                    }
                }
            }
        }, masterEventsArray).start(0);

        this.parts.push(part);

        // v4.2.2: Parche Inteligente para Bug de Exportación de Musescore
        // Si hay secciones largas configuradas a 1 tiempo (ej. 1/1 o 1/4), las forzamos a 4/4
        // pero respetamos si es una anacrusa corta (dura menos de 4 tiempos).
        let timeSignatures = this.midiData.header.timeSignatures || [];
        const ppq = this.midiData.header.ppq || 480;

        for (let i = 0; i < timeSignatures.length; i++) {
            const ts = timeSignatures[i];
            if (ts.timeSignature && ts.timeSignature[0] === 1) {
                let nextDiffTs = null;
                for (let j = i + 1; j < timeSignatures.length; j++) {
                    if (timeSignatures[j].timeSignature[0] !== 1) {
                        nextDiffTs = timeSignatures[j];
                        break;
                    }
                }
                
                const isForever = (nextDiffTs === null);
                const durationBeats = isForever ? 0 : ((nextDiffTs.ticks - ts.ticks) / ppq);
                
                // Si nunca cambia, o si dura más de 4 tiempos (no es anacrusa), forzar 4/4
                if (isForever || durationBeats > 4) {
                    ts.timeSignature = [4, 4];
                }
            }
        }

        // Configurar la métrica inicial
        let timeSigNumerator = 4;
        let timeSigDenominator = 4;
        if (timeSignatures.length > 0) {
            timeSigNumerator = timeSignatures[0].timeSignature[0] || 4;
            timeSigDenominator = timeSignatures[0].timeSignature[1] || 4;
        }
        
        // ── Metrónomo: Tone.Part pre-calculado ─────────────────────────────────
        // Reemplaza el antiguo Tone.Loop de "8n" + filtro matemático.
        // Pre-calculamos TODOS los beats en ticks exactos antes de empezar,
        // igual que las notas del piano → timing de hardware, cero desfase.
        if (metronomoPart) metronomoPart.dispose();

        const metroEvents = [];

        // Construir secciones de cambio de compás
        const sections = timeSignatures.map((ts, i) => ({
            startTicks: ts.ticks,
            numerator:  ts.timeSignature[0] || 4,
            denominator: ts.timeSignature[1] || 4,
            endTicks:   (i < timeSignatures.length - 1) ? timeSignatures[i + 1].ticks : Infinity
        }));

        if (sections.length === 0) {
            sections.push({ startTicks: 0, numerator: 4, denominator: 4, endTicks: Infinity });
        }

        for (const section of sections) {
            const num = section.numerator;
            const den = section.denominator;
            const isCompound = (den === 8 && num % 3 === 0);
            const beatTicks = (480 * 4) / den;

            let tick = section.startTicks;
            let beatInBar = 0;

            while (tick < section.endTicks && tick <= this.midiData.durationTicks) {
                const isFirstBeat = (beatInBar === 0);

                // En compuesto determinamos si sonará el click de audio
                const shouldPlayAudio = isCompound
                    ? (beatInBar % 3 === 0)
                    : true;

                metroEvents.push({
                    time: tick + "i",
                    isFirstBeat,
                    beatIndex: beatInBar,
                    numerator: num,
                    shouldPlayAudio
                });

                beatInBar = (beatInBar + 1) % num;
                tick += beatTicks;
            }
        }

        metronomoPart = new Tone.Part((time, value) => {
            // Audio del click — Player real de madera o Swift Nativo
            if (this.metronomoActivo && value.shouldPlayAudio) {
                const nativeAudio = getNativeAudioPlugin();
                if (nativeAudio) {
                    nativeAudio.playMetro({ type: value.isFirstBeat ? "hi" : "lo" });
                } else {
                    const player = value.isFirstBeat ? metroHi : metroLo;
                    if (player && player.loaded) {
                        player.start(time);
                    }
                }
            }

            // Visual sincronizado con el hilo de audio via Tone.Draw
            Tone.Draw.schedule(() => {
                window.dispatchEvent(new CustomEvent('midi-beat', {
                    detail: {
                        isFirstBeat: value.isFirstBeat,
                        beatIndex:   value.beatIndex,
                        numerator:   value.numerator,
                        activo:      this.metronomoActivo
                    }
                }));
            }, time);
        }, metroEvents).start(0);

        this.parts.push(metronomoPart);

        // Configurar detección de fin de pista usando ticks
        Tone.Transport.schedule(() => {
            setTimeout(() => { 
                if (this.repetirTrack) {
                    this.stop();
                    this.play();
                } else {
                    this.stop(); 
                    if (this.onTrackEnd) this.onTrackEnd();
                }
            }, 100);
        }, this.midiData.durationTicks + "i");
    },

    play() { 
        if (limitsManager.estaBloqueadoPorDRM()) {
            if (window.uiController && typeof window.uiController.mostrarToast === 'function') {
                window.uiController.mostrarToast(i18n.t('audio.no_autorizado'), "error");
            }
            if (window.uiController && typeof window.uiController.mostrarModalPremium === 'function') {
                window.uiController.mostrarModalPremium('audio');
            }
            return;
        }

        // Bypass Limits Manager if in Jukebox Mode (unlimited but ads handled by Jukebox)
        if (!this._modoBackground && !limitsManager.puedeReproducirAudio()) {
            if (window.uiController && typeof window.uiController.mostrarModalPremium === 'function') {
                window.uiController.mostrarModalPremium('audio');
            } else {
                alert(i18n.t('audio.alcanzado'));
            }
            return;
        }

        this._pendingPlay = false;
        if (this.midiData && Tone && this.instrumentoCargado) {
            if (!this._modoBackground) {
                const cobroEfectivo = limitsManager.registrarReproduccionAudio(this.cantoActualId);
                
                // Si es gratuito y se le acaba de descontar un crédito (cobroEfectivo), mostrar el Toast indicando audios restantes
                if (cobroEfectivo && !limitsManager.esPremium()) {
                    const restantes = limitsManager.obtenerAudiosRestantes();
                    if (restantes > 0) {
                        if (window.uiController && typeof window.uiController.mostrarToast === 'function') {
                            window.uiController.mostrarToast(`${i18n.t('audio.te_quedan')}${restantes}${i18n.t('audio.audios_hoy')}`, "info");
                        }
                    } else if (restantes === 0) {
                        if (window.uiController && typeof window.uiController.mostrarToast === 'function') {
                            window.uiController.mostrarToast(i18n.t('audio.ultimo'), "advertencia");
                        }
                    }
                }
            }

            this._lastBurstTime = 0;
            this._burstCount = 0;
            this._activarWakeLock();
            if (masterGainNode) {
                const now = Tone.now();
                masterGainNode.gain.cancelScheduledValues(now);
                masterGainNode.gain.setTargetAtTime(1, now, 0.015);
            }
            if (Tone.Transport.state !== 'started') {
                Tone.Transport.start();
            }
        } else {
            this._pendingPlay = true;
        }
    },
    
    isPlaying() {
        return Tone && Tone.Transport.state === 'started';
    },

    pause() { 
        this._pendingPlay = false;
        if (Tone && Tone.Transport.state === 'started') {
            Tone.Transport.pause();
            if (pianoInstrument) pianoInstrument.releaseAll();
        }
        // Arquitectura 3: Liberar Wake Lock al pausar para no consumir batería
        this._liberarWakeLock();
    },

    stop() { 
        this._pendingPlay = false;
        this._lastBurstTime = 0;
        this._burstCount = 0;
        if (Tone) {
            Tone.Transport.stop();
            Tone.Transport.ticks = 0;
            if (pianoInstrument) pianoInstrument.releaseAll();
        }
        // Arquitectura 3: Liberar Wake Lock al detener
        this._liberarWakeLock();
    },

    silenciarTodo() {
        this._pendingPlay = false;
        if (Tone && pianoInstrument) {
            pianoInstrument.releaseAll();
        }
    },

    manejarCambioVisibilidad(isVisible) {
        if (!Tone || !this.instrumentoCargado) return;
        if (!isVisible) {
            // Si la Jukebox está activa, NO silenciar — queremos audio con pantalla apagada
            if (this._modoBackground) return;
            try {
                if (masterGainNode) {
                    const now = Tone.now();
                    masterGainNode.gain.cancelScheduledValues(now);
                    masterGainNode.gain.setTargetAtTime(0, now, 0.015);
                }
                if (pianoInstrument) pianoInstrument.releaseAll();
                
                // v4.0.5: PAUSAR el transporte para evitar que Tone.js acumule eventos programados 
                // mientras el thread principal JS está suspendido por el sistema operativo.
                this._wasPlayingBeforeHidden = (Tone.Transport.state === 'started');
                if (this._wasPlayingBeforeHidden) {
                    Tone.Transport.pause();
                }
            } catch(e) {}
        } else {
            // Verificar estado real del AudioContext (no confiar solo en Tone.context)
            const rawCtx = Tone.context.rawContext || Tone.context._context;
            const ctxState = rawCtx ? rawCtx.state : Tone.context.state;

            if (ctxState === 'suspended' || ctxState === 'interrupted') {
                // No se puede reanudar sin gesto del usuario; disparar evento visual
                window.dispatchEvent(new CustomEvent('audio-context-state', {
                    detail: { state: ctxState }
                }));
                return;
            }

            // Bug iOS: "running pero silencioso" — forzar ciclo suspend/resume
            if (ctxState === 'running' && rawCtx && Tone.Transport.state === 'started') {
                rawCtx.suspend().then(() => rawCtx.resume()).catch(() => {});
            }

            // Restaurar volumen
            try {
                if (masterGainNode) {
                    const now = Tone.now();
                    masterGainNode.gain.cancelScheduledValues(now);
                    masterGainNode.gain.setTargetAtTime(1, now, 0.015);
                }
                
                // Restaurar transporte si estaba reproduciéndose
                if (this._wasPlayingBeforeHidden) {
                    Tone.Transport.start();
                    this._wasPlayingBeforeHidden = false; // Resetear bandera
                }
            } catch(e) {}
        }
    },

    liberarNotas(fullReset = true) {
        if (fullReset) this._pendingPlay = false;
        try {
            if (masterGainNode && Tone) {
                const now = Tone.now();
                masterGainNode.gain.cancelScheduledValues(now);
                masterGainNode.gain.setTargetAtTime(0, now, 0.015);
            }
            if (pianoInstrument && this.instrumentoCargado) pianoInstrument.releaseAll();
            
            if (Tone) {
                Tone.Transport.stop();
                Tone.Transport.ticks = 0;
                Tone.Transport.cancel(0); // Esto limpia los tempos y timeSignatures cacheados
                if (Tone.Draw) Tone.Draw.cancel(0); // v4.0.0: Limpiar eventos visuales del metrónomo
            }

            if (this.parts) {
                this.parts.forEach(p => p.dispose());
                this.parts = [];
            }
        } catch (e) {}
    },

    saltarA(porcentaje) {
        if (!this.midiData || !Tone) return;
        this._isJumping = true;
        
        const wasPlaying = Tone.Transport.state === 'started';
        if (wasPlaying) Tone.Transport.pause();
        if (pianoInstrument) pianoInstrument.releaseAll();
        
        const targetTicks = Math.floor((porcentaje / 100) * this.midiData.durationTicks);
        Tone.Transport.ticks = targetTicks;
        
        // Recalcular BPM exacto para la posición actual (Evitar perder ritardandos al saltar)
        let targetBpm = 120;
        if (this.midiData.header.tempos.length > 0) {
            targetBpm = this.midiData.header.tempos[0].bpm;
            for (let t of this.midiData.header.tempos) {
                if (t.ticks <= targetTicks) targetBpm = t.bpm;
                else break;
            }
        }
        // Aplicar instantáneamente sin rampas para el salto
        Tone.Transport.bpm.value = targetBpm * this.speed;
        
        if (wasPlaying) Tone.Transport.start();
        setTimeout(() => { this._isJumping = false; }, 50);
    },

    setVolumen(val) {
        let v = parseFloat(val);
        if (isNaN(v)) v = 1.0;
        this.volumenMaestro = v;
        if (masterVolumeNode && Tone) {
            masterVolumeNode.volume.value = this.volumenMaestro === 0 ? -Infinity : 20 * Math.log10(this.volumenMaestro); 
        }
    },

    setSpeed(val) {
        this.speed = parseFloat(val);
        this.aplicarMapaTempo();
    },

    aplicarMapaTempo() {
        if (!Tone || !this.midiData) return;
        
        // Limpiar cualquier evento de tempo anterior
        if (this._tempoEventId && this._tempoEventId.length > 0) {
            this._tempoEventId.forEach(id => Tone.Transport.clear(id));
        }
        this._tempoEventId = [];
        
        if (this.midiData.header.tempos.length > 0) {
            this.midiData.header.tempos.forEach(t => {
                const id = Tone.Transport.schedule((time) => {
                    // Usar setValueAtTime asegura precisión de sample (compensa el lookAhead de 100ms)
                    Tone.Transport.bpm.setValueAtTime(t.bpm * this.speed, time);
                }, t.ticks + "i");
                this._tempoEventId.push(id);
            });
            // Establecer el inicial inmediatamente también
            Tone.Transport.bpm.value = this.midiData.header.tempos[0].bpm * this.speed;
        } else {
            Tone.Transport.bpm.value = 120 * this.speed;
        }
    },

    toggleMetronomo(activo) {
        this.metronomoActivo = activo;
    },

    getProgreso() {
        if (!this.midiData || !Tone) return 0;
        const totalTicks = this.midiData.durationTicks;
        if (!totalTicks) return 0;
        
        return Math.max(0, Math.min(100, (Tone.Transport.ticks / totalTicks) * 100));
    },

    ticksToSeconds(ticks) {
        if (!this.midiData || !this.midiData.header.tempos.length) {
            const ppq = this.midiData ? this.midiData.header.ppq : 480;
            return (ticks / ppq) * (60 / 120) / this.speed;
        }

        let time = 0;
        let currentTicks = 0;
        let currentBpm = this.midiData.header.tempos[0].bpm;
        const ppq = this.midiData.header.ppq || 480;

        for (const t of this.midiData.header.tempos) {
            if (t.ticks > ticks) break;
            const deltaTicks = t.ticks - currentTicks;
            time += (deltaTicks / ppq) * (60 / currentBpm);
            currentTicks = t.ticks;
            currentBpm = t.bpm;
        }

        if (ticks > currentTicks) {
            const deltaTicks = ticks - currentTicks;
            time += (deltaTicks / ppq) * (60 / currentBpm);
        }

        return time / this.speed;
    },

    getTiempos() {
        if (!this.midiData || !Tone) return { actual: 0, total: 0 };
        // Cálculo matemático exacto basado en la línea de tiempo de los ticks
        return { 
            actual: this.ticksToSeconds(Tone.Transport.ticks), 
            total: this.ticksToSeconds(this.midiData.durationTicks)
        };
    },

    /**
     * Estado formateado para navigator.mediaSession.setPositionState()
     * Permite que el OS muestre la barra de progreso real en pantalla de bloqueo.
     */
    getEstadoParaMediaSession() {
        if (!this.midiData || !Tone) return null;
        const tiempos = this.getTiempos();
        return {
            duration: tiempos.total,
            position: Math.min(tiempos.actual, tiempos.total),
            playbackRate: this.speed || 1
        };
    }
};