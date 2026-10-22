# Incorporación de ocho partituras

Se añadieron las ocho obras seleccionadas expresamente por el usuario al catálogo español de la aplicación y a su copia offline. El catálogo pasa de 1352 a 1360 entradas. Cada obra tiene un UUID nuevo y un PDF empaquetado con AES-GCM, versión 1, usando la ruta de contenido `global/assets/pdf/<sha256>.enc`.

| Obra | Tema | Páginas |
| --- | --- | ---: |
| La Luz de Dios | Elección | 1 |
| Mirad al Rey | Alabanza | 2 |
| Pero Yo Creí | Elección | 2 |
| Qué Sería de Mí | Confianza | 2 |
| Resplandor de la Gloria | 12 de Diciembre | 2 |
| Vamos a Jerusalén | 1 de Agosto | 2 |
| De Tu Mano Hasta el Final | Confianza | 4 |
| Alzad Vuestros Ojos | Advenimiento | 1 |

Los archivos proceden de las copias descargadas durante la comparación del catálogo público de Mi Coro, conservadas en `output/auditoria_micoro_2026-10-20/diferencias_pdfs`. La procedencia y los hashes de cada PDF están registrados en `output/importacion_partituras_2026-10-20/incorporacion.json`. Se conservan íntegros los archivos, con sus créditos y marcas originales; su incorporación no establece autoría propia ni titularidad sobre las obras.

No se añadieron MIDI, audio ni vínculos bilingües a estas entradas. Se analizaron los ocho PDF y se renderizaron e inspeccionaron sus 16 páginas. El cifrado se comprobó mediante descifrado y comparación exacta con cada original.

Las entradas previas del catálogo principal conservan sus valores. La copia offline se sincronizó con ese catálogo, recuperando también dos diferencias preexistentes en los campos MIDI de La Restauración y Salmo 23. Los originales anteriores están preservados en la carpeta de la importación.

El cambio es local al proyecto: no incluye instalación en el teléfono, publicación en tiendas ni actualización del catálogo del sitio web o del servidor.

Validación: `flutter test --no-pub test/offline_catalog_test.dart`, tres pruebas aprobadas. Se verificaron la sincronización de los catálogos, la carga real y validez de todas las partituras empaquetadas y todos los MIDI declarados. `git diff --check` terminó sin errores.
