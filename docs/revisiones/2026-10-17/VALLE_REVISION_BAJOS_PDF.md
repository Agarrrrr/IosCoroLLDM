# Corrección posterior: bajos de Valle de los Huesos Secos

El usuario advierte que el MIDI tiene errores en los compases 9–17. El cotejo anterior con ese MIDI demostraba correspondencia entre archivos, no corrección musical. La primera entrega no debía presentarse como una transcripción completamente verificada del PDF.

## Referencia independiente

Se revisa el PDF abierto de la entrada confirmada por el usuario, sin usar el MIDI en los scripts de auditoría o corrección nuevos.

- Alturas diatónicas y octavas: posición de las cabezas de nota respecto de las cinco líneas y las claves.
- Alteraciones: glifos digitales de bemol y becuadro, armadura y persistencia dentro del compás. Se cotejaron 2.451 notas de las cuatro voces, incluidas las 603 de bajo. No se detectaron diferencias cromáticas con la copia preparada.
- Ritmo de bajo: figuras, plicas, barras de agrupación, corchetes, puntillos y silencios extraídos de la geometría del PDF. Se comprobaron los 148 compases, incluidos los sistemas donde el bajo permanece en silencio.
- Las ligaduras permanecen separadas del análisis de ataques del MIDI. Se conserva la revisión previa de sus arcos en el PDF.

## Fallo confirmado

En los compases **14 y 15**, el editable y el MIDI adelantan parte de la línea de bajo. El PDF deja sin imprimir un silencio de semicorchea, pero conserva su columna temporal: las ocho notas de bajo se alinean con las otras voces, donde ese silencio sí está impreso. La revisión visual, el total del compás y la correspondencia de columnas sustentan la inferencia de ese silencio.

La primera entrega colocó un silencio de compensación al final de esos compases. Eso completaba cuatro tiempos, pero mantenía desplazadas las notas. Se traslada ese silencio después de la tercera nota, en el segundo tiempo del compás.

Secuencia de ataques en negras desde el inicio de cada compás:

- Primera entrega: `0, 0.5, 0.75, 1, 1.25, 1.75, 2.75, 3.25`.
- Revisión según el PDF: `0, 0.5, 0.75, 1.25, 1.5, 2, 3, 3.5`.

En los otros compases del intervalo 9–17 no se detectaron diferencias de figuras, alturas o alteraciones frente a este PDF. La comprobación geométrica completa de bajo deja únicamente esas dos diferencias rítmicas antes de la corrección y ninguna después. Esto no sustituye una revisión editorial o auditiva de la obra.

## Archivo y trazabilidad

Nueva entrega: `C:/Users/Huri_/Downloads/musescore/Valle de los Huesos Secos - SATB revisado contra PDF.musicxml`.

Scripts independientes: `audit_valle_pdf_pitch.py`, `audit_valle_pdf_rhythm.py` y `correct_valle_pdf.py`, en `tools/verovio_pilot/`. No importan ni leen el MIDI.

Informes de detalle en `output/verovio_pilot_support/valle/`: `pdf-pitch-audit.json`, `pdf-bass-rhythm-before.json`, `pdf-bass-rhythm-audit.json`, `pdf-correction-report.json`. La primera entrega se conserva como registro del error.

MuseScore 4.7.5 importó y reexportó la revisión conservando el ritmo de bajo de los 148 compases. Las doce páginas se renderizaron y se revisaron visualmente las páginas que contienen los compases 9–17. Verovio confirmó 2.451 notas, 54 prolongaciones entre notas distintas y una ligadura de expresión.
