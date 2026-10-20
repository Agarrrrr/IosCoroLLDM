#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Procesador de las 8 canciones confirmadas de Con Todo Mi Ser Vol. 10
"""

import os
import shutil
import json
import re
import subprocess

FFMPEG_EXE = r"C:\Users\Huri_\AppData\Local\ffmpeg_bin\ffmpeg.exe"
VOL10_SRC = r"E:\Respaldo\Cantos\CON TODO MI SER 10"
VOCES_DIR = r"E:\Respaldo\Voces Cantadas"
INDICE_PATH = os.path.join(VOCES_DIR, "indice_voces_cantadas.json")

# Catalog paths
CATALOGO_ASSETS = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\assets\catalogo.json"
CATALOGO_OFFLINE = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\assets\offline_assets\catalogo.json"
CATALOGO_WEB = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\website\public\catalogo.json"

PDF_SRC = r"C:\Users\Huri_\Downloads\Hay_un_lugar_CARTA.pdf"
PDF_DST_ASSETS = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\assets\offline_assets\pdfs\hay_un_lugar.pdf"
PDF_DST_RESPALDO = r"E:\Respaldo\offline_assets\pdfs\hay_un_lugar.pdf"

# 1. Copiar PDF de Hay un Lugar si existe
if os.path.exists(PDF_SRC):
    os.makedirs(os.path.dirname(PDF_DST_ASSETS), exist_ok=True)
    shutil.copy2(PDF_SRC, PDF_DST_ASSETS)
    print(f"Copiado PDF a: {PDF_DST_ASSETS}")
    if os.path.exists(os.path.dirname(PDF_DST_RESPALDO)):
        shutil.copy2(PDF_SRC, PDF_DST_RESPALDO)
        print(f"Copiado PDF a: {PDF_DST_RESPALDO}")

# 2. Registrar en catálogos 'Hay un Lugar'
hay_un_lugar_entry = {
    "id": "hay_un_lugar_vol10",
    "nombre": "Hay un Lugar",
    "archivo": "hay_un_lugar.pdf",
    "temas": ["Esperanza"],
    "es_privado": False,
    "_idioma": "es",
    "idioma": "es"
}

for cat_path in [CATALOGO_ASSETS, CATALOGO_OFFLINE, CATALOGO_WEB]:
    if os.path.exists(cat_path):
        with open(cat_path, "r", encoding="utf-8") as f:
            cat_data = json.load(f)
        # Check if already exists
        if not any(c.get("id") == "hay_un_lugar_vol10" or c.get("nombre") == "Hay un Lugar" for c in cat_data):
            cat_data.append(hay_un_lugar_entry)
            with open(cat_path, "w", encoding="utf-8") as f:
                json.dump(cat_data, f, indent=2, ensure_ascii=False)
            print(f"Añadido 'Hay un Lugar' a {cat_path}")

# Cargar catálogo actualizado
with open(CATALOGO_ASSETS, "r", encoding="utf-8") as f:
    catalogo = json.load(f)

def find_in_cat(name):
    clean_n = re.sub(r"[^a-z0-9]", "", name.lower())
    for c in catalogo:
        c_clean = re.sub(r"[^a-z0-9]", "", c.get("nombre", "").lower())
        if clean_n == c_clean:
            return c
    for c in catalogo:
        c_clean = re.sub(r"[^a-z0-9]", "", c.get("nombre", "").lower())
        if clean_n in c_clean or c_clean in clean_n:
            return c
    return None

def get_duration(path):
    cmd = [FFMPEG_EXE, "-i", path]
    res = subprocess.run(cmd, stderr=subprocess.PIPE, stdout=subprocess.PIPE, text=True, errors="ignore")
    m = re.search(r"Duration:\s*(\d+):(\d+):(\d+\.\d+)", res.stderr)
    if m:
        return int(m.group(1))*3600 + int(m.group(2))*60 + float(m.group(3))
    return None

# Las 8 canciones de Vol 10
CANCIONES_VOL10 = [
    {
        "num": 142,
        "canto": "El que habita al abrigo de Dios",
        "tracks": [1, 2, 3, 4, 5]
    },
    {
        "num": 143,
        "canto": "Grato es contar la historia",
        "tracks": [11, 12, 13, 14, 15]
    },
    {
        "num": 144,
        "canto": "Hay un Lugar",
        "tracks": [16, 17, 18, 19, 20]
    },
    {
        "num": 145,
        "canto": "La luz que llegó a mi alma",
        "tracks": [21, 22, 23, 24, 25]
    },
    {
        "num": 146,
        "canto": "La tumba le encerró",
        "tracks": [26, 27, 28, 29, 30]
    },
    {
        "num": 147,
        "canto": "Oh bondad tan infinita",
        "tracks": [31, 32, 33, 34, 35]
    },
    {
        "num": 148,
        "canto": "Oh Que Gran Amor",
        "tracks": [36, 37, 38, 39, 40]
    },
    {
        "num": 149,
        "canto": "Si no hubiera Dios",
        "tracks": [51, 52, 53, 54, 55]
    }
]

VOICES_ORDER = ["Soprano", "Contralto", "Tenor", "Bajo", "Ensamble"]

print("\n=== PROCESANDO CANCIONES DE VOLUMEN 10 ===")
for item in CANCIONES_VOL10:
    num = item["num"]
    canto = item["canto"]
    safe_canto = re.sub(r'[\\/*?:"<>|]', "", canto)
    folder_name = f"{num}. {safe_canto}"
    dest_dir = os.path.join(VOCES_DIR, folder_name)
    os.makedirs(dest_dir, exist_ok=True)
    
    cat_match = find_in_cat(canto)
    pistas_meta = []
    
    for idx, track_num in enumerate(item["tracks"]):
        voz = VOICES_ORDER[idx]
        src_file = os.path.join(VOL10_SRC, f"{track_num:02d} Pista {track_num:02d}.mp3")
        dst_filename = f"{safe_canto} - {voz}.mp3"
        dst_file = os.path.join(dest_dir, dst_filename)
        
        # Convertir / etiquetar con ffmpeg
        cmd = [
            FFMPEG_EXE, "-y",
            "-i", src_file,
            "-vn",
            "-c:a", "libmp3lame",
            "-b:a", "192k",
            "-metadata", f"title={canto} - {voz}",
            "-metadata", "artist=Coro LLDM",
            "-metadata", "album=Con Todo Mi Ser Vol. 10",
            "-metadata", "genre=Coral",
            dst_file
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.returncode != 0:
            print(f"Error procesando {src_file}: {res.stderr.decode('utf-8', errors='ignore')}")
            continue
            
        dur = get_duration(dst_file)
        sz = os.path.getsize(dst_file)
        pistas_meta.append({
            "voz": voz,
            "archivo_destino": dst_filename,
            "duracion_segundos": round(dur, 2) if dur else None,
            "tamano_bytes": sz
        })
        
    meta_data = {
        "numero": num,
        "canto": canto,
        "carpeta": folder_name,
        "fuente": "Con Todo Mi Ser Vol. 10",
        "en_catalogo_app": True if cat_match else False,
        "app_id": cat_match.get("id") if cat_match else None,
        "app_nombre": cat_match.get("nombre") if cat_match else canto,
        "archivo_pdf": cat_match.get("archivo") if cat_match else None,
        "temas": cat_match.get("temas", []) if cat_match else [],
        "total_voces": len(pistas_meta),
        "pistas": pistas_meta
    }
    
    meta_path = os.path.join(dest_dir, "meta.json")
    with open(meta_path, "w", encoding="utf-8") as mf:
        json.dump(meta_data, mf, indent=2, ensure_ascii=False)
        
    print(f"  [OK] {folder_name} (5 pistas: Soprano, Contralto, Tenor, Bajo, Ensamble) -> App: {meta_data['app_nombre']} ({meta_data['archivo_pdf']})")

# 3. Regenerar índice general
print("\n=== REGENERANDO ÍNDICE MAESTRO ===")
folders = sorted([d for d in os.listdir(VOCES_DIR) if os.path.isdir(os.path.join(VOCES_DIR, d))])
nuevo_indice = []
for folder in folders:
    fpath = os.path.join(VOCES_DIR, folder)
    meta_path = os.path.join(fpath, "meta.json")
    if not os.path.exists(meta_path):
        continue
    with open(meta_path, "r", encoding="utf-8") as mf:
        m = json.load(mf)
    nuevo_indice.append({
        "numero": m.get("numero"),
        "canto": m.get("canto"),
        "carpeta": folder,
        "fuente": m.get("fuente"),
        "total_voces": len(m.get("pistas", [])),
        "voces_disponibles": [p["voz"] for p in m.get("pistas", [])],
        "en_catalogo_app": m.get("en_catalogo_app"),
        "app_id": m.get("app_id"),
        "app_nombre": m.get("app_nombre"),
        "archivo_pdf": m.get("archivo_pdf")
    })

with open(INDICE_PATH, "w", encoding="utf-8") as out:
    json.dump(nuevo_indice, out, indent=2, ensure_ascii=False)

print(f"Índice actualizado en {INDICE_PATH} con {len(nuevo_indice)} cantos en total.")
