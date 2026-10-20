#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Procesador de Voces Cantadas de 'Con Todo Mi Ser' (Volúmenes 1 al 12)
Convierte y organiza las 88 alabanzas exclusivas de Con Todo Mi Ser
en la carpeta unificada 'E:\\Respaldo\\Voces Cantadas' continuando desde el número 54 al 141.
"""

import os
import sys
import json
import re
import unicodedata
import subprocess
import time

FFMPEG_EXE = r"C:\Users\Huri_\AppData\Local\ffmpeg_bin\ffmpeg.exe"
BASE_DIR = r"E:\Respaldo\Voces Cantadas"
INDICE_PATH = os.path.join(BASE_DIR, "indice_voces_cantadas.json")
CATALOGO_APP_PATH = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\website\public\catalogo.json"

VOL_PATHS = {
    1: r"E:\Respaldo\Cantos\CON TODO MI SER 1",
    2: r"E:\Respaldo\Cantos\CON TODO MI SER 2",
    3: r"E:\Respaldo\Cantos\CON TODO MI SER 3",
    4: r"E:\Respaldo\Cantos\CON TODO MI SER 4",
    5: r"E:\Respaldo\Cantos\Con todo mi ser 5",
    6: r"E:\Respaldo\Cantos\TODO MI SER 6",
    7: r"E:\Respaldo\Cantos\TODO MI SER 7",
    8: r"E:\Respaldo\Cantos\Con todo mi ser 8",
    9: r"E:\Respaldo\Cantos\Con todo mi ser 9",
    11: r"E:\Respaldo\Cantos\Con todo mi ser 11",
    12: r"E:\Respaldo\Cantos\CON TODO MI SER 12",
}

def clean_str(text):
    if not text:
        return ""
    text = unicodedata.normalize('NFKD', text)
    text = ''.join(c for c in text if not unicodedata.combining(c))
    text = text.lower()
    text = re.sub(r'[^a-z0-9]', ' ', text)
    return re.sub(r'\s+', ' ', text).strip()

def sanitize_filename(name):
    # Reemplazar caracteres no permitidos en nombres de archivo
    name = re.sub(r'[\\/*?:"<>|]', '_', name)
    return name.strip()

def detect_voice(fname, idx_in_song=None):
    fn = fname.lower()
    
    # 1. Por palabras clave explícitas
    if any(w in fn for w in ["primera", "1a", "soprano", "sop"]):
        return "Soprano"
    if any(w in fn for w in ["segunda", "2a", "contralto", "alto"]):
        return "Contralto"
    if "tenor" in fn:
        if "tenor 2" in fn or "tenor_2" in fn:
            return "Tenor 2"
        return "Tenor"
    if "bajo" in fn:
        return "Bajo"
    if any(w in fn for w in ["musica", "pista", "voces", "general", "final", "ensamble"]):
        return "Ensamble"
        
    # 2. Por sufijo numérico (_1, _2, _3, _4, _5)
    m = re.search(r'[_ -]+([1-5])\.(?:mp3|wma|m4a)$', fn)
    if m:
        n = int(m.group(1))
        mapping = {1: "Soprano", 2: "Contralto", 3: "Tenor", 4: "Bajo", 5: "Ensamble"}
        return mapping[n]
        
    # 3. Por posición relativa en el set de pistas
    if idx_in_song is not None:
        mapping = {0: "Soprano", 1: "Contralto", 2: "Tenor", 3: "Bajo", 4: "Ensamble"}
        return mapping.get(idx_in_song, "Pista Adicional")
        
    return "Pista"

def convertir_audio(src_path, dst_path, canto_nombre, voz_nombre, vol_num):
    cmd = [
        FFMPEG_EXE,
        "-y",
        "-i", src_path,
        "-vn",
        "-c:a", "libmp3lame",
        "-b:a", "192k",
        "-metadata", f"title={canto_nombre} - {voz_nombre}",
        "-metadata", "artist=Coro LLDM",
        "-metadata", f"album=Con Todo Mi Ser Vol. {vol_num}",
        "-metadata", "genre=Coral",
        dst_path
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.returncode != 0:
        err = res.stderr.decode("utf-8", errors="ignore")
        raise RuntimeError(f"FFmpeg error: {err}")

def main():
    print("=" * 80)
    print("Iniciando Procesamiento de Voces Cantadas: Con Todo Mi Ser")
    print("=" * 80)

    # 1. Cargar catálogo de la app
    with open(CATALOGO_APP_PATH, "r", encoding="utf-8") as f:
        catalogo = json.load(f)

    cat_dict = {}
    for c in catalogo:
        cat_dict[clean_str(c["nombre"])] = c

    def match_app(canto_name):
        cn = clean_str(canto_name)
        if cn in cat_dict:
            return cat_dict[cn]
        for k, v in cat_dict.items():
            if cn == k or (len(cn) > 4 and (cn in k or k in cn)):
                return v
        return None

    # 2. Cargar mapeo final verificado
    mapping_path = r"C:\Users\Huri_\.gemini\antigravity\brain\276789a5-7098-42ba-8a46-61eb8c6a9d65\scratch\ctms_86_final_map.json"
    with open(mapping_path, "r", encoding="utf-8") as f:
        songs = json.load(f)

    # Ajuste para Aleluya al Cordero de Dios en Vol 12
    for s in songs:
        if s["canto"] == "Aleluya al Cordero de Dios":
            s["archivos"] = [
                "01_Aleluya_al_Corder_de_Dios_PRIMERA.mp3",
                "02_Aleluya_al_Corder_de_Dios_SEGUNDA.mp3",
                "03_Aleluya_al_Corder_de_Dios_TENOR.mp3",
                "04_Aleluya_al_Corder_de_Dios_BAJO.mp3",
                "01_Aleluya_al_Cordero_de_Dios_VOCES.mp3"
            ]

    # Ordenar alfabéticamente los 88 cantos para una numeración limpia
    songs = sorted(songs, key=lambda x: clean_str(x["canto"]))

    # 3. Cargar índice existente para continuar numeración desde 54
    with open(INDICE_PATH, "r", encoding="utf-8") as f:
        indice = json.load(f)

    start_num = len(indice) + 1
    print(f"Pistas previas en índice: {len(indice)}. Iniciando desde #{start_num}...")

    total_convertidos = 0
    total_errores = 0

    for i, s in enumerate(songs, start=start_num):
        canto = s["canto"]
        vol_num = s["volumen"]
        src_dir = VOL_PATHS[vol_num]
        flist = s["archivos"]

        # Carpeta destino
        canto_folder_safe = sanitize_filename(canto)
        folder_name = f"{i:02d}. {canto_folder_safe}"
        dest_folder = os.path.join(BASE_DIR, folder_name)
        os.makedirs(dest_folder, exist_ok=True)

        app_info = match_app(canto)
        en_app = app_info is not None

        print(f"\n[{i-start_num+1}/{len(songs)}] #{i}: {canto} (Vol. {vol_num}) -> {folder_name}", flush=True)

        pistas_meta = []
        canto_safe = sanitize_filename(canto)

        # Para evitar colisiones de nombre si hay varias pistas del mismo tipo
        voces_usadas = {}

        for idx, src_file in enumerate(flist):
            voz = detect_voice(src_file, idx)
            if voz in voces_usadas:
                voces_usadas[voz] += 1
                voz_label = f"{voz} {voces_usadas[voz]}"
            else:
                voces_usadas[voz] = 1
                voz_label = voz

            dest_filename = f"{canto_safe} - {voz_label}.mp3"
            src_full = os.path.join(src_dir, src_file)
            dest_full = os.path.join(dest_folder, dest_filename)

            # Convertir si no existe o es muy pequeño
            if not os.path.exists(dest_full) or os.path.getsize(dest_full) < 10000:
                try:
                    convertir_audio(src_full, dest_full, canto, voz_label, vol_num)
                    sz_mb = os.path.getsize(dest_full) / (1024 * 1024)
                    print(f"  [OK] {voz_label:<12} -> {dest_filename} ({sz_mb:.2f} MB)", flush=True)
                    total_convertidos += 1
                except Exception as e:
                    print(f"  [ERROR] {voz_label:<12} ({src_file}): {e}", flush=True)
                    total_errores += 1
            else:
                sz_mb = os.path.getsize(dest_full) / (1024 * 1024)
                print(f"  [EXISTE] {voz_label:<12} -> {dest_filename} ({sz_mb:.2f} MB)", flush=True)

            pistas_meta.append({
                "voz": voz_label,
                "archivo_destino": dest_filename,
                "archivo_origen": src_file,
                "volumen_origen": vol_num,
                "tamano_bytes": os.path.getsize(dest_full) if os.path.exists(dest_full) else 0
            })

        # Generar meta.json del canto
        meta_dict = {
            "numero": i,
            "canto": canto,
            "carpeta": folder_name,
            "fuente": f"Con Todo Mi Ser Vol. {vol_num}",
            "en_catalogo_app": en_app,
            "total_voces": len(pistas_meta),
            "pistas": pistas_meta
        }
        if app_info:
            meta_dict["app_id"] = app_info.get("id")
            meta_dict["app_nombre"] = app_info.get("nombre")
            meta_dict["archivo_pdf"] = app_info.get("archivo")
            meta_dict["midi_archivo"] = app_info.get("midi_archivo")
            meta_dict["temas"] = app_info.get("temas", [])

        with open(os.path.join(dest_folder, "meta.json"), "w", encoding="utf-8") as mf:
            json.dump(meta_dict, mf, indent=2, ensure_ascii=False)

        # Agregar al índice general
        indice_item = {
            "numero": i,
            "canto": canto,
            "carpeta": folder_name,
            "fuente": f"Con Todo Mi Ser Vol. {vol_num}",
            "total_pistas": len(pistas_meta),
            "en_catalogo_app": en_app
        }
        if app_info:
            indice_item["app_id"] = app_info.get("id")
            indice_item["app_nombre"] = app_info.get("nombre")

        indice.append(indice_item)

    # 4. Guardar índice general actualizado
    with open(INDICE_PATH, "w", encoding="utf-8") as f:
        json.dump(indice, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 80)
    print(f"Procesamiento Finalizado con Éxito:")
    print(f" - Cantos procesados: {len(songs)}")
    print(f" - Pistas convertidas: {total_convertidos}")
    print(f" - Errores: {total_errores}")
    print(f" - Total acumulado en índice español: {len(indice)} cantos")
    print(f" - Índice actualizado en: {INDICE_PATH}")
    print("=" * 80)

if __name__ == "__main__":
    main()
