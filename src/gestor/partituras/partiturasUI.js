/**
 * UI DE PARTITURAS
 * Encapsula la construcción del DOM y el renderizado de tablas/historial.
 */
export const partiturasUI = {
    construirEstructura(contenedor) {
        contenedor.innerHTML = `
            <div id="panel-avisos-admin" class="panel-seccion">
                <h3 class="panel-titulo">ENVIAR AVISO A LA SEDE</h3>
                <div class="herramientas-gestion">
                    <input id="input-aviso-texto" class="input-estandar" placeholder="Escribe un recordatorio para todos..." ">
                    <button id="btn-enviar-recordatorio" class="btn-principal" style="border: none; padding: 14px 25px; font-weight: 800; font-size: 14px; background: var(--navy-deep); color: white;">ENVIAR RECORDATORIO</button>
                </div>
            </div>
            <div style="display: flex; justify-content: center; width: 100%; margin: 45px 0;">
                <button id="btn-buscar-agregar" class="btn-principal" style="border: none; min-width: 260px; padding: 16px 35px; font-size: 16px; font-weight: 800; letter-spacing: 1px; background: var(--gold-fuerte); color: white; box-shadow: 0 8px 20px rgba(212,175,55,0.25);">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 12px;"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
                    AÑADIR PARTITURA
                </button>
            </div>
            <div class="herramientas-gestion" style="display: block; margin-bottom: 25px;">
                <div style="position: relative; width: 100%; display: flex; align-items: center;">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--color-texto-suave)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="position: absolute; left: 18px; pointer-events: none; opacity: 0.7;">
                        <circle cx="11" cy="11" r="8"></circle>
                        <line x1="21" cy="21" x2="16.65" y2="16.65"></line>
                    </svg>
                    <input id="buscador-partituras" class="input-estandar" placeholder="BUSCAR PARTITURA..." 
                        style="width: 100%; border: 1px solid var(--borde); background: #ffffff; padding-left: 54px; padding-right: 48px; border-radius: 18px; height: 56px; font-size: 15px; transition: all 0.3s ease; box-shadow: 0 2px 8px rgba(0,0,0,0.04); outline: none;">
                    <button id="btn-limpiar-buscador" style="display: none; position: absolute; right: 15px; background: transparent; border: none; cursor: pointer; color: var(--color-texto-suave); padding: 5px; align-items: center; justify-content: center;">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                    </button>
                </div>
                <div style="display: flex; gap: 10px; margin-top: 12px; overflow-x: auto; padding-bottom: 5px;">
                    <button id="btn-filtro-nomidi" class="btn-secundario filtro-toggle" style="font-size: 13px; padding: 6px 16px; border-radius: 20px; flex-shrink: 0;">Faltan MIDI</button>
                    <button id="btn-filtro-nobilingue" class="btn-secundario filtro-toggle" style="font-size: 13px; padding: 6px 16px; border-radius: 20px; flex-shrink: 0;">Faltan Bilingüe</button>
                </div>
            </div>
            <div id="lista-partituras-scroll"></div>
            <div id="historial-cantos-contenedor" class="panel-seccion" style="display: none; margin-top: 30px;">
                <h3 class="panel-titulo">HISTORIAL DE CAMBIOS</h3>
                <div id="lista-historial-scroll"></div>
            </div>
            <div id="modal-promocion-masiva" class="modal-overlay" style="display: none;">
                <div class="modal-content" style="border: none; box-shadow: 0 20px 40px rgba(0,0,0,0.2);">
                    <div class="modal-header">
                        <h3 id="titulo-modal-promocion">BUSCAR Y AÑADIR</h3>
                        <button class="btn-cerrar-ico">✕</button>
                    </div>
                    <p class="subtitulo" style="margin-bottom: 15px;">Consulta si la partitura ya existe antes de crear una nueva.</p>
                    <input id="buscador-promocion" class="input-estandar" placeholder="Escribe el nombre de la partitura..." style="margin-bottom: 25px; border: 1px solid var(--borde); background: #f8fafc;">
                    <div id="lista-cantos-promocion" style="max-height: 380px; overflow-y: auto; margin-bottom: 25px; border-radius: 12px; background: #fff;"></div>
                    <div style="border-top: 1px solid var(--borde); padding-top: 30px; display: flex; flex-direction: column; align-items: center; gap: 15px;">
                        <p class="subtitulo" style="font-size: 13px; margin: 0; color: var(--color-texto-suave);">¿No encuentras lo que buscas?</p>
                        <button id="btn-crear-nueva" class="btn-principal" style="border: none; min-width: 260px; background: linear-gradient(135deg, var(--gold-fuerte), #b48a04); color: white; box-shadow: 0 10px 25px rgba(212,175,55,0.4); font-weight: 800; padding: 16px 35px; font-size: 16px; letter-spacing: 1px;">
                             AÑADIR NUEVA PARTITURA
                        </button>
                    </div>
                </div>
            </div>`;
    },

    renderizarTabla(partituras, esSuperAdmin) {
        const listaScroll = document.getElementById('lista-partituras-scroll');
        if (!listaScroll) return;
        
        listaScroll.innerHTML = ''; 

        if (!partituras.length) {
            const emptyDiv = document.createElement('div');
            emptyDiv.className = 'panel-seccion';
            emptyDiv.style.textAlign = 'center';
            const p = document.createElement('p');
            p.className = 'subtitulo';
            p.textContent = 'NO HAY PARTITURAS EN ESTA SEDE.';
            emptyDiv.appendChild(p);
            listaScroll.appendChild(emptyDiv);
            return;
        }

        const svgEdit = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>`;
        const svgDelete = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M10 11v6M14 11v6"/></svg>`;
        const svgPreview = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>`;
        const svgAudio = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="margin-left:8px; vertical-align: middle; filter: drop-shadow(0 0 2px rgba(16,185,129,0.3));"><path d="M3 18v-6a9 9 0 0 1 18 0v6"></path><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"></path></svg>`;

        const partiturasOrdenadas = [...partituras].sort((a, b) => {
            const nomA = (a.nombre || '').toLowerCase();
            const nomB = (b.nombre || '').toLowerCase();
            return nomA.localeCompare(nomB, 'es', { 
                sensitivity: 'base',
                numeric: true,
                ignorePunctuation: true
            });
        });

        const fragment = document.createDocumentFragment();
        partiturasOrdenadas.forEach(p => {
            const tieneMidi = !!p.midi_archivo;
            const div = document.createElement('div');
            div.className = 'item-fila';
            div.setAttribute('data-id', p.id);
            div.setAttribute('data-nombre', p.nombre);
            div.setAttribute('data-accion', 'vista-previa'); // Ley de Fitts: toda la tarjeta es preview
            div.setAttribute('data-archivo', p.archivo);
            div.setAttribute('data-tiene-midi', tieneMidi);

            if (tieneMidi) {
                div.style.borderLeft = '4px solid #10b981';
                div.style.backgroundColor = 'rgba(16, 185, 129, 0.05)';
            }

            const infoTexto = document.createElement('div');
            infoTexto.className = 'info-texto';

            const spanNombre = document.createElement('span');
            spanNombre.className = 'nombre-canto-link';
            spanNombre.textContent = p.nombre.toUpperCase();
            if (tieneMidi) spanNombre.innerHTML += svgAudio;
            if (p.vinculo_idioma) spanNombre.innerHTML += ` <span class="badge-bilingue" title="Vinculado al ID: ${p.vinculo_idioma}">🌐 BILINGÜE</span>`;

            const spanSubtitulo = document.createElement('span');
            spanSubtitulo.className = 'subtitulo';
            spanSubtitulo.textContent = (p.temas || []).join(', ') || 'Sin Categoría';

            infoTexto.append(spanNombre, spanSubtitulo);

            const accionesDerecha = document.createElement('div');
            accionesDerecha.className = 'acciones-derecha';

            const btnPreview = document.createElement('button');
            btnPreview.className = 'btn-icono';
            btnPreview.setAttribute('data-accion', 'vista-previa');
            btnPreview.title = 'Vista Previa';
            btnPreview.innerHTML = svgPreview;

            const btnEditar = document.createElement('button');
            btnEditar.className = 'btn-icono';
            btnEditar.setAttribute('data-accion', 'editar');
            btnEditar.title = 'Editar';
            btnEditar.innerHTML = svgEdit;

            const btnEliminar = document.createElement('button');
            btnEliminar.className = 'btn-icono btn-peligro-hover';
            btnEliminar.setAttribute('data-accion', 'eliminar');
            btnEliminar.title = 'Quitar de esta sede';
            btnEliminar.innerHTML = svgDelete;

            accionesDerecha.append(btnPreview, btnEditar, btnEliminar);
            div.append(infoTexto, accionesDerecha);
            fragment.appendChild(div);
        });
        listaScroll.appendChild(fragment);
    },

    renderizarHistorial(historial, coroIdActual) {
        const contenedorPadre = document.getElementById('historial-cantos-contenedor');
        const listaScroll = document.getElementById('lista-historial-scroll');
        if (!historial || !historial.length) { if (contenedorPadre) contenedorPadre.style.display = 'none'; return; }
        if (contenedorPadre) contenedorPadre.style.display = 'block';
        
        if (listaScroll) {
            listaScroll.innerHTML = ''; 
            const fragment = document.createDocumentFragment();
            historial.forEach(h => {
                const fecha = new Date(h.fecha).toLocaleString('es-MX', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
                const color = h.accion === 'ELIMINO' ? '#ef4444' : (h.accion === 'EDITO' ? '#3b82f6' : '#10b981');
                const d = h.detalles || {};
                const cantoNombre = d.canto_nombre || 'S/N';
                const usuarioNombre = d.usuario_nombre || 'S/U';
                const coroNombre = d.coro_nombre || 'Desconocida';
                const esDeOtraSede = d.coro_id !== coroIdActual && d.coro_id !== 'estatal';

                const item = document.createElement('div');
                item.className = 'item-fila';
                item.style.cssText = `border-left: 4px solid ${color}; padding: 12px 20px;`;

                const infoTexto = document.createElement('div');
                infoTexto.className = 'info-texto';

                const spanCanto = document.createElement('span');
                spanCanto.style.cssText = 'font-weight: 800; font-size: 14px; color: var(--navy-deep);';
                spanCanto.textContent = cantoNombre.toUpperCase();

                const spanSubtitulo = document.createElement('span');
                spanSubtitulo.className = 'subtitulo';
                
                const bAccion = document.createElement('b');
                bAccion.style.color = color;
                bAccion.textContent = h.accion;
                
                const bUsuario = document.createElement('b');
                bUsuario.textContent = usuarioNombre.toUpperCase();

                spanSubtitulo.append(bAccion);
                if (esDeOtraSede) {
                    const spanSede = document.createElement('span');
                    spanSede.style.cssText = 'color: var(--gold-fuerte); font-weight: bold;';
                    spanSede.textContent = ` (EN: ${coroNombre.toUpperCase()})`;
                    spanSubtitulo.append(spanSede);
                }
                spanSubtitulo.append(' POR ', bUsuario, ` • ${fecha}`);
                
                infoTexto.append(spanCanto, spanSubtitulo);
                item.appendChild(infoTexto);
                fragment.appendChild(item);
            });
            listaScroll.appendChild(fragment);
        }
    },

    mostrarCarga(boton, cargando) {
        if (!boton) return;
        boton.disabled = cargando;
        boton.textContent = cargando ? "GUARDANDO..." : "GUARDAR CAMBIOS";
    }
};