# Correcciones de integridad offline — 10 de octubre de 2026

Registro posterior a `AUDITORIA_INTEGRIDAD_OFFLINE_2026-10-10.md`. El informe original de auditoría no se modifica.

## Cambios

- **Pecador, Ven al Dulce Jesús:** la referencia PDF en los dos catálogos de la app ahora apunta a `pecador-ven-al-dulce-jesus-1777250932709.pdf`, ya incluido en el paquete. Se conservan el ID, título y MIDI. La URL del catálogo del sitio web se conserva, ya que este registro corrige los recursos de la aplicación offline.
- **Maravillosa Gracia:** se sustituyó exclusivamente la compresión de los objetos 47 y 49. Sus contenidos siguen siendo `q\n` y `\nQ\n` (guardar/restaurar estado gráfico). Las nuevas secuencias tienen exactamente la misma longitud, por lo que se conservan posiciones, referencias, estructura, notas y letras del documento. El archivo empaquetado mantiene el cifrado AES-GCM y el mismo tamaño.
- La versión de Maravillosa Gracia pasa de la predeterminada 1 a 2, para renovar el PDF en instalaciones que ya tienen una copia en caché.

## Verificación

- Los 25 flujos FlateDecode del PDF reparado descomprimen sin error.
- Ambas páginas renderizadas a 1.800 px son idénticas píxel por píxel antes y después. Se revisaron visualmente las dos páginas corregidas.
- Poppler dejó de informar errores Flate en este PDF.
- Las pruebas de todos los recursos declarados, sincronización de catálogos e identidad de las dos obras «La Vida Se Va Como el Viento» terminaron correctamente: 8 pruebas.
- **Revalidación física completada después del desbloqueo manual:** Samsung SM_G986U, Android 13, paquete independiente `.perfaudit`. Ambas partituras abrieron y sus tres páginas se renderizaron mediante PDFium/pdfrx; ambos MIDI cargaron mediante MidiEngine con el SoundFont local. Las rutas de ambos cantos también abrieron con caché vacía y HTTP bloqueado: **4 recursos correctos, 2 cantos correctos, 0 incidencias y 0 intentos de red**. El test terminó con `All tests passed!`.
- El primer intento con pantalla apagada no había llegado a ejecutar los recursos; ese fallo del arnés queda conservado en el registro anterior. La ejecución exitosa prueba exclusivamente las dos correcciones, complementando la auditoría completa previa; no es una repetición de los 2.108 archivos.
- El JSON externo del test exitoso ya no estaba disponible al finalizar Flutter y realizar `adb pull`. Se conserva el registro exitoso y un resumen identificado expresamente como derivado de ese registro y de las aserciones del test; no se presenta como el JSON bruto del dispositivo.

## Conservación y evidencias

Las copias anteriores de ambos catálogos y del PDF cifrado están en `output/offline_integrity/2026-10-10/corrections/originals/`. No se modificaron los audios ni las demás obras. No se hizo commit ni push a GitHub.

- [Comprobación de reparación y hashes](../output/offline_integrity/2026-10-10/corrections/repair-verification.json)
- [Pruebas de catálogos e identidad de obras](../output/offline_integrity/2026-10-10/corrections/catalog-tests.log)
- [Registro de la prueba física](../output/offline_integrity/2026-10-10/corrections/device-tests.log)
- [Prueba física exitosa tras desbloquear el móvil](../output/offline_integrity/2026-10-10/corrections/device-tests-unlocked.log)
- [Resumen de la prueba exitosa y procedencia de la evidencia](../output/offline_integrity/2026-10-10/corrections/device-result.json)
