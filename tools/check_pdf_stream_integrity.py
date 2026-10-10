"""Check compressed PDF objects independently of successful page rendering."""
import concurrent.futures
import io
import json
import zlib
from pypdf import PdfReader
from pypdf.generic import IndirectObject, StreamObject
import audit_offline_assets as audit

def inspect(entry):
    result = {'asset': entry['asset'], 'streamErrors': [], 'checkedStreams': 0}
    try:
        reader = PdfReader(io.BytesIO(audit.clear_asset(audit.ROOT / entry['asset'])))
        if reader.is_encrypted and not reader.decrypt(''):
            raise ValueError('password required')
        for generation, objects in reader.xref.items():
            for identifier in objects:
                if not identifier:
                    continue
                value = reader.get_object(IndirectObject(identifier, generation, reader))
                if not isinstance(value, StreamObject):
                    continue
                filters = value.get('/Filter')
                if str(filters) != '/FlateDecode' and str(filters) != "['/FlateDecode']":
                    continue
                if not value._data:
                    continue
                result['checkedStreams'] += 1
                try:
                    zlib.decompress(value._data)
                except zlib.error as error:
                    result['streamErrors'].append({'object': identifier,
                        'type': str(value.get('/Type')), 'subtype': str(value.get('/Subtype')),
                        'error': str(error)})
    except Exception as error:
        result['error'] = str(error)
    return result

def main():
    report = json.loads((audit.OUT / 'deep-files-and-apk.json').read_text(encoding='utf-8'))
    entries = [entry for entry in report['resources'] if '/pdfs/' in entry['asset']]
    results = []
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
            for result in executor.map(inspect, entries):
                results.append(result)
                if len(results) % 200 == 0:
                    print(f'PDF streams checked: {len(results)}/{len(entries)}', flush=True)
    finally:
        for process in audit.bridges:
            process.stdin.close(); process.wait(timeout=20); process.stdout.close()
    (audit.OUT / 'all-pdf-streams.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'pdfs': len(results), 'checkedStreams': sum(r['checkedStreams'] for r in results),
        'pdfsWithStreamErrors': sum(bool(r['streamErrors']) for r in results),
        'readerErrors': sum('error' in r for r in results)}), flush=True)

if __name__ == '__main__':
    main()
