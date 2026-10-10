# Auditoría del gestor CoroLLDM — 10 de octubre de 2026

## Resultado

**El gestor todavía puede producir problemas de identidad de obras, sincronización e integridad offline. No conviene usarlo para una actualización masiva antes de corregir los puntos de prioridad alta.** Se reprodujeron 14 casos con funciones reales del código, catálogos sintéticos y filesystem en memoria. Todas las operaciones remotas fueron simuladas; no se escribieron los catálogos reales ni se llamó a Supabase o Cloudflare.

Código examinado: `E:/proyectos/CoroLLDM`. El gestor principal es `gestor.html`, `src/gestor/partituras`, `src/api/remoteCatalogDB.js` y el middleware de `vite.config.js`. También se revisaron el sincronizador por lotes y la herramienta adicional `tools/bulk_manager`.

La auditoría de archivos de la app comprueba el estado actual del paquete. Esta auditoría comprueba cómo futuros guardados del gestor pueden volver a deteriorarlo. No demuestra que estos defectos sean la causa histórica de cada incidente anterior.

## Prioridad alta

### 1. El nombre sigue actuando como identidad y puede reemplazar obras distintas

Confirmado mediante cuatro reproducciones:

- Un alta con otro ID y el mismo título reemplaza la fila anterior en el middleware local.
- `saveCanto` sin `editingId` encuentra un UUID por nombre y lo utiliza para actualizar la obra existente.
- La combinación de catálogo remoto/local colapsa dos UUID distintos por título y cambia el PDF de la fila conservada.
- Tanto `writeMergedCatalog` como el sincronizador por lotes eliminan entradas distintas con un título normalizado idéntico.

Referencias: [middleware, selección por nombre](E:/proyectos/CoroLLDM/vite.config.js:294), [deduplicación del destino](E:/proyectos/CoroLLDM/vite.config.js:105), [combinación remota](E:/proyectos/CoroLLDM/src/api/remoteCatalogDB.js:264), [alta convertida en edición](E:/proyectos/CoroLLDM/src/api/remoteCatalogDB.js:355), [merge por lotes](E:/proyectos/CoroLLDM/scripts/sync_catalogs.mjs:106).

**Corrección:** identidad por ID estable; migración de IDs únicamente con correspondencia explícita inequívoca. Un título duplicado debe ser una advertencia, no autorización para fusionar, eliminar o heredar un audio.

### 2. Un guardado sobrescribe todo el catálogo de la app y puede deshacer correcciones

El middleware escribe el catálogo completo del PWA directamente sobre ambos catálogos españoles de la app. El sincronizador por lotes también reemplaza los catálogos de iOS desde el PWA.

Reproducción con las copias reales cargadas en memoria: guardar metadatos de un canto ajeno volvió a dejar «Pecador, Ven al Dulce Jesús» con URL remota y «Maravillosa Gracia» con versión inferior a 2. No se ejecutó esta escritura sobre los proyectos reales. Una segunda reproducción eliminó una obra exclusiva del destino.

Referencias: [sobrescritura en cada guardado](E:/proyectos/CoroLLDM/vite.config.js:344), [sobrescritura por lotes](E:/proyectos/CoroLLDM/scripts/sync_catalogs.mjs:146).

**Corrección:** actualizar por ID únicamente la obra editada, preservar las otras filas y rechazar retrocesos de versión. Resolver de forma explícita cuál es la fuente de cada campo. Incorporar las dos correcciones offline al origen adecuado antes de volver a sincronizar.

### 3. Editar un nombre de archivo ya cifrado puede cifrarlo una segunda vez

`uploadDataUrl` lee la ruta `/offline_assets/...` y siempre aplica `encryptAsset`, sin distinguir si el recurso ya está cifrado. En una simulación con un PDF cifrado de la misma forma que los assets existentes, la carga resultante requirió dos descifrados: después del primero no tenía cabecera PDF. La app espera un único descifrado.

Referencia: [lectura y cifrado del recurso local](E:/proyectos/CoroLLDM/src/api/remoteCatalogDB.js:43).

**Corrección:** detectar y autenticar el cifrado existente; trabajar con bytes claros validados y aplicar exactamente una capa de cifrado. Comprobar tanto PDF como MIDI. El resultado simulado confirma el defecto del cliente; no se probó qué respuesta daría el Worker de producción a ese archivo.

### 4. El gestor puede declarar éxito sin tener un PDF/MIDI local válido

El middleware aceptó un alta con una referencia inexistente y sin bytes. También cifró y guardó `hello` como si fuera un PDF válido. `sync_remote_assets` considera suficiente `existsSync` para omitir una descarga; no autentica ni comprueba el archivo existente.

Referencias: [escritura sin validación de formato](E:/proyectos/CoroLLDM/vite.config.js:138), [omisión por mera existencia](E:/proyectos/CoroLLDM/vite.config.js:232), [upsert sin requisito de disponibilidad](E:/proyectos/CoroLLDM/vite.config.js:327).

**Corrección:** comprobar disponibilidad de los recursos nuevos y ya referenciados; autenticar el cifrado y abrir los archivos antes de publicar el cambio de catálogo. Para MIDI, validar estructura y pistas; para PDF, parseo y páginas. No basta la extensión o MIME declarado.

### 5. Hay cambios parciales y éxito aparente cuando falla la sincronización

Una falla simulada al escribir el PDF de iOS devolvió HTTP 500 después de que su catálogo ya se hubiese cambiado. Por separado, `saveCanto` terminó correctamente cuando `/__gestor_sync_catalog` devolvió HTTP 500: el cliente espera `fetch`, pero no comprueba `response.ok` ni el resultado del JSON. El `catch` solo avisa por consola.

Referencias: [catálogo escrito antes del asset de iOS](E:/proyectos/CoroLLDM/vite.config.js:344), [respuesta local no comprobada](E:/proyectos/CoroLLDM/src/api/remoteCatalogDB.js:438).

**Corrección:** preparar y validar primero los archivos, escribir temporalmente y aplicar cambios con recuperación ante fallos. Distinguir «guardado en la nube» de «sincronizado offline» y comunicar los fallos reales. Evitar mostrar éxito completo cuando alguna etapa no terminó.

### 6. El sincronizador por lotes trata JSON corrupto como catálogo vacío

`loadJson` devuelve `[]` cuando falta el archivo o falla el parseo. La ejecución continúa y `saveJson` puede sustituir los catálogos de destino por esas listas vacías. La lectura de un JSON inválido se reprodujo sin escribir destinos reales.

Referencia: [lectura que silencia el fallo](E:/proyectos/CoroLLDM/scripts/sync_catalogs.mjs:26).

**Corrección:** abortar antes de cualquier escritura si una fuente obligatoria falta o es inválida; validar ambos idiomas y conservar una copia previa recuperable.

## Prioridad media

### 7. Borrados no coherentes entre nube, PWA y app

La ruta local `/__gestor_sync` elimina solo del PWA. Su reproducción conservó la fila en ambos catálogos de iOS. Además, `remoteCatalogDB.deleteCanto` desactiva en nube e invalida su caché, pero no solicita la eliminación local; la combinación posterior vuelve a incluir filas locales. Estos flujos deben acordar qué significa desactivar y qué significa retirar del paquete offline.

Referencias: [borrado local](E:/proyectos/CoroLLDM/vite.config.js:186), [borrado remoto](E:/proyectos/CoroLLDM/src/api/remoteCatalogDB.js:465).

**Corrección:** propagar el estado de desactivación por ID y aplicar una política consistente; evitar borrar físicamente un recurso compartido con otras obras.

### 8. El vínculo de idioma puede reemplazar el MIDI seleccionado por el usuario

En `partiturasPanel`, se procesa primero el archivo MIDI elegido y después, si el vínculo contiene MIDI, se sustituye incondicionalmente por el de la otra obra. Esto puede ocultar que el archivo recién elegido no será el que se guarde. Se confirmó por lectura de la secuencia de instrucciones; no se ejecutó un formulario autenticado real.

Referencia: [herencia posterior a la selección](E:/proyectos/CoroLLDM/src/gestor/partituras/partiturasPanel.js:123).

**Corrección:** dar prioridad a la elección explícita; hacer visible la herencia y permitir confirmarla o retirarla, sin asumir equivalencia de arreglos por título.

## Herramienta adicional de edición masiva

`tools/bulk_manager/server.js` permite guardar el catálogo entero, subir archivos y borrar físicamente un PDF. Carece de control de versión de edición, validación de referencias y comprobación de otros cantos que compartan el PDF. El nombre de archivo de borrado procede directamente del body. Usa CORS abierto y `app.listen(PORT)` sin limitar explícitamente el host a loopback.

Estos son riesgos del código de esa herramienta adicional; no se verificó si está activa, expuesta por red o utilizada actualmente. No deben atribuirse automáticamente al gestor principal.

Referencia: [servidor de gestión masiva](E:/proyectos/CoroLLDM/tools/bulk_manager/server.js:1).

## Orden recomendado para corregir

1. Proteger identidad por ID y quitar fusiones/eliminaciones automáticas por título.
2. Sustituir sobrescrituras completas por actualizaciones verificadas por ID; preservar las correcciones offline.
3. Corregir el cifrado y exigir integridad/disponibilidad de archivos.
4. Evitar escrituras parciales y comprobar todas las respuestas de sincronización.
5. Hacer que el sincronizador aborte ante fuentes inválidas.
6. Unificar bajas y aclarar la herencia explícita del MIDI.

## Evidencias y alcance

- [10 reproducciones del middleware y sincronizador](../output/gestor_integrity/2026-10-10/isolated-reproductions.json).
- [4 reproducciones del cliente remoto, con toda la red simulada](../output/gestor_integrity/2026-10-10/remote-isolated-reproductions.json).
- [Arnés aislado del middleware](../tools/audit_gestor_isolated.cjs).
- [Arnés aislado del cliente](../tools/audit_gestor_remote_isolated.cjs).

Se ejecutó el código real extraído de los módulos, no una reimplementación de la lógica. Las pruebas no abrieron el gestor con una sesión de administrador, no verificaron las políticas del backend desplegado y no enviaron mutaciones remotas. No se modificó `CoroLLDM`, no se hicieron cambios en los catálogos reales y no hubo push o despliegue.
