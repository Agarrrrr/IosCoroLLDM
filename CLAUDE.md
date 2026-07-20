# 🛠️ CLAUDE.md - Guía de Desarrollo y Estándares

## 📋 Reglas de Oro
- **No Emojis:** Usa iconos SVG minimalistas.
- **Mayúsculas Técnicas:** Los botones, badges y encabezados importantes deben ir en `UPPERCASE` para mantener la estética profesional.
- **Surgical Updates:** No refactorices archivos completos si no es necesario. Usa `replace` para cambios precisos.
- **Seguridad:** Nunca expongas las claves de Supabase en logs o comentarios.

## 🏗️ Patrones de Diseño
- **Singleton State:** La aplicación usa un objeto `APP_STATE` (en `main.js`) y `GESTOR_STATE` (en `gestorApp.js`) como única fuente de verdad.
- **Modularidad:** Cada funcionalidad del gestor tiene su propio módulo en `/src/gestor/`.
- **Event Delegation:** Preferir el uso de delegación de eventos para listas dinámicas (ej: `lista-eventos-scroll`).

## 🧪 Pruebas y Validación
- Antes de dar por terminada una tarea, verifica la persistencia en `localStorage`.
- Prueba siempre el modo offline simulando desconexión en las DevTools.
- Valida el RBAC: entra con un usuario `miembro` para asegurar que no vea el botón de administración.

## 🔧 Comandos Frecuentes
- `npm run dev`: Iniciar servidor de desarrollo.
- `npm run build`: Generar versión de producción (Vite).

## 🗄️ Esquema de Base de Datos (Referencia Rápida)
- `perfiles.rol`: `superadmin`, `director_estatal`, `director`, `subdirector`, `delegado`, `miembro`.
- `avisos.tipo`: `VIVO`, `RECORDATORIO`.
- `eventos.coro_id`: Si es nulo y `es_estatal` es true, es global.
