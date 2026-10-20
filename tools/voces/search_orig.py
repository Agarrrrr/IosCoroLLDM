import os

vol_dirs = {
    1: r"E:\Respaldo\Cantos\CON TODO MI SER 1",
    3: r"E:\Respaldo\Cantos\CON TODO MI SER 3",
    4: r"E:\Respaldo\Cantos\CON TODO MI SER 4",
    5: r"E:\Respaldo\Cantos\Con todo mi ser 5",
    6: r"E:\Respaldo\Cantos\TODO MI SER 6",
    8: r"E:\Respaldo\Cantos\Con todo mi ser 8",
    9: r"E:\Respaldo\Cantos\Con todo mi ser 9",
    11: r"E:\Respaldo\Cantos\Con todo mi ser 11",
}

def search_files(vol_num, query):
    p = vol_dirs.get(vol_num)
    if not p or not os.path.exists(p):
        print(f"Path does not exist: {p}")
        return
    files = [f for f in os.listdir(p) if query.lower() in f.lower()]
    print(f"Vol {vol_num} query '{query}':")
    for f in sorted(files):
        print("  ", f)

search_files(9, "jehova")
search_files(6, "jesus")
search_files(8, "todos")
search_files(4, "angeles")
search_files(3, "canten")
search_files(5, "despertar")
search_files(11, "angel")
search_files(11, "gesto")
