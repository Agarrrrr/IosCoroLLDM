// src/api/localDB.js

export const localDB = {
    _cacheCantos: null,
    _cacheLocale: null,

    async _loadCantos() {
        // Calcular locale antes de validar caché, para que un cambio de idioma la invalide
        const locale = localStorage.getItem('appLang') || (navigator.language.startsWith('es') ? 'es' : 'en');
        // En desarrollo, ignoramos el caché en memoria para siempre ver lo último
        // En producción, el caché también se invalida si el locale cambió en la sesión
        if (this._cacheCantos && this._cacheLocale === locale && !import.meta.env.DEV) return this._cacheCantos;
        
        try {
            // locale ya calculado arriba para la validación de caché
            const catalogoUrl = locale === 'en' ? '/offline_assets/catalogo_en.json' : '/offline_assets/catalogo.json';
            const urlParams = import.meta.env.DEV ? `?t=${Date.now()}` : '';
            const response = await fetch(catalogoUrl + urlParams);
            let baseCantos = await response.json();
            baseCantos.forEach(c => c._idioma = locale);
            
            // Cargar overrides locales (ediciones hechas desde el gestor)
            const overrides = import.meta.env.DEV ? [] : JSON.parse(localStorage.getItem('cantos_overrides') || '[]');
            const eliminados = import.meta.env.DEV ? [] : JSON.parse(localStorage.getItem('cantos_eliminados') || '[]');
            
            // Filtrar eliminados
            baseCantos = baseCantos.filter(c => !eliminados.includes(c.id));
            
            // Aplicar overrides y agregados
            const mapBase = new Map(baseCantos.map(c => [c.id, c]));
            for (const c of overrides) {
                if (mapBase.has(c.id)) {
                    // Override de un canto existente en este idioma
                    const base = mapBase.get(c.id);
                    mapBase.set(c.id, { ...base, ...c, _idioma: base._idioma });
                } else if (c._idioma === locale || c.nuevo_local) {
                    // Es un canto nuevo creado en este idioma (identificado explícitamente)
                    // Si no tiene _idioma ni es nuevo, asumimos que es del otro catálogo.
                    mapBase.set(c.id, c);
                }
            }
            
            const cantosArray = Array.from(mapBase.values());

            const normalizar = (str) => {
                if (!str) return '';
                return str.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
            };

            cantosArray.forEach(c => {
                c._nombre_norm = normalizar(c.nombre);
                c._autor_norm = normalizar(c.autor);
            });

            cantosArray.sort((a, b) => {
                const nomA = (a.nombre || '').toLowerCase();
                const nomB = (b.nombre || '').toLowerCase();
                return nomA.localeCompare(nomB, 'es', { 
                    sensitivity: 'base',
                    numeric: true,
                    ignorePunctuation: true
                });
            });
            this._cacheLocale = locale;
            this._cacheCantos = cantosArray;
            return this._cacheCantos;
        } catch (e) {
            console.error('Error cargando catálogo local', e);
            return [];
        }
    },

    async getCantos() {
        return await this._loadCantos();
    },

    async getAmbosCatalogos() {
        try {
            const urlParams = import.meta.env.DEV ? `?t=${Date.now()}` : '';
            const respEs = await fetch('/offline_assets/catalogo.json' + urlParams);
            const cantosEs = await respEs.json();
            cantosEs.forEach(c => c._idioma = 'es');
            
            const respEn = await fetch('/offline_assets/catalogo_en.json' + urlParams);
            const cantosEn = await respEn.json();
            cantosEn.forEach(c => c._idioma = 'en');
            
            let baseCantos = [...cantosEs, ...cantosEn];
            
            const overrides = import.meta.env.DEV ? [] : JSON.parse(localStorage.getItem('cantos_overrides') || '[]');
            const eliminados = import.meta.env.DEV ? [] : JSON.parse(localStorage.getItem('cantos_eliminados') || '[]');
            
            baseCantos = baseCantos.filter(c => !eliminados.includes(c.id));
            
            const mapBase = new Map(baseCantos.map(c => [c.id, c]));
            for (const c of overrides) {
                const base = mapBase.get(c.id);
                if (base) {
                    mapBase.set(c.id, { ...base, ...c, _idioma: base._idioma });
                } else {
                    mapBase.set(c.id, c);
                }
            }
            
            const cantosArray = Array.from(mapBase.values());

            const normalizar = (str) => {
                if (!str) return '';
                return str.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
            };

            cantosArray.forEach(c => {
                c._nombre_norm = normalizar(c.nombre);
                c._autor_norm = normalizar(c.autor);
            });
            
            cantosArray.sort((a, b) => {
                const nomA = (a.nombre || '').toLowerCase();
                const nomB = (b.nombre || '').toLowerCase();
                return nomA.localeCompare(nomB, 'es', { 
                    sensitivity: 'base',
                    numeric: true,
                    ignorePunctuation: true
                });
            });

            // Auto-curación de vínculos bidireccionales retroactivos
            let overridesModificados = false;
            for (const c of cantosArray) {
                if (c.vinculo_idioma) {
                    const vinculado = cantosArray.find(x => x.id === c.vinculo_idioma);
                    if (vinculado && vinculado.vinculo_idioma !== c.id) {
                        vinculado.vinculo_idioma = c.id;
                        const vIdx = overrides.findIndex(o => o.id === vinculado.id);
                        if (vIdx >= 0) {
                            overrides[vIdx].vinculo_idioma = c.id;
                        } else {
                            const vinculadoLimpio = { ...vinculado };
                            overrides.push(vinculadoLimpio);
                        }
                        overridesModificados = true;
                    }
                }
            }
            if (overridesModificados && !import.meta.env.DEV) {
                localStorage.setItem('cantos_overrides', JSON.stringify(overrides));
            }
            
            return cantosArray;
        } catch (e) {
            console.error('Error cargando ambos catalogos', e);
            // Fallback a getCantos normal
            return await this.getCantos();
        }
    },

    async getCanto(id) {
        const cantos = await this._loadCantos();
        return cantos.find(c => c.id === id);
    },

    async saveCanto(cantoData, editandoId = null) {
        await this._loadCantos();
        let nuevo = false;
        
        let idFinal = editandoId;
        if (!editandoId) {
            idFinal = crypto.randomUUID();
            nuevo = true;
        }

        const locale = localStorage.getItem('appLang') || (navigator.language.startsWith('es') ? 'es' : 'en');
        const nuevoCanto = {
            id: idFinal,
            _idioma: locale,
            nuevo_local: nuevo ? true : (cantoData.nuevo_local || undefined),
            ...cantoData
        };

        if (import.meta.env.DEV) {
            try {
                const res = await fetch('/__gestor_sync', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ action: 'save', canto: nuevoCanto })
                });
                if (!res.ok) throw new Error('Error en gestor sync: ' + await res.text());
                this._cacheCantos = null;
                this._cacheLocale = null;
                return { id: idFinal, nuevo };
            } catch (e) {
                console.error("Error sincronizando al servidor de desarrollo Vite:", e);
                throw e;
            }
        }

        let todos = null;
        if (cantoData.vinculo_idioma) {
            todos = await this.getAmbosCatalogos();
        }

        let overrides = JSON.parse(localStorage.getItem('cantos_overrides') || '[]');
        
        // --- LOGICA VINCULO BIDIRECCIONAL ---
        if (cantoData.vinculo_idioma && todos) {
            const vinculado = todos.find(c => c.id === cantoData.vinculo_idioma);
            
            if (vinculado && vinculado.vinculo_idioma !== idFinal) {
                // Actualizar el otro canto para que apunte a este
                const vinculadoActualizado = { ...vinculado, vinculo_idioma: idFinal };
                
                const vIdx = overrides.findIndex(c => c.id === vinculado.id);
                if (vIdx >= 0) {
                    overrides[vIdx].vinculo_idioma = idFinal;
                } else {
                    overrides.push(vinculadoActualizado);
                }
            }
        }
        // -------------------------------------

        const idx = overrides.findIndex(c => c.id === idFinal);
        if (idx >= 0) {
            overrides[idx] = { ...overrides[idx], ...nuevoCanto };
        } else {
            overrides.push(nuevoCanto);
        }
        
        localStorage.setItem('cantos_overrides', JSON.stringify(overrides));

        // Actualizar caché con el canto actual (mientras la caché todavía existe)
        if (this._cacheCantos) {
            if (nuevo) {
                this._cacheCantos.push(nuevoCanto);
            } else {
                const cacheIdx = this._cacheCantos.findIndex(c => c.id === idFinal);
                if (cacheIdx >= 0) {
                    this._cacheCantos[cacheIdx] = { ...this._cacheCantos[cacheIdx], ...nuevoCanto };
                }
            }
        }

        // Invalidar caché si se escribieron overrides para el otro idioma (vínculo bidireccional)
        // Debe ir DESPUÉS de la actualización de caché anterior para no causar un TypeError
        // al intentar hacer .push() sobre null
        if (cantoData.vinculo_idioma) {
            this._cacheCantos = null;
            this._cacheLocale = null;
        }

        return { id: idFinal, nuevo };
    },

    async deleteCanto(id) {
        if (import.meta.env.DEV) {
            try {
                const res = await fetch('/__gestor_sync', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ action: 'delete', id })
                });
                if (!res.ok) throw new Error('Error en gestor sync delete');
                this._cacheCantos = null;
                this._cacheLocale = null;
                return;
            } catch (e) {
                console.error("Error sincronizando delete al servidor:", e);
                throw e;
            }
        }

        const eliminados = JSON.parse(localStorage.getItem('cantos_eliminados') || '[]');
        if (!eliminados.includes(id)) {
            eliminados.push(id);
            localStorage.setItem('cantos_eliminados', JSON.stringify(eliminados));
        }

        // Remover de overrides si estuviera ahí
        const overrides = JSON.parse(localStorage.getItem('cantos_overrides') || '[]');
        const newOverrides = overrides.filter(c => c.id !== id);
        localStorage.setItem('cantos_overrides', JSON.stringify(newOverrides));

        // Actualizar caché
        if (this._cacheCantos) {
            this._cacheCantos = this._cacheCantos.filter(c => c.id !== id);
        }
    },

    async getAuditoria() {
        return JSON.parse(localStorage.getItem('auditoria_local') || '[]');
    },

    async logAccion(accion, detalles) {
        const logs = await this.getAuditoria();
        logs.unshift({
            id: crypto.randomUUID(),
            accion,
            detalles,
            fecha: new Date().toISOString()
        });
        // Guardar maximo 100
        localStorage.setItem('auditoria_local', JSON.stringify(logs.slice(0, 100)));
    },

    resolverUrlPdf(nombre) {
        if (!nombre) return "";
        if (nombre.startsWith('http') || nombre.startsWith('blob:') || nombre.startsWith('data:')) return nombre;
        const nombreLimpio = encodeURI(nombre);
        return `/offline_assets/pdfs/${nombreLimpio}`;
    },

    resolverUrlMidi(nombre) {
        if (!nombre) return "";
        if (nombre.startsWith('http') || nombre.startsWith('blob:') || nombre.startsWith('data:')) return nombre;
        const nombreLimpio = encodeURI(nombre);
        return `/offline_assets/midis/${nombreLimpio}`;
    }
};
