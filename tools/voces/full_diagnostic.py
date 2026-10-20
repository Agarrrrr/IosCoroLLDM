import os
import json
import re
import unicodedata
import statistics

VOCES_DIR = r"E:\Respaldo\Voces Cantadas"
CAT_PATH = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\assets\catalogo.json"

with open(CAT_PATH, "r", encoding="utf-8") as f:
    catalogo = json.load(f)

def clean_str(text):
    if not text:
        return ""
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.lower()
    text = re.sub(r"[^a-z0-9]", " ", text)
    return re.sub(r"\s+", " ", text).strip()

cat_by_clean = {clean_str(c["nombre"]): c for c in catalogo}

folders = sorted([d for d in os.listdir(VOCES_DIR) if os.path.isdir(os.path.join(VOCES_DIR, d))])

report = {
    "to_delete_by_user": [],
    "to_rename_by_user": [],
    "unmatched_in_catalog": [],
    "has_track5_or_ensamble": [],
    "missing_voices_less_than_4": [],
    "ok_4_voices": [],
    "ok_5_voices_tenor2": []
}

# The 7 songs user said "matalos"
user_delete_names = [
    "la cancion sera un amen",
    "mirad al rey",
    "no hay nada mas lindo y hermoso",
    "te amamos oh samuel",
    "un excelente apostol",
    "por tu gran amor",
    "por un apostol"
]

# The 10 approved renames/matches
user_approved_renames = {
    "al meditar": "El Año Que se va",
    "no se ha dicho aun la mitad": "Del Celeste Pais",
    "oh cuan santa es la union": "Una Vida Feliz",
    "venid venid": "Venid, Venid Cantad la Bella Historia",
    "jehova te bendiga": "Jehova te bendiga y te guarde",
    "cual manada": "Cual Manada de Ovejas",
    "somos cartas": "Somos Cartas Leídas",
    "bautizados fueron todos los creyentes": "Bautizados Fueron Todos",
    "eres como los cedros": "Eres Como Cedros",
    "si callare": "Si Callare Tus Maravillas"
}

for folder in folders:
    fpath = os.path.join(VOCES_DIR, folder)
    meta_path = os.path.join(fpath, "meta.json")
    meta = {}
    if os.path.exists(meta_path):
        with open(meta_path, "r", encoding="utf-8") as mf:
            meta = json.load(mf)
            
    canto = meta.get("canto", folder)
    clean_folder_name = clean_str(re.sub(r"^\d+[\.\s_]+", "", folder))
    clean_canto_name = clean_str(canto)
    
    # Check if in user delete list
    if any(d in clean_folder_name or d in clean_canto_name for d in user_delete_names):
        report["to_delete_by_user"].append((folder, canto, meta.get("fuente")))
        continue
        
    # Check if in user renames
    is_rename = False
    for k, v in user_approved_renames.items():
        if k in clean_folder_name or k in clean_canto_name:
            report["to_rename_by_user"].append((folder, canto, v, meta.get("fuente")))
            is_rename = True
            break
            
    # Check catalog match
    matched = None
    if is_rename:
        # Check if the target rename exists in catalog
        # The target rename will match
        matched = True
    elif meta.get("app_id"):
        matched = meta.get("app_nombre")
    elif clean_folder_name in cat_by_clean:
        matched = cat_by_clean[clean_folder_name]["nombre"]
    elif clean_canto_name in cat_by_clean:
        matched = cat_by_clean[clean_canto_name]["nombre"]
        
    if not matched:
        report["unmatched_in_catalog"].append((folder, canto, meta.get("fuente")))
        
    # Check tracks and voices
    mp3s = [f for f in os.listdir(fpath) if f.endswith(".mp3")]
    pistas = meta.get("pistas", [])
    voces = [p.get("voz") for p in pistas] if pistas else []
    
    # Check if there is Ensamble or track 5
    if "Ensamble" in voces or any("ensamble" in f.lower() for f in mp3s):
        report["has_track5_or_ensamble"].append((folder, canto, voces, meta.get("fuente")))
        
    if len(mp3s) < 4:
        report["missing_voices_less_than_4"].append((folder, canto, len(mp3s), voces, meta.get("fuente")))

print("=" * 80)
print(f"1. PARA ELIMINAR SEGÚN USUARIO ({len(report['to_delete_by_user'])}):")
for f, c, src in report["to_delete_by_user"]:
    print(f"   - {f} | Canto: {c} ({src})")

print(f"\n2. PARA RENOMBRAR / ENLAZAR OFICIALMENTE ({len(report['to_rename_by_user'])}):")
for f, c, target, src in report["to_rename_by_user"]:
    print(f"   - {f} -> '{target}' ({src})")

print(f"\n3. SIN MATCH EN CATÁLOGO ({len(report['unmatched_in_catalog'])}):")
for f, c, src in report["unmatched_in_catalog"]:
    print(f"   - {f} | Canto: {c} ({src})")

print(f"\n4. CON 'ENSAMBLE' O PISTA 5 QUE DEBE ELIMINARSE O RECLASIFICARSE ({len(report['has_track5_or_ensamble'])}):")
for f, c, v, src in report["has_track5_or_ensamble"][:20]:
    print(f"   - {f}: {v} ({src})")
if len(report["has_track5_or_ensamble"]) > 20:
    print(f"   ... y {len(report['has_track5_or_ensamble']) - 20} más.")

print(f"\n5. CANCIONES CON MENOS DE 4 VOCES ({len(report['missing_voices_less_than_4'])}):")
for f, c, n, v, src in report["missing_voices_less_than_4"]:
    print(f"   - {f}: {n} voces {v} ({src})")
