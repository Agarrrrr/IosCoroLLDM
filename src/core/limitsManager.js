export const limitsManager = {
    LIMITES: {
        MAX_AUDIOS_DIARIOS: 5,
        MAX_PDFS_SIN_ANUNCIO: 10, // Mostrar anuncio a partir de la 11va partitura
        MAX_RESETEOS_OFFLINE: 3  // Límite DRM Híbrido
    },
    
    esPremium() {
        return true; // Premium por defecto para omitir compras/anuncios
    },

    setPremium(status) {
        localStorage.setItem('is_premium_user', status ? 'true' : 'false');
    },

    _obtenerFechaLocal() {
        const d = new Date();
        return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
    },

    _obtenerEstadoHoy() {
        const fechaHoy = this._obtenerFechaLocal();
        const ahora = Date.now();
        const estadoGuardado = localStorage.getItem('limites_diarios');
        let estado = estadoGuardado ? JSON.parse(estadoGuardado) : null;
        
        if (!estado) {
            estado = {
                fecha: fechaHoy,
                audiosReproducidos: 0,
                pdfsAbiertos: 0,
                offline_resets_count: 0,
                bloqueo_drm: false,
                last_timestamp: ahora,
                fecha_servidor: fechaHoy
            };
            this._guardarEstado(estado);
            return estado;
        }

        // Anti-Time Travel: Si el reloj retrocedió, detectamos trampa. No resetear.
        if (ahora < estado.last_timestamp) {
            estado.last_timestamp = ahora;
            this._guardarEstado(estado);
            return estado; 
        }

        // Cambio de día local (Reseteo Offline sin límites de internet)
        if (estado.fecha !== fechaHoy) {
            estado.fecha = fechaHoy;
            estado.audiosReproducidos = 0;
            estado.pdfsAbiertos = 0;
            estado.bloqueo_drm = false;
            estado.offline_resets_count = 0;
            estado.last_timestamp = ahora;
            this._guardarEstado(estado);
        } else {
            estado.last_timestamp = ahora;
            this._guardarEstado(estado);
        }

        return estado;
    },

    _guardarEstado(estado) {
        localStorage.setItem('limites_diarios', JSON.stringify(estado));
    },

    async sincronizarConServidor() {
        if (this.esPremium()) return;
        try {
            // Sincronización silenciosa con servidor externo de alta disponibilidad (Cloudflare)
            // Esto evita los bloqueos de red (ERR_CONNECTION_RESET) que sufre worldtimeapi
            const resp = await fetch('https://cloudflare.com/cdn-cgi/trace', { cache: 'no-store' });
            if (!resp.ok) return;
            const text = await resp.text();
            
            // Buscar la línea 'ts=1718...' (Unix timestamp en segundos)
            const match = text.match(/ts=(\d+)/);
            if (!match) return;
            
            const dateSrv = new Date(parseInt(match[1]) * 1000);
            const fechaSrv = `${dateSrv.getFullYear()}-${dateSrv.getMonth() + 1}-${dateSrv.getDate()}`;
            
            const estado = this._obtenerEstadoHoy();
            
            // Al conectarse, premiamos al usuario reseteando sus strikes offline
            estado.offline_resets_count = 0;
            estado.bloqueo_drm = false;

            if (estado.fecha_servidor !== fechaSrv) {
                estado.fecha_servidor = fechaSrv;
                estado.fecha = this._obtenerFechaLocal();
                estado.audiosReproducidos = 0;
                estado.pdfsAbiertos = 0;
            }
            
            this._guardarEstado(estado);
        } catch (e) {
            // Falla en silencio (Modo avión o sin señal)
        }
    },

    puedeReproducirAudio() {
        if (this.esPremium()) return true;
        const estado = this._obtenerEstadoHoy();
        return estado.audiosReproducidos < this.LIMITES.MAX_AUDIOS_DIARIOS;
    },

    estaBloqueadoPorDRM() {
        return false;
    },

    registrarReproduccionAudio(cantoId = null) {
        if (this.esPremium()) return false;
        if (!this.puedeReproducirAudio()) return false;
        const estado = this._obtenerEstadoHoy();
        
        // Si el usuario reproduce el mismo canto varias veces en la misma sesión/día, no le cobramos extra
        if (cantoId && estado.ultimoCantoMidi === cantoId) {
            return false;
        }
        
        estado.audiosReproducidos += 1;
        if (cantoId) {
            estado.ultimoCantoMidi = cantoId;
        }
        this._guardarEstado(estado);
        return true;
    },

    concederAudioExtra() {
        const estado = this._obtenerEstadoHoy();
        if (estado.audiosReproducidos > 0) {
            estado.audiosReproducidos -= 1;
            this._guardarEstado(estado);
        }
    },

    obtenerAudiosRestantes() {
        if (this.esPremium()) return "Ilimitado";
        const estado = this._obtenerEstadoHoy();
        return Math.max(0, this.LIMITES.MAX_AUDIOS_DIARIOS - estado.audiosReproducidos);
    },

    debeMostrarIntersticial() {
        if (this.esPremium()) return false;
        const estado = this._obtenerEstadoHoy();
        
        // Inicializar la meta si no existe (la primera vez salta a las 3 partituras)
        if (!estado.metaAnuncioPdf) {
            estado.metaAnuncioPdf = 3;
        }
        
        // Eliminar cooldown, basar puramente en aperturas
        const ahora = Date.now();
        
        if (estado.pdfsAbiertos >= estado.metaAnuncioPdf) {
            estado.ultimoIntersticial = ahora;
            // Configurar la siguiente meta: actual + un número aleatorio entre 2 y 4
            const saltosAleatorios = Math.floor(Math.random() * 3) + 2;
            estado.metaAnuncioPdf = estado.pdfsAbiertos + saltosAleatorios;
            
            this._guardarEstado(estado);
            return true;
        }
        return false;
    },

    registrarAperturaPdf() {
        if (this.esPremium()) return;
        const estado = this._obtenerEstadoHoy();
        estado.pdfsAbiertos += 1;
        this._guardarEstado(estado);
    }
};
