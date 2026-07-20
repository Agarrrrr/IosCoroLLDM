import { store } from './stateManager.js';

export const anotacionesManager = {
    PREFIX: 'anotaciones_',

    _getKey(cantoId, pagina) {
        return `${this.PREFIX}${cantoId}_${pagina}`;
    },

    guardarTrazoLocal(cantoId, pagina, trazos) {
        const key = this._getKey(cantoId, pagina);
        const data = {
            canto_id: cantoId,
            pagina: pagina,
            trazos: trazos,
            sync_status: 'synced',
            timestamp: Date.now()
        };
        localStorage.setItem(key, JSON.stringify(data));
    },

    obtenerTrazosLocal(cantoId, pagina) {
        const key = this._getKey(cantoId, pagina);
        const saved = localStorage.getItem(key);
        if (saved) {
            try {
                const parsed = JSON.parse(saved);
                let trazos = parsed.trazos;
                
                if (typeof trazos === 'string') {
                    try { trazos = JSON.parse(trazos); } catch(e) { trazos = []; }
                }
                
                return Array.isArray(trazos) ? trazos : [];
            } catch (e) {
                return [];
            }
        }
        return [];
    },

    async bajarTrazosNube(cantoId) {
        // En modo offline estático no bajamos de nube
        return;
    },

    async sincronizarPendientes() {
        // En modo offline estático no hay nube
        return;
    },

    programarSincronizacion(delay = 2000) {
        // No-op
    }
};
