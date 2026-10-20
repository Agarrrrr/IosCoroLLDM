from pathlib import Path
import json,hashlib,zipfile,xml.etree.ElementTree as ET
out=Path('docs/repertorio/2026-10-12')
rs=json.loads((out/'revision_midis.json').read_text(encoding='utf-8'))
known=[r for r in rs if not r['category'].startswith('04')]
titles={}
for r in known:titles.setdefault(r['title'],[]).append(r)
print('CASEDETAIL')
for title,rr in titles.items():
 if not all(r['similarEnding'] for r in rr):
  for r in rr:print(title,[(t['name'],round(t['lastEndSec'],2)) for t in r['tracks']])
scores=json.loads(Path('output/musescore_review/2026-10-12/scores.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256(Path(r['source']).read_bytes()).hexdigest()==r['sha256'] for r in rs)
assert all(hashlib.sha256(Path(r['source']).read_bytes()).hexdigest()==r['sha256'] for r in scores)
p=out/'revision_midis.md'
text=p.read_text(encoding='utf-8')
text=text.replace('Cuatro y finales similares; revisar polifon\u00eda','Cuatro y finales similares; voces simult\u00e1neas admitidas')
text=text.replace('No son cuatro pistas','M\u00e1s de cuatro pistas; admitido por cantidad')
text=text.replace('Cuatro y finales similares; identificar voces','Cuatro y finales similares; comprobar etiquetas')
summary=['## Criterio confirmado por el usuario','','Se aceptan cuatro o m\u00e1s pistas/pentagramas y puede haber dos voces en una pista. No se rechazan acordes ni solapamientos por s\u00ed solos. MIDI expresa pistas, no permite confirmar cu\u00e1ntos pentagramas ten\u00eda la partitura de origen.','','- 33 t\u00edtulos pendientes: todos tienen al menos cuatro pistas con notas.','- 30 t\u00edtulos tienen exactamente cuatro pistas.','- 29 de esos t\u00edtulos tienen finales separados por no m\u00e1s de una negra.','- A la Sombra de Tus Alas: seis pistas; distintos finales.','- No Puedo Imaginar: cinco pistas; distintos finales.','- Somos La Luz del Mundo: nueve pistas; incluye solista y voces adicionales.','- Perfect (CMG): cuatro pistas, pero SA, solista, TB y piano; finales diferentes.','- Los cinco archivos sin identidad se documentan por separado.','','El n\u00famero 29 es un resultado de esta nueva comprobaci\u00f3n de cuatro pistas y finales similares, no prueba del origen del conteo anterior.','','### Renombrado','','Los nombres Piano, Quintus, Soprano 1/2, Tenor 1/2 no invalidan el archivo. Renombrar solo las etiquetas en una copia puede conservar notas, tiempos e instrumentos sonoros. El orden SATB no se debe deducir \u00fanicamente del n\u00famero de pistas o de su duraci\u00f3n.','Oh Salvador Rey Nuestro necesita comprobar el orden: la tercera pista tiene registro mediano superior a la primera.','Los cinco prioritarios aplazados conservan sus observaciones sobre comp\u00e1s/arreglo; este an\u00e1lisis de duraci\u00f3n no confirma su correspondencia con el PDF.','','### Integridad','','SHA256 antes/despu\u00e9s id\u00e9ntico en los 41 MIDI examinados y en los 96 MSCZ. Cat\u00e1logos y nube no modificados en esta revisi\u00f3n.']
text=text.replace('## Resumen por archivo','\n'.join(summary)+'\n\n## Resumen por archivo')
p.write_text(text,encoding='utf-8')
m=['# Archivos MuseScore y audio del cat\u00e1logo \u2014 2026-10-12','','Se revisaron 96 MSCZ, sin alterar originales. Correspondencia por t\u00edtulo y nombre de archivo; versiones similares requieren comparaci\u00f3n musical antes de asignar un audio.','','## Canto de la app sin MIDI declarado','','- El Juicio Final: archivo El Juicio Final (1).mscz, seis partes llamadas Piano y seis pentagramas en el editable. Hay material para preparar audio; no se incorpor\u00f3.','','## Versiones que necesitan correspondencia','','- Firmes y Adelante (5 Voces) no tiene audio declarado. El editable firmes y adelante bc.mscz tiene cinco partes SATB + piano. La versi\u00f3n normal ya tiene audio; confirmar que la edici\u00f3n coincide antes de usarlo.','- A D\u00f3nde Ir\u00e9 y De su Mano normales ya tienen audio. Sus variantes \u00abte Amo Tanto\u00bb y \u00ab2007\u00bb no tienen; no se asumi\u00f3 que los editables cubran esas obras distintas.','- Jehov\u00e1 es mi Pastor Voces corresponde al material antes incorporado como Salmo 23 - Jehov\u00e1 es mi Pastor; no asignarlo al antiguo Jehov\u00e1 es mi Pastor de distinto comp\u00e1s.','- HijoProdigo, El aliento de mi ser J. y how_great_thou_art__advanced_ tienen coincidencias nominales con cantos que ya cuentan con audio.','','## Sin correspondencia nominal confirmada','','- Dos editables de Amen/Rossini.','- Ay Sandunga, Caballo Prieto Azabache, Canci\u00f3n Mixteca, Dos Arbolitos, rodalla y Vereda Tropical.','Estos archivos no se identifican como cantos sin audio de la app \u00fanicamente por el t\u00edtulo.','','Los MIDI generados para inspecci\u00f3n quedan solo en output/musescore_review/2026-10-12. No se importaron ni se cambiaron instrumentos.']
(out/'musescore_sin_audio.md').write_text('\n'.join(m),encoding='utf-8')
print('integrity verified; documents saved')
