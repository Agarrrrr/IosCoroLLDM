#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de Limpieza y Reclasificación Rigurosa de Voces Cantadas
1. Elimina pistas 5 / Música / Acompañamiento instrumental.
2. Reclasifica voces mal nombradas (Pista 1=Soprano, 2=Contralto, 3=Tenor, 4=Bajo).
3. Elimina pistas corruptas/incompletas con discrepancia extrema de duración (<60% de la mediana).
4. Actualiza meta.json e indice_voces_cantadas.json.
"""

import os
import json
import re
import subprocess
import statistics

FFMPEG_EXE = r"C:\Users\Huri_\AppData\Local\ffmpeg_bin\ffmpeg.exe"
VOCES_DIR = r"E:\Respaldo\Voces Cantadas"
INDICE_PATH = os.path.join(VOCES_DIR, "indice_voces_cantadas.json")

def get_duration(path):
    cmd = [FFMPEG_EXE, '-i', path]
    res = subprocess.run(cmd, stderr=subprocess.PIPE, stdout=subprocess.PIPE, text=True, errors='ignore')
    m = re.search(r'Duration:\s*(\d+):(\d+):(\d+\.\d+)', res.stderr)
    if m:
        return int(m.group(1))*3600 + int(m.group(2))*60 + float(m.group(3))
    return None

def main():
    print("=" * 80)
    print("Iniciando Limpieza y Reclasificación Rigurosa de Voces Cantadas")
    print("=" * 80)

    folders = sorted([d for d in os.listdir(VOCES_DIR) if os.path.isdir(os.path.join(VOCES_DIR, d))])
    
    total_musica_eliminadas = 0
    total_discrepantes_eliminadas = 0
    total_reclasificadas = 0

    for folder in folders:
        fpath = os.path.join(VOCES_DIR, folder)
        meta_path = os.path.join(fpath, "meta.json")
        if not os.path.exists(meta_path):
            continue

        with open(meta_path, "r", encoding="utf-8") as mf:
            meta = json.load(mf)

        canto = meta.get("canto", folder)
        # Extraer nombre base limpio
        # e.g. "01. Apocalipsis 14_6" -> "Apocalipsis 14_6"
        canto_safe = re.sub(r'^\d+[\.\s_]+', '', folder)
        
        # 1. PASO 1: Reclasificar voces en canciones de Con Todo Mi Ser con pistas genéricas
        # Volúmenes como 2, 6, 7 donde las pistas se llamaban Ensamble 2, Ensamble 3...
        pistas_meta = meta.get("pistas", [])
        
        # Detectar si este canto tiene pistas tipo "Ensamble 2", "Ensamble 3" o tracks numéricos de origen
        has_generic_ensambles = any("Ensamble 2" in p.get("archivo_destino", "") or "Ensamble 3" in p.get("archivo_destino", "") for p in pistas_meta)
        
        if has_generic_ensambles and len(pistas_meta) >= 4:
            # Reclasificar en orden canónico: 0=Soprano, 1=Contralto, 2=Tenor, 3=Bajo, 4=Musica
            canonical_voices = ["Soprano", "Contralto", "Tenor", "Bajo", "Musica"]
            for idx, p in enumerate(pistas_meta):
                new_v = canonical_voices[idx] if idx < len(canonical_voices) else "Pista Adicional"
                old_file = p["archivo_destino"]
                old_full = os.path.join(fpath, old_file)
                
                if new_v == "Musica":
                    # Marcar para eliminar
                    p["eliminar"] = True
                    p["motivo"] = "Pista 5 / Música instrumental"
                else:
                    new_file = f"{canto_safe} - {new_v}.mp3"
                    new_full = os.path.join(fpath, new_file)
                    if os.path.exists(old_full) and old_file != new_file:
                        if os.path.exists(new_full):
                            os.remove(new_full)
                        os.rename(old_full, new_full)
                        total_reclasificadas += 1
                    p["voz"] = new_v
                    p["archivo_destino"] = new_file

        # 2. PASO 2: Eliminar pistas que eran explícitamente "Musica" o Pista 5
        for p in pistas_meta:
            src_orig = p.get("archivo_origen", "").lower()
            dst_file = p.get("archivo_destino", "")
            dst_full = os.path.join(fpath, dst_file)
            
            # Criterios para identificar música instrumental:
            is_musica = False
            if "musica" in src_orig or "_musica" in src_orig or "pista 5" in src_orig:
                is_musica = True
            elif p.get("eliminar"):
                is_musica = True
            elif p.get("voz") == "Ensamble" and ("_5." in src_orig or "pista 5" in src_orig or "musica" in dst_file.lower()):
                is_musica = True
                
            if is_musica:
                if os.path.exists(dst_full):
                    os.remove(dst_full)
                    print(f"[{folder}] ELIMINADA PISTA MÚSICA: {dst_file} (Origen: {src_orig})")
                    total_musica_eliminadas += 1
                p["eliminada"] = True

        # Filtrar pistas que quedaron activas en disco
        current_mp3s = sorted([f for f in os.listdir(fpath) if f.endswith(".mp3")])
        
        # 3. PASO 3: Verificar duraciones y eliminar discrepancias extremas
        file_durs = {}
        for f in current_mp3s:
            d = get_duration(os.path.join(fpath, f))
            if d:
                file_durs[f] = d
                
        if len(file_durs) >= 2:
            med_dur = statistics.median(file_durs.values())
            for f, d in list(file_durs.items()):
                # Si dura menos del 65% de la mediana o la diferencia es > 25s
                if d < med_dur * 0.65 or abs(d - med_dur) > 25:
                    full_bad = os.path.join(fpath, f)
                    if os.path.exists(full_bad):
                        os.remove(full_bad)
                        print(f"[{folder}] ELIMINADA PISTA CORRUPTA / CORTADA: {f} (Dura {d:.1f}s vs Mediana {med_dur:.1f}s)")
                        total_discrepantes_eliminadas += 1
                        file_durs.pop(f, None)

        # 4. PASO 4: Actualizar meta.json del canto
        remaining_files = sorted([f for f in os.listdir(fpath) if f.endswith(".mp3")])
        nuevas_pistas = []
        for f in remaining_files:
            dur = file_durs.get(f) or get_duration(os.path.join(fpath, f))
            sz = os.path.getsize(os.path.join(fpath, f))
            # Extraer voz del nombre de archivo
            # Formato: "Nombre - Voz.mp3"
            m_voz = re.search(r'[-–]\s*([A-Za-z0-9\s]+)\.mp3$', f)
            voz_label = m_voz.group(1).strip() if m_voz else "Voz"
            nuevas_pistas.append({
                "voz": voz_label,
                "archivo_destino": f,
                "duracion_segundos": round(dur, 2) if dur else None,
                "tamano_bytes": sz
            })
            
        meta["total_voces"] = len(nuevas_pistas)
        meta["pistas"] = nuevas_pistas
        with open(meta_path, "w", encoding="utf-8") as mf:
            json.dump(meta, mf, indent=2, ensure_ascii=False)

    # 5. PASO 5: Regenerar indice_voces_cantadas.json
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
            "app_nombre": m.get("app_nombre")
        })

    with open(INDICE_PATH, "w", encoding="utf-8") as out:
        json.dump(nuevo_indice, out, indent=2, ensure_ascii=False)

    print("\n" + "=" * 80)
    print("PROCESO DE LIMPIEZA FINALIZADO:")
    print(f" - Pistas de música instrumental eliminadas: {total_musica_eliminadas}")
    print(f" - Pistas corruptas/cortadas eliminadas: {total_discrepantes_eliminadas}")
    print(f" - Pistas reclasificadas a su voz real (Soprano, Contralto, Tenor, Bajo): {total_reclasificadas}")
    print(f" - Índice maestro actualizado en: {INDICE_PATH}")
    print("=" * 80)

if __name__ == "__main__":
    main()
