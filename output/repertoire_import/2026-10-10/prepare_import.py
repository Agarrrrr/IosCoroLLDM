"""Prepare the six explicitly selected works, preserving existing score identities."""
import hashlib
import io
import json
import os
import re
import uuid
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
NAMES = ['Soprano', 'Alto', 'Tenor', 'Bajo']


def vlq(data, offset):
    value = 0
    for _ in range(4):
        byte = data[offset]
        offset += 1
        value = value * 128 + (byte & 127)
        if byte < 128:
            return value, offset
    raise ValueError('Invalid MIDI VLQ')


def encoded_vlq(value):
    result = [value & 127]
    value >>= 7
    while value:
        result.insert(0, (value & 127) | 128)
        value >>= 7
    return bytes(result)


def track_info(data):
    offset = 0
    running = None
    notes = 0
    spans = []
    while offset < len(data):
        _, offset = vlq(data, offset)
        status = data[offset]
        if status < 128:
            assert running is not None
            status = running
        else:
            offset += 1
        if status == 255:
            kind = data[offset]
            offset += 1
            start = offset
            length, offset = vlq(data, offset)
            offset += length
            assert offset <= len(data)
            if kind == 3:
                spans.append((start, offset))
        elif status in (240, 247):
            length, offset = vlq(data, offset)
            offset += length
        else:
            assert status < 240
            running = status
            kind = status >> 4
            length = 1 if kind in (12, 13) else 2
            payload = data[offset:offset + length]
            assert len(payload) == length
            offset += length
            if kind == 9 and payload[1]:
                notes += 1
    return notes, spans


def replace_names(data, spans, name):
    label = name.encode('utf-8')
    for start, end in reversed(spans):
        data = data[:start] + encoded_vlq(len(label)) + label + data[end:]
    return data


def label_voices(raw):
    assert raw[:4] == b'MThd'
    header_end = 8 + int.from_bytes(raw[4:8], 'big')
    count = int.from_bytes(raw[10:12], 'big')
    result = bytearray(raw[:header_end])
    offset = header_end
    active = 0
    note_counts = []
    for _ in range(count):
        assert raw[offset:offset + 4] == b'MTrk'
        size = int.from_bytes(raw[offset + 4:offset + 8], 'big')
        data = raw[offset + 8:offset + 8 + size]
        assert len(data) == size
        offset += 8 + size
        notes, spans = track_info(data)
        if notes:
            assert active < 4 and spans
            changed = replace_names(data, spans, NAMES[active])
            _, changed_spans = track_info(changed)
            # Prove every event other than the track name remains byte-identical.
            assert replace_names(data, spans, '') == replace_names(changed, changed_spans, '')
            data = changed
            active += 1
            note_counts.append(notes)
        result.extend(b'MTrk' + len(data).to_bytes(4, 'big') + data)
    assert offset == len(raw) and active == 4
    return bytes(result), note_counts


def main():
    catalog_paths = [ROOT / 'assets/catalogo.json', ROOT / 'assets/offline_assets/catalogo.json']
    original = catalog_paths[0].read_bytes()
    assert catalog_paths[1].read_bytes() == original
    rows = json.loads(original)
    before = {row['id']: dict(row) for row in rows}
    sources = [
        ('usmc_084c52a2ac07c757f6', 'El Cántico de los 144 Mil (Final).mid'),
        ('usmc_64b54d4f21b21cae02605d3c', 'Hay Apóstol (SATB).mid'),
        ('usmc_47d16b904344db4db6db6432', 'a-donde-ire.mid'),
        ('usmc_67ff3fd3631be412cc5bdc83', 'tiempo-de-agradecer.mid'),
    ]
    pdf_input = next(Path(r'C:\Users\Huri_\AppData\Local\Temp').glob('Al Gran*.pdf'))
    additions = [
        ('Al Gran Señor', ['Adoración'], pdf_input, 'Al Gran Señor (Adoración).mid'),
        ('Salmo 23 - Jehová es mi Pastor', ['Alabanza', 'Adoración'],
         OUT / 'salmo-23-jehova-es-mi-pastor.pdf', 'jehova-es-mi-pastor.mid'),
    ]
    assert not any(row['nombre'] in {item[0] for item in additions} for row in rows)
    source_code = (ROOT / 'lib/core/security/file_crypto.dart').read_text(encoding='utf-8')
    key = hashlib.sha256(re.search(r"_rawKey = '([^']+)'", source_code)[1].encode()).digest()
    cipher = AESGCM(key)
    staged_assets = {}
    records = []

    def stage(clear, kind):
        digest = hashlib.sha256(clear).hexdigest()
        object_key = f'global/assets/{kind}/{digest}.enc'
        asset = f'assets/offline_assets/{"pdfs" if kind == "pdf" else "midis"}/{object_key}'
        assert not (ROOT / asset).exists()
        nonce = os.urandom(12)
        encrypted = nonce + cipher.encrypt(nonce, clear, None)
        assert cipher.decrypt(encrypted[:12], encrypted[12:], None) == clear
        staged_assets[asset] = encrypted
        return object_key, digest

    for song_id, filename in sources:
        row = next(row for row in rows if row['id'] == song_id)
        assert not row.get('midi_archivo')
        clear, counts = label_voices((OUT / filename).read_bytes())
        midi_key, midi_hash = stage(clear, 'midi')
        row['midi_archivo'] = midi_key
        row['version'] = int(row.get('version', 1)) + 1
        records.append({'id': song_id, 'name': row['nombre'], 'sourceMidi': filename,
                        'midiHash': midi_hash, 'midiKey': midi_key, 'notes': counts,
                        'existingPdf': row['archivo'], 'newWork': False})

    for name, themes, pdf, filename in additions:
        raw_pdf = pdf.read_bytes()
        reader = PdfReader(io.BytesIO(raw_pdf))
        assert len(reader.pages) > 0
        pdf_key, pdf_hash = stage(raw_pdf, 'pdf')
        clear, counts = label_voices((OUT / filename).read_bytes())
        midi_key, midi_hash = stage(clear, 'midi')
        song_id = str(uuid.uuid4())
        rows.append({'id': song_id, 'nombre': name, 'archivo': pdf_key, 'temas': themes,
                     'es_privado': False, 'midi_archivo': midi_key, 'vinculo_idioma': None,
                     'coro_id': 'local', 'version': 1, 'cifrado_version': 1,
                     '_idioma': 'es', 'idioma': 'es'})
        records.append({'id': song_id, 'name': name, 'sourceMidi': filename,
                        'sourcePdf': str(pdf), 'pdfHash': pdf_hash, 'pdfKey': pdf_key,
                        'pages': len(reader.pages), 'midiHash': midi_hash,
                        'midiKey': midi_key, 'notes': counts, 'newWork': True})

    changed_ids = {record['id'] for record in records}
    after = {row['id']: row for row in rows}
    assert len(after) == len(before) + 2
    assert all(after[song_id] == row for song_id, row in before.items() if song_id not in changed_ids)
    assert all(after[song_id]['archivo'] == before[song_id]['archivo'] for song_id, _ in sources)
    (OUT / 'catalog-before.json').write_bytes(original)
    (OUT / 'catalog-after.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (OUT / 'manifest.json').write_text(json.dumps({'records': records,
        'beforeCount': len(before), 'afterCount': len(after),
        'unrelatedEntriesUnchanged': True, 'existingPdfsUnchanged': True},
        ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for asset, data in staged_assets.items():
        target = OUT / 'bundle' / asset
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    print(json.dumps({'prepared': len(records), 'newWorks': 2, 'newAssets': len(staged_assets)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
