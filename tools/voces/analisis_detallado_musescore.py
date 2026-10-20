import os
import json
import re
import unicodedata

BASE_CANTAI = r"E:\MusescoreCantai"
ESP_DIR = r"E:\Respaldo\Voces Cantadas"
CAT_PATH = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\assets\catalogo.json"

with open(os.path.join(ESP_DIR, "indice_voces_cantadas.json"), "r", encoding="utf-8") as f:
    indice_esp = json.load(f)

with open(CAT_PATH, "r", encoding="utf-8") as f:
    catalogo = json.load(f)

def clean(s):
    if not s:
        return ""
    s = re.sub(r"-\s*SATB.*", "", s, flags=re.IGNORECASE)
    s = re.sub(r"\(.*?\)", "", s)
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    s = re.sub(r"[^a-z0-9]", " ", s)
    return re.sub(r"\s+", " ", s).strip()

cat_by_clean = {clean(c["nombre"]): c for c in catalogo}

esp_songs = []
for item in indice_esp:
    c_name = item.get("canto") or item.get("app_nombre") or re.sub(r"^\d+[\.\s_]+", "", item.get("carpeta", ""))
    esp_songs.append({
        "item": item,
        "clean": clean(c_name),
        "name": c_name
    })

mscz_files = sorted([f for f in os.listdir(BASE_CANTAI) if f.endswith(".mscz") and "glory unto jesus" not in f.lower()])

analysis = []
for f in mscz_files:
    c_f = clean(f)
    
    # 1. Check match in Voces Cantadas
    match_voces = next((x for x in esp_songs if c_f == x["clean"]), None)
    if not match_voces:
        # substring
        for x in esp_songs:
            if c_f in x["clean"] or x["clean"] in c_f:
                if len(c_f) > 5 and len(x["clean"]) > 5:
                    match_voces = x
                    break
                    
    # 2. Check match in catalogo.json
    match_cat = cat_by_clean.get(c_f)
    if not match_cat:
        for ck, cv in cat_by_clean.items():
            if c_f == ck or (len(c_f) > 6 and (c_f in ck or ck in c_f)):
                match_cat = cv
                break
                
    analysis.append({
        "file": f,
        "clean": c_f,
        "match_voces": match_voces,
        "match_cat": match_cat
    })

print("=" * 80)
print("ANÁLISIS COMPLETO DE MUSESCORE CANTAI (ESPAÑOL)")
print("=" * 80)

coincidencias = [a for a in analysis if a["match_voces"]]
nuevas = [a for a in analysis if not a["match_voces"]]

print(f"Total archivos en español: {len(analysis)}")
print(f"Coincidencias con repertorio actual de Voces Cantadas: {len(coincidencias)}")
print(f"Alabanzas que NO están en Voces Cantadas (nuevas para estudio): {len(nuevas)}")

print("\n--- REPETIDAS / COINCIDENCIAS CON VOCES CANTADAS ---")
for a in coincidencias:
    item = a["match_voces"]["item"]
    fuente = item.get("fuente") or "YouTube / VPEC"
    m_vol = re.search(r"Vol\.?\s*(\d+)", fuente)
    vol_num = int(m_vol.group(1)) if m_vol else None
    
    # User rule: "si son de antes del con todo mi ser 7 sí tienen prioridad las de musescore"
    es_antes_7 = (vol_num is not None and vol_num < 7)
    prioridad_txt = f"⭐ PRIORIDAD MUSESCORE (Fuente actual es Vol. {vol_num} < 7)" if es_antes_7 else f"MANTIENE ACTUAL ({fuente})"
    
    print(f"• Archivo: '{a['file']}'")
    print(f"  -> Coincide con: [{item['numero']}] {a['match_voces']['name']} ({item['carpeta']})")
    print(f"  -> Fuente en Voces Cantadas: {fuente}")
    print(f"  -> Regla usuario: {prioridad_txt}\n")

print("\n--- ALABANZAS NUEVAS (TOTAL: {len(nuevas)}) ---")
for a in nuevas:
    cat_str = f"En catálogo: '{a['match_cat']['nombre']}' ({a['match_cat'].get('archivo')})" if a["match_cat"] else "No en catálogo"
    print(f"• {a['file']:<55} | {cat_str}")
