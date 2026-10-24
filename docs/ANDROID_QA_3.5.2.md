# Android 3.5.2 (46): verificación de Liftoff

Fecha: 2026-10-24. Dispositivo físico: Samsung SM-G986U con Android 13.

## Paquete de producción

- AAB release firmado: `build/releases/CoroLLDM-3.5.2-46.aab`.
- `bundletool validate` completado; manifiesto comprobado:
  `com.lldm.coro`, versión `3.5.2`, código `46`.
- Firma verificada con `jarsigner`; registro nativo de plugins comprobado con
  `tools/verify_android_release.ps1`.
- APKs específicos del Samsung generados desde el AAB con bundletool.
- Inspección de DEX: adaptador de Liftoff presente; adaptador y SDK de Meta
  ausentes. Meta también se retiró de Flutter y de los cambios nativos de iOS.
- SHA-256 del AAB:
  `820E39E0DB68E256DE3E99E5E65F768425EF65208A301179ADE3A4FF0D5D7326`.

## Pruebas físicas

La instalación de Google Play usa un certificado diferente de la clave local
de subida. Se conservó intacta la app instalada `3.5.0 (44)` y sus datos. Las
pruebas se hicieron en una copia **release** `com.lldm.coro.perfaudit`, construida
con el mismo código y SDK, pero con un registro de dispositivo de prueba de
AdMob. El AAB de producción no incluye ese registro ni el sufijo de auditoría.

| Comprobación | Resultado |
| --- | --- |
| Tres arranques en frío | Catálogo visible, sin excepciones fatales |
| Buscar `Sombra` | Resultados y apertura de la partitura correctos |
| PDF `A la Sombra de Tus Alas` | Páginas renderizadas, revisadas visualmente |
| MIDI y SoundFont nativos | Carga correcta, avance visible, pausa y detención |
| Favorito tras reiniciar | Conservado |
| Catálogo, PDF y MIDI sin Wi-Fi ni datos | Correctos; avance offline observado |
| AdMob y VungleMediationAdapter | Ambos en estado `ready` |
| Solicitudes de QA en AdMob | Registro confirmado como dispositivo de prueba |
| Pantalla completa de Liftoff | Mostrada y cerrada con retorno al catálogo |

El aviso de calificación interrumpió el primer ciclo de comprobación. Se
pospuso con «Más tarde» y se completaron después los tres arranques. Las
conexiones Wi-Fi y de datos se restauraron a su estado inicial al terminar.

Análisis de monetización sin errores. Las 16 pruebas existentes de estado de
monetización, cuotas y selección Premium pasaron con Meta ya retirado.

Evidencias locales (no se suben al repositorio):
`build/releases/ads-android-check/`, incluidos `startup-final/report.json`,
`offline-result.json`, XML, capturas y registros nativos.

## Límites

La copia aislada no certifica una actualización de Google Play sobre la app
instalada: para ello se necesita el mismo AAB distribuido y firmado por Play.
No se probaron compras reales ni todos los formatos de anuncios. El registro
de test en AdMob no sustituye el modo de prueba propio del panel de Liftoff.
La comprobación del MIDI cubre carga y controles, no una evaluación auditiva
de todas las voces ni una auditoría de todo el repertorio.
