# Modelo de acceso a previews públicos

La aplicación conserva sus MIDI fuente y sus claves fuera del sitio web. El sitio público sirve previews renderizados de piano, no archivos MIDI.

## Qué se publica

- Un fragmento de ensayo de hasta 1:30 por canto, en Opus y AAC/M4A.
- Un manifest que relaciona el identificador del catálogo con esos previews.
- Metadatos mínimos necesarios para mostrar el repertorio y su estado.

## Qué no se publica

- MIDI fuente, claves de cifrado, archivos locales ni rutas de almacenamiento privado.
- Credenciales de Cloudflare, R2 o servicios de la aplicación.

## Límite de protección

Todo audio servido públicamente puede ser descargado por una persona decidida. Las URLs versionadas, CORS, caché y el Worker mejoran operación y reducen exposición accidental, pero no sustituyen un control de acceso. Si un material no debe poder copiarse, no debe publicarse como preview.

## Revocación

Para retirar un preview, elimina el objeto público, quítalo del manifest y despliega Pages. Para sustituirlo, publica primero el nuevo archivo con nombre versionado, actualiza el manifest y valida el Worker antes del despliegue.
