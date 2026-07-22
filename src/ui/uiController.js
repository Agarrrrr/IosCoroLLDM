import { store } from '../core/stateManager.js';
import { i18n } from '../core/i18n.js';
import { premiumModal } from './premiumModal.js';
import { getThemeColors, getAllThemes, THEME_BASE_PROPS } from '../core/themeConfig.js';
import { limitsManager } from '../core/limitsManager.js';

export const uiController = {
    mostrarModalPremium(origen = '') {
        // No-op: todos los usuarios son Premium por defecto
    },
    
    actualizarEstadoPremiumUI() {
        const esPro = limitsManager.esPremium();
        const tagPro = document.getElementById('tag-pro-sidebar');
        const tagBasico = document.getElementById('tag-basico-sidebar');
        const btnSidebarPro = document.getElementById('btn-sidebar-pro');
        
        if (tagPro) tagPro.style.display = esPro ? 'inline-block' : 'none';
        if (tagBasico) tagBasico.style.display = esPro ? 'none' : 'inline-block';
        if (btnSidebarPro) btnSidebarPro.style.display = esPro ? 'none' : 'flex';
        
        if (esPro && window.adManager) {
            window.adManager.ocultarBanner();
        }
    },
    temasDisponibles: getAllThemes(),

    inicializarTema() {
        const temaGuardado = localStorage.getItem('tema-ui') || 'claro';
        this.aplicarTema(temaGuardado);
        
        const btnSelectorTema = document.getElementById('btn-selector-tema');
        if (btnSelectorTema) {
            btnSelectorTema.addEventListener('click', (e) => {
                e.stopPropagation();
                this.toggleMenuTemas();
            });
        }

        // Cerrar menú al hacer click fuera
        document.addEventListener('click', () => {
            this.cerrarMenuTemas();
        });
    },

    aplicarTema(nombreTema) {
        const root = document.documentElement;
        
        // Mantener clase base para hooks específicos oscuros globales si se ocupan
        const isDark = ['oscuro', 'contraste', 'oled', 'quiet'].includes(nombreTema);
        root.classList.toggle('tema-oscuro', isDark); // Mantenemos SOLO este fallback semántico
        
        // Inyectar Custom Properties dinámicamente
        const props = getThemeColors(nombreTema);
        const allProps = { ...THEME_BASE_PROPS, ...props };
        
        Object.entries(allProps).forEach(([key, val]) => {
            root.style.setProperty(key, val);
        });
        
        localStorage.setItem('tema-ui', nombreTema);
        this.actualizarIconosTema(nombreTema);
        this.actualizarMetaThemeColor(nombreTema);

        // Propagar el tema al visor PDF nativo si está activo
        if (window.pdfEngine && window.pdfEngine._modoNativo && window.pdfEngine._nativeBridge) {
            window.pdfEngine._nativeBridge.setTheme(nombreTema);
        }

        // Sincronizar con el store global si es posible
        if (store) {
            store.setState({ temaUI: nombreTema });
        }
    },

    actualizarMetaThemeColor(tema) {
        const colores = {
            'claro': '#fdfdfd',
            'oscuro': '#11161c',
            'sepia': '#f4ecd8',
            'contraste': '#000000',
            'oled': '#000000',
            'quiet': '#1c1c1e',
            'rosa': '#ffffff',
            'azul': '#ffffff',
            'jade': '#ffffff',
            'rojo': '#ffffff',
            'morado': '#ffffff'
        };
        
        const color = colores[tema] || '#fdfdfd';
        let meta = document.querySelector('meta[name="theme-color"]');
        if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'theme-color';
            document.head.appendChild(meta);
        }
        meta.setAttribute('content', color);

        if (window.Capacitor && window.Capacitor.isNativePlatform()) {
            /* // ponytail: Status bar dynamic styling removed (plugin crashes in iOS build). YAGNI. Standard iOS behavior will prevail. Upgrade path: wait for Capacitor to patch the status-bar plugin for Swift 6/Cap 8 API.
            import('@capacitor/status-bar').then(({ StatusBar, Style }) => {
                const style = ['claro', 'sepia', 'rosa', 'azul', 'jade', 'rojo', 'morado'].includes(tema) ? Style.Light : Style.Dark;
                StatusBar.setOverlaysWebView({ overlay: false }).catch(()=>{});
                StatusBar.setStyle({ style }).catch(()=>{});
                StatusBar.setBackgroundColor({ color }).catch(()=>{});
            }).catch(()=>{});
            */

            /* // ponytail: Navigation bar plugin also crashes on iOS build. YAGNI.
            import('@capgo/capacitor-navigation-bar').then(({ NavigationBar }) => {
                const isDark = ['oscuro', 'contraste', 'oled', 'quiet'].includes(tema);
                NavigationBar.setNavigationBarColor({ color, darkButtons: !isDark }).catch(()=>{});
            }).catch(()=>{});
            */
        }
    },

    toggleMenuTemas(ancla = null) {
        let menu = document.getElementById('menu-contextual-temas');
        if (menu) {
            this.cerrarMenuTemas();
        } else {
            this.mostrarMenuTemas(ancla);
        }
    },

    mostrarMenuTemas(ancla = null) {
        const menu = document.createElement('div');
        menu.id = 'menu-contextual-temas';
        menu.className = 'menu-contextual-temas';
        
        // Filtrar solo los temas "principales" o todos según preferencia. 
        // Aquí mostramos todos para dar libertad total.
        this.temasDisponibles.forEach(tema => {
            const item = document.createElement('div');
            item.className = 'menu-item-tema';
            item.innerHTML = `
                <span class="tema-muestra-mini ${tema}" style="background: ${this.obtenerColorMuestra(tema)}"></span>
                <span class="tema-nombre-mini">${i18n.t('tema.' + tema)}</span>
            `;
            item.addEventListener('click', () => {
                this.aplicarTema(tema);
                if (typeof window.actualizarBotonesAjustesTema === 'function') {
                    window.actualizarBotonesAjustesTema();
                }
                this.cerrarMenuTemas();
            });
            menu.appendChild(item);
        });

        document.body.appendChild(menu);
        
        // Posicionamiento dinámico cerca del botón ancla (o el por defecto)
        const btn = ancla || document.getElementById('btn-selector-tema');
        const rect = btn.getBoundingClientRect();
        menu.style.top = `${rect.bottom + 10}px`;
        menu.style.right = `${window.innerWidth - rect.right}px`;
    },

    obtenerColorMuestra(tema) {
        const muestras = {
            'claro': '#ffffff',
            'oscuro': '#1b2430',
            'sepia': '#f4ecd8',
            'contraste': '#000000',
            'oled': '#000000',
            'quiet': '#1c1c1e',
            'rosa': '#ffb7c5',
            'azul': '#0047ab',
            'jade': '#00a86b',
            'rojo': '#ff6b6b',
            'morado': '#9775fa'
        };
        return muestras[tema] || '#ffffff';
    },

    cerrarMenuTemas() {
        const menu = document.getElementById('menu-contextual-temas');
        if (menu) menu.remove();
    },

    actualizarIconosTema(tema) {
        const lunas = document.querySelectorAll('.icono-tema-luna');
        const soles = document.querySelectorAll('.icono-tema-sol');
        
        if (lunas.length === 0 && soles.length === 0) return;

        // Luna para temas claros/suaves, Sol para temas oscuros (incluido Quiet)
        const esClaro = ['claro', 'sepia', 'rosa', 'azul', 'jade', 'rojo', 'morado'].includes(tema);
        
        lunas.forEach(luna => luna.style.display = esClaro ? 'block' : 'none');
        soles.forEach(sol => sol.style.display = esClaro ? 'none' : 'block');
    },


    alternarSidebar(sidebar, overlay, forzarCierre = false) {
        if (!sidebar || !overlay) return;
        if (forzarCierre) sidebar.classList.add('oculto');
        else sidebar.classList.toggle('oculto');
        
        const estaAbierto = !sidebar.classList.contains('oculto');
        const esMovilOTablet = window.innerWidth <= 1024;
        
        if (esMovilOTablet) {
            if (estaAbierto) {
                overlay.style.display = 'block';
                overlay.classList.add('activo');
                setTimeout(() => overlay.style.opacity = '1', 10);
            } else {
                overlay.style.opacity = '0';
                overlay.classList.remove('activo');
                setTimeout(() => {
                    if (sidebar.classList.contains('oculto')) {
                        overlay.style.display = 'none';
                    }
                }, 300);
            }
        } else {
            // En pantalla grande (> 1024px), el overlay NUNCA debe estar visible
            overlay.style.opacity = '0';
            overlay.classList.remove('activo');
            overlay.style.display = 'none';
        }
    },

    cerrarModal(modalOrId) {
        const modal = typeof modalOrId === 'string' ? document.getElementById(modalOrId) : modalOrId;
        if (modal) {
            modal.style.display = 'none';
            modal.classList.remove('visible');
        }
    },

    cerrarBanner(id) {
        const banner = document.getElementById(id);
        if (banner) {
            banner.style.transform = 'translateX(-50%) translateY(-150%)';
            setTimeout(() => {
                banner.style.display = 'none';
                banner.style.transform = ''; // Resetear para la próxima vez
            }, 300);
        }
    },

    mostrarToast(mensaje, tipo = 'exito') {
        // 1. Buscamos el contenedor. Si no existe, lo creamos dinámicamente
        let contenedor = document.getElementById('contenedor-toasts');
        
        if (!contenedor) {
            contenedor = document.createElement('div');
            contenedor.id = 'contenedor-toasts';
            document.body.appendChild(contenedor);
        }

        // 2. Creamos y agregamos el toast
        const toast = document.createElement('div');
        toast.className = `toast ${tipo}`;
        toast.textContent = mensaje.toUpperCase();
        contenedor.appendChild(toast);

        // 3. Temporizador para desaparecerlo
        setTimeout(() => {
            toast.style.animation = 'toastOut 0.4s ease forwards';
            setTimeout(() => toast.remove(), 400);
        }, 4000);
    },

    confirmarBotonIcono(boton) {
        if (!boton) return;
        boton.classList.add('estado-confirmado');
    
        setTimeout(() => {
            if (document.body.contains(boton)) {
                boton.classList.remove('estado-confirmado');
            }
        }, 1000);
    },

    crearScrollVirtual: function(opciones) {
        const {
            contenedor, 
            datos, 
            renderItem, 
            alturaItem = 95, 
            gap = 12, 
            buffer = 25,
            mensajeVacio
        } = opciones;

        contenedor.innerHTML = '';
        
        if (datos.length === 0) {
            const p = document.createElement('p');
            p.style.cssText = 'text-align:center; padding:20px; color:#888; margin: auto; line-height: 1.5;';
            p.innerHTML = mensajeVacio || i18n.t('buscador.sin_resultados');
            contenedor.appendChild(p);
            return null;
        }

        const alturaFila = alturaItem + gap;
        const totalHeight = datos.length * alturaFila;

        if (getComputedStyle(contenedor).position === 'static') {
            contenedor.style.position = 'relative';
        }

        // Spacer para crear el scroll real
        const spacer = document.createElement('div');
        spacer.style.flexShrink = '0';
        spacer.style.width = '1px';
        spacer.style.height = `${totalHeight}px`;
        spacer.style.pointerEvents = 'none';
        spacer.style.visibility = 'hidden';

        // Wrapper donde se renderizarán los elementos
        const wrapper = document.createElement('div');
        wrapper.style.position = 'absolute';
        wrapper.style.top = '15px'; // Compensa padding-top del contenedor
        wrapper.style.left = '20px'; // Compensa padding-left del contenedor
        wrapper.style.right = '20px'; // Compensa padding-right
        wrapper.style.display = 'flex';
        wrapper.style.flexDirection = 'column';
        wrapper.style.gap = `${gap}px`;
        
        contenedor.appendChild(spacer);
        contenedor.appendChild(wrapper);

        let ultimoStartIndex = -1;

        const renderizar = () => {
            const scrollTop = contenedor.scrollTop;
            let startIndex = Math.floor(scrollTop / alturaFila);
            
            startIndex = Math.max(0, Math.min(startIndex, datos.length - buffer));
            if (datos.length <= buffer) startIndex = 0;

            if (startIndex === ultimoStartIndex) return;
            ultimoStartIndex = startIndex;
            
            wrapper.style.transform = `translateY(${startIndex * alturaFila}px)`;
            
            wrapper.innerHTML = '';
            const fragment = document.createDocumentFragment();
            
            const limit = Math.min(startIndex + buffer, datos.length);
            for (let i = startIndex; i < limit; i++) {
                const node = renderItem(datos[i]);
                node.style.height = `${alturaItem}px`;
                node.style.boxSizing = 'border-box';
                node.style.flexShrink = '0';
                fragment.appendChild(node);
            }
            wrapper.appendChild(fragment);
        };

        const onScroll = () => {
            window.requestAnimationFrame(renderizar);
        };
        
        contenedor.addEventListener('scroll', onScroll, { passive: true });
        renderizar();

        return {
            destruir: () => {
                contenedor.removeEventListener('scroll', onScroll);
                contenedor.innerHTML = '';
            }
        };
    }
};

window.uiController = uiController;
