import { localDB } from '../api/localDB.js';
import './types.js';

export const partiturasController = {
    async obtenerPartituras(coroId) {
        return await localDB.getCantos();
    },

    async obtenerTemasUnicos() {
        const cantos = await localDB.getCantos();
        const setTemas = new Set();
        cantos.forEach(item => {
            if (item.temas) {
                item.temas.forEach(t => setTemas.add(t.trim()));
            }
        });
        return Array.from(setTemas).sort();
    },

    async subirArchivo(file, nombreLimpio) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result);
            reader.onerror = error => reject(error);
            reader.readAsDataURL(file);
        });
    },

    async subirMidi(file, nombreLimpio) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result);
            reader.onerror = error => reject(error);
            reader.readAsDataURL(file);
        });
    },

    async eliminarRelacionSede(id, coroId) {
        await localDB.deleteCanto(id);
    },

    async guardarCanto(payload, editandoId = null) {
        return await localDB.saveCanto(payload, editandoId);
    },

    async registrarVistaCanto(cantoId, coroId) {
        // No-op for offline
    },

    async registrarAccion(accion, nombre, coroId, cantoId = null, cambiosDetalle = []) {
        await localDB.logAccion(accion, {
            usuario_nombre: 'Admin Local',
            canto_nombre: nombre,
            canto_id: cantoId,
            coro_id: 'local',
            coro_nombre: 'Local',
            cambios: cambiosDetalle
        });
    },

    async obtenerHistorialAuditoria(coroId, listaIdsPermitidos = []) {
        const logs = await localDB.getAuditoria();
        return logs.slice(0, 20);
    },

    async esSuperAdmin() {
        return true;
    },
    
    async obtenerCatalogoGlobal() {
        return await localDB.getAmbosCatalogos();
    }
};