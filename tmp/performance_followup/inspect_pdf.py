import json
from pathlib import Path
from pypdf import PdfReader
root = Path('tmp/performance_followup')
reader = PdfReader(root / 'expensive_pdf.pdf')
pages = []
for page in reader.pages:
    images = []
    for image in page.images:
        obj = image.indirect_reference.get_object()
        images.append({'name': image.name, 'width': obj.get('/Width'), 'height': obj.get('/Height'),
            'filter': str(obj.get('/Filter')), 'bits': obj.get('/BitsPerComponent'),
            'colorSpace': str(obj.get('/ColorSpace')), 'encodedBytes': len(image.data)})
    pages.append({'size': list(page.mediabox), 'images': images,
        'contentBytes': len(page.get_contents().get_data())})
report = {'metadata': dict(reader.metadata or {}), 'pages': pages}
(root / 'pdf_structure.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
