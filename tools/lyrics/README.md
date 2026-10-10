# Letras compactas desde PDF digitales SATB cerrados

Herramienta editorial previa a la compilación. No incorpora OCR, IA remota ni dependencias nuevas a la app. No modifica los catálogos, PDF o MIDI originales.

## Qué acepta

- PDF con texto extraíble, fuentes musicales digitales y pentagramas vectoriales.
- Disposición cerrada candidata: S/A en el primer pentagrama y T/B en el segundo, identificadas explícitamente en el documento.
- Filas de letra que pueden asignarse sin contradicciones a estrofas y coro.

Se excluye cualquier página con imágenes raster, aunque tenga OCR invisible, y también documentos híbridos, formatos musicales no reconocidos, SATB abierto, ausencia de etiquetas suficientes y filas ambiguas. Esta selección es deliberadamente conservadora: algunos PDF digitales válidos quedarán fuera. Los dos pentagramas por sí solos no prueban SATB; podría ser piano. Las etiquetas y geometría tampoco certifican el contenido musical: los candidatos siguen necesitando revisión.

## Salida

```text
Título

Estrofa 1
...

Coro
...

Estrofa 2
...

Estrofa 3
...
```

El coro se almacena como una sección, sin desplegarlo tras cada estrofa. Se conserva la repetición de frases que sí forma parte de su texto. Los saltos entre sistemas se reconstruyen cuando existe un guion explícito; `_` separa palabras unidas por elisión. No se adivinan palabras a partir de sílabas sin separadores ni se corrigen faltas del original automáticamente.

- `report.json`: clasificación, motivos, dudas, letra candidata, texto de voces secundarias e identidad del PDF.
- `drafts/<ID>.txt`: borradores **no destinados a publicación**.
- `approved/<ID>.txt`: únicamente las letras revisadas mediante un manifiesto.
- `lyrics.json`: índice de publicación **solo con aprobaciones del recorrido actual**. Sin manifiesto queda vacío.

Los avisos incluyen filas cambiantes, sílabas sin guiones, números de estrofa mal codificados y límites de palabra como `si-no`. El texto de voces secundarias se conserva como evidencia; no se concatena con la voz principal. Debe comprobarse que no haya contrapunto con letras diferentes ni versos omitidos. Repeticiones impresas del coro, cambios de sección sin etiqueta y estructuras excepcionales requieren edición del manifiesto.

## Instalación y ejecución

Python 3.10+ y Dart con las dependencias de este repositorio (`flutter pub get`). El puente `tools/read_lyrics_pdf.dart` reutiliza el descifrado de la app; no duplica la clave ni guarda copias descifradas en disco. Mantiene un proceso por lector para lotes.

```powershell
python -m pip install -r tools/lyrics/requirements.txt

# Piloto concreto, por ID; nunca se identifica una obra por parecido del título.
python tools/lyrics/extract.py --id usmc_47d16b904344db4db6db6432 --dart C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe --output output/lyrics/pilot

# Catálogo español completo. Máximo cuatro procesos, sin red.
python tools/lyrics/extract.py --workers 4 --dart C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe --output output/lyrics/catalog-es

# Inglés, en una carpeta distinta para conservar ambos índices.
python tools/lyrics/extract.py --catalog assets/catalogo_en.json --workers 4 --dart C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe --output output/lyrics/catalog-en

# Ambos idiomas en un único índice.
python tools/lyrics/extract.py --catalog assets/catalogo.json --catalog assets/catalogo_en.json --workers 4 --dart C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe --output output/lyrics/catalog
```

`--limit 20` permite un piloto por cantidad. Los errores de recursos se registran y producen código de salida 1; las exclusiones previstas no se consideran fallos. La salida del proceso solo enumera ID/estado y conteos, sin volcar los PDF ni sus letras.

En la copia de trabajo local, `tools/lyrics/reviewed.json` contiene el ejemplo de «A Dónde Iré» revisado contra su página y el texto aportado por el usuario, con las correcciones editoriales expresas. No se publica ese manifiesto ni las letras generadas en GitHub. Para reproducir el ejemplo local, añadir `--approved tools/lyrics/reviewed.json` al comando; en otra copia hay que crear su propio manifiesto revisado como se describe abajo. El PDF original permanece intacto.

## Revisión y publicación offline

1. Revisar **todas las páginas** y confirmar SATB cerrado y letra común. No aprobar por el nombre del canto.
2. Copiar del informe el ID y `source_sha256` del contenido descifrado.
3. Crear un manifiesto como el de abajo con la letra corregida y las secciones definitivas. No eliminar repeticiones internas legítimas.
4. Ejecutar nuevamente con `--approved ruta/revision.json`.
5. Importar únicamente `lyrics.json`. Las letras y el índice siguen siendo recursos locales; esta herramienta no añade todavía su pantalla a la app.

```json
{
  "ID_REAL_DEL_CANTO": {
    "source_sha256": "HASH_REAL_DEL_PDF_DEL_INFORME",
    "satb_closed": true,
    "common_lyrics": true,
    "sections": [
      {"id": "estrofa_1", "lines": ["Primera línea revisada."]},
      {"id": "coro", "lines": ["Coro revisado, una sola vez."]},
      {"id": "estrofa_2", "lines": ["Segunda estrofa revisada."]}
    ]
  }
}
```

Una aprobación con otro hash falla; si cambia el PDF hay que revisar su nueva versión. Se rechazan IDs duplicados, rutas fuera de la biblioteca, secciones repetidas y aprobaciones sin confirmación de SATB/letra común. El índice se reconstruye cada vez; usar carpetas distintas para lotes parciales. Un archivo TXT antiguo de un canto fuera del lote no acredita aprobación vigente: el índice es la referencia.

## Pruebas

```powershell
python -m unittest discover -s tools/lyrics -p test_extract.py -v
```

Las pruebas requieren también `reportlab` y `Pillow` (disponibles en el runtime de documentos); generan en memoria un escaneo con texto para comprobar que no se acepta como partitura digital.

Referencias técnicas: [pdfplumber](https://github.com/jsvine/pdfplumber), [pypdf](https://pypdf.readthedocs.io/). La extracción es geométrica y textual; no reconoce notas para reconstruir MusicXML ni promete exactitud musical automática.
