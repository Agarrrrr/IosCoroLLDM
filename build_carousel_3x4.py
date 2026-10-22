import os
import json
import re
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1080, 1440
bg_ivory = (250, 248, 245)
c_gold = (197, 155, 39)
c_dark_gold = (140, 109, 59)
c_text_main = (46, 36, 34)
c_text_muted = (115, 100, 92)
c_line = (235, 227, 213)

base_img_path = r'd:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\social-media\alabanzas\a-donde-ire\portadas\portada-tiktok-a-donde-ire-3x4.jpg'
out_dir = r'output\redes_sociales\carrusel_actualizacion_3x4'
os.makedirs(out_dir, exist_ok=True)

# Typography
font_tag = ImageFont.truetype(r'C:\Windows\Fonts\georgiab.ttf', 36)
font_title = ImageFont.truetype(r'C:\Windows\Fonts\georgiab.ttf', 62)
font_title_big = ImageFont.truetype(r'C:\Windows\Fonts\georgiab.ttf', 68)
font_sub = ImageFont.truetype(r'C:\Windows\Fonts\georgiai.ttf', 32)
font_desc = ImageFont.truetype(r'C:\Windows\Fonts\georgiai.ttf', 26)
font_pill = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 14)
font_footer = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 16)
font_callout_title = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 22)
font_callout_desc = ImageFont.truetype(r'C:\Windows\Fonts\segoeui.ttf', 19)

font_list_title = ImageFont.truetype(r'C:\Windows\Fonts\georgiab.ttf', 40)
font_list_sub = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 19)
font_song_num = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 16)
font_song_name = ImageFont.truetype(r'C:\Windows\Fonts\segoeuib.ttf', 17)
font_song_tema = ImageFont.truetype(r'C:\Windows\Fonts\segoeui.ttf', 13)

def get_base_canvas():
    base = Image.open(base_img_path).convert('RGB')
    d = ImageDraw.Draw(base)
    # Clear only the center area from y=320 to y=1210 (preserving top emblem, pill, stores card and border)
    d.rectangle([60, 320, W - 60, 1210], fill=bg_ivory)
    return base

# -------------------------------------------------------------
# SLIDE 1: PORTADA "TE PRESENTAMOS TODO LO NUEVO"
# -------------------------------------------------------------
def make_slide_01():
    base = get_base_canvas()
    d = ImageDraw.Draw(base)

    tag_text = "N U E V A   A C T U A L I Z A C I Ó N"
    tw = font_tag.getlength(tag_text)
    d.text(((W - tw) / 2, 420), tag_text, font=font_tag, fill=c_gold)

    # Decorative line
    line_w = tw + 40
    d.line([(W - line_w)/2, 474, (W + line_w)/2, 474], fill=(225, 200, 135), width=2)
    d.polygon([(W/2, 470), (W/2 + 5, 474), (W/2, 478), (W/2 - 5, 474)], fill=c_gold)

    # Main Title: TE PRESENTAMOS TODO LO NUEVO
    lines = ["TE PRESENTAMOS", "TODO LO NUEVO"]
    y_t = 505
    for l in lines:
        lw = font_title_big.getlength(l)
        d.text(((W - lw) / 2, y_t), l, font=font_title_big, fill=c_text_main)
        y_t += 76

    # Subtitle: Voces Cantadas
    sub_text = "Voces Cantadas (Soprano · Contralto · Tenor · Bajo)"
    sw = font_sub.getlength(sub_text)
    d.text(((W - sw) / 2, 680), sub_text, font=font_sub, fill=c_gold)

    # Diamond
    d.polygon([(W / 2, 745), (W / 2 + 8, 753), (W / 2, 761), (W / 2 - 8, 753)], fill=c_gold)

    # Descriptive note
    desc_lines = [
        "«Estudio individual por voces",
        "y ensamble coral en vivo»"
    ]
    dy = 795
    for line in desc_lines:
        lw = font_desc.getlength(line)
        d.text(((W - lw) / 2, dy), line, font=font_desc, fill=(89, 66, 26))
        dy += 42

    out_file = os.path.join(out_dir, '01_portada_te_presentamos_todo_lo_nuevo_3x4.jpg')
    base.save(out_file, 'JPEG', quality=96, subsampling=0)
    print("Saved:", out_file)

# -------------------------------------------------------------
# SLIDE 2: ¿DÓNDE SE ENCUENTRA EL REPRODUCTOR?
# -------------------------------------------------------------
def make_slide_02():
    base = get_base_canvas()
    d = ImageDraw.Draw(base)

    tag_text = "G U Í A   D E   U S O"
    tw = font_tag.getlength(tag_text)
    d.text(((W - tw) / 2, 345), tag_text, font=font_tag, fill=c_gold)

    title_text = "¿DÓNDE SE ENCUENTRA?"
    ttw = font_title.getlength(title_text)
    d.text(((W - ttw) / 2, 395), title_text, font=font_title, fill=c_text_main)

    sub_text = "El nuevo reproductor vocal interactivo"
    sw = font_sub.getlength(sub_text)
    d.text(((W - sw) / 2, 470), sub_text, font=font_sub, fill=c_gold)

    # Insert Phone Visor Mockup (Cropped focus on score + player panel)
    phone_src = r'C:\Users\Huri_\.gemini\antigravity\brain\276789a5-7098-42ba-8a46-61eb8c6a9d65\phone_visor_es.png'
    if os.path.exists(phone_src):
        ph = Image.open(phone_src).convert('RGBA')
        # Crop from sheet music down to player
        # In 1080x2400: crop sheet music and vocal panel y=380 to 2260
        ph_crop = ph.crop((30, 420, 1050, 2260))
        
        target_w = 640
        target_h = 520
        ph_res = ph_crop.resize((target_w, target_h), Image.Resampling.LANCZOS)

        px = (W - target_w) // 2
        py = 525

        # Shadow
        sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([px - 6, py + 8, px + target_w + 6, py + target_h + 14], radius=24, fill=(46, 36, 34, 45))
        sh = sh.filter(ImageFilter.GaussianBlur(12))
        base.paste(sh, (0, 0), sh)

        # Phone frame
        d = ImageDraw.Draw(base)
        d.rounded_rectangle([px - 4, py - 4, px + target_w + 4, py + target_h + 4], radius=24, fill=(255, 255, 255), outline=c_gold, width=3)
        
        mask = Image.new('L', (target_w, target_h), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, target_w, target_h], radius=20, fill=255)
        base.paste(ph_res, (px, py), mask)

    # Explanatory card below screenshot
    cy1 = 1065
    cy2 = 1205
    cx1 = 110
    cx2 = W - 110
    d.rounded_rectangle([cx1, cy1, cx2, cy2], radius=16, fill=(255, 255, 255), outline=(230, 220, 202), width=1)
    d.rounded_rectangle([cx1, cy1, cx1 + 8, cy2], radius=4, fill=c_gold)

    d.text((cx1 + 30, cy1 + 22), "Acceso directo en el Visor de Partituras", font=font_callout_title, fill=c_text_main)
    desc1 = "Al abrir cualquier partitura con audios vocales, el panel inferior te permite"
    desc2 = "seleccionar tu voz (Soprano, Contralto, Tenor, Bajo) o ensamble completo."
    d.text((cx1 + 30, cy1 + 58), desc1, font=font_callout_desc, fill=c_text_muted)
    d.text((cx1 + 30, cy1 + 88), desc2, font=font_callout_desc, fill=c_text_muted)

    out_file = os.path.join(out_dir, '02_donde_se_encuentra_el_reproductor_3x4.jpg')
    base.save(out_file, 'JPEG', quality=96, subsampling=0)
    print("Saved:", out_file)

# -------------------------------------------------------------
# SLIDE 3: REPRODUCCIÓN CON PANTALLA APAGADA
# -------------------------------------------------------------
def make_slide_03():
    base = get_base_canvas()
    d = ImageDraw.Draw(base)

    tag_text = "R E P R O D U C C I Ó N   C O N T I N U A"
    tw = font_tag.getlength(tag_text)
    d.text(((W - tw) / 2, 345), tag_text, font=font_tag, fill=c_gold)

    title_text = "PANTALLA APAGADA"
    ttw = font_title.getlength(title_text)
    d.text(((W - ttw) / 2, 395), title_text, font=font_title, fill=c_text_main)

    sub_text = "Repasa tus voces mientras realizas tus labores"
    sw = font_sub.getlength(sub_text)
    d.text(((W - sw) / 2, 470), sub_text, font=font_sub, fill=c_gold)

    # Insert Phone Screen with playback queue / lockscreen
    queue_src = r'output\redes_sociales\WhatsApp Image 2026-10-21 at 9.17.05 AM.jpeg'
    if os.path.exists(queue_src):
        ph = Image.open(queue_src).convert('RGBA')
        target_w = 640
        target_h = 520
        # Resize to fit nicely
        ph_res = ph.resize((target_w, target_h), Image.Resampling.LANCZOS)

        px = (W - target_w) // 2
        py = 525

        # Shadow
        sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([px - 6, py + 8, px + target_w + 6, py + target_h + 14], radius=24, fill=(46, 36, 34, 45))
        sh = sh.filter(ImageFilter.GaussianBlur(12))
        base.paste(sh, (0, 0), sh)

        d = ImageDraw.Draw(base)
        d.rounded_rectangle([px - 4, py - 4, px + target_w + 4, py + target_h + 4], radius=24, fill=(255, 255, 255), outline=c_gold, width=3)
        
        mask = Image.new('L', (target_w, target_h), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, target_w, target_h], radius=20, fill=255)
        base.paste(ph_res, (px, py), mask)

    # Explanatory card below screenshot
    cy1 = 1065
    cy2 = 1205
    cx1 = 110
    cx2 = W - 110
    d.rounded_rectangle([cx1, cy1, cx2, cy2], radius=16, fill=(255, 255, 255), outline=(230, 220, 202), width=1)
    d.rounded_rectangle([cx1, cy1, cx1 + 8, cy2], radius=4, fill=c_gold)

    d.text((cx1 + 30, cy1 + 22), "Estudio constante en segundo plano", font=font_callout_title, fill=c_text_main)
    desc1 = "Bloquea tu teléfono y continúa escuchando tus partes vocales"
    desc2 = "con el reproductor continuo tipo streaming y controles en pantalla de bloqueo."
    d.text((cx1 + 30, cy1 + 58), desc1, font=font_callout_desc, fill=c_text_muted)
    d.text((cx1 + 30, cy1 + 88), desc2, font=font_callout_desc, fill=c_text_muted)

    out_file = os.path.join(out_dir, '03_reproductor_pantalla_apagada_3x4.jpg')
    base.save(out_file, 'JPEG', quality=96, subsampling=0)
    print("Saved:", out_file)

# -------------------------------------------------------------
# SLIDES 4-7: LISTA DE CANTOS EN 3:4 (4 PARTES)
# -------------------------------------------------------------
def make_slides_song_list():
    def clean(s):
        return re.sub(r'[^a-z0-9]', '', s.lower())

    with open('assets/voces_manifest.json', 'r', encoding='utf-8') as f:
        manifest = json.load(f)

    with open('assets/catalogo.json', 'r', encoding='utf-8') as f:
        catalogo = json.load(f)

    cat_map = {clean(c['nombre']): c.get('temas', []) for c in catalogo}
    id_map = {c['id']: c.get('temas', []) for c in catalogo if 'id' in c}

    es_cantos = sorted(manifest['idiomas']['es']['cantos'], key=lambda x: x['canto'].lower())

    prepared_songs = []
    for c in es_cantos:
        temas = []
        if c.get('id') and c['id'] in id_map and id_map[c['id']]:
            temas = id_map[c['id']]
        elif clean(c['canto']) in cat_map and cat_map[clean(c['canto'])]:
            temas = cat_map[clean(c['canto'])]
        if not temas:
            temas = ['Repertorio Coral']
        prepared_songs.append({
            'canto': c['canto'],
            'temas': temas[:2]
        })

    chunk_size = 39
    total_parts = 4

    for part_idx in range(total_parts):
        start_i = part_idx * chunk_size
        end_i = min(start_i + chunk_size, len(prepared_songs))
        chunk = prepared_songs[start_i:end_i]

        first_l = chunk[0]['canto'][0].upper()
        last_l = chunk[-1]['canto'][0].upper()
        range_str = f"({first_l} - {last_l})"

        # Blank 3:4 Ivory Canvas
        img = Image.new('RGB', (W, H), bg_ivory)
        d = ImageDraw.Draw(img)

        # Double Gold Border
        d.rounded_rectangle([24, 24, W - 24, H - 24], radius=28, outline=c_gold, width=2)
        d.rounded_rectangle([34, 34, W - 34, H - 34], radius=20, outline=(234, 215, 161), width=1)

        # Header Pill
        pill_txt = f"• REPERTORIO CORAL • VOCES CANTADAS • PARTE {part_idx + 1} DE {total_parts} {range_str} •"
        pw = font_pill.getlength(pill_txt)
        px1 = (W - pw) / 2.0 - 18
        py1 = 58
        d.rounded_rectangle([px1, py1, px1 + pw + 36, py1 + 34], radius=17, fill=(255, 255, 255), outline=c_gold, width=1)
        d.text((px1 + 18, py1 + 8), pill_txt, font=font_pill, fill=c_dark_gold)

        # Main Title
        hdr_title = "¿ESTÁ AQUÍ TU CANTO FAVORITO?"
        htw = font_list_title.getlength(hdr_title)
        d.text(((W - htw) / 2, 106), hdr_title, font=font_list_title, fill=c_text_main)

        # Subtitle
        hdr_sub = "Desliza para ver la lista completa • Comenta cuál te gustaría agregar"
        hsw = font_list_sub.getlength(hdr_sub)
        d.text(((W - hsw) / 2, 162), hdr_sub, font=font_list_sub, fill=c_dark_gold)

        # Divider line
        d.line([60, 206, W - 60, 206], fill=(215, 185, 110), width=1)

        # Two Columns Layout
        col_w = 445
        col_gap = 40
        c1_x = 75
        c2_x = c1_x + col_w + col_gap
        
        # Paging: Col 1 has 20 songs, Col 2 has 19 songs
        col1_songs = chunk[:20]
        col2_songs = chunk[20:]

        row_y_start = 224
        row_h = 54

        for col_i, songs_in_col in enumerate([col1_songs, col2_songs]):
            cx = c1_x if col_i == 0 else c2_x
            for r_i, s in enumerate(songs_in_col):
                global_idx = start_i + col_i * 20 + r_i + 1
                ry = row_y_start + r_i * row_h

                # Number prefix
                num_txt = f"{global_idx:02d}"
                d.text((cx, ry + 3), num_txt, font=font_song_num, fill=c_gold)

                # Song Title (truncated if exceeds col width)
                canto_name = s['canto']
                if font_song_name.getlength(canto_name) > (col_w - 40):
                    while font_song_name.getlength(canto_name + "...") > (col_w - 40) and len(canto_name) > 5:
                        canto_name = canto_name[:-1]
                    canto_name = canto_name.strip() + "..."

                d.text((cx + 32, ry + 2), canto_name, font=font_song_name, fill=c_text_main)

                # Song topics
                temas_txt = " · ".join([t.upper() for t in s['temas']])
                d.text((cx + 32, ry + 26), temas_txt, font=font_song_tema, fill=c_text_muted)

                # Subtle hairline divider
                d.line([cx, ry + 48, cx + col_w, ry + 48], fill=c_line, width=1)

        # Official Footer strictly: • CORO LLDM • WWW.LLDMCORO.COM • APP STORE • GOOGLE PLAY •
        footer_txt = "•   C O R O   L L D M   •   W W W . L L D M C O R O . C O M   •   A P P   S T O R E   •   G O O G L E   P L A Y   •"
        ftw = font_footer.getlength(footer_txt)
        d.text(((W - ftw) / 2, 1378), footer_txt, font=font_footer, fill=c_dark_gold)

        out_file = os.path.join(out_dir, f'0{part_idx + 4}_lista_cantos_voces_3x4_parte_{part_idx + 1}.jpg')
        img.save(out_file, 'JPEG', quality=96, subsampling=0)
        print("Saved song list part:", out_file)

make_slide_01()
make_slide_02()
make_slide_03()
make_slides_song_list()
print("All slides completed!")
