"""Deliver only our generated files; never replace an unrelated user file."""
from pathlib import Path
import hashlib,json,shutil
from no_hay_amigo_model import OUT
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def deliver():
    destination=Path('C:/Users/Huri_/Downloads/musescore');destination.mkdir(exist_ok=True)
    manifest=OUT/'delivery.json';previous=json.loads(manifest.read_text()) if manifest.exists() else {}
    pairs=[(OUT/'No Hay Amigo Mejor - SATB desarrollado.musicxml',destination/'No Hay Amigo Mejor - SATB desarrollado - Cantai.musicxml'),(OUT/'render/score.mscz',destination/'No Hay Amigo Mejor - SATB desarrollado - Cantai.mscz')]
    for source,target in pairs:
        assert source.is_file()
        if target.exists():assert digest(target) in [digest(source),previous.get(str(target))],f'User file requires preservation: {target}'
    result={}
    for source,target in pairs:shutil.copy2(source,target);result[str(target)]=digest(target);print(target)
    manifest.write_text(json.dumps(result,indent=2),encoding='utf-8')
if __name__=='__main__':deliver()
