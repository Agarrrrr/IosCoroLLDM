import { uiController } from './uiController.js';
import { i18n } from '../core/i18n.js';
import { store } from '../core/stateManager.js';

export const buscadorUI = {
    temaActual: 'Todos',
    
    limpiarTexto: function(texto) {
        return texto.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/['"!?¿¡.,()]/g, "").toLowerCase().trim();
    },

    _cacheTemasPorLista: new WeakMap(),

    generarMenuTemas: function(lista, listaTemasElement, callbackFiltro) {
        if (!this._cacheTemasPorLista) this._cacheTemasPorLista = new WeakMap();
        
        let temasData;
        if (this._cacheTemasPorLista.has(lista)) {
            temasData = this._cacheTemasPorLista.get(lista);
        } else {
            let mapaTemas = new Map();
            lista.forEach(c => {
                if (c.temas) {
                    c.temas.forEach(t => {
                        let limpio = t.trim();
                        if (!limpio) return;
                        let key = this.limpiarTexto(limpio);
                        if (!mapaTemas.has(key)) {
                            if (limpio === limpio.toLowerCase()) {
                                limpio = limpio.charAt(0).toUpperCase() + limpio.slice(1);
                            }
                            mapaTemas.set(key, limpio);
                        } else {
                            let guardado = mapaTemas.get(key);
                            if (/[áéíóúÁÉÍÓÚñÑ]/.test(limpio) && !/[áéíóúÁÉÍÓÚñÑ]/.test(guardado)) {
                                mapaTemas.set(key, limpio);
                            }
                        }
                    });
                }
            });
            let temasUnicos = Array.from(mapaTemas.values());
            temasUnicos.sort((a, b) => a.localeCompare(b, 'es'));
            const tieneCantosSinTema = lista.some(c => !c.temas || c.temas.filter(t => t.trim() !== '').length === 0);
            
            temasData = { temasUnicos, tieneCantosSinTema };
            this._cacheTemasPorLista.set(lista, temasData);
        }

        let temasUnicos = temasData.temasUnicos;
        let tieneCantosSinTema = temasData.tieneCantosSinTema;

        listaTemasElement.innerHTML = ''; // Limpieza segura

        const crearItem = (texto, dataTema, activo = false) => {
            const div = document.createElement('div');
            div.className = activo ? 'item-tema activo' : 'item-tema';
            div.setAttribute('data-tema', dataTema);
            div.textContent = texto;
            div.addEventListener('click', (e) => {
                document.querySelectorAll('.item-tema').forEach(i => i.classList.remove('activo'));
                div.classList.add('activo');
                this.temaActual = dataTema;
                callbackFiltro(dataTema);
            });
            return div;
        };

        listaTemasElement.appendChild(crearItem(i18n.t('buscador.todos'), 'Todos', true));
        
        if (tieneCantosSinTema) {
            listaTemasElement.appendChild(crearItem(i18n.t('buscador.sin_tema_especifico'), 'Sin Tema'));
        }

        temasUnicos.forEach(tema => {
            listaTemasElement.appendChild(crearItem(tema, tema));
        });
    },

    filtrarCantos: function(cantos, inputTexto) {
        const textoBuscado = this.limpiarTexto(inputTexto);
        const palabrasBusqueda = textoBuscado.split(' ').filter(p => p !== '');
        
        let filtrados = cantos.filter(c => {
            if (!c._nombreLimpioCache) c._nombreLimpioCache = this.limpiarTexto(c.nombre);
            const nombreLimpio = c._nombreLimpioCache;
            const coincideTexto = palabrasBusqueda.every(palabra => nombreLimpio.includes(palabra));
            
            let coincideTema = false;
            if (this.temaActual === 'Todos') coincideTema = true;
            else if (this.temaActual === 'Sin Tema') coincideTema = (c.temas.length === 0);
            else coincideTema = c.temas.includes(this.temaActual);

            return (coincideTexto || palabrasBusqueda.length === 0) && coincideTema;
        });

        if (textoBuscado !== '') {
            filtrados.sort((a, b) => {
                if (!a._nombreLimpioCache) a._nombreLimpioCache = this.limpiarTexto(a.nombre);
                if (!b._nombreLimpioCache) b._nombreLimpioCache = this.limpiarTexto(b.nombre);
                const nombreA = a._nombreLimpioCache;
                const nombreB = b._nombreLimpioCache;
                
                let puntosA = 0; let puntosB = 0;
                
                // Prioridad 1: Empieza exactamente con la búsqueda (ej. "Tu gloria" -> "Tu gloria llena")
                if (nombreA.startsWith(textoBuscado)) puntosA += 200;
                if (nombreB.startsWith(textoBuscado)) puntosB += 200;
                
                // Prioridad 2: Contiene la frase exacta de búsqueda junta (ej. "la grandeza de tu gloria")
                if (nombreA.includes(textoBuscado)) puntosA += 100;
                if (nombreB.includes(textoBuscado)) puntosB += 100;
                
                // Prioridad 3: La primera palabra coincide (ej. "tu" -> "Tu fidelidad")
                if (nombreA.split(' ')[0] === palabrasBusqueda[0]) puntosA += 50;
                if (nombreB.split(' ')[0] === palabrasBusqueda[0]) puntosB += 50;
                
                if (puntosA !== puntosB) return puntosB - puntosA; 
                return nombreA.localeCompare(nombreB, 'es', { 
                    sensitivity: 'base',
                    numeric: true,
                    ignorePunctuation: true
                });
            });
        }
        return filtrados;
    },

    renderizarLista: function(lista, contenedorElement, onClickCanto, mensajeVacio = null) {
        if (this._scrollVirtualInstancia) {
            this._scrollVirtualInstancia.destruir();
            this._scrollVirtualInstancia = null;
        }

        const renderItem = (canto) => {
            const div = document.createElement('div');
            div.className = 'tarjeta-canto';
            div.setAttribute('data-id', canto.id);
            div.setAttribute('data-nombre', canto.nombre);
            div.style.display = 'flex';
            div.style.justifyContent = 'space-between';
            div.style.alignItems = 'center';
            
            const info = document.createElement('div');
            info.className = 'info-canto';
            info.style.flex = '1';
            const h3 = document.createElement('h3');
            h3.style.display = 'flex';
            h3.style.alignItems = 'center';
            h3.style.gap = '8px';
            
            const spanNombre = document.createElement('span');
            spanNombre.textContent = canto.nombre;
            h3.appendChild(spanNombre);

            if (false && canto.midi_archivo) {
                const divAudio = document.createElement('div');
                divAudio.innerHTML = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="color: var(--color-acento)"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>`;
                divAudio.style.display = 'flex';
                h3.appendChild(divAudio);
            }
            
            info.appendChild(h3);

            const temasContenedor = document.createElement('div');
            temasContenedor.style.cssText = 'display: flex; gap: 6px; flex-wrap: wrap; margin-top: 5px;';

            if (canto.temas && canto.temas.length > 0) {
                let vistos = new Set();
                let temasUnicosCanto = [];
                canto.temas.forEach(t => {
                    let limpio = t.trim();
                    if (!limpio) return;
                    let key = buscadorUI.limpiarTexto(limpio);
                    if (!vistos.has(key)) {
                        vistos.add(key);
                        // Capitalizar primera letra por consistencia
                        if (limpio === limpio.toLowerCase()) {
                            limpio = limpio.charAt(0).toUpperCase() + limpio.slice(1);
                        }
                        temasUnicosCanto.push(limpio);
                    }
                });

                if (temasUnicosCanto.length > 0) {
                    temasUnicosCanto.forEach(t => {
                        const span = document.createElement('span');
                        span.className = 'tema-etiqueta';
                        span.textContent = t;
                        temasContenedor.appendChild(span);
                    });
                } else {
                    const span = document.createElement('span');
                    span.className = 'tema-etiqueta';
                    span.style.opacity = '0.4';
                    span.textContent = i18n.t('buscador.sin_tema');
                    temasContenedor.appendChild(span);
                }
            } else {
                const span = document.createElement('span');
                span.className = 'tema-etiqueta';
                span.style.opacity = '0.4';
                span.textContent = i18n.t('buscador.sin_tema');
                temasContenedor.appendChild(span);
            }
            
            info.appendChild(temasContenedor);
            div.appendChild(info);

            // Botón Favorito
            const favs = JSON.parse(localStorage.getItem('favoritos_repertorio') || '[]');
            const isFav = favs.includes(canto.id);
            const btnFav = document.createElement('button');
            btnFav.className = 'btn-fav';
            // Incrementar significativamente el área táctil (touch target) sin afectar el layout visual
            btnFav.style.cssText = 'background: none; border: none; padding: 20px; margin: -10px -10px -10px 0; cursor: pointer; display: flex; align-items: center; justify-content: center; color: var(--color-texto-suave); position: relative; z-index: 2;';
            btnFav.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="${isFav ? 'var(--color-acento)' : 'none'}" stroke="${isFav ? 'var(--color-acento)' : 'currentColor'}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path></svg>`;
            
            btnFav.addEventListener('click', (e) => {
                e.stopPropagation();
                let currentFavs = JSON.parse(localStorage.getItem('favoritos_repertorio') || '[]');
                
                // Remove animation class before triggering again
                btnFav.classList.remove('heart-burst-anim');
                // Force reflow
                void btnFav.offsetWidth;

                if (currentFavs.includes(canto.id)) {
                    currentFavs = currentFavs.filter(id => id !== canto.id);
                    btnFav.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path></svg>`;
                    uiController.mostrarToast('Eliminado de Favoritos');
                } else {
                    currentFavs.push(canto.id);
                    btnFav.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="var(--color-acento)" stroke="var(--color-acento)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path></svg>`;
                    btnFav.classList.add('heart-burst-anim');
                    uiController.mostrarToast('Añadido a Favoritos', 'exito');
                }
                localStorage.setItem('favoritos_repertorio', JSON.stringify(currentFavs));
                
                if (store.getState().categoriaActiva === 'favoritos' && !currentFavs.includes(canto.id)) {
                    div.style.display = 'none';
                }
            });

            div.appendChild(btnFav);

            div.addEventListener('click', () => {
                onClickCanto(canto);
            });

            return div;
        };

        this._scrollVirtualInstancia = uiController.crearScrollVirtual({
            contenedor: contenedorElement,
            datos: lista,
            renderItem: renderItem,
            alturaItem: 95, 
            gap: 12, 
            buffer: 25,
            mensajeVacio: mensajeVacio
        });
    }
};