import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1080, 1440
bg_ivory = (250, 248, 245)
c_gold = (197, 155, 39)
c_dark_gold = (140, 109, 59)
c_text_main = (46, 36, 34)
c_text_muted = (115, 100, 92)

base_img_path = r'd:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\social-media\alabanzas\a-donde-ire\portadas\portada-tiktok-a-donde-ire-3x4.jpg'
out_dir = r'output\redes_sociales\carrusel_actualizacion_3x4'

font_tag = ImageFont.truetype(r'C:\Windows\Fonts\georgiab.ttf', 30)
font_title = ImageFont.truetype(r'C:\Windows\Fonts\georgiab.ttf', 52)
font_sub = ImageFont.truetype(r'C:\Windows\Fonts\georgiai.ttf', 26)
font_callout_title = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 20)
font_callout_desc = ImageFont.truetype(r'C:\Windows\Fonts\segoeui.ttf', 17)

def make_framed_slide(out_filename, tag_text, title_text, sub_text, screenshot_path, callout_title, callout_desc1, callout_desc2):
    base = Image.open(base_img_path).convert('RGB')
    d = ImageDraw.Draw(base)

    # Clear only the center area from y=240 to y=1220
    d.rectangle([60, 240, W - 60, 1220], fill=bg_ivory)

    # 1. Header Texts
    tw = font_tag.getlength(tag_text)
    d.text(((W - tw) / 2, 252), tag_text, font=font_tag, fill=c_gold)

    ttw = font_title.getlength(title_text)
    d.text(((W - ttw) / 2, 292), title_text, font=font_title, fill=c_text_main)

    sw = font_sub.getlength(sub_text)
    d.text(((W - sw) / 2, 354), sub_text, font=font_sub, fill=c_gold)

    # 2. Mockup Screen - 100% PROPORTIONAL (NO SQUISHING / NO FLATTENING!)
    if os.path.exists(screenshot_path):
        scr = Image.open(screenshot_path).convert('RGBA')
        orig_w, orig_h = scr.size
        
        # Phone target height = 750 px
        target_h = 740
        target_w = int(target_h * (orig_w / float(orig_h))) # Exactly proportional!

        scr_res = scr.resize((target_w, target_h), Image.Resampling.LANCZOS)

        px = (W - target_w) // 2
        py = 398

        # Ambient Shadow
        sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([px - 6, py + 8, px + target_w + 6, py + target_h + 14], radius=24, fill=(46, 36, 34, 45))
        sh = sh.filter(ImageFilter.GaussianBlur(14))
        base.paste(sh, (0, 0), sh)

        # Phone Bezel / Border (Titanium White with Gold hairline)
        d = ImageDraw.Draw(base)
        d.rounded_rectangle([px - 4, py - 4, px + target_w + 4, py + target_h + 4], radius=24, fill=(255, 255, 255), outline=c_gold, width=3)

        # Screen Mask
        mask = Image.new('L', (target_w, target_h), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, target_w, target_h], radius=20, fill=255)
        base.paste(scr_res, (px, py), mask)

    # 3. Callout Box (Below Screenshot)
    cy1 = 1152
    cy2 = 1242
    cx1 = 100
    cx2 = W - 100
    d.rounded_rectangle([cx1, cy1, cx2, cy2], radius=14, fill=(255, 255, 255), outline=(230, 220, 202), width=1)
    d.rounded_rectangle([cx1, cy1, cx1 + 6, cy2], radius=3, fill=c_gold)

    d.text((cx1 + 24, cy1 + 14), callout_title, font=font_callout_title, fill=c_text_main)
    d.text((cx1 + 24, cy1 + 42), callout_desc1, font=font_callout_desc, fill=c_text_muted)
    if callout_desc2:
        d.text((cx1 + 24, cy1 + 64), callout_desc2, font=font_callout_desc, fill=c_text_muted)

    out_file = os.path.join(out_dir, out_filename)
    base.save(out_file, 'JPEG', quality=96, subsampling=0)

    # Copy to brain artifact dir
    art_file = os.path.join(r"C:\Users\Huri_\.gemini\antigravity\brain\276789a5-7098-42ba-8a46-61eb8c6a9d65", out_filename)
    base.save(art_file, 'JPEG', quality=96, subsampling=0)
    print("Saved:", out_file)

# Slide 02: Sidebar / Menú Lateral
make_framed_slide(
    '02_donde_se_encuentra_sidebar_3x4.jpg',
    "N U E V O   A C C E S O",
    "EN EL MENÚ LATERAL",
    "Encuentra el nuevo Reproductor Vocal en el Sidebar",
    r'output\redes_sociales\WhatsApp Image 2026-10-21 at 9.15.47 AM.jpeg', # Index 7 (Sidebar con 🎧 Reproductor)
    "Acceso rápido desde cualquier pantalla",
    "Abre el menú lateral (icono de tres barras) y selecciona «Reproductor»",
    "para acceder directamente a todas las pistas de streaming y estudio."
)

# Slide 03: Distintivo en el Catálogo
make_framed_slide(
    '03_distintivo_catalogo_3x4.jpg',
    "D I S T I N T I V O   D O R A D O",
    "EN EL CATÁLOGO",
    "Reconoce al instante las partituras con Voces Cantadas",
    r'output\redes_sociales\WhatsApp Image 2026-10-21 at 9.15.46 AM (2).jpeg', # Index 1 (Catálogo con distintivo dorado)
    "Icono de voz cantada en cada alabanza",
    "Cada canto con audios disponibles muestra un distintivo dorado",
    "junto al icono del piano para que lo encuentres de inmediato."
)

# Slide 04: Visor de Partituras (Voces Individuales)
make_framed_slide(
    '04_visor_partitura_voces_3x4.jpg',
    "E N   E L   V I S O R",
    "ENSAYA CADA VOZ",
    "Soprano, Contralto, Tenor, Bajo o Ensamble",
    r'output\redes_sociales\WhatsApp Image 2026-10-21 at 9.15.46 AM.jpeg', # Index 2 (Visor con partitura y panel)
    "Controles directos sobre la partitura",
    "Al abrir cualquier canto, el panel inferior te permite activar y aislar",
    "tu voz por separado para estudiar entonación, ritmo y dicción."
)

# Slide 05: Reproductor Completo / Pantalla Apagada
make_framed_slide(
    '05_reproductor_pantalla_apagada_3x4.jpg',
    "R E P R O D U C C I Ó N   C O N T I N U A",
    "PANTALLA APAGADA",
    "Repasa tus voces mientras realizas tus labores",
    r'output\redes_sociales\WhatsApp Image 2026-10-21 at 9.15.47 AM (2).jpeg', # Index 4 (Reproductor completo)
    "Estudio continuo en segundo plano",
    "Reproduce tus alabanzas con la pantalla bloqueada o apagada",
    "y controla la música directamente desde la pantalla de bloqueo."
)
