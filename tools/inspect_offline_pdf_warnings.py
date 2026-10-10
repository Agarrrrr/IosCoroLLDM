"""Local visual samples and stream diagnostics; original PDFs remain untouched."""
import io
import json
import subprocess
import zlib
from pathlib import Path
from pypdf import PdfReader
from pypdf.generic import IndirectObject, StreamObject
import audit_offline_assets as audit

def main():
    output = audit.OUT / 'previews'
    output.mkdir(exist_ok=True)
    samples = [
        'maravillosa-gracia-1782161328444.pdf',
        '04c79188cdea334f3a8e2850_i_praise_the_omnipotent_god.pdf',
        'pecador-ven-al-dulce-jesus-1777250932709.pdf',
    ]
    report = []
    try:
        for name in samples:
            clear = audit.clear_asset(audit.ROOT / 'assets/offline_assets/pdfs' / name)
            reader = PdfReader(io.BytesIO(clear))
            item = {'asset': name, 'pages': len(reader.pages), 'streamErrors': []}
            for generation, objects in reader.xref.items():
                for identifier in objects:
                    if identifier == 0:
                        continue
                    value = reader.get_object(IndirectObject(identifier, generation, reader))
                    if isinstance(value, StreamObject) and str(value.get('/Filter')) == '/FlateDecode':
                        try:
                            zlib.decompress(value._data)
                        except zlib.error as error:
                            item['streamErrors'].append({'object': identifier,
                                'type': str(value.get('/Type')), 'subtype': str(value.get('/Subtype')),
                                'error': str(error)})
            command = [audit.shutil.which('pdftoppm'), '-scale-to', '1200', '-png']
            if name != samples[0]:
                command += ['-f', '1', '-l', '1']
            process = subprocess.run(command + ['-'], input=clear, capture_output=True, timeout=90)
            if process.returncode:
                raise RuntimeError(process.stderr.decode(errors='replace'))
            for number, png in enumerate(audit.png_pages(process.stdout), 1):
                (output / f'{Path(name).stem}-{number}.png').write_bytes(png)
            report.append(item)
    finally:
        for process in audit.bridges:
            process.stdin.close()
            process.wait(timeout=20)
            process.stdout.close()
    (audit.OUT / 'warning-stream-inspection.json').write_text(json.dumps(report, indent=2), encoding='utf-8')

if __name__ == '__main__':
    main()
