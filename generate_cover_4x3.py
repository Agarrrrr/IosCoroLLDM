import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1920, 1440

# Fonts
font_emblem_pill = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 20)
font_category = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 22)
font_title = ImageFont.truetype(r'C:\Windows\Fonts\georgiab.ttf', 72)
font_sub = ImageFont.truetype(r'C:\Windows\Fonts\georgiai.ttf', 32)
font_card_title = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 24)
font_card_desc = ImageFont.truetype(r'C:\Windows\Fonts\segoeui.ttf', 20)
font_badge = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 18)
font_footer = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 20)
font_stores = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 18)

def create_cover(lang='es'):
    canvas = Image.new('RGBA', (W, H), (250, 248, 245, 255)) # Luxury Ivory #FAF8F5
    d = ImageDraw.Draw(canvas)

    # 1. Double Gold Borders
    # Outer
    d.rounded_rectangle([32, 32, W - 32, H - 32], radius=32, outline=(197, 155, 39, 255), width=3)
    # Inner hairline
    d.rounded_rectangle([44, 44, W - 44, H - 44], radius=24, outline=(234, 215, 161, 200), width=1)

    # 2. Emblema Sacro & Header
    emblem_path = r'assets\brand\emblem-transparent.png'
    if os.path.exists(emblem_path):
        emblem = Image.open(emblem_path).convert('RGBA')
        emblem = emblem.resize((84, 84), Image.Resampling.LANCZOS)
        canvas.paste(emblem, (90, 72), emblem)

    pill_text = "• CORO LLDM • NUEVA ACTUALIZACIÓN •" if lang == 'es' else "• TLOTW CHOIR • NEW UPDATE •"
    pill_w = font_emblem_pill.getlength(pill_text)
    pill_box = [190, 88, 190 + pill_w + 36, 88 + 48]
    d.rounded_rectangle(pill_box, radius=24, fill=(255, 255, 255, 255), outline=(197, 155, 39, 255), width=2)
    d.text((190 + 18, 100), pill_text, font=font_emblem_pill, fill=(180, 138, 30, 255))

    # Version pill at right header
    ver_text = "VERSIÓN 4.3" if lang == 'es' else "VERSION 4.3"
    ver_w = font_emblem_pill.getlength(ver_text)
    d.rounded_rectangle([W - 90 - ver_w - 36, 88, W - 90, 88 + 48], radius=24, fill=(255, 255, 255, 255), outline=(220, 205, 175, 255), width=1)
    d.text((W - 90 - ver_w - 18, 100), ver_text, font=font_emblem_pill, fill=(140, 109, 59, 255))

    # 3. Main Titles (Left Column)
    cat_text = "HERRAMIENTA DE ESTUDIO CORAL" if lang == 'es' else "CHORAL REPERTOIRE STUDY TOOL"
    d.text((90, 175), cat_text, font=font_category, fill=(140, 109, 59, 255))

    title_text = "VOCES CANTADAS" if lang == 'es' else "SUNG VOICES"
    d.text((90, 215), title_text, font=font_title, fill=(46, 36, 34, 255))

    sub_text = "Estudio individual por voces y ensamble coral en vivo" if lang == 'es' else "Rehearse each voice part individually or with full ensemble"
    d.text((90, 305), sub_text, font=font_sub, fill=(197, 155, 39, 255))

    # Gold ornamental separator
    d.line([90, 365, 880, 365], fill=(215, 185, 110, 255), width=2)
    d.polygon([(485, 360), (490, 365), (485, 370), (480, 365)], fill=(197, 155, 39, 255))

    # 4. Feature Cards (Left Column)
    features_es = [
        (
            "Voces Separadas e Individuales",
            "Soprano, Contralto, Tenor, Bajo o Coro Completo para perfeccionar entonación, ritmo y dicción."
        ),
        (
            "Reproductor Continuo en Segundo Plano",
            "Transmisión continua de audio para escuchar y estudiar con la pantalla apagada o bloqueada."
        ),
        (
            "Distintivo Dorado en Catálogo",
            "Identificación instantánea de cada himno con pistas vocales disponibles para estudio."
        ),
        (
            "Visualización Optimizada para Atril",
            "Partituras nítidas en tablets y móviles, ideal para ensayos y presentaciones en vivo."
        )
    ]

    features_en = [
        (
            "Individual & Separated Voice Parts",
            "Soprano, Alto, Tenor, Bass, or Full Choir to perfect pitch, timing, and choral diction."
        ),
        (
            "Continuous Background Playback",
            "Seamless streaming player to practice your repertoire even with your screen turned off."
        ),
        (
            "Golden Badge in Song Catalog",
            "Instantly spot scores with singing voice audio tracks ready for individual practice."
        ),
        (
            "Optimized Music Stand View",
            "Crystal-clear sheet music view on tablets and phones, tailored for live rehearsals."
        )
    ]

    features = features_es if lang == 'es' else features_en

    card_y = 395
    card_w = 790
    card_h = 135
    card_spacing = 24

    for i, (ft_title, ft_desc) in enumerate(features):
        cy = card_y + i * (card_h + card_spacing)

        # Card shadow
        c_sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(c_sh).rounded_rectangle([90, cy + 4, 90 + card_w, cy + card_h + 4], radius=18, fill=(46, 36, 34, 25))
        c_sh = c_sh.filter(ImageFilter.GaussianBlur(8))
        canvas = Image.alpha_composite(canvas, c_sh)
        d = ImageDraw.Draw(canvas)

        # Card body
        d.rounded_rectangle([90, cy, 90 + card_w, cy + card_h], radius=18, fill=(255, 255, 255, 255), outline=(230, 222, 208, 255), width=1)
        
        # Left golden accent bar
        d.rounded_rectangle([90, cy, 98, cy + card_h], radius=4, fill=(197, 155, 39, 255))

        # Card bullet dot
        d.ellipse([120, cy + 28, 134, cy + 42], fill=(197, 155, 39, 255))
        d.ellipse([124, cy + 32, 130, cy + 38], fill=(255, 255, 255, 255))

        # Text
        d.text((150, cy + 22), ft_title, font=font_card_title, fill=(46, 36, 34, 255))
        
        # Multiline description wrap
        words = ft_desc.split(' ')
        line1, line2 = "", ""
        for w in words:
            if font_card_desc.getlength(line1 + w + " ") < 680:
                line1 += w + " "
            else:
                line2 += w + " "
        
        d.text((150, cy + 62), line1.strip(), font=font_card_desc, fill=(110, 95, 88, 255))
        if line2:
            d.text((150, cy + 92), line2.strip(), font=font_card_desc, fill=(110, 95, 88, 255))

    # Stores Card (Bottom Left)
    st_y = 1045
    st_w = 790
    st_h = 105
    d.rounded_rectangle([90, st_y, 90 + st_w, st_y + st_h], radius=20, fill=(255, 255, 255, 255), outline=(197, 155, 39, 255), width=2)
    
    st_title = "DISPONIBLE TOTALMENTE GRATIS EN:" if lang == 'es' else "AVAILABLE COMPLETELY FREE ON:"
    d.text((120, st_y + 18), st_title, font=ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 16), fill=(140, 109, 59, 255))

    badges_txt = "Google Play  •  App Store  •  www.lldmcoro.com"
    d.text((120, st_y + 52), badges_txt, font=ImageFont.truetype(r'C:\Windows\Fonts\georgiab.ttf', 24), fill=(46, 36, 34, 255))

    # 5. Right Column: Mobile Device Mockup
    # Load captured screen
    screen_src = r'C:\Users\Huri_\.gemini\antigravity\brain\276789a5-7098-42ba-8a46-61eb8c6a9d65\phone_visor_es.png' if lang == 'es' else r'C:\Users\Huri_\.gemini\antigravity\brain\276789a5-7098-42ba-8a46-61eb8c6a9d65\current_screen.png'
    
    dev_x = 990
    dev_y = 175
    dev_w = 840
    dev_h = 1110
    screen_crop_h = 1920

    if os.path.exists(screen_src):
        scr = Image.open(screen_src).convert('RGBA')
        # Crop out status bar and bottom buttons
        # 1080x2400: status bar top ~100px, bottom nav ~120px
        scr_cropped = scr.crop((0, 95, 1080, 2260))
        scr_resized = scr_cropped.resize((dev_w - 24, dev_h - 24), Image.Resampling.LANCZOS)

        # Phone frame with shadow
        ph_sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(ph_sh).rounded_rectangle([dev_x - 12, dev_y + 14, dev_x + dev_w + 12, dev_y + dev_h + 24], radius=44, fill=(46, 36, 34, 55))
        ph_sh = ph_sh.filter(ImageFilter.GaussianBlur(18))
        canvas = Image.alpha_composite(canvas, ph_sh)
        d = ImageDraw.Draw(canvas)

        # Phone bezel base (Titanium White with Gold Rim)
        d.rounded_rectangle([dev_x, dev_y, dev_x + dev_w, dev_y + dev_h], radius=40, fill=(255, 255, 255, 255), outline=(197, 155, 39, 255), width=4)

        # Mask for inner screen rounded corners
        mask = Image.new('L', (dev_w - 24, dev_h - 24), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, dev_w - 24, dev_h - 24], radius=32, fill=255)
        
        canvas.paste(scr_resized, (dev_x + 12, dev_y + 12), mask)

        # Floating Pill on Device Mockup (Top Right of Device)
        fl_txt = "EN VIVO: AUDIO MULTI-VOZ" if lang == 'es' else "LIVE: MULTI-VOICE AUDIO"
        fl_w = font_badge.getlength(fl_txt)
        fl_box = [dev_x + dev_w - fl_w - 50, dev_y + 24, dev_x + dev_w - 18, dev_y + 68]
        
        # Shadow for floating pill
        fl_sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(fl_sh).rounded_rectangle([fl_box[0] - 2, fl_box[1] + 3, fl_box[2] + 2, fl_box[3] + 5], radius=20, fill=(46, 36, 34, 40))
        fl_sh = fl_sh.filter(ImageFilter.GaussianBlur(6))
        canvas = Image.alpha_composite(canvas, fl_sh)
        d = ImageDraw.Draw(canvas)

        d.rounded_rectangle(fl_box, radius=20, fill=(197, 155, 39, 255), outline=(255, 255, 255, 255), width=2)
        d.text((fl_box[0] + 16, fl_box[1] + 11), fl_txt, font=font_badge, fill=(255, 255, 255, 255))

    # 6. Official Footer (Strict Rule 9)
    footer_text = "•  C O R O   L L D M   •   W W W . L L D M C O R O . C O M  •"
    ft_w = font_footer.getlength(footer_text)
    d.text(((W - ft_w) / 2, 1378), footer_text, font=font_footer, fill=(140, 109, 59, 255))

    # Export paths
    out_dir = r"output\redes_sociales"
    os.makedirs(out_dir, exist_ok=True)
    slug = "portada_update_voces_cantadas_4x3" if lang == 'es' else "portada_update_sung_voices_4x3_en"
    
    jpg_path = os.path.join(out_dir, f"{slug}.jpg")
    png_path = os.path.join(out_dir, f"{slug}.png")

    # RGB for JPG (Quality 96, 4:4:4 subsampling)
    canvas_rgb = canvas.convert('RGB')
    canvas_rgb.save(jpg_path, 'JPEG', quality=96, subsampling=0)
    canvas.save(png_path, 'PNG')

    # Also copy to artifacts dir
    art_dir = r"C:\Users\Huri_\.gemini\antigravity\brain\276789a5-7098-42ba-8a46-61eb8c6a9d65"
    canvas_rgb.save(os.path.join(art_dir, f"{slug}.jpg"), 'JPEG', quality=96, subsampling=0)
    canvas.save(os.path.join(art_dir, f"{slug}.png"), 'PNG')

    print(f"Generated 4:3 cover ({lang}): {jpg_path}")

create_cover('es')
create_cover('en')
