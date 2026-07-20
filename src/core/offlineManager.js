import { localDB } from '../api/localDB.js';
import { i18n } from './i18n.js';

export const offlineManager = {
    NOMBRE_CACHE: 'pdf-cache-offline',

    registrarServiceWorker: function() {
        // No-op for Capacitor offline app
    },

    resolverUrl: function(archivo) {
        return localDB.resolverUrlPdf(archivo);
    },

    resolverUrlMidi: function(archivoMidi) {
        return localDB.resolverUrlMidi(archivoMidi);
    },

    actualizarContador: async function(cantos, elementoContador) {
        if (!elementoContador) return;
        elementoContador.style.display = 'inline-block';
        elementoContador.innerHTML = `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 4px;"><polyline points="20 6 9 17 4 12"></polyline></svg> ${i18n.t('offline.disponible_offline')}`;
        elementoContador.classList.add('completado');
    },

    actualizarEstadisticas: async function(cantos) {
        const txtPdfs = document.getElementById('txt-contador-pdfs');
        const txtMidis = document.getElementById('txt-contador-midis');
        
        let totalMidis = cantos.filter(c => c.midi_archivo).length;
        
        if (txtPdfs) txtPdfs.textContent = `${cantos.length} / ${cantos.length}`;
        if (txtMidis) txtMidis.textContent = `${totalMidis} / ${totalMidis}`;
    },

    sincronizarPartituras: async function() {},
    forzarSincronizacion: async function(cantos, elementoContador, progressCallback, signal) {
        if (progressCallback) progressCallback(cantos.length, cantos.length);
        this.actualizarContador(cantos, elementoContador);
    },

    obtenerPorcentajeCache: async function() {
        return 100;
    }
};