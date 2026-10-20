import json
import unicodedata
import re

with open(r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\assets\catalogo.json", "r", encoding="utf-8") as f:
    catalogo = json.load(f)

def clean(s):
    if not s:
        return ""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    return re.sub(r"[^a-z0-9]", " ", s).strip()

cat_by_clean = {clean(c["nombre"]): c for c in catalogo}

search_titles = [
    "El que habita al abrigo de Dios",
    "Grato es contar la historia",
    "Hay un Lugar",
    "Hay un lugar do quiero estar",
    "La luz que llegó a mi alma",
    "La tumba le encerró",
    "Oh bondad tan infinita",
    "Oh Que Gran Amor",
    "Si no hubiera Dios"
]

for t in search_titles:
    ct = clean(t)
    match = cat_by_clean.get(ct)
    if not match:
        matches = [c for c in catalogo if ct in clean(c["nombre"]) or clean(c["nombre"]) in ct]
        if matches:
            for m in matches:
                print(f"PARCIAL: '{t}' -> '{m['nombre']}' (id: {m['id']}, pdf: {m.get('archivo')})")
        else:
            print(f"NO ENCONTRADO: '{t}'")
    else:
        print(f"EXACTO: '{t}' -> '{match['nombre']}' (id: {match['id']}, pdf: {match.get('archivo')})")
