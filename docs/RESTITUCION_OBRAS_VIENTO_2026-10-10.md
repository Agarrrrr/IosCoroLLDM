# Restitución de las dos obras «La vida se va como el viento»

## Error constatado en esta revisión

El catálogo del sitio conservaba las dos obras. Sin embargo, `assets/catalogo.json` y `assets/offline_assets/catalogo.json` contenían únicamente el ID de la obra larga con el nombre de la corta. El informe anterior `REVISION_INTEGRIDAD_CATALOGO_2026-09-30.md` describía una recuperación que no estaba presente en esos archivos de esta copia del proyecto. Se conserva ese informe y se registra aquí la discrepancia, sin atribuir una causa no comprobada.

## Corrección

- Restituida «La Vida se va Como el Viento», ID `eaeafa56-1d25-4517-b13f-1b3f7f6beced`, versión 4, tema Evangelización, con su propio PDF y MIDI.
- Restituido el título completo «La Vida Se Va Como El Viento y Pronto en Las Nubes Vendrá», ID `f034d95c-6ae5-45ad-9d7c-c0ea51075a58`, versión 6, con sus referencias distintas de PDF y MIDI.
- Recuperación basada en IDs y metadatos originales ya conservados, sin fusionar por similitud de nombres.
- Los cuatro recursos ya existían en los directorios offline declarados en `pubspec.yaml`.

## Verificación permanente

`test/viento_catalog_identity_test.dart`: cinco pruebas aprobadas. Comprueba ambas entradas únicas con título y versión originales en app, biblioteca offline y sitio; referencias distintas; carga real de los cuatro assets empaquetados, descifrado y hashes SHA-256 del contenido contra las identidades verificadas previamente. Los dos MIDI tienen Soprano, Alto, Tenor y Bajo, con duraciones respectivas de aproximadamente 216 y 159 segundos.

Evidencia: `output/accessibility/viento-identity-2026-10-10.log`.

Esta corrección está en los archivos locales. No se ha generado ni instalado una compilación nueva en este paso; la aplicación instalada no cambia hasta recibir una compilación que incluya los catálogos corregidos.
