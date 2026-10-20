# Prueba local de lector interactivo: partituras completas

Fecha: 17 de octubre de 2026. Seguimiento independiente del informe del 15 de octubre, que se conserva.

## Alcance y resultado

Prototipo Android separado, `com.lldm.veroviopilot.coro_lldm`, versión 0.2.0+2. No cambia la aplicación principal, el catálogo ni los PDF/MIDI originales. No se publica ni se hace push como parte de esta prueba.

Se cargan completos los tres documentos preparados. «Completo» se refiere al documento usado por el piloto; **no certifica una transcripción exacta de cada PDF**. Se detectaron diferencias entre fuentes que se detallan abajo.

| Canto | Disposición | Compases escritos | Notas escritas | Ataques del MIDI original | Duración del MIDI |
|---|---|---:|---:|---:|---:|
| Acércame a Ti | Cerrado, dos pentagramas | 28 | 405 | 1159 | 205.332 s |
| Al Gran Señor | Abierto, cuatro pentagramas | 91 | 1746 | 1742 | 245.332 s |
| Ven a la Cena | Dos pentagramas en estrofas, tres en coro | 16 | 284 | 280 | 41.999 s |

Las diferencias entre notas escritas y ataques se explican por repeticiones y prolongaciones. El recorrido de Acércame contiene tres vueltas con finales distintos; se vincula al reloj del MIDI mediante un recorrido explícito.

## Fuentes

- Los dos primeros ejemplos conservan la notación editable propia suministrada anteriormente, de la carpeta local MuseScore. Sus MIDI proceden de los recursos empaquetados de la aplicación. La letra de Acércame se transcribió del PDF de la app; se recuperaron diez arcos de fraseo mediante OMR del mismo PDF.
- **El tercer ejemplo utiliza exclusivamente el PDF y el MIDI del catálogo de la app. No utiliza un editable ni un MIDI externo.** Se seleccionó entre once candidatos con cuatro pistas, cero eventos MIDI de letra, extensión breve y PDF de hasta dos páginas, usando semilla 20261017.
- Audiveris se ejecutó localmente sobre los PDF propios. Su salida tenía errores de lectura; no se acepta automáticamente como una transcripción musical correcta. En Ven a la Cena se usaron las alturas y ritmos del MIDI, con letra y prolongaciones revisadas sobre el PDF.

Ven a la Cena, ID `ccc7dcfd-adf1-4ee8-b538-57a3f8bf9788`:

- PDF: `ven-a-la-cena-1781223731334.pdf`, una página.
- MIDI: `all-things-are-ready-1781398015307.mid`, 59/75/75/71 notas por pista; **cero eventos de letra**.
- SHA-256 PDF: `ccccca1b35a5ef8e2460f1160e3ff80f579cffedafc46cb80b94a6450af32aec`.
- SHA-256 MIDI: `6d66bf9b7e30f25fec1408a3a9ce648b0b030a5fe1ca7ec6471dc701c4f21940`.

## Cambios del piloto

1. Se elimina el límite de ocho compases y se reproduce el MIDI completo.
2. Disposición bloqueada: una obra abierta permanece abierta. Ven a la Cena se graba en dos secciones para respetar el cambio de dos a tres pentagramas.
3. Tres estrofas de Acércame y cuatro de Ven a la Cena se muestran sobre la misma música. El texto común no se duplica en las cuatro voces del modo cerrado. Las respuestas distintas se mantienen aparte; no se ha certificado cada respuesta secundaria del PDF.
4. Se respeta la colocación del texto por encima del pentagrama donde existen respuestas simultáneas, evitando superponer ambos textos.
5. Se recuperan agrupaciones de corcheas/semicorcheas, ligaduras de prolongación y arcos de fraseo. Las negras no se agrupan con barras.
6. Se ocultan las barras ordinarias de compás; permanecen los signos de repetición y las barras finales. Una barra ordinaria puede tener varios segmentos verticales: se comprueba su coordenada horizontal común.
7. Cursor vertical con avance interpolado entre notas, altura del sistema completo y seguimiento durante reproducción. Se corrige el desplazamiento provocado por medir la página antes de ocultar el mensaje de carga.
8. Cambiar de canto restablece posición, reloj y desplazamiento. Se mantiene el ajuste de separación de palabras cercano a un espacio de pentagrama; el PDF no se reproduce píxel por píxel.

## Corrección posterior al aviso del usuario: prolongaciones y voces

El usuario señaló que se volvían a atacar notas ligadas y que solo se atenuaban algunas partes de las voces silenciadas.

- Se genera un plan explícito de prolongaciones independiente del dibujo: doce ocurrencias en Acércame, ocho en Al Gran Señor y cuatro en Ven a la Cena.
- Se prolonga el ataque inicial y se elimina un ataque en el instante de continuación cuando existe. Se conservan los ataques repetidos que no tienen una ligadura de prolongación indicada.
- Cuatro prolongaciones del cierre del editable de Al Gran Señor estaban codificadas como arcos de fraseo entre notas iguales. Se corrigen en la copia del piloto y se suprimen cuatro ataques adicionales del plan de audio. El MIDI original no se reescribe.
- Las otras veinte ocurrencias ya correspondían a notas MIDI sostenidas. No se ha demostrado que todas ellas produjeran un ataque adicional en el motor anterior. La prueba verifica la programación del audio, sin sustituir una escucha musical del usuario.
- Al reanudar o situarse dentro de una nota sostenida, se recupera su duración restante; pasar por una continuación visual durante reproducción normal no provoca otro ataque.
- El atenuado se aplica a los elementos gráficos de la voz: cabezas, plicas, barras, silencios, alteraciones particulares y arcos. Las claves, armaduras compartidas y el texto común permanecen legibles.

## Verificación

Dispositivo: Samsung SM-G986U, Android 13, conectado por ADB. Compilación release ARM64 e instalación en la aplicación de prueba independiente.

- Seis pruebas Dart pasaron: correspondencia de todos los ataques de los tres MIDI con notas visuales y prolongaciones sin segundo ataque. El total de audio se conserva; solo Al Gran Señor reduce cuatro ataques en el plan preparado.
- Analizador Dart sin incidencias antes del último ajuste de recuperación de notas al reanudar; la compilación release valida también ese ajuste.
- Arranque de WASM comprobado en condiciones de inicialización inmediata, tardía, callback duplicado y ausencia del motor con error visible.
- Verovio 6.3.0-425dd7b valida todos los identificadores y genera todas las páginas. Tras corregir el cierre: Acércame 4 prolongaciones escritas/10 arcos/93 grupos de barras; Al Gran Señor 8/57/335; Ven a la Cena 4/3/72.
- En el móvil se comprobó apertura de los tres cantos, dos y tres pentagramas de Ven a la Cena, cuatro de Al Gran Señor, cursor y desplazamiento, reproducción tras saltar cerca del final y atenuado de voces. No se escucharon íntegramente las tres obras de principio a fin.
- Los tiempos de preparación observados en una ejecución del móvil fueron aproximadamente 1.0 s, 1.6 s y 0.4 s respectivamente. Son observaciones de carga, no un benchmark de FPS.
- El prototipo empaqueta motor, partituras, MIDI y SoundFont. El manifiesto release no necesita permiso de Internet; los recursos del lector tienen una política que bloquea conexiones.

Evidencia: `output/verovio_pilot_support/device/`, especialmente `final-acercame-verse-layout`, `final-solo-soprano`, `final-ven-sections`, `final-ven-chorus`, `final-al-gran-open-verified` y `final-al-gran-end`. Algunas capturas anteriores corresponden a compilaciones intermedias y registran fallos ya corregidos.

## Diferencias pendientes: no ocultarlas

1. **Al Gran Señor:** el editable/MIDI usado no es idéntico al PDF empaquetado. El editable termina con el Amén y tiene 91 compases; el PDF tiene un cierre adicional «Canten al Señor» hasta el compás 93. Además hay una diferencia de altura en Tenor, compás 73 del editable: Fa4 escrito frente a Sol4 en el MIDI. La nota se marca en ámbar. Hace falta resolver qué versión se quiere publicar antes de considerar este canto una reproducción fiel del PDF. No se reemplazó ningún original.
2. **Ven a la Cena:** existen pequeñas variantes rítmicas PDF/MIDI. La notación del piloto sigue el MIDI; la letra procede del PDF. El audio contiene una vuelta de estrofa y coro, aunque se muestran las cuatro estrofas.
3. Al Gran Señor produce siete avisos de extensores de sílaba en una sola nota heredados de la fuente. No bloquean la carga, pero su tipografía necesita revisión musical.
4. No hay validación iOS ni certificación de fidelidad de todas las sílabas, ligaduras o voces secundarias. El resultado sigue siendo una prueba local, no una conversión automática lista para todo el catálogo.

## Reproducción del trabajo

Scripts: `select_app_sample.py`, `run_omr.py`, `prepare_complete.py` (incluye `prepare_ties.py`), `validate_complete.cjs`, `check_loader.cjs`, en `tools/verovio_pilot/`. Las pruebas Dart están dentro del proyecto independiente `output/verovio_pilot/test/`.

APK de entrega: `output/verovio_pilot_support/Coro-Prueba-Lector-Completo-0.2.0.apk`.
