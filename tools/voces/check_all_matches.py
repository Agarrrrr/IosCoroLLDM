import os
import json
import re
import unicodedata

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

# Check all folders
folders = sorted([d for d in os.listdir(VOCES_DIR) if os.path.isdir(os.path.join(VOCES_DIR, d))])

user_delete_names = [
    "la cancion sera un amen",
    "mirad al rey",
    "no hay nada mas lindo y hermoso",
    "te amamos oh samuel",
    "un excelente apostol",
    "por tu gran amor",
    "por un apostol"
]

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

matches_summary = []
for folder in folders:
    clean_f = clean_str(re.sub(r"^\d+[\.\s_]+", "", folder))
    if any(d in clean_f for d in user_delete_names):
        continue
    
    meta_path = os.path.join(VOCES_DIR, folder, "meta.json")
    meta = {}
    if os.path.exists(meta_path):
        with open(meta_path, "r", encoding="utf-8") as mf:
            meta = json.load(mf)
            
    canto = meta.get("canto", folder)
    clean_c = clean_str(canto)
    
    # Is it in approved renames?
    target_rename = None
    for k, v in user_approved_renames.items():
        if k in clean_f or k in clean_c:
            target_rename = v
            break
            
    cat_match = None
    if target_rename:
        clean_target = clean_str(target_rename)
        if clean_target in cat_by_clean:
            cat_match = cat_by_clean[clean_target]
        else:
            # search partial
            for ck, cv in cat_by_clean.items():
                if clean_target in ck or ck in clean_target:
                    cat_match = cv
                    break
    elif meta.get("app_id"):
        # find in cat by id
        cat_match = next((c for c in catalogo if c["id"] == meta["app_id"]), None)
    elif clean_f in cat_by_clean:
        cat_match = cat_by_clean[clean_f]
    elif clean_c in cat_by_clean:
        cat_match = cat_by_clean[clean_c]
    else:
        # Partial search
        for ck, cv in cat_by_clean.items():
            if clean_f == ck or clean_c == ck:
                cat_match = cv
                break
                
    matches_summary.append({
        "folder": folder,
        "canto": canto,
        "rename": target_rename,
        "cat_match": cat_match["nombre"] if cat_match else "NO MATCH",
        "cat_id": cat_match["id"] if cat_match else None,
        "cat_pdf": cat_match.get("archivo") if cat_match else None,
        "fuente": meta.get("fuente")
    })

print(f"Total procesadas evaluadas: {len(matches_summary)}")
no_matches = [m for m in matches_summary if m["cat_match"] == "NO MATCH"]
print(f"Sin match: {len(no_matches)}")
for m in no_matches:
    print(" ", m)

# Let's check which songs have slight name differences
diff_names = [m for m in matches_summary if m["cat_match"] != "NO MATCH" and clean_str(m["cat_match"]) != clean_str(m["canto"])]
print(f"\nDiferencias de nombre con el catalogo oficial: {len(diff_names)}")
for m in diff_names:
    print(f"  Carpeta: '{m['folder']}' | Canto: '{m['canto']}' -> Catalogo: '{m['cat_match']}' (PDF: {m['cat_pdf']})")
