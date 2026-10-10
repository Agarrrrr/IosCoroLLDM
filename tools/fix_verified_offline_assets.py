"""Repair two audited assets, retaining originals and checking PDF pixel equality."""
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import zlib
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from PIL import Image, ImageChops
from pypdf import PdfReader
from pypdf.generic import IndirectObject, StreamObject
import audit_offline_assets as audit

ROOT = audit.ROOT
OUT = ROOT / 'output/offline_integrity/2026-10-10/corrections'
PDF = ROOT / 'assets/offline_assets/pdfs/maravillosa-gracia-1782161328444.pdf'
PECADOR = 'c35b5fd9-8d99-445f-89e3-21dd998a3e92'
GRACIA = '9c7eeee3-d5d7-4cd1-8f77-96ce435ac5f2'


def render(clear):
    process = subprocess.run([shutil.which('pdftoppm'), '-scale-to', '1800', '-png', '-'],
                             input=clear, capture_output=True, check=True)
    return list(audit.png_pages(process.stdout)), process.stderr.decode(errors='replace')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    originals = OUT / 'originals'
    originals.mkdir(exist_ok=True)
    raw = PDF.read_bytes()
    # Existing application key, never printed or written into audit reports.
    source = (ROOT / 'lib/core/security/file_crypto.dart').read_text(encoding='utf-8')
    key = hashlib.sha256(re.search(r"_rawKey = '([^']+)'", source)[1].encode()).digest()
    cipher = AESGCM(key)
    clear = cipher.decrypt(raw[:12], raw[12:], None)
    reader = PdfReader(io.BytesIO(clear))
    fixed = clear
    changes = []
    for identifier, expected in [(47, b'q\n'), (49, b'\nQ\n')]:
        stream = reader.get_object(IndirectObject(identifier, 0, reader))
        assert str(stream.get('/Filter')) == '/FlateDecode'
        assert stream.get_data() == expected
        old = stream._data
        new = zlib.compress(expected)
        assert len(new) == len(old), 'Offsets and lengths must remain unchanged'
        assert clear.count(old) == 1, 'Stream replacement must be unambiguous'
        fixed = fixed.replace(old, new, 1)
        changes.append({'object': identifier, 'decodedBytes': len(expected),
                        'compressedBytes': len(new)})
    assert len(fixed) == len(clear)
    checked = PdfReader(io.BytesIO(fixed))
    streams = 0
    for generation, objects in checked.xref.items():
        for identifier in objects:
            if not identifier:
                continue
            value = checked.get_object(IndirectObject(identifier, generation, checked))
            if isinstance(value, StreamObject) and str(value.get('/Filter')) == '/FlateDecode':
                zlib.decompress(value._data)
                streams += 1
    before, before_warnings = render(clear)
    after, after_warnings = render(fixed)
    assert len(before) == len(after) == 2
    comparisons = []
    for page, (a, b) in enumerate(zip(before, after), 1):
        image_a = Image.open(io.BytesIO(a)).convert('RGB')
        image_b = Image.open(io.BytesIO(b)).convert('RGB')
        assert image_a.size == image_b.size
        changed = ImageChops.difference(image_a, image_b).getbbox()
        comparisons.append({'page': page, 'identicalPixels': changed is None})
        (OUT / f'maravillosa-gracia-fixed-{page}.png').write_bytes(b)
        assert changed is None, 'Repair must not change rendered music or lyrics'
    assert 'flate stream' not in after_warnings.lower()
    catalogs = [ROOT / 'assets/catalogo.json', ROOT / 'assets/offline_assets/catalogo.json']
    updated = []
    for path in catalogs:
        text = path.read_text(encoding='utf-8')
        rows = json.loads(text)
        pecador = next(row for row in rows if row['id'] == PECADOR)
        assert pecador['archivo'].startswith('https://')
        local_pdf = 'pecador-ven-al-dulce-jesus-1777250932709.pdf'
        assert (ROOT / 'assets/offline_assets/pdfs' / local_pdf).is_file()
        # Exact textual replacement preserves all other catalog formatting and entries.
        text = text.replace('"archivo": ' + json.dumps(pecador['archivo']),
                            '"archivo": ' + json.dumps(local_pdf), 1)
        # Invalidate the existing cached PDF when users install this correction.
        gracia = next(row for row in rows if row['id'] == GRACIA)
        assert 'version' not in gracia, 'Review existing cache version before updating'
        marker = '"archivo": "maravillosa-gracia-1782161328444.pdf",'
        assert text.count(marker) == 1
        text = text.replace(marker, marker + '\n    "version": 2,', 1)
        new_rows = json.loads(text)
        for old_row, new_row in zip(rows, new_rows):
            if old_row['id'] == PECADOR:
                assert new_row == dict(old_row, archivo=local_pdf)
            elif old_row['id'] == GRACIA:
                assert new_row == dict(old_row, version=2)
            else:
                assert old_row == new_row
        updated.append((path, text))
    # Back up all originals before changing the bundled sources.
    assert not (originals / 'maravillosa-gracia-original-encrypted.pdf').exists()
    (originals / 'maravillosa-gracia-original-encrypted.pdf').write_bytes(raw)
    for index, (path, _) in enumerate(updated):
        shutil.copyfile(path, originals / f'catalogo-original-{index}.json')
    nonce = os.urandom(12)
    repaired_raw = nonce + cipher.encrypt(nonce, fixed, None)
    assert cipher.decrypt(repaired_raw[:12], repaired_raw[12:], None) == fixed
    PDF.write_bytes(repaired_raw)
    for path, text in updated:
        path.write_text(text, encoding='utf-8', newline='\n')
    result = {'repairedPdf': str(PDF.relative_to(ROOT)), 'streams': changes,
              'allFlateStreamsValid': streams, 'pageComparisons': comparisons,
              'beforeWarnings': before_warnings, 'afterWarnings': after_warnings,
              'originalEncryptedSha256': hashlib.sha256(raw).hexdigest(),
              'repairedEncryptedSha256': hashlib.sha256(repaired_raw).hexdigest(),
              'repairedClearSha256': hashlib.sha256(fixed).hexdigest(),
              'catalogChanges': {'pecadorPdf': local_pdf, 'graciaPdfVersion': 2}}
    (OUT / 'repair-verification.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
