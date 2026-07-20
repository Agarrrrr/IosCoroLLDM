import { limitsManager } from './limitsManager.js';
import { Purchases } from '@revenuecat/purchases-capacitor';

// Llave oficial de RevenueCat
const REVENUECAT_API_KEY = 'goog_RoxJlYcfQtiNpbQvWBrEvLUsBMM';

export const revenueManager = {
    precioMensual: "$49.00 MXN",
    precioAnual: "$299.00 MXN",
    paqueteMensual: null,
    paqueteAnual: null,

    async inicializar() {
        if (window.Capacitor && window.Capacitor.isNativePlatform()) {
            try {
                await Purchases.configure({ apiKey: REVENUECAT_API_KEY });
                
                try {
                    const offerings = await Purchases.getOfferings();
                    if (offerings && offerings.current && offerings.current.availablePackages.length > 0) {
                        offerings.current.availablePackages.forEach(pkg => {
                            if (pkg.packageType === 'MONTHLY' || pkg.identifier === '$rc_monthly') {
                                this.paqueteMensual = pkg;
                                if (pkg.product && pkg.product.priceString) {
                                    this.precioMensual = pkg.product.priceString;
                                }
                            } else if (pkg.packageType === 'ANNUAL' || pkg.identifier === '$rc_annual') {
                                this.paqueteAnual = pkg;
                                if (pkg.product && pkg.product.priceString) {
                                    this.precioAnual = pkg.product.priceString;
                                }
                            }
                        });
                        
                        // Fallback si no usan los tipos por defecto
                        if (!this.paqueteAnual && offerings.current.availablePackages.length > 0) {
                            this.paqueteAnual = offerings.current.availablePackages[0];
                            this.precioAnual = this.paqueteAnual.product.priceString;
                        }
                    }
                } catch(e) {
                    console.warn("[RevenueCat] No se pudieron cargar los precios locales.", e);
                }

                // Actualizar caché de limitsManager según lo que diga Google/RevenueCat
                const customerInfo = await Purchases.getCustomerInfo();
                this._actualizarEstadoDesdeInfo(customerInfo.customerInfo);
            } catch (err) {
                console.warn("[RevenueCat] No se pudo conectar. Se usará el caché offline.", err);
            }
        }
    },

    _actualizarEstadoDesdeInfo(info) {
        if (info && info.entitlements && info.entitlements.active['premium']) {
            limitsManager.setPremium(true);
            console.log("[RevenueCat] Usuario es PREMIUM.");
        } else {
            limitsManager.setPremium(false);
            console.log("[RevenueCat] Usuario es FREE.");
        }
    },

    async comprarPremium(tipo = 'anual') {
        if (!window.Capacitor || !window.Capacitor.isNativePlatform()) {
            alert("Las compras solo están disponibles en la aplicación móvil.");
            return;
        }

        if (window.uiController && typeof window.uiController.mostrarToast === 'function') {
            window.uiController.mostrarToast("Conectando con la tienda...", "info");
        }

        try {
            const paqueteAComprar = tipo === 'mensual' ? this.paqueteMensual : this.paqueteAnual;
            let result;
            
            if (paqueteAComprar) {
                result = await Purchases.purchasePackage({ aPackage: paqueteAComprar });
            } else {
                // Fallback directo a Google si no cargaron los packages
                const productIdentifier = tipo === 'mensual' ? 'suscripcion_mensual_coro' : 'suscripcion_anual_coro';
                result = await Purchases.purchaseStoreProduct({ product: { identifier: productIdentifier, productCategory: "SUBSCRIPTION" } });
            }
            
            this._actualizarEstadoDesdeInfo(result.customerInfo);

            if (limitsManager.esPremium()) {
                if (window.uiController && typeof window.uiController.mostrarToast === 'function') {
                    window.uiController.mostrarToast("¡Gracias por tu compra! Tu app ahora es Premium.", "exito");
                }
                const modal = document.getElementById('modal-premium-paywall');
                if (modal) modal.style.display = 'none';
                if (window.uiController && typeof window.uiController.actualizarEstadoPremiumUI === 'function') {
                    window.uiController.actualizarEstadoPremiumUI();
                }
            } else {
                if (window.uiController && typeof window.uiController.mostrarToast === 'function') {
                    window.uiController.mostrarToast("La compra no se completó.", "error");
                }
            }

        } catch (e) {
            if (!e.userCancelled) {
                if (window.uiController && typeof window.uiController.mostrarToast === 'function') {
                    window.uiController.mostrarToast("Error al conectar: " + e.message, "error");
                }
            }
        }
    },

    async restaurarCompras() {
        if (!window.Capacitor || !window.Capacitor.isNativePlatform()) return;
        
        if (window.uiController && typeof window.uiController.mostrarToast === 'function') {
            window.uiController.mostrarToast("Restaurando compras...", "info");
        }
        
        try {
            const { customerInfo } = await Purchases.restorePurchases();
            this._actualizarEstadoDesdeInfo(customerInfo);
            
            if (limitsManager.esPremium()) {
                alert("Compras restauradas con éxito.");
                const modal = document.getElementById('modal-premium-paywall');
                if (modal) modal.classList.remove('visible');
                if (window.uiController && typeof window.uiController.actualizarEstadoPremiumUI === 'function') {
                    window.uiController.actualizarEstadoPremiumUI();
                }
            } else {
                alert("No se encontraron compras previas en esta cuenta.");
            }
        } catch (e) {
            alert("Error al restaurar: " + e.message);
        }
    }
};

window.revenueManager = revenueManager;
