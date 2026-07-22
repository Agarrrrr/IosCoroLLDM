export const limitsManager = {
    LIMITES: {
        MAX_AUDIOS_DIARIOS: 999999,
        MAX_PDFS_SIN_ANUNCIO: 999999,
        MAX_RESETEOS_OFFLINE: 999999
    },
    
    esPremium() {
        return true; // Audios y partituras ilimitados por defecto
    },

    setPremium(status) {
        if (typeof localStorage !== 'undefined') {
            localStorage.setItem('is_premium_user', 'true');
        }
    },

    _obtenerFechaLocal() {
        const d = new Date();
        return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
    },

    _obtenerEstadoHoy() {
        const fechaHoy = this._obtenerFechaLocal();
        const ahora = Date.now();
        return {
            fecha: fechaHoy,
            audiosReproducidos: 0,
            pdfsAbiertos: 0,
            offline_resets_count: 0,
            bloqueo_drm: false,
            last_timestamp: ahora,
            fecha_servidor: fechaHoy
        };
    },

    _guardarEstado(estado) {},

    async sincronizarConServidor() {},

    puedeReproducirAudio() {
        return true; // Sin límite de audios
    },

    estaBloqueadoPorDRM() {
        return false;
    },

    registrarReproduccionAudio(cantoId = null) {
        return false;
    },

    concederAudioExtra() {},

    obtenerAudiosRestantes() {
        return "Ilimitado";
    },

    debeMostrarIntersticial() {
        return false;
    },

    registrarAperturaPdf() {}
};
