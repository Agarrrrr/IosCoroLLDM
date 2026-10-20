import { supabase } from './supabase.js';
import { localDB } from './localDB.js';

const apiUrl = (import.meta.env.VITE_API_URL || '').replace(/\/+$/, '');
const GLOBAL_ASSET_KEY = /^global\/assets\/(pdf|midi)\/[a-f0-9]{64}\.enc$/i;

function currentLanguage() {
    return localStorage.getItem('appLang') ||
        (navigator.language.startsWith('es') ? 'es' : 'en');
}

async function accessToken() {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session?.access_token) {
        throw new Error('La sesión de superadmin expiró. Inicia sesión de nuevo en el gestor.');
    }

    // Validar el token actual directamente contra la API de Supabase
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData?.user) {
        console.warn('[remoteCatalogDB] Token rechazado por Supabase, intentando refrescar...');
        const { data: refreshData, error: refreshError } = await supabase.auth.refreshSession();
        if (refreshError || !refreshData?.session?.access_token) {
            throw new Error('La sesión expiró. Cierra sesión e inicia sesión de nuevo en el gestor.');
        }
        window.__catalogAccessToken = refreshData.session.access_token;
        return refreshData.session.access_token;
    }

    window.__catalogAccessToken = session.access_token;
    return session.access_token;
}

function asDataUrl(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = reject;
        reader.readAsDataURL(file);
    });
}

async function uploadDataUrl(dataUrl, cantoId, language, type, version, token) {
    if (!dataUrl) return null;
    if (GLOBAL_ASSET_KEY.test(dataUrl)) return dataUrl;
    if (dataUrl.startsWith('global/') || dataUrl.startsWith('assets/')) {
        throw new Error(`La ruta remota del ${type} no tiene una clave global válida: ${dataUrl}`);
    }
    if (!apiUrl) throw new Error('Falta VITE_API_URL en el entorno local.');

    let bytes;
    if (dataUrl.startsWith('data:')) {
        const response = await fetch(dataUrl);
        bytes = await response.arrayBuffer();
    } else if (!dataUrl.startsWith('http')) {
        // Es un nombre de archivo local no cifrado como "Salmo 125.pdf"
        const folder = type === 'pdf' ? 'pdfs' : 'midis';
        const localUrl = `/offline_assets/${folder}/${dataUrl}`;
        const response = await fetch(localUrl);
        if (!response.ok) {
            throw new Error(`No se pudo leer el archivo local ${localUrl} (${response.status}). No se guardó el canto para evitar una ruta 404.`);
        }
        bytes = await response.arrayBuffer();
    } else {
        throw new Error(`La URL del ${type} no es un asset global válido. Descarga o carga el archivo antes de guardar.`);
    }

    // Calcular SHA-256 del contenido original (requerido por el Worker para cargas cifradas)
    const hashBuffer = await crypto.subtle.digest('SHA-256', bytes);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const contentHash = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');

    const encryptedBytes = await encryptAsset(bytes);
    const url = new URL('/v1/admin/upload', apiUrl);
    url.searchParams.set('canto', cantoId);
    url.searchParams.set('language', language);
    url.searchParams.set('type', type);
    url.searchParams.set('version', String(version));

    const uploadToken = token || await accessToken();

    const upload = await fetch(url, {
        method: 'PUT',
        headers: {
            Authorization: `Bearer ${uploadToken}`,
            'Content-Type': 'application/octet-stream',
            'X-Content-Encrypted': 'v1',
            'X-Content-SHA256': contentHash
        },
        body: encryptedBytes
    });
    if (!upload.ok) {
        throw new Error(`No se pudo subir ${type}: ${await upload.text()}`);
    }
    return (await upload.json()).object_key;
}

async function encryptAsset(bytes) {
    const rawKey = new TextEncoder().encode('repertorio-coral-lldm-key-2026');
    const keyHash = await crypto.subtle.digest('SHA-256', rawKey);
    const key = await crypto.subtle.importKey('raw', keyHash, { name: 'AES-GCM' }, false, ['encrypt']);
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, bytes);
    const result = new Uint8Array(iv.byteLength + encrypted.byteLength);
    result.set(iv, 0);
    result.set(new Uint8Array(encrypted), iv.byteLength);
    return result;
}

async function copyEncryptedAsset(sourceSongId, targetSongId, language, type) {
    if (!apiUrl) throw new Error('Falta VITE_API_URL en el entorno local.');
    const token = await accessToken();
    const source = await fetch(
        `${apiUrl}/v1/files/${sourceSongId}/${type}`,
        { headers: { Authorization: `Bearer ${token}` } }
    );
    if (source.status === 403 && type === 'midi') return null;
    if (!source.ok) {
        throw new Error(`No se pudo leer el ${type} local (${source.status}).`);
    }

    const uploadUrl = new URL('/v1/admin/upload', apiUrl);
    uploadUrl.searchParams.set('canto', targetSongId);
    uploadUrl.searchParams.set('language', language);
    uploadUrl.searchParams.set('type', type);
    uploadUrl.searchParams.set('version', '1');
    const bytes = await source.arrayBuffer();
    const preview = new Uint8Array(bytes, 0, Math.min(bytes.byteLength, 1024));
    const header = String.fromCharCode(...preview);
    const isPlain = type === 'pdf'
        ? header.includes('%PDF')
        : header.startsWith('MThd');
    const uploadBytes = isPlain ? await encryptAsset(bytes) : bytes;
    const headers = {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/octet-stream',
        'X-Content-Encrypted': 'v1'
    };

    const upload = await fetch(uploadUrl, {
        method: 'PUT',
        headers,
        body: uploadBytes
    });
    if (!upload.ok) {
        throw new Error(`No se pudo copiar el ${type} local: ${await upload.text()}`);
    }
    return (await upload.json()).object_key;
}

function normalizeRows(rows) {
    const normalized = (rows || []).map((row) => {
        const lang = row.idioma || row._idioma || 'es';
        return {
            ...row,
            idioma: lang,
            _idioma: lang,
            nombre: (row.nombre || '')
                .replace(/^\s*envi[oó]\s+señal\s+en\s+vivo\s*:\s*/i, '')
                .trim(),
            _nombre_norm: (row.nombre || '').toLocaleLowerCase('es'),
            _autor_norm: (row.autor || '').toLocaleLowerCase('es')
        };
    });
    localDB.configureRemoteCatalog(normalized, apiUrl);
    return normalized;
}

export const remoteCatalogDB = {
    _cache: null,

    async syncExistingAssetsToLocal() {
        if (!import.meta.env.DEV) {
            throw new Error('La sincronización local solo está disponible en desarrollo.');
        }

        const token = await accessToken();
        // Para sincronizar archivos existentes no necesitamos consultar RPC;
        // el catálogo local ya contiene las claves global/* que se van a copiar.
          const catalogRows = (await localDB.getAmbosCatalogos())
              .filter(row =>
                  String(row.archivo || '').startsWith('global/') ||
                  String(row.midi_archivo || '').startsWith('global/')
              )
          // El catálogo puede conservar una clave antigua. Antes de descargar,
          // pedimos a Supabase la clave autorizada real para cada tipo; así el
          // sincronizador no depende de que catálogo y cantos estén idénticos.
          const rows = await Promise.all(catalogRows.map(async row => {
              const resolved = {};
              for (const type of ['pdf', 'midi']) {
                  const catalogKey = type === 'pdf' ? row.archivo : row.midi_archivo;
                  if (!String(catalogKey || '').startsWith('global/')) continue;
                  const { data, error } = await supabase.rpc('resolver_archivo_canto', {
                      p_canto_id: row.id,
                      p_tipo: type
                  });
                  if (!error && data?.[0]?.object_key) resolved[type] = data[0].object_key;
              }
              return {
                  id: row.id,
                  archivo: resolved.pdf || row.archivo || null,
                  midi_archivo: resolved.midi || row.midi_archivo || null
              };
          }));

        const response = await fetch('/__gestor_sync_catalog', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'sync_remote_assets',
                rows,
                apiUrl,
                accessToken: token
            })
        });
        const result = await response.json().catch(() => ({}));
        if (!response.ok) {
            throw new Error(result.error || 'No se pudieron sincronizar los archivos remotos.');
        }
        return result;
    },

    async getAmbosCatalogos(force = false) {
        if (this._cache && !force) return this._cache;
        let remoteRows = [];
        try {
            const { data, error } = await supabase.rpc('catalogo_global_bilingue');
            if (!error && Array.isArray(data)) {
                remoteRows = data;
            }
        } catch (e) {
            console.warn('Error consultando Supabase RPC, usando base local:', e);
        }

        const localRows = await localDB.getAmbosCatalogos();
        if (remoteRows.length === 0) {
            this._cache = normalizeRows(localRows);
            return this._cache;
        }

        // Deduplicación e integración inteligente de datos locales con remotos
        const mapCombined = new Map();
        const keyMap = new Map();

        const normalizarClave = (str) => (str || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim();

        // 1. Agregar filas locales
        for (const row of localRows) {
            mapCombined.set(row.id, row);
            const lang = row.idioma || row._idioma || 'es';
            const normKey = `${normalizarClave(row.nombre)}_${lang}`;
            keyMap.set(normKey, row.id);
            if (row.external_id) keyMap.set(row.external_id, row.id);
            // Si el id local no es UUID, tratarlo también como external_id candidato
            if (row.id && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(row.id)) {
                keyMap.set(row.id, row.id);
            }
        }

        // 2. Integrar filas remotas evitando duplicados por ID, external_id o nombre+idioma
        for (const row of remoteRows) {
            const lang = row.idioma || row._idioma || 'es';
            const normKey = `${normalizarClave(row.nombre)}_${lang}`;
            const existingLocalId = keyMap.get(row.id) || keyMap.get(row.external_id) || keyMap.get(normKey);

            if (existingLocalId && mapCombined.has(existingLocalId)) {
                // Sobrescribir/enriquecer la entrada existente para no duplicar.
                // Si el ID local era legacy (no-UUID) y el remoto trae un UUID real,
                // migrar la entrada al UUID para que la resolución funcione correctamente.
                const base = mapCombined.get(existingLocalId);
                const isLegacyLocal = !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(existingLocalId);
                const remoteHasUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(row.id);
                if (isLegacyLocal && remoteHasUUID) {
                    // Eliminar la entrada legacy y registrar con el UUID real
                    mapCombined.delete(existingLocalId);
                    const merged = {
                        ...base,
                        ...row,
                        // Una respuesta remota incompleta (por ejemplo, una
                        // relación de sede sin MIDI) no debe borrar el asset
                        // que ya existe en el catálogo local.
                        archivo: row.archivo || base.archivo || null,
                        midi_archivo: row.midi_archivo || base.midi_archivo || null,
                        id: row.id,
                        external_id: existingLocalId
                    };
                    mapCombined.set(row.id, merged);
                    keyMap.set(existingLocalId, row.id);
                    keyMap.set(normKey, row.id);
                } else {
                    mapCombined.set(existingLocalId, {
                        ...base,
                        ...row,
                        // Conserva los archivos locales cuando Supabase
                        // devuelve null/vacío para la copia de una sede.
                        archivo: row.archivo || base.archivo || null,
                        midi_archivo: row.midi_archivo || base.midi_archivo || null,
                        id: existingLocalId
                    });
                }
            } else {
                // Canto nuevo creado en la nube que no existe localmente
                mapCombined.set(row.id, row);
                keyMap.set(normKey, row.id);
            }
        }

        this._cache = normalizeRows(Array.from(mapCombined.values()));
        return this._cache;
    },

    async getCantos(force = false) {
        const language = currentLanguage();
        return (await this.getAmbosCatalogos(force))
            .filter((row) => (row.idioma || row._idioma) === language);
    },

    async getCanto(id) {
        const all = await this.getAmbosCatalogos();
        // Buscar por id exacto primero
        const byId = all.find((row) => row.id === id);
        if (byId) return byId;
        // Si el id no es UUID, buscar por external_id (para IDs legacy)
        return all.find((row) => row.external_id === id) || null;
    },

    async saveCanto(cantoData, editingId = null) {
        const isUUID = (str) => typeof str === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str);
        
        const existing = editingId ? await this.getCanto(editingId) : null;
        let id = editingId && isUUID(editingId) ? editingId : null;

        // Si el ID local no es UUID, intentar resolver el UUID real desde el catálogo combinado
        if (!id && existing?.id && isUUID(existing.id)) {
            id = existing.id;
        }

        // Último recurso: consultar Supabase directamente por external_id para evitar conflicto 23505
        if (!id && editingId && !isUUID(editingId)) {
            try {
                const { data: remoteRow } = await supabase
                    .from('cantos')
                    .select('id')
                    .eq('external_id', editingId)
                    .maybeSingle();
                if (remoteRow?.id) {
                    id = remoteRow.id;
                    console.log(`[remoteCatalogDB] UUID resuelto para "${editingId}": ${id}`);
                }
            } catch (e) {
                console.warn('[remoteCatalogDB] No se pudo resolver UUID por external_id:', e.message);
            }
        }

        // Búsqueda preventiva por nombre e idioma para evitar duplicados si no se pasó editingId
        if (!id && cantoData.nombre) {
            const all = await this.getAmbosCatalogos();
            const norm = (str) => (str || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9\s]/gi, "").trim();
            const targetNorm = norm(cantoData.nombre);
            const targetLang = cantoData.idioma || cantoData._idioma || currentLanguage();
            const foundByName = all.find(c => norm(c.nombre) === targetNorm && (c.idioma || c._idioma || 'es') === targetLang);
            if (foundByName && foundByName.id && isUUID(foundByName.id)) {
                id = foundByName.id;
            }
        }

        if (!id) {
            id = crypto.randomUUID();
        }

        const externalId = cantoData.external_id || existing?.external_id || (editingId && !isUUID(editingId) ? editingId : null);
        // Idioma real: solo se usa para saber en qué JSON escribir (catalogo.json vs catalogo_en.json)
        const languageForJson = cantoData.idioma || cantoData._idioma || existing?.idioma || existing?._idioma || currentLanguage();
        // Cloudflare y Supabase ignoran el idioma → siempre 'es'
        const languageForCloud = 'es';
        const nextVersion = Math.max(Number(existing?.version || 0) + 1, 1);

        // Obtener el token UNA vez — la rotación de refresh tokens invalidaría
        // el segundo upload si cada llamada hace su propio refreshSession().
        const uploadToken = await accessToken();

        const pdf = await uploadDataUrl(
            cantoData.archivo,
            id,
            languageForCloud,
            'pdf',
            nextVersion,
            uploadToken
        );
        // Una edición de metadatos o una importación incompleta nunca debe
        // borrar un MIDI que ya existe en el catálogo global.
        const midi = cantoData.midi_archivo
            ? await uploadDataUrl(
                cantoData.midi_archivo,
                id,
                languageForCloud,
                'midi',
                nextVersion,
                uploadToken
            )
            : existing?.midi_archivo || null;

        const { data, error } = await supabase.rpc('gestionar_canto_global', {
            p_id: id,
            p_external_id: externalId,
            p_nombre: cantoData.nombre,
            p_archivo: pdf,
            p_temas: cantoData.temas || [],
            p_midi_archivo: midi,
            p_idioma: languageForCloud,
            p_vinculo_idioma: null,          // Solo relevante en el JSON local, ignorar en Supabase
            p_cifrado_version: 1,
            p_derivado_de: cantoData.derivado_de || null
        });
        if (error) throw error;

        // Obtener el archivo key devuelto por Cloudflare (object_key en R2) o el original
        const archivoFinal = pdf || cantoData.archivo || existing?.archivo || null;
        const midiFinal    = midi || existing?.midi_archivo || null;

        // Persistir el cambio al JSON local en disco (solo en DEV vía servidor Vite plugin)
        // En producción (Cloudflare), el JSON se actualiza con npm run sync-catalogs
        if (import.meta.env.DEV) {
            try {
                const cantoGuardado = {
                    id,
                    external_id: externalId || null,
                    nombre: cantoData.nombre,
                    archivo: archivoFinal,
                    midi_archivo: midiFinal,
                    temas: cantoData.temas || [],
                    idioma: languageForJson,
                    _idioma: languageForJson,
                    vinculo_idioma: cantoData.vinculo_idioma || null,
                    version: data?.[0]?.version || nextVersion,
                    ...(externalId && { external_id: externalId })
                };
                await fetch('/__gestor_sync_catalog', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        action: 'upsert',
                        canto: cantoGuardado,
                        oldId: editingId,
                        // El servidor local necesita los bytes originales para
                        // generar la copia offline del proyecto iOS.
                        archivoData: cantoData.archivo?.startsWith('data:') ? cantoData.archivo : null,
                        midiData: cantoData.midi_archivo?.startsWith('data:') ? cantoData.midi_archivo : null
                    })
                });
            } catch (e) {
                console.warn('[remoteCatalogDB] No se pudo persistir al JSON local (dev):', e.message);
            }
        }

        this._cache = null;
        await this.getAmbosCatalogos(true);
        return {
            id,
            nuevo: !editingId,
            version: data?.[0]?.version || nextVersion
        };
    },

    async deleteCanto(id) {
        const { data, error } = await supabase.rpc('desactivar_canto_global', {
            p_canto_id: id
        });
        if (error) throw error;
        if (data !== true) throw new Error('El canto global no existe o ya está inactivo.');
        this._cache = null;
    },

    async getPendingLocalSongs() {
        const { data, error } = await supabase.rpc('cantos_locales_pendientes');
        if (error) throw error;
        return data || [];
    },

    async markLocalSongReviewed(id, status) {
        const { data, error } = await supabase.rpc('marcar_revision_canto_local', {
            p_canto_id: id,
            p_estado: status
        });
        if (error) throw error;
        return data === true;
    },

    async cloneLocalSong(song) {
        const id = crypto.randomUUID();
        const pdf = await copyEncryptedAsset(song.id, id, 'es', 'pdf');
        const midi = song.midi_archivo
            ? await copyEncryptedAsset(song.id, id, 'es', 'midi')
            : null;

        const result = await this.saveCanto({
            nombre: song.nombre,
            archivo: pdf,
            midi_archivo: midi,
            temas: song.temas || [],
            idioma: 'es',
            derivado_de: song.id
        }, id);
        result.nuevo = true;
        await this.markLocalSongReviewed(song.id, 'incorporado');
        return result;
    },

    async getAuditoria() {
        const { data, error } = await supabase
            .from('auditoria')
            .select('*')
            .order('fecha', { ascending: false })
            .limit(50);
        if (error) return [];
        return data || [];
    },

    async logAccion(accion, detalles) {
        const { data: { user } } = await supabase.auth.getUser();
        const { error } = await supabase.from('auditoria').insert({
            usuario_id: user?.id || null,
            accion,
            detalles
        });
        if (error) console.warn('No se pudo registrar auditoría:', error.message);
    },

    fileToDataUrl: asDataUrl
};
