import os
import shutil
import json

esp_dir = r"E:\Respaldo\Voces Cantadas"
indice_path = os.path.join(esp_dir, "indice_voces_cantadas.json")

folders_to_delete = [
    "54. Al Despertar por la Mañana",
    "55. El Año Que se va",
    "56. Al Sonar de la Trompeta",
    "67. Canten a Cristo Rey",
    "72. Con mis manos hacia el Cielo",
    "80. Dios os Guarde",
    "84. El libro de la Vida",
    "85. El Nombre del Señor",
    "93. Jehova te bendiga y te guarde",
    "98. La voz de muchos Ángeles",
    "102. Mi Jesús vendrá",
    "106. No es de Todos",
    "108. Del Celeste Pais",
    "122. Santo es el Señor",
    "128. Te Loamos",
    "130. Un Ángel Bendito",
    "133. Un Gesto Divino",
    "137. Una Lumbrera",
    "140. Ven a la Fiesta"
]

print("=== ELIMINANDO 19 CARPETAS INCOMPLETAS EN ESPAÑOL ===")
deleted_count = 0
for f in folders_to_delete:
    p = os.path.join(esp_dir, f)
    if os.path.exists(p):
        shutil.rmtree(p)
        print(f"  [BORRADA] {f}")
        deleted_count += 1
    else:
        print(f"  [NO EXISTE] {f}")

print(f"\nTotal eliminadas: {deleted_count}")

# Regenerar índice maestro
folders_remaining = sorted([d for d in os.listdir(esp_dir) if os.path.isdir(os.path.join(esp_dir, d))])
nuevo_indice = []
for folder in folders_remaining:
    fpath = os.path.join(esp_dir, folder)
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

with open(indice_path, "w", encoding="utf-8") as out:
    json.dump(nuevo_indice, out, indent=2, ensure_ascii=False)

print(f"Nuevo total en índice español: {len(nuevo_indice)} alabanzas.")
