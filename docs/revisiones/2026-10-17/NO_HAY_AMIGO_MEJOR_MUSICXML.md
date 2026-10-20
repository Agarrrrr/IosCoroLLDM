# No Hay Amigo Mejor — desarrollo de tres estrofas

## Entrega

- MusicXML y MuseScore editables, independientes del repertorio actual.
- Estrofa 1 → coro → estrofa 2 → coro → estrofa 3 → coro, confirmado por el usuario.
- Una línea de letra por pentagrama y por pasada, para Cantai: una bajo Soprano/Alto y otra bajo Tenor/Bajo. La línea inferior se asocia a las notas del tenor; todas las entradas de letra coinciden con ataques reales, sin colocarlas en silencios o continuaciones ligadas.
- SATB cerrado: Soprano/Alto en el pentagrama superior y Tenor/Bajo en el inferior, con voces independientes y plicas opuestas.
- 109 compases escritos, sin saltos de repetición. Se une la cadencia de dos tiempos con la anacrusa siguiente de un tiempo.
- Sílabas separadas mediante guiones, sinalefas y prolongaciones de letra.
- Mi mayor, tempo base ♩ = 85, cambios 3/4 ↔ 2/4 y calderones del PDF. MuseScore interpreta los calderones mediante una pausa local del tempo; el MIDI original mantiene 85 constantes.

## Fuentes

Canto `51057ef0-9aa8-436c-9467-6580a67a0e29` del catálogo local: PDF digital `no-hay-amigo-mejor.pdf` y MIDI `no-hay-amigo-mejor-1779935161707.midi`. No se modificaron los originales.

Autor: Neftalí Medina F. Arreglos: Omar G. Ortega H.

El MIDI ya contiene tres pasadas musicales. Se usa como referencia de alturas, ataques y duraciones; las tres letras y la disposición de voces proceden del PDF.

## Diferencia conservada y registrada

En el compás 36 del PDF, al final del coro, la soprano del MIDI incluye una rearticulación que el PDF no muestra. Se conserva la música del MIDI, sin inventar una sílaba nueva para esa nota. Las figuras de 1,75 tiempos se escriben como negra ligada a corchea con puntillo; esas continuaciones no se vuelven a atacar.

## Comprobaciones realizadas

- Comparación de las cuatro voces del MusicXML con el MIDI completo: 360 ataques de Soprano, 360 de Alto, 354 de Tenor y 360 de Bajo; alturas, posiciones y duraciones coinciden.
- 1.602 figuras de nota, incluidas las continuaciones ligadas, durante 318 negras de música escrita.
- Misma comparación tras importar en MuseScore, exportar a MusicXML y volver a importar/exportar: las cuatro voces conservadas.
- Texto completo de cada estrofa y de los tres coros comprobado automáticamente en ambos pentagramas; una sola línea de letra en cada pentagrama, con las mismas entradas temporales y ningún texto nuevo sobre una continuación ligada.
- Secciones comprobadas en los tiempos 0, 62, 106, 168, 212 y 274.
- Renderizado de MuseScore: cinco páginas, con revisión visual.

Evidencias reproducibles en `output/verovio_pilot_support/no_hay_amigo_mejor/`, especialmente `validation.json`, `word-underlay.json`, `render/` y los registros de importación/exportación.

No se ha incorporado a la app ni subido a GitHub.
