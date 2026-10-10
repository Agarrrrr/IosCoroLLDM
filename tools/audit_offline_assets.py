"""Read-only inventory, APK checks, full PDF rendering and strict MIDI structure audit."""
import base64
import concurrent.futures
import hashlib
import io
import json
import logging
import shutil
import struct
import subprocess
import threading
import zipfile
from urllib.parse import quote
from pathlib import Path
from PIL import Image, ImageStat
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/offline_integrity/2026-10-10'
DART = 'C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe'
local = threading.local()
bridges = []
bridge_lock = threading.Lock()

def clear_asset(path):
    raw = path.read_bytes()
    if raw.startswith((b'%PDF', b'MThd')):
        return raw
    if not hasattr(local, 'bridge'):
        local.bridge = subprocess.Popen([DART, 'run', str(ROOT / 'tools/read_offline_asset.dart')],
            cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, encoding='utf-8')
        with bridge_lock:
            bridges.append(local.bridge)
    process = local.bridge
    process.stdin.write(json.dumps(str(path)) + '\n')
    process.stdin.flush()
    response = process.stdout.readline()
    if not response:
        raise ValueError('decryption bridge stopped')
    data = json.loads(response)
    if 'error' in data:
        raise ValueError(data['error'])
    return base64.b64decode(data['bytes'], validate=True)

def midi_structure(data):
    if data[:4] != b'MThd' or len(data) < 14:
        raise ValueError('invalid MIDI header')
    header_size = int.from_bytes(data[4:8], 'big')
    fmt, tracks, division = struct.unpack('>HHH', data[8:14])
    if header_size < 6 or 8 + header_size > len(data) or fmt > 2 or not tracks or not division:
        raise ValueError('invalid MIDI header fields')
    offset, count, notes, warnings = 8 + header_size, 0, 0, []
    def vlq(buf, position):
        value = 0
        for _ in range(4):
            if position >= len(buf):
                raise ValueError('truncated variable-length MIDI value')
            byte = buf[position]; position += 1
            value = (value << 7) | (byte & 127)
            if not byte & 128:
                return value, position
        raise ValueError('MIDI variable-length value exceeds 4 bytes')
    while offset < len(data):
        if offset + 8 > len(data):
            raise ValueError('truncated MIDI chunk header')
        kind = data[offset:offset + 4]
        length = int.from_bytes(data[offset + 4:offset + 8], 'big')
        offset += 8
        if offset + length > len(data):
            raise ValueError('MIDI track length exceeds file')
        body = data[offset:offset + length]; offset += length
        if kind != b'MTrk':
            warnings.append('non-track chunk: ' + repr(kind)); continue
        count += 1
        pos, running, ended = 0, None, False
        while pos < len(body):
            _, pos = vlq(body, pos)
            if pos >= len(body):
                raise ValueError('missing MIDI event after delta')
            status = body[pos]
            if status & 128:
                pos += 1
            else:
                if running is None:
                    raise ValueError('MIDI running status without previous event')
                status = running
            if status == 255:
                if pos >= len(body):
                    raise ValueError('missing MIDI meta type')
                meta = body[pos]; pos += 1
                size, pos = vlq(body, pos)
                if pos + size > len(body):
                    raise ValueError('truncated MIDI meta event')
                if meta == 47:
                    if size:
                        raise ValueError('invalid end-of-track event')
                    ended = True
                if meta == 81 and (size != 3 or int.from_bytes(body[pos:pos + size], 'big') == 0):
                    raise ValueError('invalid MIDI tempo')
                pos += size
            elif status in (240, 247):
                size, pos = vlq(body, pos)
                if pos + size > len(body):
                    raise ValueError('truncated MIDI SysEx')
                pos += size
            elif 128 <= status <= 239:
                running = status
                size = 1 if status & 240 in (192, 208) else 2
                if pos + size > len(body) or any(byte >= 128 for byte in body[pos:pos + size]):
                    raise ValueError('invalid MIDI channel event')
                if status & 240 == 144 and body[pos + 1] > 0:
                    notes += 1
                pos += size
            else:
                raise ValueError(f'unsupported MIDI status {status:#x}')
        if not ended:
            warnings.append(f'track {count} has no end-of-track marker')
    if count != tracks or not notes:
        raise ValueError(f'declared tracks {tracks}, actual {count}, note-ons {notes}')
    if fmt == 2 or division & 32768:
        warnings.append('format 2 or SMPTE timing needs playback review')
    return {'format': fmt, 'tracks': tracks, 'noteOns': notes, 'warnings': warnings}

def png_pages(data):
    pos = 0
    while pos < len(data):
        start = pos
        if data[pos:pos + 8] != b'\x89PNG\r\n\x1a\n':
            raise ValueError('invalid rendered PNG stream')
        pos += 8
        while True:
            if pos + 12 > len(data):
                raise ValueError('truncated rendered PNG')
            size = int.from_bytes(data[pos:pos + 4], 'big')
            kind = data[pos + 4:pos + 8]
            pos += 12 + size
            if pos > len(data):
                raise ValueError('invalid rendered PNG chunk')
            if kind == b'IEND':
                break
        yield data[start:pos]

def inspect(path):
    result = {'asset': path.relative_to(ROOT).as_posix()}
    try:
        clear = clear_asset(path)
        result['clearSha256'] = hashlib.sha256(clear).hexdigest()
        if '/pdfs/' in result['asset']:
            reader = PdfReader(io.BytesIO(clear), strict=False)
            if reader.is_encrypted and not reader.decrypt(''):
                raise ValueError('PDF still requires a password after app decryption')
            pages = len(reader.pages)
            if not pages:
                raise ValueError('PDF has no pages')
            for page in reader.pages:
                if float(page.mediabox.width) <= 0 or float(page.mediabox.height) <= 0:
                    raise ValueError('invalid PDF page dimensions')
                contents = page.get_contents()
                if contents is not None:
                    contents.get_data()
            process = subprocess.run([shutil.which('pdftoppm'), '-scale-to', '256', '-png', '-'],
                input=clear, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
            if process.returncode:
                raise ValueError(process.stderr.decode('utf-8', errors='replace'))
            rendered, blank = 0, []
            for png in png_pages(process.stdout):
                rendered += 1
                with Image.open(io.BytesIO(png)) as image:
                    image.load()
                    if ImageStat.Stat(image.convert('L')).extrema[0][0] >= 254:
                        blank.append(rendered)
            if rendered != pages:
                raise ValueError(f'PDF pages {pages}, rendered {rendered}')
            result.update(pages=pages, renderedPages=rendered, blankPages=blank,
                warnings=process.stderr.decode('utf-8', errors='replace').strip())
        else:
            result.update(midi_structure(clear))
        result['status'] = 'ok'
    except Exception as error:
        result.update(status='error', error=str(error))
    return result

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    catalogs = {}
    refs = {'pdfs': set(), 'midis': set()}
    remote, absent = [], []
    rows = []
    for suffix in ['', '_en']:
        path = ROOT / f'assets/catalogo{suffix}.json'
        catalogs[path.relative_to(ROOT).as_posix()] = path.read_bytes()
        for row in json.loads(path.read_text(encoding='utf-8-sig')):
            rows.append(row)
            for field, folder in [('archivo', 'pdfs'), ('midi_archivo', 'midis')]:
                value = row.get(field)
                if not value:
                    continue
                if value.startswith(('http:', 'https:')):
                    remote.append({'id': row['id'], 'name': row['nombre'], 'type': folder, 'url': value})
                    continue
                asset = f'assets/offline_assets/{folder}/{value}'
                refs[folder].add(asset)
                if not (ROOT / asset).is_file():
                    absent.append({'id': row['id'], 'name': row['nombre'], 'asset': asset})
    files = sorted(path for folder in refs for path in (ROOT / f'assets/offline_assets/{folder}').rglob('*') if path.is_file())
    package = {'apk': 'build/app/outputs/flutter-apk/app-debug.apk', 'errors': []}
    apk = ROOT / package['apk']
    if apk.is_file():
        with zipfile.ZipFile(apk) as archive:
            package['zipCrcError'] = archive.testzip()
            names = set(archive.namelist())
            for path in files + [ROOT / key for key in catalogs] + [ROOT / 'assets/Piano.sf2']:
                key = 'assets/flutter_assets/' + path.relative_to(ROOT).as_posix()
                # Flutter stores spaces and Unicode filenames as URI paths.
                if key not in names:
                    key = quote(key, safe='/')
                if key not in names or hashlib.sha256(archive.read(key)).digest() != hashlib.sha256(path.read_bytes()).digest():
                    package['errors'].append(key)
            package['verifiedAssets'] = len(files) + len(catalogs) + 1
    else:
        package['errors'].append('APK absent')
    font = (ROOT / 'assets/Piano.sf2').read_bytes()
    package['soundfontValidHeader'] = font[:4] == b'RIFF' and font[8:12] == b'sfbk' and int.from_bytes(font[4:8], 'little') + 8 == len(font)
    results = []
    logging.getLogger('pypdf').setLevel(logging.ERROR)
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
            for result in executor.map(inspect, files):
                results.append(result)
                if len(results) % 100 == 0:
                    print(f'Inspected {len(results)}/{len(files)}; errors={sum(r["status"] == "error" for r in results)}', flush=True)
    finally:
        for process in bridges:
            try:
                process.stdin.close()
            except OSError:
                pass
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
            process.stdout.close()
    inventory = {p.relative_to(ROOT).as_posix() for p in files}
    report = {'catalogEntries': len(rows), 'remoteReferences': remote, 'missingReferences': absent,
        'apk': package, 'unreferencedAssets': sorted(inventory - set.union(*refs.values())),
        'resources': results, 'errors': [r for r in results if r['status'] != 'ok']}
    (OUT / 'deep-files-and-apk.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'resources': len(results), 'pdfPagesRendered': sum(r.get('renderedPages', 0) for r in results),
        'errors': len(report['errors']), 'remoteReferences': len(remote), 'missingReferences': len(absent),
        'apkErrors': len(package['errors'])}, ensure_ascii=False), flush=True)

if __name__ == '__main__':
    main()
