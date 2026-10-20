#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import json
import unicodedata
import re

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
# Also map by first few words / words set
all_cat_names = [c["nombre"] for c in catalogo]

folders = sorted([d for d in os.listdir(VOCES_DIR) if os.path.isdir(os.path.join(VOCES_DIR, d))])
print(f"Total carpetas encontradas: {len(folders)}")

songs_info = []

for folder in folders:
    fpath = os.path.join(VOCES_DIR, folder)
    meta_path = os.path.join(fpath, "meta.json")
    meta = {}
    if os.path.exists(meta_path):
        with open(meta_path, "r", encoding="utf-8") as mf:
            meta = json.load(mf)
    
    mp3s = [f for f in os.listdir(fpath) if f.endswith(".mp3")]
    pistas = meta.get("pistas", [])
    canto = meta.get("canto", folder)
    
    # check if matched to catalogo
    matched_cat = None
    app_id = meta.get("app_id")
    if app_id:
        matched_cat = meta.get("app_nombre")
    else:
        clean_f = clean_str(re.sub(r"^\d+[\.\s_]+", "", folder))
        if clean_f in cat_by_clean:
            matched_cat = cat_by_clean[clean_f]["nombre"]
            app_id = cat_by_clean[clean_f]["id"]
        else:
            clean_c = clean_str(canto)
            if clean_c in cat_by_clean:
                matched_cat = cat_by_clean[clean_c]["nombre"]
                app_id = cat_by_clean[clean_c]["id"]
    
    voces = [p.get("voz") for p in pistas] if pistas else []
    
    songs_info.append({
        "folder": folder,
        "canto": canto,
        "matched_cat": matched_cat,
        "app_id": app_id,
        "mp3_count": len(mp3s),
        "voces": voces,
        "mp3s": mp3s,
        "fuente": meta.get("fuente", "")
    })

print("\n" + "=" * 80)
print("1. CANCIONES SIN MATCH EN CATALOGO (o pendientes de enlazar)")
print("=" * 80)
no_match = [s for s in songs_info if not s["matched_cat"]]
for s in no_match:
    print(f"Carpeta: '{s['folder']}' | Canto: '{s['canto']}' | Fuente: '{s['fuente']}' | MP3s: {s['mp3_count']}")

print(f"\nTotal sin match: {len(no_match)}")

print("\n" + "=" * 80)
print("2. CANCIONES CON PROBLEMAS DE PISTAS (No tienen exactamente Soprano, Contralto, Tenor, Bajo)")
print("=" * 80)
problemas_pistas = []
for s in songs_info:
    v_set = set(s["voces"])
    # Standard 4 voices
    expected_4 = {"Soprano", "Contralto", "Tenor", "Bajo"}
    # Some songs have Tenor 1 and Tenor 2 (5 tracks total)
    expected_5 = {"Soprano", "Contralto", "Tenor", "Tenor 2", "Bajo"}
    expected_5_alt = {"Soprano", "Contralto", "Tenor 1", "Tenor 2", "Bajo"}
    
    is_valid_4 = (s["mp3_count"] == 4 and expected_4.issubset(v_set))
    is_valid_5 = (s["mp3_count"] == 5 and (expected_5.issubset(v_set) or expected_5_alt.issubset(v_set)))
    
    if not (is_valid_4 or is_valid_5):
        problemas_pistas.append(s)

for s in problemas_pistas:
    print(f"Carpeta: '{s['folder']}' | MP3s: {s['mp3_count']} | Voces: {s['voces']}")

print(f"\nTotal con problemas de pistas: {len(problemas_pistas)}")
