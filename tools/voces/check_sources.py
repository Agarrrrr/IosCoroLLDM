import os
import json

voces_dir = r"E:\Respaldo\Voces Cantadas"

# Check original source files for these songs
folders_to_check = [
    "54. Al Despertar por la Mañana",
    "67. Canten a Cristo Rey",
    "72. Con mis manos hacia el Cielo",
    "80. Dios os Guarde",
    "84. El libro de la Vida",
    "85. El Nombre del Señor",
    "93. Jehová te Bendiga",
    "98. La voz de muchos Ángeles",
    "102. Mi Jesús vendrá",
    "106. No es de Todos",
    "122. Santo es el Señor",
    "128. Te Loamos",
    "130. Un Ángel Bendito",
    "133. Un Gesto Divino",
    "137. Una Lumbrera",
    "140. Ven a la Fiesta"
]

for fld in folders_to_check:
    mpath = os.path.join(voces_dir, fld, "meta.json")
    if os.path.exists(mpath):
        with open(mpath, "r", encoding="utf-8") as f:
            m = json.load(f)
        print(f"=== {fld} ===")
        fuente = m.get("fuente")
        print(f"  Fuente: {fuente}")
        # Look at pistas in meta
        for p in m.get("pistas", []):
            print(f"  pista: {p.get('voz')} -> {p.get('archivo_destino')} (orig: {p.get('archivo_origen')})")
