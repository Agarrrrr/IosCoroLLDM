import json

ind_path = r"E:\Respaldo\Voces Cantadas\indice_voces_cantadas.json"
with open(ind_path, "r", encoding="utf-8") as f:
    ind = json.load(f)

v10 = [x for x in ind if x.get("fuente") == "Con Todo Mi Ser Vol. 10"]
print(f"Total cantos de Con Todo Mi Ser Vol. 10 procesados: {len(v10)}")
for item in v10:
    print(f"{item['numero']}. {item['canto']} | Pistas ({item['total_voces']}): {item['voces_disponibles']}")
    print(f"   -> App: {item['app_nombre']} | PDF: {item['archivo_pdf']} | ID: {item['app_id']}\n")
