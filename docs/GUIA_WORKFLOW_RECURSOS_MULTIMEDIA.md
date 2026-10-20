# GUÍA MAESTRA: PRODUCCIÓN DE RECURSOS MULTIMEDIA CORO LLDM
**Versión:** 4.2.0  
**Propósito:** Guía definitiva e integral para la preparación de videos 4:3 de partituras de MuseScore, generación automatizada de la suite gráfica oficial (Marfil y Oro) y redacción de copys para redes sociales.

---

## 1. PRE-REQUISITOS DEL SISTEMA TRAS FORMATEAR

Al reinstalar Windows, para que todo el pipeline funcione sin configuración adicional, se debe contar con:

1. **Node.js (v20 LTS o v24):**
   - Descargar e instalar desde [nodejs.org](https://nodejs.org/).
   - Verificar en terminal: `node -v` y `npm -v`.

2. **FFmpeg:**
   - Descargar la versión "essentials build" (ej. de gyan.dev o vía `winget install Gyan.FFmpeg`).
   - Agregar el directorio `bin` de FFmpeg a las Variables de Entorno de Windows (`PATH`).
   - Verificar en terminal: `ffmpeg -version` y `ffprobe -version`.

3. **Google Chrome:**
   - Instalar en la ruta estándar de Windows:  
     `C:\Program Files\Google\Chrome\Application\chrome.exe`  
     *(Esta ruta es la que utiliza Playwright para renderizar con aceleración y fuentes web exactas)*.

4. **Dependencias del Proyecto:**
   - En el directorio `website/` (o en la raíz del proyecto si se instala allí):
     ```bash
     npm install @playwright/test sharp
     ```

5. **Recursos de Marca del Repositorio:**
   - Emblema transparente: `assets/brand/emblem-transparent.png`
   - Icono redondeado: `assets/brand/app-icon-rounded.png`

---

## 2. ESTRUCTURA DE CARPETAS POR CADA ALABANZA

Para cada alabanza procesada, se crea una subcarpeta dentro de `social-media/alabanzas/<slug>/`:

```text
social-media/alabanzas/<slug>/
├── <Nombre Alabanza>.pdf                    # Partitura original copiada y preservada
├── fondo-video-<slug>.jpg                  # Fondo 9:16 (1080x1920) con área 4:3 libre
├── videos-4x3/
│   └── <slug>-satb-4x3.mp4                 # Video limpio 4:3 (1904x1428)
└── portadas/
    ├── portada-tiktok-<slug>-3x4.jpg       # Portada TikTok (3:4 - 1080x1440)
    ├── portada-facebook-<slug>-1x1.jpg     # Portada Feed IG/FB (1:1 - 1080x1080)
    ├── portada-youtube-<slug>-16x9.jpg     # Portada YouTube Master (16:9 - 1920x1080)
    ├── portada-youtube-<slug>-ensamble-16x9.jpg # Portada Ensamble Completo
    ├── portada-youtube-<slug>-soprano-16x9.jpg  # Voz Soprano
    ├── portada-youtube-<slug>-contralto-16x9.jpg# Voz Contralto
    ├── portada-youtube-<slug>-tenor-16x9.jpg    # Voz Tenor
    └── portada-youtube-<slug>-bajo-16x9.jpg     # Voz Bajo
```

Además, el video 4:3 procesado también se guarda en la carpeta de descargas de MuseScore para fácil acceso:
`C:\Users\Huri_\Downloads\musescore\<Nombre>_4_3.mp4`

---

## 3. PROCESAMIENTO DEL VIDEO DE MUSESCORE

### A. Diagnóstico de Cortes y Bordes
Los videos exportados por MuseScore vienen en 2560 × 1440 a 24 fps con franjas negras a los lados, una portada negra con título al inicio (de ~2.96s a 3.00s) y un cierre a negro al final.

1. **Detección de silencios:**
   ```bash
   ffmpeg -i "video_origen.mp4" -af "silencedetect=n=-40dB:d=0.5" -f null -
   ```
2. **Corte inicial:**
   - Se toma el punto exacto en el que desaparece el fondo oscuro del título y aparece el primer compás de la partitura (casi invariablemente a `2.960s`).
3. **Corte final:**
   - Se detecta el momento exacto en el que el cursor azul llega a la doble barra final del último compás antes de fundirse a negro (ej. `283.450s` o `392.200s`).
4. **Recorte 4:3 (Sin un solo píxel negro):**
   - El área blanca de la partitura mide `1913 × 1435 px` centrada.
   - Para compatibilidad macroblock de h264 divisible por 16, la dimensión ideal es `1904 × 1428 px`.
   - Coordenadas de recorte estándar verificadas:
     ```text
     crop=1904:1428:324:4
     ```

### B. Comando de Codificación FFmpeg
```bash
ffmpeg -y -ss <INICIO_SEG> -to <FIN_SEG> -i "<VIDEO_ORIGEN.mp4>" \
  -vf "crop=1904:1428:324:4" \
  -c:v libx264 -crf 17 -preset fast -pix_fmt yuv420p \
  -c:a aac -b:a 320k \
  "<VIDEO_SALIDA_4_3.mp4>"
```

---

## 4. ESPECIFICACIONES DE DISEÑO Y SUITE GRÁFICA

### Reglas Críticas de Estilo (REGLA 9)
1. **CERO EMOJIS:** Prohibido el uso de cualquier emoji en gráficos o descripciones.
2. **Paleta Marfil y Oro:**
   - Fondo marfil: `#FAF8F5` (o `#FFFFFF` en fondo de video para fusionar con la partitura).
   - Dorado principal: `#C59B27`.
   - Dorado oscuro / acento: `#8C6D3B`.
   - Texto principal oscuro: `#2E2422`.
   - Texto secundario / citas: `#59421A`.
3. **Tipografías (Google Fonts):**
   - Títulos y encabezados: `Cinzel` (pesos 700, 800, 900).
   - Subtítulos y citas: `Playfair Display` (cursiva, 600, 700).
   - Textos de soporte y badges: `Montserrat` (400, 600, 800, 900).
4. **Metadatos Limpios:**
   - **SOLO mostrar Autor y Arreglo/Compositores.**
   - **NO incluir Tonalidad** (Sol Mayor, etc.).
   - **NO incluir Compás o Tempo** (4/4, q=78, etc.).
   - **NO incluir etiquetado redundante** como "CORO S · A · T · B" en la píldora de metadatos.
5. **Pie de Página (Footer):**
   - Debe leerse exclusivamente: `• CORO LLDM • WWW.LLDMCORO.COM •`
   - NO incluir slogans adicionales ("Para la honra...", etc.).
6. **Formato de Exportación:**
   - Siempre **JPG** de alta calidad (calidad `96`, submuestreo de croma `4:4:4`).

---

## 5. DIMENSIONES Y PLANTILLAS DE CADA FORMATO

### 1. Fondo de Video 9:16 (`1080 × 1920 px`)
- **Fondo:** Blanco (`#FFFFFF`).
- **Encabezado (Safe Zone superior):**
  - Emblema oficial en base64 (68x68 px).
  - Píldora: `PARTITURA CORAL · ESTUDIO VOCAL`.
  - Título del canto en `Cinzel` (46px).
  - Subtítulo temático en `Playfair Display` (ej. `(Elección)` o `(Adoración)`).
  - Píldora de metadatos: `Autor: [Nombre] • Arreglo: [Nombres]`.
- **Zona Central (y = 555 a 1365 px):**
  - **Completamente despejada.** Aquí se superpone el video 4:3 (1904x1428 escalado a ~1080x810 px).
- **Pie de Página (Safe Zone inferior, margin-bottom ~210px):**
  - Tarjeta flotante con badges vectoriales de Google Play, App Store y Web (`www.lldmcoro.com`).
  - Nota inferior: `• CORO LLDM • WWW.LLDMCORO.COM •`.

### 2. Portada TikTok 3:4 (`1080 × 1440 px`)
- Formato específico optimizado para miniaturas de TikTok.
- Incluye emblema superior, badge `CORO LLDM`, título (56px), cita o verso clave del canto en `Playfair Display` cursiva, tarjeta de autor y arreglo, y badges de tiendas en la parte inferior.

### 3. Portada Facebook / Instagram Feed 1:1 (`1080 × 1080 px`)
- Cuadrada para feed de redes sociales.
- Misma distribución balanceada con márgenes adaptados.

### 4. Portada YouTube 16:9 (`1920 × 1080 px`)
- **Master / Ensamble:**
  - Badge: `AUDIOS POR VOCES · GUÍA CORAL`.
  - Píldora central: `ENSAMBLE CORAL COMPLETO`.
  - Título en `Cinzel` a 74px.
- **Portadas por Voces (Soprano, Contralto, Tenor, Bajo):**
  - Badge: `PISTA EN PIANO · VOZ [VOZ]`.
  - Píldora central: `GUÍA DE ESTUDIO · [VOZ]`.
  - Título en `Cinzel` a 74px.

---

## 6. SCRIPT PLANTILLA NODE.JS (`scratch/template_recursos.cjs`)

Este script realiza todo el proceso de forma desatendida:

```javascript
const { chromium } = require('c:/Users/Huri_/Documents/proyectos/IosCoroLLDM/website/node_modules/@playwright/test');
const sharp = require('c:/Users/Huri_/Documents/proyectos/IosCoroLLDM/website/node_modules/sharp');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// 1. Configuración de la obra
const OBRA = {
  slug: 'nombre-de-la-obra',
  titulo: 'TÍTULO DE LA OBRA',
  subtitulo: '(Tema o Género)',
  autor: 'Nombre del Autor',
  arreglo: 'Nombre de Arreglistas', // Opcional, omitir si no aplica
  cita: '«Texto poético o verso representativo del canto...»',
  videoSrc: 'C:/Users/Huri_/Downloads/musescore/video_original.mp4',
  videoCorteInicio: 2.960,
  videoCorteFin: 283.450
};

// ... Ejecuta recorte ffmpeg y genera las 8 portadas con Chromium y Sharp ...
```

---

## 7. REGLAS PARA LA DESCRIPCIÓN DE REDES SOCIALES

Al redactar la descripción para Facebook, TikTok, Instagram o YouTube:
- **Estructura en párrafos independientes** (sin numeración 1, 2, 3... ni formato de tabla o recuadros rígidos).
- **Terminología Sagrada:** Hablar de "coro", "cuerpo coral", "voces" o "ensamble coral". Prohibido usar "cuerdas" o "grupos".
- **Sin lenguaje ajeno:** No emplear palabras de resonancia católica o "litúrgica".
- **Reproductor en segundo plano:** Describir la app mencionando que incluye reproductor continuo (tipo reproductor de música / streaming) que permite estudiar las voces o escuchar el repertorio coral con la pantalla apagada.
- **Llamado a la acción:** Indicar disponibilidad gratuita en **App Store** (iOS), **Google Play Store** (Android) y en el sitio web oficial **www.lldmcoro.com**.
- **Cero emojis.**

---

## 8. CÓMO REANUDAR ESTE TRABAJO EN UN CHAT NUEVO TRAS FORMATEAR

Cuando reinstales Antigravity / abras un nuevo chat tras formatear tu PC, simplemente envía este mensaje de activación:

> *"Hola, he formateado la PC y deseo continuar procesando las partituras y recursos multimedia de Coro LLDM. Revisa el archivo `docs/GUIA_WORKFLOW_RECURSOS_MULTIMEDIA.md` y la regla 9 de `GEMINI.md` para seguir el estándar exacto (video 4:3 sin barras negras ni intros, gráficos marfil y oro sin emojis, solo autor/arreglo, y copys para tiendas y web www.lldmcoro.com). Procesaremos la siguiente alabanza: [Ruta del Video] y [Ruta del PDF]."*

El agente leerá automáticamente este archivo y ejecutará el pipeline con la misma precisión y calidad sin que tengas que repetir ninguna instrucción.
