# Correcciones del gestor CoroLLDM — 10 de octubre de 2026

Registro posterior a la auditoría del gestor. Se conservaron los informes originales.

## Repertorio conservado

Antes de editar el código se tomaron hashes SHA-256 de los catálogos y recursos de ambos proyectos. La comparación posterior verificó **2.112 archivos del PWA y 2.112 archivos de la app sin cambios**. No se ejecutó una sincronización sobre los catálogos reales ni se cambiaron sus IDs, títulos, PDFs, MIDIs o asignaciones durante esta corrección del gestor.

La mezcla de los catálogos españoles reales se probó únicamente en memoria: 1.343 obras antes y después, sin cambios de referencias PDF/MIDI ni versiones de obras existentes. Las correcciones anteriores de Pecador y Maravillosa Gracia en la app se conservaron.

## Cambios aplicados

- Se retiraron las coincidencias y eliminaciones automáticas por título del middleware, del sincronizador por lotes y del cliente remoto. Dos obras con el mismo nombre y diferentes IDs se conservan.
- La edición modifica la obra por ID en cada destino, sin sustituir el catálogo completo del PWA sobre la app. Las obras exclusivas del destino se mantienen.
- Las versiones más antiguas no sustituyen versiones recientes. Las referencias nuevas que cambian un archivo sin aumentar su versión se rechazan en una edición; en una mezcla por lotes se mantiene el recurso existente. Una URL HTTP no sustituye un recurso local.
- Las migraciones ambiguas de IDs se detienen y requieren una correspondencia explícita. No se cambian los IDs del repertorio automáticamente para deduplicar.
- PDF y MIDI se descifran, autentican y validan antes de preparar su copia offline. El PDF debe tener páginas y el MIDI pistas con notas. La carga del cliente también valida el formato antes de subirlo.
- Un archivo local ya cifrado se descifra antes de volver a cifrarlo: se conserva una sola capa AES-GCM. El hash enviado a la API corresponde al contenido claro. Los bytes claros validados también se entregan al sincronizador local, incluso al editar archivos heredados.
- Los archivos y los catálogos se preparan en temporales antes de aplicar la escritura. Si falla una sustitución, se recuperan los archivos anteriores. Las solicitudes locales se procesan en orden para evitar guardados simultáneos que se sobrescriban.
- La sincronización de recursos comprueba el contenido existente, en lugar de considerar suficiente que haya un archivo. Procesa descargas sucesivamente y actualiza la referencia de catálogo cuando el servicio resuelve una clave nueva.
- El cliente comprueba HTTP y el JSON de respuesta. Si la nube guardó y la copia offline falló, el usuario ve ese resultado parcial; no se informa éxito completo.
- El sincronizador por lotes aborta si alguna fuente obligatoria falta o no contiene JSON válido. Incluye `--dry-run` y el comando `npm run sync-catalogs:check` para comprobar sin escribir.
- La baja explícita se propaga por ID a los catálogos locales; los PDF/MIDI físicos se conservan para evitar borrar recursos compartidos.
- La herencia de MIDI por vínculo de idioma solo se aplica cuando no hay un MIDI propio o elegido. Se impiden envíos repetidos del formulario mientras guarda.
- El editor antiguo `tools/bulk_manager` quedó en **solo lectura**, enlazado a loopback. Sus rutas masivas no disponían de las garantías del gestor principal; ahora indican que los cambios se deben guardar desde ese gestor.

## Pruebas

- **18 pruebas nuevas de seguridad:** identidad, versiones, preservación de exclusivas, rechazo de recursos inválidos, recuperación ante fallo, referencias locales, bajas por ID, lectura JSON obligatoria, mezcla sin escrituras, cifrado único, hash del contenido claro y propagación de errores.
- **20 pruebas existentes:** todas pasaron.
- Compilación de producción del gestor comprobada. El aviso de tamaño del paquete de dependencias continúa; no representa un fallo de compilación.
- Conservación de los repertorios verificada mediante hashes, no solo mediante conteos.

Comando de regresión añadido al repositorio del gestor:

```text
npm run test:catalog-safety
```

## Límites

Las pruebas del cliente utilizaron llamadas remotas simuladas y las del filesystem utilizaron carpetas temporales. No se guardaron ni borraron obras en Supabase/Cloudflare, no se desplegó el gestor y no se ejecutó una sesión real autenticada. La operación entre nube y disco local no es una transacción distribuida: una falla local posterior a un guardado remoto se informa al usuario y requiere volver a sincronizar. La recuperación de archivos cubre errores de escritura durante la ejecución; no equivale a una garantía ante corte eléctrico en mitad de una operación.

## Evidencias

- [Hashes y conservación del repertorio](../output/gestor_integrity/2026-10-10/fix/repertoire-preservation.json)
- [18 pruebas nuevas](../output/gestor_integrity/2026-10-10/fix/final-safety-tests.log)
- [20 pruebas existentes](../output/gestor_integrity/2026-10-10/fix/existing-tests.log)
- [Compilación final](../output/gestor_integrity/2026-10-10/fix/final-manager-build.log)

Los respaldos originales de las fuentes están en `output/gestor_integrity/2026-10-10/fix/source-originals/`. El código corregido y las pruebas están en `E:/proyectos/CoroLLDM/scripts/` y en los módulos del gestor.
