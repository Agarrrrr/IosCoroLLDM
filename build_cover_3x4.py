import os
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1440

base_img_path = r'd:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\social-media\alabanzas\a-donde-ire\portadas\portada-tiktok-a-donde-ire-3x4.jpg'

# Fonts
font_tag = ImageFont.truetype(r'C:\Windows\Fonts\georgiab.ttf', 38)        # NUEVA ACTUALIZACIÓN (SUPER GRANDE)
font_title = ImageFont.truetype(r'C:\Windows\Fonts\georgiab.ttf', 82)      # VOCES CANTADAS
font_sub = ImageFont.truetype(r'C:\Windows\Fonts\georgiai.ttf', 36)        # (Soprano · Contralto · Tenor · Bajo)
font_desc = ImageFont.truetype(r'C:\Windows\Fonts\georgiai.ttf', 28)       # Subtítulo elegante
font_pill = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 14)

def generate_clean_3x4(lang='es'):
    base = Image.open(base_img_path).convert('RGB')
    d = ImageDraw.Draw(base)

    bg_ivory = (250, 248, 245)
    
    # Clear ONLY the center text area from y=320 to y=1210.
    # We DO NOT touch anything below y=1210 so the stores card and outer border are 100% pristine!
    d.rectangle([60, 320, W - 60, 1210], fill=bg_ivory)

    # If english, update top pill
    if lang == 'en':
        d.rounded_rectangle([425, 107, 655, 133], radius=13, fill=bg_ivory, outline=(197, 155, 39), width=2)
        top_pill = "• TLOTW CHOIR •"
        tpw = font_pill.getlength(top_pill)
        d.text(((W - tpw) / 2, 112), top_pill, font=font_pill, fill=(140, 109, 59))

    # 1. "NUEVA ACTUALIZACIÓN" - EN SUPER GRANDE
    tag_text = "N U E V A   A C T U A L I Z A C I Ó N" if lang == 'es' else "N E W   U P D A T E"
    tw = font_tag.getlength(tag_text)
    d.text(((W - tw) / 2, 450), tag_text, font=font_tag, fill=(197, 155, 39))

    # Decorative thin line underneath tag
    line_w = tw + 40
    d.line([(W - line_w)/2, 508, (W + line_w)/2, 508], fill=(225, 200, 135), width=2)
    d.polygon([(W/2, 504), (W/2 + 5, 508), (W/2, 512), (W/2 - 5, 508)], fill=(197, 155, 39))

    # 2. "VOCES CANTADAS" - Título principal masivo
    title_text = "VOCES CANTADAS" if lang == 'es' else "SUNG VOICES"
    ttw = font_title.getlength(title_text)
    d.text(((W - ttw) / 2, 545), title_text, font=font_title, fill=(46, 36, 34))

    # 3. "(Soprano · Contralto · Tenor · Bajo)"
    sub_text = "(Soprano · Contralto · Tenor · Bajo)" if lang == 'es' else "(Soprano · Alto · Tenor · Bass)"
    sw = font_sub.getlength(sub_text)
    d.text(((W - sw) / 2, 655), sub_text, font=font_sub, fill=(197, 155, 39))

    # 4. Diamond
    d.polygon([(W / 2, 735), (W / 2 + 8, 743), (W / 2, 751), (W / 2 - 8, 743)], fill=(197, 155, 39))

    # 5. Elegant statement
    if lang == 'es':
        desc_lines = [
            "«Estudio individual por voces",
            "y ensamble coral en vivo»"
        ]
    else:
        desc_lines = [
            "«Individual study by voice parts",
            "and live choral ensemble»"
        ]

    dy = 785
    for line in desc_lines:
        lw = font_desc.getlength(line)
        d.text(((W - lw) / 2, dy), line, font=font_desc, fill=(89, 66, 26))
        dy += 44

    # Save outputs
    out_dir = r"output\redes_sociales"
    slug = "portada_tiktok_update_voces_cantadas_3x4" if lang == 'es' else "portada_tiktok_update_sung_voices_3x4_en"
    
    jpg_path = os.path.join(out_dir, f"{slug}.jpg")
    base.save(jpg_path, 'JPEG', quality=96, subsampling=0)

    art_path = os.path.join(r"C:\Users\Huri_\.gemini\antigravity\brain\276789a5-7098-42ba-8a46-61eb8c6a9d65", f"{slug}.jpg")
    base.save(art_path, 'JPEG', quality=96, subsampling=0)

    print(f"Generated clean 3:4 cover ({lang}): {jpg_path}")

generate_clean_3x4('es')
generate_clean_3x4('en')
