# 🗄️ ESTRUCTURA DE LA BASE DE DATOS (Supabase)

El backend opera sobre PostgreSQL a través de Supabase. Este modelo permite transacciones ACID y control estricto de seguridad mediante Políticas de Seguridad por Filas (Row Level Security o RLS).

---

## 1. Tablas Maestras

### `coros` (Sedes)
La definición territorial y administrativa.
- `id`: UUID (ej: un identificador para la iglesia 'Tijuana Otay').
- `nombre`: Nombre de la iglesia o región.
- `municipio`: Ciudad a la que pertenece.

### `perfiles` (Usuarios y RBAC)
Vinculado directamente a `auth.users` de Supabase.
- `id`: UUID (FK de autenticación).
- `rol`: Niveles jerárquicos de acceso: `superadmin`, `director_estatal`, `director`, `subdirector`, `delegado`, `miembro`.
- `coro_id`: FK a `coros.id` (Restringe la visibilidad del usuario a esta sede).
- `estado`: Control de aprobación de cuentas (`activo`, `pendiente`, `rechazado`).
- `nombre`: Nombre legible.

### `cantos` (Repertorio Físico)
El archivo maestro universal. Independiente de las sedes.
- `id`: Int8 (Autoincremental).
- `nombre`: Título de la pieza o himno.
- `archivo`: La ruta del PDF y el MIDI alojados en Supabase Storage.
- `temas`: Array de textos para agrupación por categorías litúrgicas.
- `creado_en`: Timestamp estricto.

---

## 2. Tablas de Relación (Pivot)

Para evitar duplicidad masiva, los cantos se asocian a los coros mediante N:N.

### `cantos_coros` (El Catálogo Local)
- `id`: Serial.
- `coro_id`: FK a `coros.id`.
- `canto_id`: FK a `cantos.id`.
> *Regla de RLS:* Un miembro solo puede descargar la data si el `coro_id` concuerda con el `coro_id` de su `perfil`.

### `eventos` (Carpetas o Setlists)
Las colecciones ordenadas creadas por un Director para un culto.
- `id`: UUID.
- `nombre`: Título de la carpeta.
- `coro_id`: FK a `coros.id` (El propietario/creador).
- `sedes_participantes`: Array de UUIDs. (Abre la RLS para permitir accesos Inter-sedes).
- `es_estatal`: Booleano para eventos magnos.

### `eventos_cantos` (Contenido Secuencial)
- `evento_id`: FK a `eventos.id`.
- `canto_id`: FK a `cantos.id`.
- `orden`: Integer. (Esencial para la reproducción secuencial del `Jukebox`).

---

## 3. Tablas de Operación y Telemetría

### `avisos` (El Bus Realtime)
Usada como "puente" para enviar instrucciones a los WebSockets.
- `id`: Serial.
- `tipo`: Enumerador: `VIVO` (Canto en el altar), `RECORDATORIO` (Mensajes), o `SYNC_SILENCIOSA` (Triggers del sistema de red).
- `coro_id`: Filtro de destino.
- `metadata`: Objeto JSONB (Generalmente aloja el ID del canto que debe ser forzado a abrir en las pantallas o que debe ser eliminado del estado local).

### `auditoria` (Seguimiento Histórico)
Registro inmutable para los perfiles de Supervisión.
- `id`: Serial.
- `usuario_id`: UUID del ejecutor.
- `accion`: `ELIMINO`, `EDITO`, `CREO`, `MOVIO`.
- `detalles`: Bloque JSONB con el payload exacto anterior y nuevo.
- `fecha`: Timestamp de red (no del cliente local).

---

## 4. Perspectiva Local (Offline SyncQueue)

Si bien este documento define la estructura en Supabase, es crucial entender que **estas estructuras son modeladas en la memoria local (RAM) y en IndexedDB** mediante el módulo `/core/syncQueue.js`.

Cuando el sistema está desconectado, los inserts destinados a `eventos_cantos` (añadir a la carpeta) se alojan en la tabla `mutations` del navegador, respetando este mismo esquema JSON relacional, listos para ser despachados cuando la conectividad se restablezca.
