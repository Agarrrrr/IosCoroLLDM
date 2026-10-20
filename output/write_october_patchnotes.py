from pathlib import Path
import json,unicodedata
docs=Path('docs')
a=json.loads((docs/'repertorio/2026-10-10/incorporacion_seleccionada.json').read_text(encoding='utf-8'))['records']
b=json.loads((docs/'repertorio/2026-10-11/midis_confirmados.json').read_text(encoding='utf-8'))['records']
c=json.loads((docs/'repertorio/2026-10-12/incorporados_30.json').read_text(encoding='utf-8'))['records']
new={r['id']:r for r in a+c if r.get('newWork')}
old={r['id']:r for r in a if not r.get('newWork')}
old.update({r['id']:r for r in b if not r.get('existingAppAudioPreserved')})
old.update({r['id']:r for r in c if not r.get('newWork')})
canonical={'El Cantico de Los 144 Mil':'El C\u00e1ntico de los 144 Mil','HEME AQU\u00cd':'Heme Aqu\u00ed'}
names=sorted([canonical.get(r['name'],r['name']) for r in old.values()],key=lambda s:unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().lower())
assert len(new)==8 and len(names)==44
text='''# Novedades de octubre de 2026

Cambios incorporados hasta el 12 de octubre. Borrador de notas de actualizaci\u00f3n; no implica que todos los cambios est\u00e9n publicados en las tiendas.

## M\u00e1s repertorio para ensayar

- Ocho cantos nuevos, cada uno con partitura PDF y audio MIDI.
- Audios MIDI a\u00f1adidos a 44 cantos que ya ten\u00edan partitura.
- Los nuevos PDF y MIDI est\u00e1n incluidos en los recursos offline.
- Recuperadas como obras independientes \u00abLa Vida se va Como el Viento\u00bb y \u00abLa Vida Se Va Como El Viento y Pronto en Las Nubes Vendr\u00e1\u00bb, cada una con su propia partitura y audio.
- Corregida la apertura offline de \u00abPecador, Ven al Dulce Jes\u00fas\u00bb y un problema de lectura del PDF de \u00abMaravillosa Gracia\u00bb.

## Lectura y apariencia

- Mejor contraste de textos, botones e indicadores en los temas de lectura.
- Resaltes s\u00f3lidos y dorado m\u00e1s brillante en el modo claro.
- La barra superior del visor combina con el fondo de la partitura.
- Ajustes y Obtener Premium permanecen visibles en el men\u00fa lateral.
- Identificaci\u00f3n m\u00e1s clara de los cantos con audio.
- Controles m\u00e1s c\u00f3modos y mejor adaptaci\u00f3n al tama\u00f1o de texto del sistema.
- La pantalla permanece encendida mientras tienes una partitura abierta.

## Anotaciones

- Nuevo subrayador transl\u00facido con amarillo, azul, rosa y otros colores, adaptado al tema de lectura.
- Los colores de las anotaciones conservan su tono al cambiar de tema; la tinta negra y blanca se adapta al fondo.
- Borrado visible durante el movimiento, sin esperar a levantar el dedo.
- Vista previa de texto m\u00e1s completa y fiel al resultado sobre la p\u00e1gina.
- Deshacer y Rehacer reflejan las acciones disponibles.
- Confirmaci\u00f3n antes de borrar todas las anotaciones de un canto.
- Mejoras de respuesta al dibujar, borrar y reabrir p\u00e1ginas muy anotadas.
- Guardado y carga de anotaciones extensas con menos trabajo en el hilo de la interfaz.

## Reproductor

- Dise\u00f1o m\u00e1s compacto: mezclador y velocidad a los lados del bot\u00f3n de reproducci\u00f3n, dentro de sus submen\u00fas.
- Cierre del panel deslizando hacia abajo, sin detener el audio.
- Mejor separaci\u00f3n visual del reproductor respecto al fondo y ajustes de contraste en sepia.
- Movimiento del metr\u00f3nomo m\u00e1s natural y sincronizado con el pulso.
- Indicaci\u00f3n del comp\u00e1s m\u00e1s sencilla, sin sumas adicionales.
- Controles deshabilitados mientras se prepara el audio.

## Cat\u00e1logo, mensajes y exportaci\u00f3n

- B\u00fasqueda global al comenzar a escribir; los filtros seleccionados despu\u00e9s se respetan.
- Estados vac\u00edos m\u00e1s claros para favoritos, filtros y b\u00fasquedas sin resultados.
- Mensajes sencillos cuando una partitura, audio o exportaci\u00f3n no est\u00e1 disponible.
- Avisos breves mediante banners visibles por encima de las ventanas.
- Protecci\u00f3n frente a pulsaciones repetidas durante la preparaci\u00f3n y exportaci\u00f3n.
- Cancelaci\u00f3n de lotes con informaci\u00f3n inmediata del estado.
- Mejor manejo de archivos MP3 incompletos para evitar reutilizarlos en exportaciones posteriores.

## Ajustes y Premium

- Ajustes reorganizados por Apariencia, Partituras, Idioma, Premium y Ayuda.
- Restauraci\u00f3n de compras con mensajes m\u00e1s claros seg\u00fan el resultado.
- Precios, periodos y ofertas mostrados con las condiciones disponibles de la tienda.
- Plan anual destacado como \u00abMejor plan\u00bb.
- Compra directa al tocar un plan.
- Pol\u00edtica de privacidad y t\u00e9rminos de uso colocados juntos.
- Eliminada la vinculaci\u00f3n manual mediante identificadores; se conserva Restaurar compras.
- Identificador de soporte con una presentaci\u00f3n m\u00e1s limpia.
- Corregida la conservaci\u00f3n de recompensas de exportaci\u00f3n al cambiar de d\u00eda.
- iOS requiere ahora la versi\u00f3n 15.0 o posterior.

## Cantos nuevos: PDF y MIDI

'''
for r in new.values():text+='- '+r['name']+'\n'
text+='\n\u00abSalmo 23 - Jehov\u00e1 es mi Pastor\u00bb se incorpor\u00f3 como un arreglo independiente; no sustituy\u00f3 el canto anterior \u00abJehov\u00e1 es mi Pastor\u00bb ni \u00abSalmo 23\u00bb.\n'
text+='\n## Cantos existentes que recibieron MIDI\n\nEstos 44 cantos ya ten\u00edan PDF; se les a\u00f1adi\u00f3 el archivo MIDI de ensayo.\n\n| Canto | Canto |\n|---|---|\n'
half=(len(names)+1)//2
for i in range(half):text+='| '+names[i]+' | '+(names[i+half] if i+half<len(names) else '')+' |\n'
text+='''
## Cambios de mantenimiento

- Optimizaciones del renderizado PDF, descifrado y reutilizaci\u00f3n de anotaciones.
- Gestor con validaci\u00f3n de archivos, conservaci\u00f3n de IDs y versiones y recuperaci\u00f3n ante errores de escritura.
- Dos cantos con nombres similares conservan identidades independientes.
- Herramienta interna para preparar borradores compactos de letras de partituras digitales SATB. No es una funci\u00f3n nueva disponible en la app.

## iOS: implementaci\u00f3n pendiente de comprobaci\u00f3n nativa

Se implementaron un nuevo flujo para compartir PDF/MP3 y la opci\u00f3n \u00abGuardar en Archivos\u00bb, con protecci\u00f3n frente a ventanas simult\u00e1neas y anuncios durante el selector. Falta compilar el c\u00f3digo Swift y validar en iPhone/iPad antes de anunciar el cierre de la incidencia de iOS 26 como resuelto.

## Alcance de la validaci\u00f3n

- No se afirma una certificaci\u00f3n WCAG de toda la aplicaci\u00f3n: se revisaron contraste, texto ampliado y componentes concretos.
- Las 109 pruebas de incorporaci\u00f3n verifican apertura offline y exportaci\u00f3n; no sustituyen una revisi\u00f3n musical nota por nota.
- Sigue pendiente revisar la correspondencia musical de los cinco arreglos se\u00f1alados: A lo Largo de la Vida, Fue por M\u00ed, Linaje de Bendici\u00f3n, Recordando la Muerte de Cristo y Ven a la Fiesta.
- Coronadle Rey, Remembranza Gloriosa, Perfect (CMG) y los archivos sin identidad no se cuentan como incorporaciones.
- El Juicio Final y Firmes y Adelante (5 Voces) siguen siendo material detectado para preparar; no se a\u00f1adieron en estas tandas.
- Las incorporaciones de El C\u00e1ntico de los 144 Mil y Hay Ap\u00f3stol no se duplican al contar su posterior sincronizaci\u00f3n con la nube.
- Los cantos y audios anunciados para 3.1.0 que ya estaban presentes al comenzar octubre no se vuelven a contar como novedades de este mes.

## Fuentes del recuento

- repertorio/2026-10-10/incorporacion_seleccionada.json
- repertorio/2026-10-11/midis_confirmados.json
- repertorio/2026-10-12/incorporados_30.json
- Comparaci\u00f3n de los cat\u00e1logos actuales con el estado anterior al primer commit de octubre (3131ac4).
'''
p=docs/'PATCH_NOTES_OCTUBRE_2026.md';p.write_text(text,encoding='utf-8')
print(str(p.resolve()));print('newScores',len(new),'existingScoresWithNewMidi',len(names))
