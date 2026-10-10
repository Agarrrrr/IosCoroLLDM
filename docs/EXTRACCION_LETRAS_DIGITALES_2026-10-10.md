# Letras compactas desde PDF digitales SATB cerrados

## Entrega

Extractor editorial local: `tools/lyrics/extract.py`. Puente de descifrado: `tools/read_lyrics_pdf.dart`. Uso, revisión y dependencias: `tools/lyrics/README.md`.

No se modifican PDF, MIDI ni catálogos. No usa OCR ni envía documentos a servicios externos. No añade aún una pantalla de letras a la aplicación. Genera recursos de texto y JSON que pueden empaquetarse offline posteriormente.

## Recorrido completo

Ejecutado sobre los dos catálogos actuales, con cuatro lectores y el manifiesto revisado del ejemplo:

```powershell
python tools/lyrics/extract.py --catalog assets/catalogo.json --catalog assets/catalogo_en.json --dart C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe --approved tools/lyrics/reviewed.json --workers 4 --output output/lyrics/catalog
```

| Resultado | Cantidad |
| --- | ---: |
| Entradas examinadas | 1.651 |
| Español / inglés | 1.343 / 308 |
| Borradores pendientes de revisión | 27 |
| Ejemplo revisado: A Dónde Iré | 1 |
| Fuera de generación automática | 1.623 |
| Errores de ejecución | 0 |

La selección es conservadora. **Estas cifras no significan que 1.623 PDF sean escaneos o que ninguno pueda transcribirse.** Incluyen SATB abierto, formatos que el detector no reconoce y estructuras de letra que no puede separar con seguridad. No se puede prometer generación fiable para la mayoría del catálogo con este primer detector.

Motivo principal de salida, uno por entrada (el informe conserva todos los motivos y páginas):

| Motivo | Entradas |
| --- | ---: |
| S/A y T/B en dos pentagramas no confirmados | 590 |
| Raster o híbrido | 330 |
| Fuentes musicales digitales no confirmadas | 278 |
| Filas ambiguas: estrofas frente a voces distintas | 196 |
| Filas de coro ambiguas | 99 |
| Geometría/glyphs musicales no confirmados | 72 |
| Demasiadas filas de letra | 53 |
| Pentagramas separados de voces detectados | 4 |
| Referencia remota, sin lectura local | 1 |

Como control visual de una exclusión se revisó Adelante Juventud: su primera página muestra cuatro pentagramas separados para S, A, T y B, por lo que no corresponde a la disposición cerrada pedida. Este control puntual no certifica todas las otras exclusiones.

## Formato y protección de identidad

- Estrofa 1, coro una vez, estrofas restantes numeradas. En inglés: Verse/Chorus.
- Reconstrucción de sílabas con guion explícito, elisiones y palabras partidas entre sistemas. No se inventan palabras de sílabas sin separadores.
- Coros impresos repetidos se almacenan una vez; versiones diferentes quedan señaladas para revisión. No se eliminan repeticiones de frases que forman parte del propio coro.
- Texto de otras voces separado como evidencia; no se concatena indiscriminadamente con la línea principal.
- Resultados asociados a ID y SHA-256 del PDF descifrado. Una revisión de un documento distinto no sirve para aprobarlo. No se identifican obras por parecido del título.
- Cualquier página raster/híbrida invalida la generación de ese documento, incluso si tiene una capa de OCR invisible. No se publica una letra parcial extraída solo de sus páginas digitales.

## Ejemplo revisado

`tools/lyrics/reviewed.json` documenta la página de A Dónde Iré, su hash y las correcciones editoriales. Se retiró un número de estrofa mal codificado como L y se normalizaron puntuación/saltos y si-no. La lectura «ese amor» utiliza el ejemplo aportado por el usuario; el PDF imprime «ese mor». Se conserva «vida me da» del PDF, aunque el ejemplo aportado decía «vida me dan».

Archivo compacto: `output/lyrics/catalog/approved/usmc_47d16b904344db4db6db6432.txt`. Índice listo para importación: `output/lyrics/catalog/lyrics.json` (solo ese ejemplo). Los 27 restantes se conservan como borradores, no como letras aprobadas.

## Verificación y evidencia

- 15 pruebas del extractor aprobadas: escaneo con OCR oculto, SATB abierto, documentos mixtos, texto sin partitura, sílabas, elisiones, continuaciones, filas contradictorias, coro compacto, coro repetido, variantes del coro, estrofa explícita tras el coro, referencias remotas, rutas externas y aprobación por hash.
- Puente Dart analizado sin incidencias.
- Recorrido final de 1.651 entradas terminado con código 0.
- Registros: `output/accessibility/lyrics-script-tests-2026-10-10.log`, `output/accessibility/lyrics-bridge-analysis-2026-10-10.log`, `output/lyrics/catalog/run.log`.
- Informe por ID y página: `output/lyrics/catalog/report.json`.

Siguiente trabajo para ampliar cobertura: revisar documentos excluidos que sí sean digitales y cerrados, ampliar sus formatos reconocidos y validar las letras contra todas sus páginas. Los originales y la auditoría histórica se conservan.

## Publicación del trabajo

Se publica en GitHub el código, las pruebas, esta documentación y los registros de verificación del script. Las letras generadas, el manifiesto del ejemplo y el informe detallado de extracción se conservan **localmente**: la revisión automática rechazó incluir ese contenido derivado en el push sin autorización específica de publicación. Los comandos de aprobación requieren ese manifiesto local o uno nuevo revisado.
