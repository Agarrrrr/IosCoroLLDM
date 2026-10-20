"""Copy only the verified new score, preserving any existing user files."""
from pathlib import Path
import hashlib,json,shutil
from validate_alabad import OUT,errors
assert not errors
destination=Path('C:/Users/Huri_/Downloads/musescore')
assert destination.is_dir()
manifest=[]
previous=json.loads((OUT/'delivery.json').read_text(encoding='utf-8')) if (OUT/'delivery.json').exists() else []
for origin,extension in [(OUT/'render/exported.musicxml','musicxml'),(OUT/'render/score.mscz','mscz')]:
    target=destination/f'Alabad a Jehová - SATB revisado contra PDF.{extension}'
    digest=hashlib.sha256(origin.read_bytes()).hexdigest()
    if target.exists():
        current=hashlib.sha256(target.read_bytes()).hexdigest()
        assert current==digest or any(p['path']==str(target) and p['sha256']==current for p in previous),f'Existing user-edited file: {target}'
    shutil.copy2(origin,target)
    assert hashlib.sha256(target.read_bytes()).hexdigest()==digest
    manifest.append(dict(path=str(target),bytes=target.stat().st_size,sha256=digest))
(OUT/'delivery.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(manifest,ensure_ascii=False,indent=2))
