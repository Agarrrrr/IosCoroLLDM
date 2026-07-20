/**
 * basePanelController.js
 * Utilidades comunes para la gestión de paneles administrativos (CRUD Optimista).
 */
import { store } from './stateManager.js';

export const basePanelController = {
    /**
     * Maneja el estado de carga de un botón con feedback visual nativo.
     */
    async ejecutarConCarga(boton, callback, mensajeExito = "OPERACIÓN EXITOSA") {
        if (!boton) return await callback();
        
        const originalText = boton.innerHTML;
        const originalDisabled = boton.disabled;
        
        try {
            boton.disabled = true;
            boton.classList.add('cargando');
            // Si el botón tiene un span de texto, podemos animarlo
            const res = await callback();
            if (mensajeExito && window.mostrarToast) {
                window.mostrarToast(mensajeExito, "exito");
            }
            return res;
        } catch (error) {
            console.error("Error en ejecución basePanel:", error);
            if (window.mostrarToast) {
                const msg = error.message ? error.message.toUpperCase() : "ERROR EN LA OPERACIÓN";
                window.mostrarToast(msg, "error");
            }
            throw error;
        } finally {
            boton.disabled = originalDisabled;
            boton.classList.remove('cargando');
            boton.innerHTML = originalText;
        }
    },

    /**
     * Implementa un flujo de confirmación de dos pasos antes de ejecutar una acción destructiva.
     */
    confirmarAccion(boton, callback, textoConfirmar = "¿ESTÁ SEGURO?") {
        if (boton.dataset.confirmar === 'true') {
            callback();
            return;
        }

        const originalText = boton.innerHTML;
        boton.dataset.confirmar = 'true';
        boton.classList.add('confirmando');
        boton.textContent = textoConfirmar;

        const timeout = setTimeout(() => {
            if (boton) {
                boton.dataset.confirmar = 'false';
                boton.classList.remove('confirmando');
                boton.innerHTML = originalText;
            }
        }, 3000);

        boton._confirmTimeout = timeout;
    },

    /**
     * Lógica de actualización optimista genérica.
     * @param {Array} lista Arreglo local de datos.
     * @param {Function} apiCall Promesa que realiza la petición real.
     * @param {Function} renderCall Función para repintar la UI.
     */
    async operacionOptimista(lista, apiCall, renderCall, backup) {
        try {
            renderCall(lista);
            await apiCall();
        } catch (error) {
            if (backup) renderCall(backup);
            throw error;
        }
    },

    /**
     * Centraliza la validación de red antes de operaciones críticas.
     */
    verificarConexion() {
        const { online } = store.getState();
        if (!online) {
            if (window.mostrarToast) window.mostrarToast("SIN CONEXIÓN: ACCIÓN NO DISPONIBLE", "error");
            return false;
        }
        return true;
    }
};
