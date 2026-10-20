#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generador del Manifiesto Oficial de Voces Cantadas
Organizado estrictamente por idioma (es, en) con pesos reales en bytes.
"""

import os
import json
import re

ESP_DIR = r"E:\Respaldo\Voces Cantadas"
ENG_DIR = r"E:\Respaldo\Voces Cantadas (English)"
OUT_PATH_ASSETS = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\assets\voces_manifest.json"
OUT_PATH_WEB = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\website\public\voces_manifest.json"
OUT_PATH_RESPALDO = r"E:\Respaldo\voces_manifest.json"

CAT_ES_PATH = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\assets\catalogo.json"
CAT_EN_PATH = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\build\app\intermediates\flutter\debug\flutter_assets\assets\catalogo_en.json"

with open(CAT_ES_PATH, "r", encoding="utf-8") as f:
    cat_es = json.load(f)

with open(CAT_EN_PATH, "r", encoding="utf-8") as f:
    cat_en = json.load(f)

def clean_name(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())

cat_es_by_clean = {clean_name(c["nombre"]): c for c in cat_es}
cat_en_by_clean = {clean_name(c["nombre"]): c for c in cat_en}

manifest = {
    "version": 1,
    "generado_el": "2026-10-19T19:20:00Z",
    "base_url": "https://coro-lldm-previews.huritolentino.workers.dev/audio",
    "idiomas": {
        "es": {
            "total_alabanzas": 0,
            "totales_bytes": {
                "Soprano": 0,
                "Contralto": 0,
                "Tenor": 0,
                "Bajo": 0,
                "Ensamble": 0,
                "total": 0
            },
            "cantos": []
        },
        "en": {
            "total_alabanzas": 0,
            "totales_bytes": {
                "Soprano": 0,
                "Contralto": 0,
                "Tenor": 0,
                "Bajo": 0,
                "Ensamble": 0,
                "total": 0
            },
            "cantos": []
        }
    }
}

# 1. Procesar Español (123 alabanzas)
folders_es = sorted([d for d in os.listdir(ESP_DIR) if os.path.isdir(os.path.join(ESP_DIR, d))])
for folder in folders_es:
    fpath = os.path.join(ESP_DIR, folder)
    meta_path = os.path.join(fpath, "meta.json")
    meta = {}
    if os.path.exists(meta_path):
        with open(meta_path, "r", encoding="utf-8") as mf:
            meta = json.load(mf)
            
    canto_nombre = meta.get("canto") or re.sub(r"^\d+[\.\s_]+", "", folder)
    app_id = meta.get("app_id")
    if not app_id:
        c_match = cat_es_by_clean.get(clean_name(canto_nombre))
        if c_match:
            app_id = c_match["id"]
            
    mp3s = [f for f in os.listdir(fpath) if f.endswith(".mp3")]
    voces_canto = {}
    
    for m in mp3s:
        full_m = os.path.join(fpath, m)
        sz = os.path.getsize(full_m)
        voz_label = "Pista"
        for v in ["Soprano", "Contralto", "Tenor", "Bajo", "Ensamble"]:
            if v in m:
                voz_label = v
                break
                
        voces_canto[voz_label] = {
            "archivo": m,
            "size_bytes": sz,
            "r2_path": f"es/{folder}/{m}"
        }
        
        if voz_label in manifest["idiomas"]["es"]["totales_bytes"]:
            manifest["idiomas"]["es"]["totales_bytes"][voz_label] += sz
        manifest["idiomas"]["es"]["totales_bytes"]["total"] += sz
        
    manifest["idiomas"]["es"]["cantos"].append({
        "id": app_id,
        "canto": canto_nombre,
        "carpeta": folder,
        "fuente": meta.get("fuente"),
        "voces": voces_canto
    })

manifest["idiomas"]["es"]["total_alabanzas"] = len(manifest["idiomas"]["es"]["cantos"])

# 2. Procesar Inglés (250 alabanzas)
folders_en = sorted([d for d in os.listdir(ENG_DIR) if os.path.isdir(os.path.join(ENG_DIR, d))])
for folder in folders_en:
    fpath = os.path.join(ENG_DIR, folder)
    meta_path = os.path.join(fpath, "meta.json")
    meta = {}
    if os.path.exists(meta_path):
        with open(meta_path, "r", encoding="utf-8") as mf:
            meta = json.load(mf)
            
    canto_nombre = meta.get("canto") or re.sub(r"^\d+[\.\s_]+", "", folder)
    app_id = meta.get("app_id")
    if not app_id:
        c_match = cat_en_by_clean.get(clean_name(canto_nombre))
        if c_match:
            app_id = c_match["id"]
            
    mp3s = [f for f in os.listdir(fpath) if f.endswith(".mp3")]
    voces_canto = {}
    
    for m in mp3s:
        full_m = os.path.join(fpath, m)
        sz = os.path.getsize(full_m)
        voz_label = "Pista"
        for v in ["Soprano", "Contralto", "Tenor", "Bajo", "Ensamble"]:
            if v in m:
                voz_label = v
                break
                
        voces_canto[voz_label] = {
            "archivo": m,
            "size_bytes": sz,
            "r2_path": f"en/{folder}/{m}"
        }
        
        if voz_label in manifest["idiomas"]["en"]["totales_bytes"]:
            manifest["idiomas"]["en"]["totales_bytes"][voz_label] += sz
        manifest["idiomas"]["en"]["totales_bytes"]["total"] += sz
        
    manifest["idiomas"]["en"]["cantos"].append({
        "id": app_id,
        "canto": canto_nombre,
        "carpeta": folder,
        "fuente": "TLOTW Choir Studio",
        "voces": voces_canto
    })

manifest["idiomas"]["en"]["total_alabanzas"] = len(manifest["idiomas"]["en"]["cantos"])

# Guardar manifiesto en assets de Flutter, website y respaldo
for dest in [OUT_PATH_ASSETS, OUT_PATH_WEB, OUT_PATH_RESPALDO]:
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"Manifiesto guardado en: {dest}")

print("\n=== RESUMEN POR IDIOMA EN MANIFIESTO ===")
for lang in ["es", "en"]:
    data = manifest["idiomas"][lang]
    print(f"\nIdioma [{lang.upper()}]: {data['total_alabanzas']} alabanzas")
    for v, b in data["totales_bytes"].items():
        print(f"  - {v:<10}: {b / (1024**2):>7.1f} MB ({b / (1024**3):.2f} GB) [{b:,} bytes]")
