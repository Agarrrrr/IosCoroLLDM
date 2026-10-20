import os
import json

esp_dir = r"E:\Respaldo\Voces Cantadas"
folders = sorted([d for d in os.listdir(esp_dir) if os.path.isdir(os.path.join(esp_dir, d))])

strictly_incomplete = []
for f in folders:
    p = os.path.join(esp_dir, f)
    mp3s = [x for x in os.listdir(p) if x.endswith(".mp3")]
    voices = set()
    for m in mp3s:
        for v in ["Soprano", "Contralto", "Tenor", "Bajo"]:
            if v in m:
                voices.add(v)
    # Check if missing any of SATB
    missing = {"Soprano", "Contralto", "Tenor", "Bajo"} - voices
    if missing:
        meta_p = os.path.join(p, "meta.json")
        src = "Desconocida"
        if os.path.exists(meta_p):
            with open(meta_p, "r", encoding="utf-8") as mf:
                src = json.load(mf).get("fuente", "Desconocida")
        strictly_incomplete.append((f, len(mp3s), sorted(list(voices)), sorted(list(missing)), src))

print(f"Total carpetas estrictamente incompletas (< 4 voces SATB): {len(strictly_incomplete)}")
for f, n, has_v, miss_v, src in strictly_incomplete:
    print(f"• {f}")
    print(f"    Tiene {n} pistas: {has_v}")
    print(f"    Falta: {miss_v} (Fuente: {src})\n")
