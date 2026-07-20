/**
 * @typedef {Object} PerfilUsuario
 * @property {string} id - UUID del usuario en Supabase.
 * @property {string} nombre - Nombre completo.
 * @property {string} email - Correo electrónico.
 * @property {string} coro_id - ID de la sede a la que pertenece.
 * @property {'superadmin'|'director_estatal'|'director'|'subdirector'|'delegado'|'miembro'} rol - Nivel de acceso.
 * @property {string} [municipio] - Municipio de la sede.
 */

/**
 * @typedef {Object} Canto
 * @property {string|number} id - ID único del canto.
 * @property {string} nombre - Título del canto.
 * @property {string} archivo - Nombre o URL del archivo PDF en Storage.
 * @property {string[]} temas - Lista de etiquetas/temas asociados.
 * @property {Object[]} [cantos_coros] - Relación con las sedes.
 * @property {string} cantos_coros.coro_id - ID de la sede vinculada.
 */

/**
 * @typedef {Object} Evento
 * @property {string} id - ID único de la carpeta/evento.
 * @property {string} nombre - Nombre descriptivo.
 * @property {string} coro_id - ID de la sede propietaria.
 * @property {boolean} es_estatal - Si es una carpeta de alcance estatal.
 * @property {string[]} [sedes_participantes] - IDs de sedes con acceso.
 * @property {string[]} [miembros_participantes] - IDs de usuarios invitados.
 */

/**
 * @typedef {Object} AppState
 * @property {PerfilUsuario|null} perfil - Datos del usuario logueado.
 * @property {Canto[]} cantos - Catálogo completo cargado.
 * @property {string} categoriaActiva - Filtro de categoría actual (ej: 'local', 'estatal', 'ev-ID').
 * @property {boolean} online - Estado de conexión del navegador.
 * @property {boolean} MODO_OFFLINE_FORZADO - Toggle manual de modo offline.
 * @property {Evento[]} eventos - Carpetas especiales disponibles.
 * @property {string} temaUI - Tema visual activo.
 */

export {};
