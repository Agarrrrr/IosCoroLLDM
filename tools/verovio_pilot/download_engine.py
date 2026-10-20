"""Fetch the official Verovio browser distribution for the isolated pilot."""
from pathlib import Path
import hashlib,json,urllib.request

out=Path('output/verovio_pilot/assets/reader');out.mkdir(parents=True,exist_ok=True)
url='https://www.verovio.org/javascript/latest/verovio-toolkit-wasm.js'
with urllib.request.urlopen(url,timeout=60) as response:data=response.read()
(out/'verovio-toolkit-wasm.js').write_bytes(data)
with urllib.request.urlopen('https://raw.githubusercontent.com/rism-digital/verovio/develop/COPYING',timeout=30) as response:license_data=response.read()
(out/'COPYING-Verovio.txt').write_bytes(license_data)
(out/'provenance.json').write_text(json.dumps({'url':url,'sha256':hashlib.sha256(data).hexdigest(),'license':'LGPL-3.0','date':'2026-10-15'},indent=2),encoding='utf-8')
print(len(data),data[:150],data[-300:])
