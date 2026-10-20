#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Descargador y Gestor de Voces Cantadas para Coro LLDM
Descarga y procesa pistas vocales individuales (Soprano, Contralto, Tenor, Bajo, Ensamble)
desde YouTube (@VPEC-LLDM.), eliminando títulos ruidosos y organizándolas por canto.
"""

import os
import sys
import json
import time
import argparse
import subprocess
import unicodedata
import re

FFMPEG_EXE = r"C:\Users\Huri_\AppData\Local\ffmpeg_bin\ffmpeg.exe"
BASE_DIR = r"E:\Respaldo\Voces Cantadas"
INDICE_PATH = os.path.join(BASE_DIR, "indice_voces_cantadas.json")

def clean_str(text):
    if not text:
        return ""
    text = unicodedata.normalize('NFKD', text)
    text = ''.join(c for c in text if not unicodedata.combining(c))
    text = text.lower()
    text = re.sub(r'[^a-z0-9]', '', text)
    return text

def cargar_indice():
    if not os.path.exists(INDICE_PATH):
        print(f"Error: No se encontró el índice en {INDICE_PATH}", flush=True)
        sys.exit(1)
    with open(INDICE_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def status_cantos():
    indice = cargar_indice()
    print("=" * 95, flush=True)
    print(f"{'#':<3} | {'Canto':<28} | {'Carpeta':<30} | {'Estado / Voces'}", flush=True)
    print("=" * 95, flush=True)
    
    total_descargados = 0
    total_esperados = 0
    cantos_completos = 0
    
    for item in indice:
        num = item["numero"]
        canto = item["canto"]
        carpeta = item["carpeta"]
        folder_path = os.path.join(BASE_DIR, carpeta)
        meta_path = os.path.join(folder_path, "meta.json")
        
        if not os.path.exists(meta_path):
            continue
            
        with open(meta_path, "r", encoding="utf-8") as mf:
            meta = json.load(mf)
            
        pistas = meta.get("pistas", [])
        total_esperados += len(pistas)
        
        descargadas = []
        for p in pistas:
            dest = os.path.join(folder_path, p["archivo_destino"])
            if os.path.exists(dest) and os.path.getsize(dest) > 100000:
                descargadas.append(f"{p['voz']}")
                total_descargados += 1
                
        if len(descargadas) == len(pistas) and len(pistas) > 0:
            cantos_completos += 1
            status_str = f"COMPLETO [{', '.join(descargadas)}]"
        elif descargadas:
            status_str = f"PARCIAL ({len(descargadas)}/{len(pistas)}): {', '.join(descargadas)}"
        else:
            status_str = "Pendiente"
            
        print(f"{num:<3} | {canto[:26]:<28} | {carpeta[:28]:<30} | {status_str}", flush=True)
        
    print("=" * 95, flush=True)
    print(f"Resumen: {cantos_completos}/{len(indice)} cantos completos | {total_descargados}/{total_esperados} pistas listas.", flush=True)
    print("=" * 95, flush=True)

def descargar_pista(youtube_url, destino_path, canto_nombre, voz_nombre):
    import yt_dlp
    
    folder = os.path.dirname(destino_path)
    temp_tmpl = os.path.join(folder, f"_temp_{re.sub(r'[^a-zA-Z0-9]', '_', voz_nombre)}.%(ext)s")
    
    ydl_opts = {
        'format': '140/bestaudio/18/best',
        'outtmpl': temp_tmpl,
        'extractor_args': {
            'youtube': {
                'player_client': ['android', 'web']
            }
        },
        'quiet': True,
        'no_warnings': True,
    }
        
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(youtube_url, download=True)
        downloaded_file = ydl.prepare_filename(info)
        
    if not os.path.exists(downloaded_file):
        raise FileNotFoundError(f"No se pudo descargar el archivo temporal de {youtube_url}")
        
    # Convertir a MP3 usando FFmpeg
    cmd = [
        FFMPEG_EXE,
        "-y",
        "-i", downloaded_file,
        "-vn",
        "-c:a", "libmp3lame",
        "-b:a", "192k",
        "-metadata", f"title={canto_nombre} - {voz_nombre}",
        "-metadata", f"artist=Coro LLDM",
        "-metadata", f"album=Voces de Estudio",
        "-metadata", f"genre=Coral",
        destino_path
    ]
    
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    
    # Limpiar archivo temporal
    if os.path.exists(downloaded_file):
        try:
            os.remove(downloaded_file)
        except Exception:
            pass
            
    if res.returncode != 0:
        raise RuntimeError(f"FFmpeg error: {res.stderr.decode('utf-8', errors='ignore')}")

def descargar_canto(item, progreso_global=None):
    num = item["numero"]
    canto = item["canto"]
    carpeta = item["carpeta"]
    folder_path = os.path.join(BASE_DIR, carpeta)
    meta_path = os.path.join(folder_path, "meta.json")
    
    with open(meta_path, "r", encoding="utf-8") as mf:
        meta = json.load(mf)
        
    pistas = meta.get("pistas", [])
    print(f"\n=======================================================", flush=True)
    if progreso_global:
        print(f">>> [{progreso_global[0]}/{progreso_global[1]}] Canto #{num}: {canto} ({len(pistas)} voces)", flush=True)
    else:
        print(f">>> Canto #{num}: {canto} ({len(pistas)} voces)", flush=True)
    print(f"=======================================================", flush=True)
    
    for p in pistas:
        dest = os.path.join(folder_path, p["archivo_destino"])
        if os.path.exists(dest) and os.path.getsize(dest) > 100000:
            print(f"  [YA EXISTE] {p['voz']}: {p['archivo_destino']} ({os.path.getsize(dest)/1024/1024:.2f} MB)", flush=True)
            continue
            
        print(f"  [DESCARGANDO] {p['voz']} -> {p['youtube_url']}...", flush=True)
        try:
            descargar_pista(p["youtube_url"], dest, canto, p["voz"])
            if os.path.exists(dest):
                print(f"  [OK] Guardado: {p['archivo_destino']} ({os.path.getsize(dest)/1024/1024:.2f} MB)", flush=True)
            else:
                print(f"  [AVISO] Verificado proceso para {p['archivo_destino']}", flush=True)
            # Pequeña pausa de cortesía para evitar saturar YouTube
            time.sleep(0.5)
        except Exception as e:
            print(f"  [ERROR] {p['voz']}: {e}", flush=True)

def main():
    parser = argparse.ArgumentParser(description="Descargador de Voces Cantadas para Coro LLDM")
    parser.add_argument("--status", action="store_true", help="Mostrar estado de descargas")
    parser.add_argument("--canto", type=str, help="Número (1-48) o nombre del canto a descargar")
    parser.add_argument("--todos", action="store_true", help="Descargar todas las pistas de los 48 cantos")
    args = parser.parse_args()
    
    indice = cargar_indice()
    
    if args.status or (not args.canto and not args.todos):
        status_cantos()
        return
        
    if args.todos:
        total_cantos = len(indice)
        for i, item in enumerate(indice, 1):
            descargar_canto(item, progreso_global=(i, total_cantos))
        print("\n¡Descarga masiva de todos los cantos finalizada!", flush=True)
        status_cantos()
        return
        
    if args.canto:
        c_val = args.canto.strip()
        target_item = None
        if c_val.isdigit():
            num = int(c_val)
            for item in indice:
                if item["numero"] == num:
                    target_item = item
                    break
        else:
            q = clean_str(c_val)
            for item in indice:
                if q in clean_str(item["canto"]):
                    target_item = item
                    break
                    
        if not target_item:
            print(f"No se encontró ningún canto con: '{args.canto}'", flush=True)
            return
            
        descargar_canto(target_item)
        print(f"\n¡Canto #{target_item['numero']} completado con éxito!", flush=True)

if __name__ == "__main__":
    main()
