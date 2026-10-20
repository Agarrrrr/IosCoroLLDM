from PIL import Image
import numpy as np
import potrace
import os

img_path = r"C:/Users/Huri_/.gemini/antigravity/brain/276789a5-7098-42ba-8a46-61eb8c6a9d65/.user_uploaded/media_1792457331852_401c98c8.png"
out_svg_assets = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\assets\icons\human_singing.svg"
os.makedirs(os.path.dirname(out_svg_assets), exist_ok=True)

img = Image.open(img_path).convert("L")
arr = np.array(img)
binary = (arr < 128)

bmp = potrace.Bitmap(binary)
path = bmp.trace(turdsize=5, alphamax=1.0, opttolerance=0.2)

w, h = img.size

# We collect all curves except Curve 0 (outer box)
path_d = []
for curve in path.curves[1:]:
    start = curve.start_point
    path_d.append(f"M {start.x:.2f},{start.y:.2f}")
    for segment in curve.segments:
        if segment.is_corner:
            c = segment.c
            end = segment.end_point
            path_d.append(f"L {c.x:.2f},{c.y:.2f} L {end.x:.2f},{end.y:.2f}")
        else:
            c1 = segment.c1
            c2 = segment.c2
            end = segment.end_point
            path_d.append(f"C {c1.x:.2f},{c1.y:.2f} {c2.x:.2f},{c2.y:.2f} {end.x:.2f},{end.y:.2f}")
    path_d.append("Z")

svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="100%" height="100%" fill="currentColor">
  <path d="{" ".join(path_d)}" fill-rule="evenodd"/>
</svg>'''

with open(out_svg_assets, "w", encoding="utf-8") as f:
    f.write(svg_content)

print("SVG generado con éxito. Tamaño:", len(svg_content), "bytes")
