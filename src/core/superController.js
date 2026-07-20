import { localDB } from '../api/localDB.js';

export const superController = {
    async obtenerMetricasSede(coroId, rango = '1w') {
        const catalogoLocal = await localDB.getCantos();
        
        const totalCantosSede = catalogoLocal.length;
        const conMidi = catalogoLocal.filter(c => c.midi_archivo).length;
        const porcentajeMidi = totalCantosSede > 0 ? Math.round((conMidi / totalCantosSede) * 100) : 0;

        const distVoces = { soprano: 0, contralto: 0, tenor: 0, bajo: 0, sin_asignar: 0 };

        return {
            totalMiembros: 0,
            activosSemana: 0,
            usuariosOffline: 0,
            porcentajeOffline: 100,
            notificaciones: { activas: 0, porcentaje: 0 },
            coberturaMidi: {
                total: totalCantosSede,
                conMidi: conMidi,
                porcentaje: porcentajeMidi
            },
            distribucionVoces: distVoces,
            catalogoLocal,
            topCantos: [],
            bottomCantos: [],
            errores: []
        };
    },

    async obtenerHistorialUsoCanto(coroId, cantoId, rango = '1w') {
        return [];
    },

    async obtenerDetalleMiembrosMetricas(coroId, filtro = 'activos') {
        return [];
    },

    async obtenerAuditoriaGlobalSede(coroId, limit = 150) {
        return await localDB.getAuditoria();
    },

    limpiarCache() {}
};
