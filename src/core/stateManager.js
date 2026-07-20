/**
 * stateManager.js
 * Orquestador central de estado para Repertorio BC.
 * Implementa un patrón de "Store" reactivo simple para Vanilla JS.
 */

import './types.js';

class StateStore {
    constructor() {
        /** @type {import('./types.js').AppState} */
        this._state = {
            perfil: null,
            cantos: [],
            categoriaActiva: 'local', // 'local', 'estatal', o 'ev-[ID]'
            online: typeof navigator !== 'undefined' ? navigator.onLine : true,
            MODO_OFFLINE_FORZADO: window.MODO_OFFLINE_FORZADO || false,
            eventos: [], // Carpetas/Setlists
            temaUI: localStorage.getItem('tema-ui') || 'claro',
            // --- NUEVO ESTADO DE UI (Reactividad Pura) ---
            busqueda: '',
            temaSeleccionado: 'Todos',
            cantosVisibles: []
        };
        /** @type {Set<function(import('./types.js').AppState):void>} */
        this._listeners = new Set();
    }

    /**
     * Obtiene una copia del estado actual.
     * @returns {import('./types.js').AppState}
     */
    getState() {
        return { ...this._state };
    }

    /**
     * Actualiza una o varias propiedades del estado y notifica a los suscriptores.
     * Calcula propiedades derivadas (Selectores) si cambian los filtros.
     * @param {Partial<import('./types.js').AppState>} newState 
     */
    setState(newState) {
        const oldState = { ...this._state };
        let nextState = { ...this._state, ...newState };
        
        // Si cambió la base, o los filtros (búsqueda/tema/categoría), recalculamos cantosVisibles
        const cambioBase = (newState.cantos !== undefined || newState.categoriaActiva !== undefined);
        const cambioFiltros = (newState.busqueda !== undefined || newState.temaSeleccionado !== undefined);

        if (cambioBase || cambioFiltros) {
            nextState.cantosVisibles = this._aplicarFiltrosUI(nextState);
        }

        this._state = nextState;
        
        // Notificar si hubo cambios reales
        if (JSON.stringify(oldState) !== JSON.stringify(this._state)) {
            this._notify();
        }
    }

    _filtrarPorCategoria(state) {
        const cat = state.categoriaActiva;
        if (!state.cantos || state.cantos.length === 0) return [];

        // Si la categoría es favoritos
        if (cat === 'favoritos') {
            const favs = JSON.parse(localStorage.getItem('favoritos_repertorio') || '[]');
            return state.cantos.filter(canto => favs.includes(canto.id));
        }

        // Modelo monolítico: siempre devolver todos los cantos
        return state.cantos;
    }

    /**
     * Aplica el buscador de texto y el filtro de Tema sobre los cantos de la categoría actual.
     */
    _aplicarFiltrosUI(state) {
        const busqueda = (state.busqueda || '').trim();
        
        let filtrados = [];
        if (busqueda !== '') {
            // En búsqueda global iteramos sobre todo el catálogo
            filtrados = state.cantos || [];
        } else {
            // Aplicar el filtro de categoría al vuelo (sin caché)
            filtrados = this._filtrarPorCategoria(state);
        }

        // 1. Filtro por Tema
        const tema = state.temaSeleccionado;
        if (tema && tema !== 'Todos') {
            if (tema === 'Sin Tema') {
                filtrados = filtrados.filter(c => !c.temas || c.temas.length === 0);
            } else {
                filtrados = filtrados.filter(c => c.temas && c.temas.includes(tema));
            }
        }

        // 2. Filtro por Búsqueda (Texto) Global
        if (busqueda !== '') {
            const normalizedB = this._normalizar(busqueda);
            const palabrasBusqueda = normalizedB.split(' ').filter(p => p !== '');

            filtrados = filtrados.filter(canto => {
                const tituloNormalizado = canto._nombre_norm || this._normalizar(canto.nombre);
                const autorNormalizado = canto._autor_norm || this._normalizar(canto.autor);
                
                return palabrasBusqueda.every(palabra => {
                    return tituloNormalizado.includes(palabra) || 
                           (canto.numero && String(canto.numero) === palabra) || 
                           autorNormalizado.includes(palabra);
                });
            });

            // Ordenamiento por relevancia
            filtrados.sort((a, b) => {
                const nombreA = a._nombre_norm || this._normalizar(a.nombre);
                const nombreB = b._nombre_norm || this._normalizar(b.nombre);
                let puntosA = 0; let puntosB = 0;
                
                if (nombreA.startsWith(normalizedB)) puntosA += 100;
                else if (nombreA.split(' ')[0] === palabrasBusqueda[0]) puntosA += 50;
                
                if (nombreB.startsWith(normalizedB)) puntosB += 100;
                else if (nombreB.split(' ')[0] === palabrasBusqueda[0]) puntosB += 50;
                
                if (puntosA !== puntosB) return puntosB - puntosA; 
                return nombreA.localeCompare(nombreB, 'es', { 
                    sensitivity: 'base',
                    numeric: true,
                    ignorePunctuation: true
                });
            });
        }

        return filtrados;
    }

    _normalizar(str) {
        if (!str) return '';
        return str.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }

    /**
     * Se suscribe a los cambios de estado. Retorna una función para cancelar la suscripción.
     */
    subscribe(callback) {
        this._listeners.add(callback);
        // Ejecutar inmediatamente para sincronización inicial
        callback(this._state);
        return () => this._listeners.delete(callback);
    }

    _notify() {
        this._listeners.forEach(callback => callback(this._state));
    }
}

export const store = new StateStore();

// Sincronización automática con eventos de red
if (typeof window !== 'undefined') {
    window.addEventListener('online', () => store.setState({ online: true }));
    window.addEventListener('offline', () => store.setState({ online: false }));
}
