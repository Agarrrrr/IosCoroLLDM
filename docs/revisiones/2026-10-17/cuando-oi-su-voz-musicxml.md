# Cuando Oí Su Voz — MusicXML SATB desarrollado

## Entrega

- MusicXML canónico y proyecto MuseScore en `C:/Users/Huri_/Downloads/musescore`, nombre `Cuando Oí Su Voz - SATB extendido - Cantai`.
- Cuatro partes independientes: Soprano, Alto, Tenor y Bajo. Se conservan las claves de sol de las mujeres y de fa de los hombres del original.
- Tres estrofas, cada una seguida de su coro. Las dos primeras usan la primera/segunda casilla; la tercera conduce al cierre final. Se desarrollan 47 compases fuente en 128 compases, 506 negras.
- Letra silabeada por pentagrama, con guiones, elisiones y prolongaciones. El bajo mantiene sus silencios y ritmos independientes: se alinea el texto compartido con sus entradas, sin copiarle notas del tenor para forzar cada sílaba.
- Se conserva el divisi final del alto en su propio pentagrama.
- Separación mínima de letras de 1 sp y espacio lateral de notas respecto de las barras. El cierre se agrupa para evitar un último compás aislado.

## Fuentes y decisiones

Se usan el PDF digital de tres páginas y el MIDI de la aplicación, descifrados únicamente en la carpeta de trabajo. Los recursos originales y los catálogos no se modifican.

El PDF determina la notación y la letra; el MIDI ayuda a separar voces y duraciones. Diferencias resueltas:

1. El PDF indica **negra = 78**. El MIDI usa 85, con reinicios a 120 durante silencios y desaceleraciones no impresas. La entrega conserva 78; no añade calderones ni cambios de tempo ausentes del PDF.
2. Se conservan los tres tiempos iniciales de silencio que el MIDI recorta. La comparación con el MIDI suma tres negras a sus posiciones.
3. En el compás fuente 4, el MIDI omite seis notas del movimiento compartido de hombres. Se recuperan del PDF en Tenor y Bajo, en las tres estrofas: 36 notas sonoras recuperadas.
4. La nota entre paréntesis del compás fuente 6 se conserva como nota opcional pequeña en las dos voces masculinas. No suena en la reproducción de MuseScore.
5. Alto: el final del compás fuente 32 se toma como Mi y el tresillo final del 42 como Re, siguiendo las cabezas de nota del PDF frente a las alturas distintas del MIDI.
6. Se recuperan divisiones gráficas de notas que el MIDI une en un único evento, manteniendo la duración mediante ligaduras de prolongación.
7. Las curvas que coinciden con nuevas sílabas en otras estrofas se tratan como fraseo: «gran-de» / «fe-liz» y «Su Au-». No se silencian esas sílabas por copiar ciegamente la prolongación de la primera estrofa. Las voces masculinas que sostienen «Uh» conservan su prolongación.
8. Se corrigen dos defectos evidentes del texto: «intante» → «instante» y el punto interno de «Di.os.» → «Dios.». No se cambia su posición musical.

## Validación

- PDF: todas las cabezas de nota identificadas están representadas; sin discrepancias pendientes de geometría, altura, figura ni cabezas omitidas en `pdf-layout.json`.
- 128 compases completos en cada una de las cuatro partes; cambios a 2/4 y regreso a 4/4 conservados en cada pasada.
- 2.015 notas escritas, incluyendo seis notas opcionales; 48 enlaces de prolongación, 12 arcos de frase y 1.707 notas con texto de letra.
- Importación en MuseScore 4.7.5, exportación MusicXML y segunda importación: notas, alturas, duraciones, letra, ligaduras y tempo conservados.
- MIDI de reproducción de MuseScore y MIDI tras reimportar: 1.961 ataques sonoros, con posiciones y alturas coincidentes con el MusicXML interpretando sus ligaduras. Las seis notas opcionales quedan excluidas.
- Se revisan las 12 páginas renderizadas; informe estructurado en `output/verovio_pilot_support/cuando_oi_su_voz/validation.json`.

Esta revisión comprueba estructura, notación y reproducción en MuseScore. No constituye una importación probada en Cantai ni una revisión cantada por un director; la distribución editorial del texto en entradas independientes del bajo puede afinarse en ensayo.
