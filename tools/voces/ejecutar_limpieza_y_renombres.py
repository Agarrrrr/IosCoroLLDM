import os
import shutil
import json
import re
import unicodedata
import subprocess

VOCES_DIR = r"E:\Respaldo\Voces Cantadas"
CAT_PATH = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\assets\catalogo.json"
FFMPEG_EXE = r"C:\Users\Huri_\AppData\Local\ffmpeg_bin\ffmpeg.exe"

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

# 1. DELETE THE 7 SONGS
folders_to_delete = [
    "95. La Canción será un Amén",
    "104. Mirad al Rey",
    "107. No hay Nada más Lindo y Hermoso",
    "115. Por tu Gran Amor",
    "116. Por un Apóstol",
    "127. Te Amamos oh Samuel",
    "132. Un Excelente Apóstol"
]

print("=== 1. ELIMINANDO 7 CANCIONES DESCARTADAS ===")
for fld in folders_to_delete:
    p = os.path.join(VOCES_DIR, fld)
    if os.path.exists(p):
        shutil.rmtree(p)
        print(f"  [ELIMINADA] Carpeta: {fld}")
    else:
        print(f"  [NO ENCONTRADA] {fld}")

# 2. RENAME / UPDATE THE 10 SONGS
renames = [
    ("55. Al Meditar", "El Año Que se va"),
    ("65. Bautizados fueron todos los Creyentes", "Bautizados Fueron Todos"),
    ("74. Cual Manada", "Cual Manada de Ovejas"),
    ("89. Eres como los Cedros", "Eres Como Cedros"),
    ("93. Jehová te Bendiga", "Jehova te bendiga y te guarde"),
    ("108. No se ha dicho aún la Mitad", "Del Celeste Pais"),
    ("111. Oh Cuán Santa es la Unión", "Una Vida Feliz"),
    ("125. Si Callare", "Si Callare Tus Maravillas"),
    ("126. Somos Cartas", "Somos Cartas Leídas"),
    ("141. Venid Venid", "Venid, Venid Cantad la Bella Historia")
]

print("\n=== 2. RENOMBRANDO Y ENLAZANDO 10 CANCIONES ===")
for old_folder_name, new_title in renames:
    old_path = os.path.join(VOCES_DIR, old_folder_name)
    if not os.path.exists(old_path):
        print(f"  [ERROR] No existe {old_path}")
        continue
        
    # Get number prefix e.g. "55. "
    m = re.match(r"^(\d+\.\s*)", old_folder_name)
    prefix = m.group(1) if m else ""
    # Safe folder name
    safe_title = re.sub(r'[\\/*?:"<>|]', "", new_title)
    new_folder_name = f"{prefix}{safe_title}"
    new_path = os.path.join(VOCES_DIR, new_folder_name)
    
    # Rename directory
    if old_path != new_path:
        os.rename(old_path, new_path)
        print(f"  [CARPETA RENOMBRADA] {old_folder_name} -> {new_folder_name}")
        
    # Find in catalog
    cat_entry = cat_by_clean.get(clean_str(new_title))
    if not cat_entry:
        # try partial match
        for ck, cv in cat_by_clean.items():
            if clean_str(new_title) in ck or ck in clean_str(new_title):
                cat_entry = cv
                break
                
    if not cat_entry:
        print(f"  [ALERTA] No se encontró entrada de catálogo para '{new_title}'")
        
    # Now rename internal mp3 files
    mp3s = [f for f in os.listdir(new_path) if f.endswith(".mp3")]
    new_pistas = []
    for mp3 in mp3s:
        # Extract voice name
        # pattern: "Old Title - Voice.mp3"
        m_voz = re.search(r'[-–]\s*([A-Za-z0-9\s]+)\.mp3$', mp3)
        voz = m_voz.group(1).strip() if m_voz else "Voz"
        new_mp3_name = f"{safe_title} - {voz}.mp3"
        
        old_mp3_path = os.path.join(new_path, mp3)
        new_mp3_path = os.path.join(new_path, new_mp3_name)
        if old_mp3_path != new_mp3_path:
            if os.path.exists(new_mp3_path):
                os.remove(new_mp3_path)
            os.rename(old_mp3_path, new_mp3_path)
            
        # Update ID3 tags
        cmd = [
            FFMPEG_EXE, "-y", "-i", new_mp3_path,
            "-c", "copy",
            "-metadata", f"title={new_title} - {voz}",
            "-metadata", "artist=Coro LLDM",
            os.path.join(new_path, "temp_" + new_mp3_name)
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.returncode == 0:
            temp_p = os.path.join(new_path, "temp_" + new_mp3_name)
            os.remove(new_mp3_path)
            os.rename(temp_p, new_mp3_path)
            
        sz = os.path.getsize(new_mp3_path)
        new_pistas.append({
            "voz": voz,
            "archivo_destino": new_mp3_name,
            "tamano_bytes": sz
        })
        
    # Update meta.json
    meta_file = os.path.join(new_path, "meta.json")
    meta = {}
    if os.path.exists(meta_file):
        with open(meta_file, "r", encoding="utf-8") as mf:
            meta = json.load(mf)
            
    meta["canto"] = new_title
    meta["carpeta"] = new_folder_name
    meta["en_catalogo_app"] = True if cat_entry else False
    if cat_entry:
        meta["app_id"] = cat_entry.get("id")
        meta["app_nombre"] = cat_entry.get("nombre")
        meta["archivo_pdf"] = cat_entry.get("archivo")
        meta["temas"] = cat_entry.get("temas", [])
    meta["pistas"] = new_pistas
    meta["total_voces"] = len(new_pistas)
    
    with open(meta_file, "w", encoding="utf-8") as mf:
        json.dump(meta, mf, indent=2, ensure_ascii=False)
        
    print(f"  [META ACTUALIZADO] {new_folder_name}: app_id={meta.get('app_id')}, app_nombre='{meta.get('app_nombre')}'")

print("\nOperación completada exitosamente.")
