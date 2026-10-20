from pathlib import Path
import hashlib,json,shutil
from aleluya_model import OUT
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def deliver():
    dest=Path('C:/Users/Huri_/Downloads/musescore');dest.mkdir(exist_ok=True)
    manifest=OUT/'delivery.json';previous=json.loads(manifest.read_text()) if manifest.exists() else {}
    stem='Aleluya al Rey - SATB con letra - Cantai'
    pairs=[(OUT/(stem+'.musicxml'),dest/(stem+'.musicxml')),(OUT/'render/score.mscz',dest/(stem+'.mscz'))]
    for source,target in pairs:
        assert source.is_file()
        if target.exists():assert digest(target) in [digest(source),previous.get(str(target))],f'Preserve existing user file: {target}'
    result={}
    for source,target in pairs:shutil.copy2(source,target);result[str(target)]=digest(target);print(target)
    manifest.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
if __name__=='__main__':deliver()
