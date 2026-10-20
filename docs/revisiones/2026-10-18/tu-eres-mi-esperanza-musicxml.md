# Tú Eres mi Esperanza — MusicXML SATB para Cantai

Fecha: 2026-10-18.

## Fuentes y alcance

- Registro exacto: `379a569c-c84f-4a6e-9e45-fdaa318bd3a9`, «Tú Eres mi Esperanza».
- PDF digital de la app: `assets/offline_assets/pdfs/tu-eres-mi-esperanza.pdf`, dos páginas cerradas SA/TB.
- MIDI de la app: `assets/offline_assets/midis/tu-eres-mi-esperanza-1779936147742.midi`, cuatro pistas identificadas soprano, contralto, tenor y bajo.
- Autor: Neftalí Medina F.; arreglos: Jacob Medina / Job Ruiz P.
- Entrega independiente en Downloads/musescore; no se cambian el catálogo ni los PDF/MIDI de la app.

## Desarrollo musical

- Cuatro pentagramas SATB, tenor en clave de sol octavada, con letra por pentagrama.
- Mi bemol mayor, 12/8, anacrusa de tres negras, negra = 85.
- Tres estrofas, cada una con su coro, y final especial. Secuencia del PDF: 1–23; 2–23; 2–22 y 24–26. Resultado: 69 compases, 411 negras de duración escrita.
- Se respetan las entradas distintas del tenor y del bajo en el coro y el divisi del tenor. No se fuerza el ritmo de soprano a las otras voces.
- El MIDI repite cuatro veces el mismo ciclo con final y omite silencios entre ciclos; se usa su primer ciclo como referencia de notas, siguiendo la forma y los silencios del PDF.
- Compás original 16: soprano Re bemol, explícito en el PDF; el MIDI contiene Re natural. Corrección repetida en los tres coros.
- Compás original 14: el Re inferior del divisi de tenor está ligado entre la blanca con puntillo y la negra. Se elimina el reataque del MIDI; la voz superior Si bemol → La bemol conserva su ligadura de expresión.
- Las dos frases con cambio de altura del tenor se distinguen de las ligaduras de prolongación.
- Dinámicas y reguladores del conjunto cerrado se trasladan a las cuatro partes. La apertura del crescendo del coro se prolonga desde el compás 12 hasta el 14, cruzando la página del PDF.
- Ritardando final con reproducción efectiva. Destino editorial de 60 BPM desde 85, porque el PDF sólo indica «rit.» y el MIDI permanece a 85. Se preserva el calderón, cuya prolongación aplica MuseScore adicionalmente.
- Letra silabeada con guiones, sinalefas y prolongaciones, ortografía «mí?» en la pregunta del coro. Espaciado mínimo configurado de letra: 1 sp.

## Verificación

`tools/verovio_pilot/validate_esperanza.py` verifica:

- Lectura del XML, importación a MuseScore 4.7.5, exportación y nueva importación.
- Cuatro partes y duración completa de todos los compases.
- 1 561 notas escritas, 218 continuaciones ligadas, seis ligaduras de expresión, cuatro calderones y 1 296 notas con texto.
- 1 343 ataques efectivos: soprano 326, alto 326, tenor 362, bajo 329. El MIDI generado por MuseScore y el de la reimportación coinciden en posición y altura; las ligaduras no crean ataques nuevos.
- Correspondencia de ataques y duración agregada con el primer ciclo del MIDI de referencia, desarrollado según el PDF, permitiendo únicamente el Re bemol de soprano y la prolongación del Re del tenor descritos arriba.
- Alturas y posiciones contra las cabezas de nota del PDF digital: sin notas omitidas ni discrepancias pendientes en los controles de geometría, alturas o figuras.
- Letra, notas, ligaduras, frases y calderones conservados después de la exportación/reimportación.
- 76 indicaciones dinámicas y 28 reguladores en la versión desarrollada.
- Los 17 puntos de tempo del XML canónico se reproducen en el proyecto nativo, incluido el ritardando y el efecto adicional del calderón.
- Revisión visual de las dos páginas fuente, hoja de contacto de las nueve páginas generadas y páginas completas representativas 1, 3 y 9. Cuatro pentagramas visibles y sin recorte inferior; expansión vertical automática desactivada.

## Archivos y limitación de intercambio

Entregables: `Tú Eres mi Esperanza - SATB extendido - Cantai.musicxml` y el proyecto `.mscz` del mismo nombre.

Para Cantai usar el XML canónico entregado directamente. MuseScore conserva el ritardando en su proyecto nativo, pero su reexportación a MusicXML omite varios puntos de tempo ocultos y redondea otros. No sustituir el XML entregado por esa reexportación si se quiere conservar la curva completa. No se ha probado esta entrega dentro de Cantai.

Evidencia y vistas previas: `output/verovio_pilot_support/tu_eres_mi_esperanza/`; comprobaciones en `validation.json`, decisión y conteos en `preparation.json`, manifiesto de entrega en `delivery.json`.

## Reproducción local

En orden, ejecutar con Python: `inspect_esperanza.py`, `esperanza_model.py`, `esperanza_geometry.py`, `esperanza_underlay.py`, `esperanza_words.py`, `esperanza_expressions.py`, `prepare_esperanza.py`, `render_esperanza.py`, `validate_esperanza.py`, `deliver_esperanza.py`, todos en `tools/verovio_pilot/`.

El último paso comprueba hashes antes de reemplazar una entrega anterior para preservar posibles modificaciones del usuario.
