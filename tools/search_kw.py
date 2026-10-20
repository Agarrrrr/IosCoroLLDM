import os

search_words = ["saturado", "saturaci", "distorsion", "lector", "headroom", "fluidsynth"]
for root, dirs, files in os.walk("."):
    if any(x in root for x in [".git", "build", ".dart_tool"]):
        continue
    for f in files:
        if f.endswith((".dart", ".md", ".txt")):
            p = os.path.join(root, f)
            try:
                with open(p, "r", encoding="utf-8", errors="ignore") as fp:
                    txt = fp.read()
                    for sw in search_words:
                        if sw in txt.lower():
                            print(f'Found "{sw}" in {p}')
            except Exception:
                pass
