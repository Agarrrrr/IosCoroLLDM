import ast
import hashlib
import json
import re
import shutil
import sys
import unicodedata
from pathlib import Path

SOURCE = Path('E:/MIDIS REVISAR TODOS')
DEST = Path('E:/Audios Octubre/Candidatos revisados - 2026-10-10')
HERE = Path(__file__).resolve().parent

def norm(s):
    return re.sub(r'[^a-z0-9]+', ' ', unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode().lower()).strip()

# Reuse only the MIDI reader functions; do not execute the import script.
tree = ast.parse((HERE / 'repertoire_import/2026-10-10/prepare_import.py').read_text(encoding='utf-8'))
functions = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in ('vlq', 'track_info')]
scope = {}
exec(compile(ast.Module(body=functions, type_ignores=[]), '<midi-reader>', 'exec'), scope)

def active_tracks(path):
    b = path.read_bytes()
    assert b[:4] == b'MThd'
    pos = 8 + int.from_bytes(b[4:8], 'big')
    active = 0
    for _ in range(int.from_bytes(b[10:12], 'big')):
        assert b[pos:pos+4] == b'MTrk'
        size = int.from_bytes(b[pos+4:pos+8], 'big')
        track = b[pos+8:pos+8+size]
        assert len(track) == size
        active += scope['track_info'](track)[0] > 0
        pos += 8 + size
    return active

priority = 'A lo Largo de la Vida|Canten los Ángeles|Como mi Padre|Cosas Maravillosas|Cuando Escucho su Nombre|Cuerdas de Amor|Divino Mandamiento|El Cántico de los 144 Mil|El Santo Llamamiento|El Ángel de Cristo|Firme Estoy|Fue por Mí|Ha Triunfado mi Señor|Hasta el Final|Hay Apóstol|Linaje de Bendición|Mi Plegaria|Mi Siervo Amado|Nadie Como Tú|Recordando la Muerte de Cristo|Ven a la Fiesta|HEME AQUÍ|Él Vive'.split('|')
review = 'Mi Tiempo Ha Llegado|Más Allá de las Estrellas|A la Sombra de Tus Alas|Ante Tus Pies|Ciertamente Casa de Dios|Día Venturoso|El Alfarero|El Cántico de Moisés|El Pacto con Dios|El Ángel Que Juan Vio|Eterno Dios|Fuente de Salvación|La Luz de Aquella Ciudad|Mi Esperanza es en Ti|No Puedo Imaginar|Oh Salvador Rey Nuestro|Te Bendecimos|Un Gran Consolador|Ángel de Dios'.split('|')
new = 'Coronadle Rey|El Latido de tu Corazón|Hoy Se Cumplen|Lluvias Tardías|Perfect (CMG)|Remembranza Gloriosa|Salmo 148|Somos La Luz del Mundo|Te Prometo mi Señor'.split('|')
aliases = {'cuando escucho su nombre cmg': 'cuando escucho su nombre', 'lluvias tardias cj4s': 'lluvias tardias', 'lluvias tardias rec': 'lluvias tardias'}
groups = {}
for category, titles in [('01 - SATB prioritarios', priority), ('02 - Revisar voces o solapamientos', review), ('03 - Titulos no encontrados en el catalogo', new)]:
    for title in titles:
        groups[norm(title)] = {'category': category, 'title': title, 'sources': []}
unknown = {'en tu amor': 'En tu amor', 'proyecto 2': 'Proyecto 2', 'te loamos te glorificamos': 'Te loamos, Te glorificamos'}
for key, title in unknown.items():
    groups[key] = {'category': '04 - Identidad pendiente', 'title': title, 'sources': []}

for path in sorted(SOURCE.rglob('*')):
    if path.suffix.lower() not in ('.mid', '.midi'):
        continue
    parent = aliases.get(norm(path.parent.name), norm(path.parent.name))
    stem = norm(path.stem)
    key = parent if parent in groups else stem if stem in groups else None
    if stem == 'perfect cmg': key = norm('Perfect (CMG)')
    if 'te loamos te glorificamos' in stem: key = 'te loamos te glorificamos'
    if not key:
        continue
    count = active_tracks(path)
    if count >= 4:
        groups[key]['sources'].append({'path': str(path), 'hash': hashlib.sha256(path.read_bytes()).hexdigest(), 'activeTracks': count})

missing = [g['title'] for g in groups.values() if not g['sources']]
assert not missing, missing
assert len(priority) + len(review) + len(new) == 51
records = []
for group in groups.values():
    by_hash = {}
    for source in group['sources']:
        by_hash.setdefault(source['hash'], []).append(source)
    occupied = set()
    for digest, sources in by_hash.items():
        source = Path(sources[0]['path'])
        filename = source.name
        if norm(filename) in occupied: filename = source.stem + ' - ' + digest[:8] + source.suffix
        occupied.add(norm(filename))
        target = DEST / group['category'] / group['title'] / filename
        records.append({'title': group['title'], 'category': group['category'], 'source': str(source), 'destination': str(target), 'sha256': digest, 'activeTracks': sources[0]['activeTracks'], 'identicalSources': [s['path'] for s in sources]})

plan = {'candidateTitles': 51, 'unidentifiedFiles': sum(r['category'].startswith('04') for r in records), 'midiFiles': len(records), 'records': records}
(HERE / 'october_candidates_plan.json').write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding='utf-8')
if '--copy' in sys.argv:
    for record in records:
        target = Path(record['destination'])
        if target.exists(): assert hashlib.sha256(target.read_bytes()).hexdigest() == record['sha256'], str(target)
    for record in records:
        target = Path(record['destination'])
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists(): shutil.copyfile(record['source'], target)
        assert hashlib.sha256(target.read_bytes()).hexdigest() == record['sha256']
    index = '# MIDI candidatos revisados\n\n51 títulos candidatos y 5 archivos de identidad pendiente. Clasificación recuperada de la auditoría anterior: no confirma correspondencia musical con el PDF ni ausencia con otro título. El Cántico de los 144 Mil y Hay Apóstol ya se incorporaron posteriormente a la app.\n\nSe conservaron todas las versiones de contenido diferente. Las copias idénticas se incluyen una vez; sus rutas originales constan en el registro. No se modificaron notas, pistas ni archivos originales.\n\n| Canto | Grupo | MIDI distintos |\n|---|---|---:|\n'
    for group in groups.values():
        count = sum(r['title'] == group['title'] and r['category'] == group['category'] for r in records)
        index += f"| {group['title']} | {group['category']} | {count} |\n"
    for name, content in [('LEEME.md', index), ('registro.json', json.dumps(plan, ensure_ascii=False, indent=2))]:
        target = DEST / name
        if target.exists(): assert target.read_text(encoding='utf-8') == content
        else: target.write_text(content, encoding='utf-8')
print(json.dumps({k: v for k, v in plan.items() if k != 'records'}, ensure_ascii=False))
for group in groups.values():
    print(group['category'], '|', group['title'], '|', len({s['hash'] for s in group['sources']}))
