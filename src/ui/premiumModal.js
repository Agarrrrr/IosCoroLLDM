import { store } from '../core/stateManager.js';
import { i18n } from '../core/i18n.js';
import { limitsManager } from '../core/limitsManager.js';

export const premiumModal = {
    mostrar(origen = 'sidebar') {
        const modalId = 'modal-premium-paywall';
        let modal = document.getElementById(modalId);
        
        let titulo, mensaje, mostrarVideoAd;
        
        if (origen === 'audio') {
            titulo = i18n.t('premium.titulo_limite');
            mensaje = i18n.t('premium.mensaje_limite');
            mostrarVideoAd = true;
        } else {
            titulo = i18n.t('premium.titulo_mejora');
            mensaje = i18n.t('premium.mensaje_mejora');
            mostrarVideoAd = false;
        }

        const precioString = window.revenueManager && window.revenueManager.precioPremium ? window.revenueManager.precioPremium : "Cargando Precio...";
        
        const txtPrueba = i18n.getLanguage() === 'en' ? 'FREE TRIAL' : 'PRUEBA GRATUITA';
        
        let trialMensualHTML = '';
        if (window.revenueManager && window.revenueManager.paqueteMensual && window.revenueManager.paqueteMensual.product.introPrice) {
            trialMensualHTML = `<div style="font-size: 10px; color: #10b981; font-weight: 800; margin-bottom: 4px; background: rgba(16, 185, 129, 0.1); padding: 3px 6px; border-radius: 6px; display: inline-block; letter-spacing: 0.5px;">${txtPrueba}</div>`;
        }

        let trialAnualHTML = '';
        if (window.revenueManager && window.revenueManager.paqueteAnual && window.revenueManager.paqueteAnual.product.introPrice) {
            trialAnualHTML = `<div style="font-size: 10px; color: #10b981; font-weight: 800; margin-bottom: 4px; background: rgba(16, 185, 129, 0.1); padding: 3px 6px; border-radius: 6px; display: inline-block; letter-spacing: 0.5px;">${txtPrueba}</div>`;
        }

        if (!modal) {
            modal = document.createElement('div');
            modal.id = modalId;
            modal.className = 'modal-overlay modal-sheet visible';
            document.body.appendChild(modal);
        }

        modal.innerHTML = `
            <div class="modal-card modal-premium-card" style="text-align: center; max-width: 360px; width: 90%; border-radius: 20px; background: var(--color-superficie); box-shadow: 0 10px 40px rgba(0,0,0,0.2); margin-top: 20px; position: relative;">
                <div style="background: var(--color-superficie-secundaria); padding: 40px 20px 20px; border-bottom: 1px solid var(--color-borde); border-radius: 20px 20px 0 0; position: relative;">
                    <div style="position: absolute; top: -25px; left: 50%; transform: translateX(-50%); width: 50px; height: 50px; background: linear-gradient(135deg, #d4af37, #aa7700); border-radius: 50%; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 10px rgba(212, 175, 55, 0.4); z-index: 2;">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg>
                    </div>
                    <h2 style="color: var(--color-texto); margin: 0; font-weight: 800; font-size: 20px; letter-spacing: 0.5px;">${i18n.t('premium.version_pro')}</h2>
                </div>
                <div style="padding: 30px 20px; max-height: 65vh; overflow-y: auto; border-radius: 0 0 20px 20px;">
                    <h3 style="margin-top: 0; color: var(--color-texto); font-size: 18px; font-weight: 700;">${titulo}</h3>
                    <p style="color: var(--color-texto-secundario); font-size: 14px; margin-bottom: 25px; line-height: 1.5;">
                        ${mensaje}
                    </p>
                    
                    <div style="display: flex; gap: 10px; margin-bottom: 25px;">
                        <div style="flex: 1; background: rgba(212, 175, 55, 0.05); border-radius: 12px; padding: 15px; border: 1px solid rgba(212, 175, 55, 0.2); text-align: center; cursor: pointer; transition: all 0.2s;" onclick="window.revenueManager.comprarPremium('mensual')">
                            ${trialMensualHTML}
                            <span style="display: block; font-size: 10px; color: var(--color-texto-secundario); text-transform: uppercase; font-weight: 800; letter-spacing: 1px; margin-bottom: 5px;">${i18n.t('premium.mensual')}</span>
                            <span style="font-size: 18px; font-weight: 800; color: var(--color-texto);">${window.revenueManager ? window.revenueManager.precioMensual : "$49.00 MXN"}</span>
                            <span style="display: block; font-size: 11px; color: var(--color-acento); font-weight: 600; margin-top: 6px;">${i18n.t('premium.seleccionar')}</span>
                        </div>
                        <div style="flex: 1; background: rgba(212, 175, 55, 0.15); border-radius: 12px; padding: 15px; border: 2px solid #aa7700; text-align: center; cursor: pointer; position: relative; transition: all 0.2s;" onclick="window.revenueManager.comprarPremium('anual')">
                            <div style="position: absolute; top: -10px; left: 50%; transform: translateX(-50%); background: #aa7700; color: white; font-size: 9px; font-weight: 800; padding: 2px 8px; border-radius: 10px; letter-spacing: 0.5px; white-space: nowrap;">${i18n.t('premium.mejor_valor')}</div>
                            ${trialAnualHTML}
                            <span style="display: block; font-size: 10px; color: #aa7700; text-transform: uppercase; font-weight: 800; letter-spacing: 1px; margin-bottom: 5px;">${i18n.t('premium.anual')}</span>
                            <span style="font-size: 18px; font-weight: 800; color: var(--color-texto);">${window.revenueManager ? window.revenueManager.precioAnual : "$299.00 MXN"}</span>
                            <span style="display: block; font-size: 11px; color: #aa7700; font-weight: 800; margin-top: 6px;">${i18n.t('premium.seleccionar')}</span>
                        </div>
                    </div>
                    
                    ${mostrarVideoAd ? `
                    <button id="btn-recompensa-premium" style="width: 100%; padding: 14px; background: transparent; color: var(--color-texto); border: 1px solid var(--color-borde); border-radius: 12px; font-size: 14px; font-weight: 600; cursor: pointer; margin-top: 10px; display: flex; align-items: center; justify-content: center; gap: 8px;">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polygon points="10 8 16 12 10 16 10 8"></polygon></svg> ${i18n.t('premium.btn_video')}
                    </button>
                    ` : ''}

                    ${origen === 'anuncios' ? `
                    <label style="display: flex; align-items: center; justify-content: center; gap: 8px; font-size: 12px; color: var(--color-texto-suave); margin-top: 15px; cursor: pointer;">
                        <input type="checkbox" id="chk-no-mostrar-pro"> ${i18n.t('premium.no_volver_mostrar')}
                    </label>
                    ` : ''}

                    <button id="btn-cerrar-premium" style="width: 100%; padding: 12px; background: transparent; color: var(--color-texto-suave); border: none; font-size: 14px; font-weight: 600; cursor: pointer; margin-top: 10px;">
                        ${i18n.t('premium.btn_quizas')}
                    </button>
                    
                    <button id="btn-restaurar-compras" style="width: 100%; padding: 12px 12px 0 12px; background: transparent; color: var(--color-texto-secundario); border: none; font-size: 13px; text-decoration: underline; cursor: pointer; margin-top: 5px;">
                        ${i18n.t('premium.restaurar_compras')}
                    </button>
                </div>
            </div>
        `;

        modal.style.display = 'flex';
        modal.classList.add('visible');

        document.getElementById('btn-cerrar-premium').onclick = () => {
            const chk = document.getElementById('chk-no-mostrar-pro');
            if (chk && chk.checked) {
                localStorage.setItem('ocultar_modal_pro_anuncios', 'true');
            }
            modal.style.display = 'none';
            modal.classList.remove('visible');
        };

        const btnRestaurar = document.getElementById('btn-restaurar-compras');
        if (btnRestaurar) {
            btnRestaurar.onclick = () => {
                if (window.revenueManager) window.revenueManager.restaurarCompras();
            };
        }


        const btnRecompensa = document.getElementById('btn-recompensa-premium');
        if (btnRecompensa) {
            btnRecompensa.onclick = async () => {
                if (limitsManager.estaBloqueadoPorDRM()) {
                    if (window.uiController) window.uiController.mostrarToast("Reseteo bloqueado. Conéctate a internet para certificar tu hora local.", "error");
                    return;
                }

                if (!window.adManager || !window.adManager._rewardedCargado) {
                    if (window.uiController) window.uiController.mostrarToast("Anuncio no disponible en este momento. Revisa tu conexión o intenta más tarde.", "error");
                    return;
                }
                
                const textoOriginal = btnRecompensa.innerHTML;
                btnRecompensa.innerHTML = 'Cargando...';
                btnRecompensa.disabled = true;

                const exito = await window.adManager.mostrarAnuncioRecompensaMidi();
                
                btnRecompensa.innerHTML = textoOriginal;
                btnRecompensa.disabled = false;

                if (exito) {
                    modal.style.display = 'none';
                    modal.classList.remove('visible');
                    limitsManager.concederAudioExtra();
                    if (window.midiEngine) window.midiEngine.play();
                } else {
                    if (window.uiController) window.uiController.mostrarToast("No se pudo desbloquear el audio. Asegúrate de ver el anuncio completo y no usar AdBlockers.", "error");
                }
            };
        }
    }
};
