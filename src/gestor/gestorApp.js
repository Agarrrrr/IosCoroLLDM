import '../core/polyfills.js';
import { globalErrorHandler } from '../core/globalErrorHandler.js';
globalErrorHandler.iniciar();

import { store } from '../core/stateManager.js';
import { pdfEngine } from '../core/pdfEngine.js';

// Registrar limpieza global
window.limpiarRecursos = async () => {
    await pdfEngine.limpiarMotorPdf();
    if(window.midiEngine) window.midiEngine.stop();
};

import { inicializarPartiturasPanel } from './partituras/partiturasPanel.js';
import { uiController } from '../ui/uiController.js';

// Sobreescribir mostrarToast global para el gestor (específico para su UI)
window.mostrarToast = (mensaje, tipo = 'exito') => uiController.mostrarToast(mensaje, tipo);
window.confirmarBotonIcono = (boton) => uiController.confirmarBotonIcono(boton);

const CONFIG = {
    SELECTORES: {
        MENSAJE_CARGA: 'estado-carga-global'
    }
};

window.GESTOR_STATE = {
    get sedeId() { return 'local'; }
};

async function inicializarGestor() {
    // Cálculo de VH real para navegadores móviles
    const updateVH = () => {
        let vh = window.innerHeight * 0.01;
        document.documentElement.style.setProperty('--vh', `${vh}px`);
    };
    window.addEventListener('resize', updateVH);
    updateVH();

    try {
        store.setState({ categoriaActiva: 'local' });
        
        const panel = document.getElementById('panel-partituras');
        if (panel) panel.hidden = false;
        
        await inicializarPartiturasPanel('local');
        
        const loader = document.getElementById(CONFIG.SELECTORES.MENSAJE_CARGA);
        if (loader) loader.style.display = 'none';

        // Listeners de cierre de modales
        const btnCerrarModal = document.getElementById('btn-cerrar-modal');
        if (btnCerrarModal) {
            btnCerrarModal.addEventListener('click', () => uiController.cerrarModal('modal-partitura'));
        }
        
        const btnCerrarVistaPrevia = document.getElementById('btn-cerrar-vista-previa');
        if (btnCerrarVistaPrevia) {
            btnCerrarVistaPrevia.addEventListener('click', () => uiController.cerrarModal('modal-vista-previa'));
        }

        // --- CIERRE GLOBAL DE MODALES AL HACER CLICK FUERA (OVERLAY) ---
        document.addEventListener('click', function(e) {
            if (e.target.classList.contains('modal-overlay')) {
                e.target.style.display = 'none';
                
                if (e.target.id === 'modal-vista-previa') {
                    const previewContainer = document.getElementById('contenedor-preview-pdf');
                    if (previewContainer) previewContainer.innerHTML = '';
                }
            }
        });

    } catch (err) {
        console.warn('Error inicialización:', err);
        const loader = document.getElementById(CONFIG.SELECTORES.MENSAJE_CARGA);
        if (loader) loader.style.display = 'none';
    }
}



const btnPublico = document.getElementById('btn-ir-publico');
if (btnPublico) btnPublico.onclick = () => window.location.href = '/index.html';

inicializarGestor();