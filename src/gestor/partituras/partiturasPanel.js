import { partiturasController } from '../../core/partiturasController.js';
import { partiturasUI } from './partiturasUI.js';
import { pdfEngine } from '../../core/pdfEngine.js';
import { basePanelController } from '../../core/basePanelController.js';
import { buscadorUI } from '../../ui/buscador.js';

const normalizarNombreArchivo = (nombre) => {
    return nombre.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/\([^)]*\)/g, "").replace(/[^a-z0-9\s-]/g, "").trim().replace(/\s+/g, "-");          
};

// Función Debounce reutilizable
function debounce(func, wait) {
    let timeout;
    return function(...args) {
        clearTimeout(timeout);
        timeout = setTimeout(() => func.apply(this, args), wait);
    };
}

let listaLocal = []; // Cambiado de listaGlobal a listaLocal para mayor claridad
let listaGlobalCache = []; // Cache del catálogo completo para filtrar rápido
let coroIdActual = null;
let refrescarFn = null; 
let panelAbortController = null;
let esSuperAdminLocal = false;

export async function inicializarPartiturasPanel(coroId) {
    // --- LIMPIEZA DE EVENTOS ANTERIORES ---
    if (panelAbortController) panelAbortController.abort();
    panelAbortController = new AbortController();
    const signal = panelAbortController.signal;

    coroIdActual = coroId;
    listaLocal = [];
    listaGlobalCache = [];

    const contenedor = document.getElementById('panel-partituras');
    const modal = document.getElementById('modal-partitura');
    const form = document.getElementById('form-partitura');
    let editandoId = null, urlArchivoActual = "", urlMidiActual = null;
    if (!contenedor || !modal) return;

    esSuperAdminLocal = await partiturasController.esSuperAdmin();

    partiturasUI.construirEstructura(contenedor);
    modal.style.display = 'none';

    async function cargarTemasSelect() {
        const selectTemas = document.getElementById('partitura-temas');
        if (!selectTemas) return;
        try {
            const temas = await partiturasController.obtenerTemasUnicos();
            selectTemas.innerHTML = '';
            temas.forEach(t => {
                const opt = document.createElement('option');
                opt.value = t;
                opt.textContent = t.toUpperCase();
                selectTemas.appendChild(opt);
            });
        } catch (e) { console.error("Error cargando temas:", e); }
    }

    await cargarTemasSelect();

    // --- REALTIME UNIFICADO: Conectar al Cerebro Central ---
    window.cbRepertorioGestor = () => {
        if (refrescarFn) refrescarFn();
    };

    document.getElementById('partitura-archivo-file').onchange = (e) => {
        const file = e.target.files[0];
        const label = document.getElementById('texto-archivo-seleccionado');
        if (file && label) {
            label.textContent = file.name.toUpperCase();
            label.style.color = 'var(--gold-fuerte)';
        }
    };

    document.getElementById('partitura-midi-file').onchange = (e) => {
        const file = e.target.files[0];
        const label = document.getElementById('texto-midi-seleccionado');
        if (file && label) {
            label.textContent = file.name.toUpperCase();
            label.style.color = '#10b981'; // Un verde esmeralda para diferenciar del PDF
        }
    };

    form.onsubmit = async (e) => {
        e.preventDefault();
        const btnGuardar = document.getElementById('btn-guardar');
        partiturasUI.mostrarCarga(btnGuardar, true);

        try {
            const nombre = document.getElementById('partitura-nombre').value.trim();
            const fileInput = document.getElementById('partitura-archivo-file');
            const midiInput = document.getElementById('partitura-midi-file');
            const midiExistente = document.getElementById('partitura-midi-existente-hidden')?.value;
            const temasLibres = document.getElementById('partitura-temas-libres').value.split(',').map(t => t.trim()).filter(t => t !== "");
            const temasSeleccionados = Array.from(document.getElementById('partitura-temas').selectedOptions).map(opt => opt.value);
            const temasFinales = [...new Set([...temasSeleccionados, ...temasLibres])];

            let urlArchivo = urlArchivoActual;
            const cambiosDetectados = [];
            
            if (fileInput.files[0]) {
                urlArchivo = await partiturasController.subirArchivo(fileInput.files[0], normalizarNombreArchivo(nombre));
                cambiosDetectados.push('PDF Actualizado');
            }

            let urlMidi = urlMidiActual;
            if (midiInput.files[0]) {
                urlMidi = await partiturasController.subirMidi(midiInput.files[0], normalizarNombreArchivo(nombre));
                cambiosDetectados.push(!urlMidiActual ? 'MIDI Añadido' : 'MIDI Actualizado');
            } else if (midiExistente && midiExistente !== urlMidiActual) {
                urlMidi = midiExistente;
                cambiosDetectados.push('MIDI Reutilizado');
            }

            const vinculoIdioma = document.getElementById('partitura-vinculo-idioma')?.value;
            // Regla: Si se vincula a otro idioma y ese canto tiene MIDI, heredarlo
            if (vinculoIdioma) {
                const globalData = await partiturasController.obtenerCatalogoGlobal();
                const vinculado = globalData.find(c => c.id === vinculoIdioma);
                if (vinculado && vinculado.midi_archivo) {
                    urlMidi = vinculado.midi_archivo;
                    cambiosDetectados.push('MIDI Heredado por Vínculo');
                }
            }

            const payload = { 
                nombre, 
                archivo: urlArchivo, 
                midi_archivo: urlMidi,
                vinculo_idioma: vinculoIdioma || null,
                temas: temasFinales, 
                coro_id: coroIdActual 
            };
            const resultado = await partiturasController.guardarCanto(payload, editandoId);

            if (resultado.nuevo) {
                await partiturasController.registrarAccion('CREO', nombre, coroIdActual, resultado.id, ['Partitura Creada']);
                window.mostrarToast("NUEVA PARTITURA CREADA");
            } else if (resultado.forked) {
                // Registrar que se creó un fork
                await partiturasController.registrarAccion('CREO', nombre, coroIdActual, resultado.id, ['Copia Independiente (Fork)']);
                window.mostrarToast("COPIA INDEPENDIENTE CREADA");
            } else {
                if (cambiosDetectados.length === 0) cambiosDetectados.push('Metadatos / Etiquetas');
                await partiturasController.registrarAccion('EDITO', nombre, coroIdActual, editandoId, cambiosDetectados);
                window.mostrarToast("PARTITURA ACTUALIZADA");
            }

            modal.style.display = 'none';
            
            // Limpiar buscador si existe para regresar a la lista completa
            const buscador = document.getElementById('buscador-partituras');
            const btnLimpiar = document.getElementById('btn-limpiar-buscador');
            if (buscador) {
                buscador.value = '';
                if (btnLimpiar) btnLimpiar.style.display = 'none';
            }

            await refrescarDatos();
            await cargarTemasSelect();
        } catch (error) {
            console.error("Error al guardar:", error);
            window.mostrarToast("ERROR AL GUARDAR", "error");
        } finally {
            partiturasUI.mostrarCarga(btnGuardar, false);
        }
    };

    async function refrescarDatos() {
        try {
            listaLocal = await partiturasController.obtenerPartituras(coroIdActual);
            partiturasUI.renderizarTabla(listaLocal, esSuperAdminLocal);
            const idsPermitidos = listaLocal.map(c => c.id);
            const log = await partiturasController.obtenerHistorialAuditoria(coroIdActual, idsPermitidos);
            partiturasUI.renderizarHistorial(log, coroIdActual);
        } catch (e) { console.error('Error al refrescar datos:', e); }
    }
    refrescarFn = refrescarDatos;


    window.midisDisponibles = [];

    async function extraerMidisDisponibles() {
        const urlMap = new Map();
        const globalData = await partiturasController.obtenerCatalogoGlobal();
        window._debugGlobalLength = globalData ? globalData.length : -1;
        window._debugMidisEncontrados = globalData ? globalData.filter(c => c.midi_archivo).length : -1;
        
        globalData.filter(c => c.midi_archivo).forEach(c => {
            if (!urlMap.has(c.midi_archivo)) {
                const filename = c.midi_archivo.split('/').pop() || 'Archivo MIDI';
                urlMap.set(c.midi_archivo, { url: c.midi_archivo, nombre: filename, canto_origen: c.nombre });
            }
        });
        window.midisDisponibles = Array.from(urlMap.values());
    }

    function renderizarListaMidis(filtro = "") {
        const contenedor = document.getElementById('lista-midis-resultados');
        if (!contenedor) return;
        contenedor.innerHTML = "";
        const query = filtro.toLowerCase();
        
        const filtrados = window.midisDisponibles.filter(m => m.nombre.toLowerCase().includes(query) || m.canto_origen.toLowerCase().includes(query));
        
        if (filtrados.length === 0) {
            contenedor.innerHTML = `<p class="subtitulo" style="text-align:center; margin-top: 20px;">No se encontraron MIDIs.<br><br><span style="font-size:10px; color:gray;">[Debug: Total Global: ${window._debugGlobalLength} | MIDIs: ${window._debugMidisEncontrados} | Disponibles: ${window.midisDisponibles.length}]</span></p>`;
            return;
        }

        filtrados.forEach(m => {
            const div = document.createElement('div');
            div.style.cssText = "padding: 12px; border: 1px solid var(--borde); border-radius: 8px; display: flex; justify-content: space-between; align-items: center; background: #fff;";
            
            const info = document.createElement('div');
            const spanNombre = document.createElement('span');
            spanNombre.style.cssText = "font-weight: 600; font-size: 13px; color: var(--navy-deep); display: block; word-break: break-all;";
            spanNombre.textContent = m.nombre;
            const spanOrigen = document.createElement('span');
            spanOrigen.style.cssText = "font-size: 11px; color: var(--color-texto-suave);";
            spanOrigen.textContent = `Usado en: ${m.canto_origen}`;
            info.appendChild(spanNombre);
            info.appendChild(spanOrigen);
            
            const btn = document.createElement('button');
            btn.type = "button";
            btn.className = "btn-principal";
            btn.style.cssText = "padding: 6px 12px; font-size: 12px; border-radius: 6px; min-width: 100px;";
            btn.textContent = "SELECCIONAR";
            btn.onclick = () => {
                const hiddenInput = document.getElementById('partitura-midi-existente-hidden');
                if (hiddenInput) hiddenInput.value = m.url;
                const txt = document.getElementById('texto-midi-existente-seleccionado');
                if (txt) {
                    txt.textContent = `SELECCIONADO: ${m.nombre}`;
                    txt.style.display = 'block';
                }
                document.getElementById('modal-buscador-midi').style.display = 'none';
            };
            
            div.appendChild(info);
            div.appendChild(btn);
            contenedor.appendChild(div);
        });
    }

    const btnAbrirMidi = document.getElementById('btn-abrir-buscador-midi');
    if (btnAbrirMidi) {
        btnAbrirMidi.onclick = async () => {
            btnAbrirMidi.textContent = "CARGANDO MIDIS...";
            await extraerMidisDisponibles();
            btnAbrirMidi.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="margin-right: 8px; vertical-align: middle;"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>BUSCAR MIDI EXISTENTE`;
            const modalMidi = document.getElementById('modal-buscador-midi');
            const inputBuscar = document.getElementById('input-buscar-midi');
            if (modalMidi && inputBuscar) {
                inputBuscar.value = "";
                renderizarListaMidis("");
                modalMidi.style.display = 'flex';
                setTimeout(() => inputBuscar.focus(), 100);
            }
        };
    }

    const btnCerrarMidi = document.getElementById('btn-cerrar-buscador-midi');
    if (btnCerrarMidi) {
        btnCerrarMidi.onclick = () => {
            document.getElementById('modal-buscador-midi').style.display = 'none';
        };
    }

    const inputBuscarMidi = document.getElementById('input-buscar-midi');
    if (inputBuscarMidi) {
        inputBuscarMidi.oninput = (e) => {
            renderizarListaMidis(e.target.value);
        };
    }

    // --- LOGICA VINCULOS BILINGÜES ---
    window.vinculosDisponibles = [];

    async function extraerVinculosDisponibles() {
        const globalData = await partiturasController.obtenerCatalogoGlobal();
        window._debugGlobalVinculos = globalData ? globalData.length : -1;
        // Filtramos para excluir la que se está editando si aplica
        window.vinculosDisponibles = globalData.filter(c => c.id !== editandoId).map(c => ({
            id: c.id,
            nombre: c.nombre,
            tieneMidi: !!c.midi_archivo
        }));
    }

    function renderizarListaVinculos(filtro = "") {
        const contenedor = document.getElementById('lista-vinculos-resultados');
        if (!contenedor) return;
        contenedor.innerHTML = "";
        
        const limpiarTexto = (str) => str.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9\s]/gi, "");
        const query = limpiarTexto(filtro.toLowerCase());
        
        const filtrados = window.vinculosDisponibles.filter(m => 
            limpiarTexto(m.nombre.toLowerCase()).includes(query)
        );
        
        if (filtrados.length === 0) {
            contenedor.innerHTML = `<p class="subtitulo" style="text-align:center; margin-top: 20px;">No se encontraron partituras.<br><br><span style="font-size:10px; color:gray;">[Debug: Total Global: ${window._debugGlobalVinculos} | Vinculos Disp: ${window.vinculosDisponibles.length}]</span></p>`;
            return;
        }

        filtrados.forEach(m => {
            const div = document.createElement('div');
            div.style.cssText = "padding: 12px; border: 1px solid var(--borde); border-radius: 8px; display: flex; justify-content: space-between; align-items: center; background: #fff;";
            
            const info = document.createElement('div');
            const spanNombre = document.createElement('span');
            spanNombre.style.cssText = "font-weight: 600; font-size: 13px; color: var(--navy-deep); display: block; word-break: break-all;";
            spanNombre.textContent = m.nombre;
            const spanOrigen = document.createElement('span');
            spanOrigen.style.cssText = `font-size: 11px; color: ${m.tieneMidi ? '#10b981' : 'var(--color-texto-suave)'};`;
            spanOrigen.textContent = m.tieneMidi ? 'Tiene MIDI heredable' : 'Sin MIDI';
            info.appendChild(spanNombre);
            info.appendChild(spanOrigen);
            
            const btn = document.createElement('button');
            btn.type = "button";
            btn.className = "btn-principal";
            btn.style.cssText = "padding: 6px 12px; font-size: 12px; border-radius: 6px; min-width: 100px;";
            btn.textContent = "VINCULAR";
            btn.onclick = () => {
                const hiddenInput = document.getElementById('partitura-vinculo-idioma');
                if (hiddenInput) hiddenInput.value = m.id;
                const txt = document.getElementById('texto-vinculo-seleccionado');
                if (txt) {
                    txt.textContent = `VINCULADO A: ${m.nombre}`;
                    txt.style.display = 'block';
                }
                document.getElementById('modal-buscador-vinculo').style.display = 'none';
            };
            
            div.appendChild(info);
            div.appendChild(btn);
            contenedor.appendChild(div);
        });
    }

    const btnAbrirVinculo = document.getElementById('btn-abrir-buscador-vinculo');
    if (btnAbrirVinculo) {
        btnAbrirVinculo.onclick = async () => {
            btnAbrirVinculo.textContent = "CARGANDO...";
            await extraerVinculosDisponibles();
            btnAbrirVinculo.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="margin-right: 8px; vertical-align: middle;"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>BUSCAR PARTITURA`;
            const modalVinculo = document.getElementById('modal-buscador-vinculo');
            const inputBuscarV = document.getElementById('input-buscar-vinculo');
            if (modalVinculo && inputBuscarV) {
                inputBuscarV.value = "";
                renderizarListaVinculos("");
                modalVinculo.style.display = 'flex';
                setTimeout(() => inputBuscarV.focus(), 100);
            }
        };
    }

    const btnCerrarVinculo = document.getElementById('btn-cerrar-buscador-vinculo');
    if (btnCerrarVinculo) {
        btnCerrarVinculo.onclick = () => {
            document.getElementById('modal-buscador-vinculo').style.display = 'none';
        };
    }

    const inputBuscarVinculo = document.getElementById('input-buscar-vinculo');
    if (inputBuscarVinculo) {
        inputBuscarVinculo.oninput = (e) => {
            renderizarListaVinculos(e.target.value);
        };
    }

    // Función para abrir el formulario de subida (CREAR NUEVA)
    const abrirFormularioNuevo = () => {
        editandoId = null; form.reset(); urlArchivoActual = ""; urlMidiActual = null;
        document.getElementById('partitura-archivo-file').required = true;
        document.getElementById('titulo-form').textContent = "NUEVA PARTITURA";
        const labelPdf = document.getElementById('texto-archivo-seleccionado');
        if (labelPdf) { labelPdf.textContent = "SELECCIONAR PDF"; labelPdf.style.color = 'inherit'; }
        const labelMidi = document.getElementById('texto-midi-seleccionado');
        if (labelMidi) { labelMidi.textContent = "SELECCIONAR MIDI NUEVO"; labelMidi.style.color = 'inherit'; }
        
        const hiddenMidi = document.getElementById('partitura-midi-existente-hidden');
        if (hiddenMidi) hiddenMidi.value = "";
        const txtMidi = document.getElementById('texto-midi-existente-seleccionado');
        if (txtMidi) { txtMidi.textContent = ""; txtMidi.style.display = 'none'; }

        const hiddenVinculo = document.getElementById('partitura-vinculo-idioma');
        if (hiddenVinculo) hiddenVinculo.value = "";
        const txtVinculo = document.getElementById('texto-vinculo-seleccionado');
        if (txtVinculo) { txtVinculo.textContent = ""; txtVinculo.style.display = 'none'; }
        
        modal.style.display = 'flex';
        document.getElementById('partitura-nombre').focus();
    };

    const abrirFormularioEdicion = (cantoObj) => {
        form.reset(); // LIMPIEZA CRÍTICA: Previene subida accidental de archivos residuales del input
        editandoId = cantoObj.id;
        document.getElementById('partitura-nombre').value = cantoObj.nombre;
        document.getElementById('titulo-form').textContent = "EDITANDO: " + cantoObj.nombre.toUpperCase();
        urlArchivoActual = cantoObj.archivo;
        urlMidiActual = cantoObj.midi_archivo;
        
        document.getElementById('partitura-archivo-file').required = false;
        const labelPdf = document.getElementById('texto-archivo-seleccionado');
        if (labelPdf) { labelPdf.textContent = "ARCHIVO ACTUAL: " + cantoObj.archivo.substring(0, 15) + "..."; labelPdf.style.color = 'var(--gold-fuerte)'; }
        
        const labelMidi = document.getElementById('texto-midi-seleccionado');
        if (labelMidi) {
            if (cantoObj.midi_archivo) {
                labelMidi.textContent = "MIDI ACTUAL: " + cantoObj.midi_archivo.substring(0, 15) + "...";
                labelMidi.style.color = '#10b981';
            } else {
                labelMidi.textContent = "SIN MIDI (OPCIONAL)";
                labelMidi.style.color = 'inherit';
            }
        }

        const selectTemas = document.getElementById('partitura-temas');
        if (selectTemas && cantoObj.temas) {
            Array.from(selectTemas.options).forEach(opt => { opt.selected = cantoObj.temas.includes(opt.value); });
        }

        const hiddenInput = document.getElementById('partitura-midi-existente-hidden');
        const textSel = document.getElementById('texto-midi-existente-seleccionado');
        if (hiddenInput && cantoObj.midi_archivo) {
            hiddenInput.value = cantoObj.midi_archivo;
            if (textSel) {
                textSel.textContent = `MIDI ACTUAL SELECCIONADO`;
                textSel.style.display = 'block';
            }
        } else {
            if (hiddenInput) hiddenInput.value = "";
            if (textSel) textSel.style.display = 'none';
        }

        const hiddenVinculo = document.getElementById('partitura-vinculo-idioma');
        const txtVinculo = document.getElementById('texto-vinculo-seleccionado');
        if (hiddenVinculo && cantoObj.vinculo_idioma) {
            hiddenVinculo.value = cantoObj.vinculo_idioma;
            if (txtVinculo) {
                // Para mostrar el nombre real del vinculo, buscar en el catalogo o usar un placeholder
                txtVinculo.textContent = `VINCULADO A ID: ${cantoObj.vinculo_idioma}`;
                txtVinculo.style.display = 'block';
            }
        } else {
            if (hiddenVinculo) hiddenVinculo.value = "";
            if (txtVinculo) txtVinculo.style.display = 'none';
        }

        modal.style.display = 'flex';
    };


    // Exponer al scope global para que el panel de Eventos pueda reutilizar este formulario
    window.gestorPartituras = {
        abrirFormularioNuevo,
        abrirFormularioEdicion
    };

    document.getElementById('btn-crear-nueva').onclick = () => {
        document.getElementById('modal-promocion-masiva').style.display = 'none';
        abrirFormularioNuevo();
    };

    document.getElementById('btn-cerrar-modal').onclick = () => modal.style.display = 'none';

    // Manejador para el modal de vista previa
    const modalVistaPrevia = document.getElementById('modal-vista-previa');
    const btnCerrarVistaPrevia = document.getElementById('btn-cerrar-vista-previa');
    if (btnCerrarVistaPrevia) {
        btnCerrarVistaPrevia.onclick = async () => {
            modalVistaPrevia.style.display = 'none';
            document.getElementById('contenedor-preview-pdf').innerHTML = "";
            // La limpieza del PDF ya la gestiona pdfEngine internamente en su próximo uso
        };
    }

    const abrirVistaPrevia = async (archivo) => {
        if (!modalVistaPrevia) return;
        const contenedor = document.getElementById('contenedor-preview-pdf');
        modalVistaPrevia.style.display = 'flex';
        await pdfEngine.renderizarVistaPreviaRapida(archivo, contenedor);
    };

    document.getElementById('lista-partituras-scroll').onclick = async (e) => {
        const btn = e.target.closest('button[data-accion]');
        const card = e.target.closest('.item-fila');
        
        if (btn) {
            e.stopPropagation(); // Evitar que el click llegue a la tarjeta
            const item = card;
            const { id, nombre } = item.dataset;

            if (btn.dataset.accion === 'editar') {
                const canto = listaLocal.find(c => c.id === id);
                if (canto) abrirFormularioEdicion(canto);
                return;
            }

            if (btn.dataset.accion === 'eliminar') {
                basePanelController.confirmarAccion(btn, async () => {
                    try {
                        await basePanelController.ejecutarConCarga(btn, async () => {
                            await partiturasController.eliminarRelacionSede(id, coroIdActual);
                            await partiturasController.registrarAccion('ELIMINO', nombre, coroIdActual, id);
                            await refrescarDatos();
                        }, "QUITADO DE LA SEDE");
                    } catch (err) {
                        console.error("Error eliminando relación:", err);
                    }
                }, "¿QUITAR DE ESTA SEDE?");
                return;
            }
        } else if (card) {
            // Clic en cualquier parte de la tarjeta -> Vista Previa
            if (card.dataset.accion === 'vista-previa') {
                abrirVistaPrevia(card.dataset.archivo);
            }
        }
    };

    await refrescarDatos();

    // --- RENDERIZADO DEL CATÁLOGO GLOBAL (MODAL) ---
    function renderizarCatalogoGlobal(lista) {
        const listaProm = document.getElementById('lista-cantos-promocion');
        if (!listaProm) return;
        
        listaProm.innerHTML = '';
        const idsLocales = new Set(listaLocal.map(l => l.id));
        const svgAudio = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="margin-left:8px; vertical-align: middle;"><path d="M3 18v-6a9 9 0 0 1 18 0v6"></path><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"></path></svg>`;

        if (lista.length === 0) {
            listaProm.innerHTML = '<p class="subtitulo" style="text-align:center; padding:20px;">NO SE ENCONTRARON PARTITURAS.</p>';
            return;
        }

        lista.forEach(p => {
            const tieneMidi = !!p.midi_archivo;
            const div = document.createElement('div');
            div.className = 'item-fila'; 
            div.setAttribute('data-id', p.id);
            div.setAttribute('data-archivo', p.archivo);
            div.setAttribute('data-accion', 'vista-previa');

            if (tieneMidi) {
                div.style.borderLeft = '4px solid #10b981';
                div.style.backgroundColor = 'rgba(16, 185, 129, 0.05)';
            }

            const info = document.createElement('div'); info.className = 'info-texto';
            const span = document.createElement('span');
            span.className = 'nombre-canto-link'; 
            span.textContent = p.nombre.toUpperCase();
            if (tieneMidi) span.insertAdjacentHTML('beforeend', svgAudio);
            info.appendChild(span);

            const acciones = document.createElement('div'); acciones.className = 'acciones-derecha';
            if (idsLocales.has(p.id)) {
                const spanReg = document.createElement('span'); 
                spanReg.className = 'subtitulo texto-atenuado'; 
                spanReg.textContent = 'REGISTRADO';
                acciones.appendChild(spanReg);
            } else {
                const btn = document.createElement('button'); 
                btn.className = 'btn-promover'; 
                btn.setAttribute('data-accion', 'clonar-global'); 
                btn.textContent = 'AÑADIR A MI SEDE';
                acciones.appendChild(btn);
            }
            div.append(info, acciones); listaProm.appendChild(div);
        });
    }

    // --- LISTENERS GLOBALES CON SIGNAL PARA EVITAR FUGAS ---
    document.addEventListener('click', async (e) => {
        const btnBuscarAgregar = e.target.closest('#btn-buscar-agregar');
        if (btnBuscarAgregar) {
            btnBuscarAgregar.disabled = true;
            try {
                listaGlobalCache = await partiturasController.obtenerCatalogoGlobal();
                renderizarCatalogoGlobal(listaGlobalCache);
                document.getElementById('modal-promocion-masiva').style.display = 'flex';
                document.getElementById('buscador-promocion').value = "";
                document.getElementById('buscador-promocion').focus();
            } finally { btnBuscarAgregar.disabled = false; }
        }

        const btnClonar = e.target.closest('.btn-promover[data-accion="clonar-global"]');
        if (btnClonar && coroIdActual) {
            btnClonar.disabled = true;
            btnClonar.textContent = 'AÑADIENDO...';
            const { id } = btnClonar.closest('.item-fila').dataset;
            const nombre = btnClonar.closest('.item-fila').querySelector('.info-texto span').textContent;
            try {
                const cantoGlobal = listaGlobalCache.find(c => c.id === id);
                if (cantoGlobal) {
                    await partiturasController.guardarCanto(cantoGlobal, id);
                }
                await partiturasController.registrarAccion('VINCULO', nombre, coroIdActual, id);
                if (window.mostrarToast) window.mostrarToast('AÑADIDO A MI SEDE');
                if (refrescarFn) await refrescarFn();
                btnClonar.parentElement.innerHTML = '<span class="subtitulo texto-atenuado">REGISTRADO</span>';
            } catch (err) {
                console.error("Error vinculando con sede:", err);
                btnClonar.disabled = false;
                btnClonar.textContent = 'AÑADIR A MI SEDE';
                if (window.mostrarToast) window.mostrarToast('ERROR AL AÑADIR (Posible duplicado)', 'error');
            }
        }

        const btnCerrarGlobal = e.target.closest('#modal-promocion-masiva .btn-cerrar-ico');
        if (btnCerrarGlobal) document.getElementById('modal-promocion-masiva').style.display = 'none';
        
        // Manejador de vista previa en catálogo global (delegado al engine central)
        const linkVPGlobal = e.target.closest('#lista-cantos-promocion [data-accion="vista-previa"]');
        if (linkVPGlobal) {
            // Solo si no se hizo click en el botón de añadir
            if (!e.target.closest('button')) await abrirVistaPrevia(linkVPGlobal.dataset.archivo);
        }

    }, { signal });

    const actualizarFiltrosLocal = () => {
        const buscador = document.getElementById('buscador-partituras');
        const query = buscador ? buscador.value : '';
        let filtrados = buscadorUI.filtrarCantos(listaLocal, query);
        
        const btnMidi = document.getElementById('btn-filtro-nomidi');
        const btnBil = document.getElementById('btn-filtro-nobilingue');
        
        if (btnMidi && btnMidi.classList.contains('activo')) {
            filtrados = filtrados.filter(p => !p.midi_archivo);
        }
        if (btnBil && btnBil.classList.contains('activo')) {
            filtrados = filtrados.filter(p => !p.vinculo_idioma);
        }
        
        partiturasUI.renderizarTabla(filtrados, esSuperAdminLocal);
    };

    // Evento para limpiar el buscador local y botones de filtro
    document.addEventListener('click', (e) => {
        const btnLimpiar = e.target.closest('#btn-limpiar-buscador');
        if (btnLimpiar) {
            const buscador = document.getElementById('buscador-partituras');
            if (buscador) {
                buscador.value = '';
                btnLimpiar.style.display = 'none';
                actualizarFiltrosLocal();
                buscador.focus();
            }
        }
        
        const btnFiltroMidi = e.target.closest('#btn-filtro-nomidi');
        if (btnFiltroMidi) {
            btnFiltroMidi.classList.toggle('activo');
            if (btnFiltroMidi.classList.contains('activo')) {
                btnFiltroMidi.style.background = 'var(--navy-deep)';
                btnFiltroMidi.style.color = 'white';
                btnFiltroMidi.style.borderColor = 'var(--navy-deep)';
            } else {
                btnFiltroMidi.style.background = '';
                btnFiltroMidi.style.color = '';
                btnFiltroMidi.style.borderColor = '';
            }
            actualizarFiltrosLocal();
        }

        const btnFiltroBil = e.target.closest('#btn-filtro-nobilingue');
        if (btnFiltroBil) {
            btnFiltroBil.classList.toggle('activo');
            if (btnFiltroBil.classList.contains('activo')) {
                btnFiltroBil.style.background = 'var(--navy-deep)';
                btnFiltroBil.style.color = 'white';
                btnFiltroBil.style.borderColor = 'var(--navy-deep)';
            } else {
                btnFiltroBil.style.background = '';
                btnFiltroBil.style.color = '';
                btnFiltroBil.style.borderColor = '';
            }
            actualizarFiltrosLocal();
        }
    }, { signal });

    document.addEventListener('input', debounce((e) => {
        if (e.target.id === 'buscador-promocion') {
            const query = e.target.value;
            // Usar la lógica potente del index (buscadorUI)
            const filtrados = buscadorUI.filtrarCantos(listaGlobalCache, query);
            renderizarCatalogoGlobal(filtrados);
        }
        if (e.target.id === 'buscador-partituras') {
            const query = e.target.value;
            
            // Mostrar u ocultar el botón de limpiar
            const btnLimpiar = document.getElementById('btn-limpiar-buscador');
            if (btnLimpiar) {
                btnLimpiar.style.display = query.length > 0 ? 'flex' : 'none';
            }

            // Usar la lógica combinada de texto y filtros extra
            actualizarFiltrosLocal();
        }
    }, 250), { signal });
}