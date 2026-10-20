import os
import json
import re
import unicodedata

BASE_CANTAI = r"E:\MusescoreCantai"
ESP_DIR = r"E:\Respaldo\Voces Cantadas"
ENG_DIR = r"E:\Respaldo\Voces Cantadas (English)"
INDICE_ESP = os.path.join(ESP_DIR, "indice_voces_cantadas.json")

with open(INDICE_ESP, "r", encoding="utf-8") as f:
    indice_esp = json.load(f)

def clean(s):
    if not s:
        return ""
    # Remove common suffixes like "- SATB - Cantai", "(variante SATB)", etc.
    s = re.sub(r"-\s*SATB.*", "", s, flags=re.IGNORECASE)
    s = re.sub(r"\(.*?\)", "", s)
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    s = re.sub(r"[^a-z0-9]", " ", s)
    return re.sub(r"\s+", " ", s).strip()

esp_items = []
for item in indice_esp:
    name = item.get("canto") or item.get("app_nombre") or re.sub(r"^\d+[\.\s_]+", "", item.get("carpeta", ""))
    clean_name = clean(name)
    esp_items.append({
        "clean": clean_name,
        "name": name,
        "item": item
    })

eng_folders = os.listdir(ENG_DIR)
eng_items = []
for f in eng_folders:
    clean_f = clean(re.sub(r"^\d+[\.\s_]+", "", f))
    eng_items.append({
        "clean": clean_f,
        "folder": f
    })

mscz_files = sorted([f for f in os.listdir(BASE_CANTAI) if f.endswith(".mscz")])

results_esp = []
results_eng = []

for f in mscz_files:
    clean_name = clean(f)
    if "glory unto jesus christ" in clean_name:
        # English
        match_eng = next((x for x in eng_items if clean_name == x["clean"] or clean_name in x["clean"] or x["clean"] in clean_name), None)
        results_eng.append({
            "file": f,
            "clean": clean_name,
            "matched_repo": match_eng["folder"] if match_eng else None
        })
    else:
        # Spanish
        # Exact clean match or substring
        match_esp = next((x for x in esp_items if clean_name == x["clean"]), None)
        if not match_esp:
            # try fuzzy / words match
            clean_words = set(clean_name.split())
            for x in esp_items:
                target_words = set(x["clean"].split())
                if clean_words and target_words:
                    intersection = clean_words.intersection(target_words)
                    # If 80% of words match and at least 2 words
                    if len(intersection) >= max(len(clean_words), len(target_words)) * 0.75 and len(intersection) >= 2:
                        match_esp = x
                        break
                        
        results_esp.append({
            "file": f,
            "clean": clean_name,
            "match": match_esp["item"] if match_esp else None,
            "matched_name": match_esp["name"] if match_esp else None
        })

print("=" * 80)
print(f"1. INGLÉS (Total en MusescoreCantai: {len(results_eng)})")
print("=" * 80)
for r in results_eng:
    print(f"  Archivo: '{r['file']}'")
    print(f"    -> En repositorio inglés: {r['matched_repo']}")

print("\n" + "=" * 80)
print(f"2. ESPAÑOL (Total en MusescoreCantai: {len(results_esp)})")
print("=" * 80)

coincidencias = [r for r in results_esp if r["match"]]
no_coincidencias = [r for r in results_esp if not r["match"]]

print(f"Coincidencias encontradas en Voces Cantadas: {len(coincidencias)}")
print(f"Alabanzas sin audio actual en Voces Cantadas (Nuevas): {len(no_coincidencias)}")

print("\n--- COINCIDENCIAS / REPETIDAS EN ESPAÑOL ---")
for r in coincidencias:
    m = r["match"]
    fuente = m.get("fuente") or "YouTube / VPEC"
    m_vol = re.search(r"Vol\.?\s*(\d+)", fuente)
    vol_num = int(m_vol.group(1)) if m_vol else None
    
    es_antes_vol7 = (vol_num is not None and vol_num < 7)
    if es_antes_vol7:
        prioridad = f"⭐ SÍ - TIENE PRIORIDAD MUSESCORE (Fuente actual es Vol. {vol_num} < 7)"
    else:
        prioridad = f"❌ NO - SE MANTIENE ACTUAL (Fuente actual es {fuente})"
        
    print(f"• Archivo: '{r['file']}'")
    print(f"    -> Coincide con: [{m['numero']}] {r['matched_name']} ({m['carpeta']})")
    print(f"    -> Fuente actual: {fuente}")
    print(f"    -> Prioridad: {prioridad}\n")

print("\n--- ALABANZAS NUEVAS (SIN AUDIO EN VOCES CANTADAS) ---")
# Group unique
unique_nuevas = {}
for r in no_coincidencias:
    unique_nuevas.setdefault(r["clean"], []).append(r["file"])

for clean_n, files in sorted(unique_nuevas.items()):
    print(f"• {clean_n.title()} ({', '.join(files)})")
