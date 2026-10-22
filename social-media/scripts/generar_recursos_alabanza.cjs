/**
 * CORO LLDM - GENERADOR MAESTRO DE RECURSOS MULTIMEDIA
 *
 * Uso:
 *   node social-media/scripts/generar_recursos_alabanza.cjs
 *
 * Configura el objeto OBRA con los datos de la alabanza a procesar.
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const rootDir = path.resolve(__dirname, '../../');
const { chromium } = require(path.join(rootDir, 'website/node_modules/@playwright/test'));
const sharp = require(path.join(rootDir, 'website/node_modules/sharp'));

// =========================================================================
// CONFIGURACIÓN DE LA OBRA (MODIFICAR SEGÚN EL CANTO)
// =========================================================================
const OBRA = {
  slug: 'valle-de-los-huesos-secos',
  titulo: 'VALLE DE LOS HUESOS SECOS',
  subtitulo: '(Alabanza)',
  autor: 'M. Salvador Castro S.',
  arreglo: '',
  cita: '«Hijo de hombre, profetiza sobre estos huesos y vivirán. ¡Y un estruendo majestuoso ha salido por la tierra! Es la palabra que a su Siervo el Señor le reveló y su pueblo se levantó.»',
  videoSrc: 'E:/MusescoreCantai/videos/Valle de los Huesos Secos.mp4',
  audioSrc: 'E:/SV5/ValledeLosHuesosSecos/ValledeLosHuesosSecos_MixDown.wav',
  audioDelayMs: 49,
  videoCorteInicio: 3.000,
  videoCorteFin: 296.000,
  videoFiltro: 'crop=1904:1428:324:4'
};

// =========================================================================
// DIRECTORIOS Y RUTAS
// =========================================================================
const outBaseDir = path.join(rootDir, 'social-media/alabanzas', OBRA.slug);
const outPortadasDir = path.join(outBaseDir, 'portadas');
const outVideosDir = path.join(outBaseDir, 'videos-4x3');
const museDir = 'C:/Users/Huri_/Downloads/musescore';

for (const d of [outBaseDir, outPortadasDir, outVideosDir, museDir]) {
  if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });
}

// =========================================================================
// RECURSOS BASE64
// =========================================================================
const emblemB64 = fs.readFileSync(path.join(rootDir, 'assets/brand/emblem-transparent.png')).toString('base64');
const iconB64 = fs.readFileSync(path.join(rootDir, 'assets/brand/app-icon-rounded.png')).toString('base64');

const googlePlaySvg = `
<svg width="24" height="24" viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M47.7 15.6C40.6 23.3 36.5 35.3 36.5 50.8v410.4c0 15.5 4.1 27.5 11.2 35.2l2.6 2.4L278 271.1V240.9L50.3 13.2l-2.6 2.4z" fill="url(#gpA)"/>
  <path d="M358.4 351.5l-80.4-80.4v-30.2l80.4-80.4 1.8 1 95.3 54.1c27.2 15.4 27.2 40.7 0 56.2l-95.3 54.1-1.8 5.6z" fill="url(#gpB)"/>
  <path d="M360.2 345.9L278 263.7 50.3 491.4c9 9.5 23.8 10.7 40.5 1.3l269.4-146.8z" fill="url(#gpC)"/>
  <path d="M360.2 166.1L90.8 19.3C74.1 9.9 59.3 11.1 50.3 20.6L278 248.3l82.2-82.2z" fill="url(#gpD)"/>
  <defs>
    <linearGradient id="gpA" x1="256.7" y1="469.7" x2="38.7" y2="251.7" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#00A0FF"/><stop offset=".01" stop-color="#00A1FF"/><stop offset=".26" stop-color="#00BEFF"/><stop offset=".51" stop-color="#00D2FF"/><stop offset=".76" stop-color="#00DFFF"/><stop offset="1" stop-color="#00E3FF"/>
    </linearGradient>
    <linearGradient id="gpB" x1="480.9" y1="256" x2="33.8" y2="256" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFE000"/><stop offset=".41" stop-color="#FFBD00"/><stop offset=".78" stop-color="#FFA500"/><stop offset="1" stop-color="#FF9C00"/>
    </linearGradient>
    <linearGradient id="gpC" x1="300.9" y1="286.6" x2="108.9" y2="478.6" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FF3A44"/><stop offset="1" stop-color="#C31162"/>
    </linearGradient>
    <linearGradient id="gpD" x1="94.4" y1="48" x2="242.4" y2="196" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#32A071"/><stop offset=".07" stop-color="#2DA771"/><stop offset=".48" stop-color="#15CF74"/><stop offset=".8" stop-color="#06E775"/><stop offset="1" stop-color="#00F076"/>
    </linearGradient>
  </defs>
</svg>
`;

const appleSvg = `
<svg width="22" height="22" viewBox="0 0 170 170" fill="#2E2422" xmlns="http://www.w3.org/2000/svg">
  <path d="M150.37 130.25c-2.45 5.66-5.35 10.87-8.71 15.66-4.58 6.53-8.33 11.05-11.22 13.56-4.48 4.12-9.28 6.23-14.42 6.35-3.69 0-8.14-1.05-13.32-3.18-5.19-2.12-9.97-3.17-14.34-3.17-4.58 0-9.49 1.05-14.75 3.17-5.26 2.13-9.5 3.24-12.74 3.35-4.35.13-9.16-1.9-14.42-6.08-3.7-3.08-7.71-7.98-12.04-14.7-5.99-9.35-10.74-20.12-14.25-32.32-3.51-12.2-5.27-23.77-5.27-34.72 0-14.04 3.63-25.79 10.89-35.25 7.26-9.46 16.29-14.34 27.09-14.65 4.58 0 9.77 1.25 15.58 3.75 5.81 2.5 9.76 3.86 11.84 4.08 1.96-.22 5.96-1.58 12.01-4.08 6.05-2.5 11.13-3.69 15.24-3.57 11.45.65 20.73 4.89 27.84 12.72-9.91 5.99-14.77 14.37-14.58 25.14.22 8.49 3.51 15.72 9.87 21.7 6.36 5.98 13.93 9.4 22.71 10.25-2.29 6.86-5.12 13.78-8.49 20.76zM119.22 33.15c0-6.75 2.45-13.12 7.35-19.11 4.9-5.99 10.9-9.8 18-11.44.22 1.31.33 2.51.33 3.6 0 6.64-2.56 13.06-7.68 19.26-5.12 6.2-11.27 10.02-18.45 11.46-.44-1.31-.66-2.56-.66-3.77z"/>
</svg>
`;

const fontImports = `
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700;800;900&family=Montserrat:wght@400;500;600;700;800;900&family=Playfair+Display:ital,wght@0,600;0,700;1,600;1,700&display=swap" rel="stylesheet">
`;

function getCommonCSS() {
  return `
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #FAF8F5;
      font-family: 'Montserrat', sans-serif;
      color: #2E2422;
      position: relative;
      overflow: hidden;
      -webkit-font-smoothing: antialiased;
    }
    .gold-frame {
      position: absolute;
      top: 24px; left: 24px; right: 24px; bottom: 24px;
      border: 2px solid #C59B27;
      border-radius: 20px;
      pointer-events: none;
      z-index: 20;
    }
    .gold-frame-inner {
      position: absolute;
      top: 32px; left: 32px; right: 32px; bottom: 32px;
      border: 1px solid rgba(197, 155, 39, 0.35);
      border-radius: 15px;
      pointer-events: none;
      z-index: 20;
    }
    .ornament-divider {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 16px;
      width: 100%;
    }
    .ornament-line {
      height: 1px;
      flex: 1;
      max-width: 140px;
      background: linear-gradient(90deg, transparent, #C59B27, transparent);
    }
    .ornament-diamond {
      width: 8px;
      height: 8px;
      background: #C59B27;
      transform: rotate(45deg);
    }
  `;
}

// =========================================================================
// PART 1: VIDEO 4:3 & AUDIO MP3
// =========================================================================
function procesarVideo() {
  const ffmpegBin = process.env.FFMPEG_BIN || 'ffmpeg';

  // 1. Convertir Audio a MP3 si se proveyó audioSrc
  if (OBRA.audioSrc && fs.existsSync(OBRA.audioSrc)) {
    console.log(`--- Convirtiendo Audio a MP3 (320k) ---`);
    const dstMp3Muse = path.join(museDir, `${OBRA.titulo}.mp3`);
    const dstMp3Proj = path.join(outBaseDir, `${OBRA.titulo}.mp3`);
    const cmdMp3 = `"${ffmpegBin}" -y -i "${OBRA.audioSrc}" -c:a libmp3lame -b:a 320k "${dstMp3Muse}"`;
    execSync(cmdMp3, { stdio: 'inherit' });
    fs.copyFileSync(dstMp3Muse, dstMp3Proj);
    console.log(`Audio MP3 guardado en: ${dstMp3Muse} y ${dstMp3Proj}`);
  }

  if (!fs.existsSync(OBRA.videoSrc)) {
    console.log(`[Video] Archivo no encontrado: ${OBRA.videoSrc}. Se omite video.`);
    return;
  }
  const dstMuse = path.join(museDir, `${OBRA.titulo}_4_3.mp4`);
  const dstProj = path.join(outVideosDir, `${OBRA.slug}-satb-4x3.mp4`);

  console.log(`--- Recortando Video a 4:3 (1904x1428) ---`);
  const vf = OBRA.videoFiltro || 'crop=1904:1428:324:4';
  let cmd;
  if (OBRA.audioSrc && fs.existsSync(OBRA.audioSrc)) {
    console.log(`--- Sincronizando con Audio Externo (${OBRA.audioSrc}) con delay ${OBRA.audioDelayMs || 0}ms ---`);
    const dur = (OBRA.videoCorteFin - OBRA.videoCorteInicio).toFixed(3);
    const fadeStart = (dur - 0.2).toFixed(3);
    const delay = OBRA.audioDelayMs || 0;
    cmd = `"${ffmpegBin}" -y -ss ${OBRA.videoCorteInicio} -to ${OBRA.videoCorteFin} -i "${OBRA.videoSrc}" -i "${OBRA.audioSrc}" -filter_complex "[0:v]${vf}[vout];[1:a]adelay=${delay}|${delay},atrim=0:${dur},asetpts=PTS-STARTPTS,afade=t=out:st=${fadeStart}:d=0.2[aout]" -map "[vout]" -map "[aout]" -c:v libx264 -crf 17 -preset fast -pix_fmt yuv420p -c:a aac -b:a 320k "${dstMuse}"`;
  } else {
    cmd = `"${ffmpegBin}" -y -ss ${OBRA.videoCorteInicio} -to ${OBRA.videoCorteFin} -i "${OBRA.videoSrc}" -vf "${vf}" -c:v libx264 -crf 17 -preset fast -pix_fmt yuv420p -c:a aac -b:a 320k "${dstMuse}"`;
  }
  execSync(cmd, { stdio: 'inherit' });
  fs.copyFileSync(dstMuse, dstProj);
  console.log(`Video guardado en: ${dstMuse} y ${dstProj}`);
}

// =========================================================================
// PART 2: PLANTILLAS HTML
// =========================================================================
function htmlTikTok3x4() {
  const arregloCol = OBRA.arreglo ? `
    <div class="info-col">
      <span class="info-label">Arreglo</span>
      <span class="info-val">${OBRA.arreglo}</span>
    </div>
  ` : '';

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  ${fontImports}
  <style>
    ${getCommonCSS()}
    body {
      width: 1080px; height: 1440px; display: flex; flex-direction: column;
      justify-content: space-between; align-items: center; padding: 60px 75px; text-align: center;
    }
    .top-section { position: relative; z-index: 10; display: flex; flex-direction: column; align-items: center; gap: 12px; }
    .emblem-img { width: 84px; height: 84px; object-fit: contain; filter: drop-shadow(0 4px 12px rgba(197, 155, 39, 0.25)); }
    .top-badge {
      display: inline-flex; align-items: center; gap: 10px; background: #FFFFFF; border: 2px solid #C59B27;
      padding: 8px 30px; border-radius: 30px; font-size: 13.5px; font-weight: 900; letter-spacing: 3.5px;
      color: #C59B27; text-transform: uppercase; box-shadow: 0 4px 14px rgba(197, 155, 39, 0.12);
    }
    .gold-dot { width: 6px; height: 6px; border-radius: 50%; background: #C59B27; }
    .middle-section { position: relative; z-index: 10; display: flex; flex-direction: column; align-items: center; gap: 20px; width: 100%; }
    .hymn-intro { font-size: 15px; font-weight: 800; letter-spacing: 4px; color: #8C6D3B; text-transform: uppercase; }
    .hymn-title { font-family: 'Cinzel', serif; font-size: 56px; font-weight: 900; line-height: 1.1; letter-spacing: 2px; color: #2E2422; }
    .hymn-subtitle { font-family: 'Playfair Display', serif; font-size: 26px; font-style: italic; color: #C59B27; font-weight: 700; margin-top: -6px; }
    .hymn-verse-quote { font-family: 'Playfair Display', serif; font-style: italic; font-size: 20.5px; font-weight: 600; line-height: 1.45; color: #59421A; max-width: 840px; padding: 0 10px; }
    .info-card {
      background: #FFFFFF; border: 1.8px solid rgba(197, 155, 39, 0.6); border-radius: 18px; padding: 20px 40px;
      box-shadow: 0 6px 20px rgba(46, 36, 34, 0.05); display: flex; flex-direction: column; gap: 12px; width: 100%; max-width: 820px;
    }
    .info-grid { display: flex; justify-content: space-around; align-items: center; gap: 30px; }
    .info-col { display: flex; flex-direction: column; gap: 5px; }
    .info-label { font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: 2px; color: #A3907C; }
    .info-val { font-size: 16px; font-weight: 800; color: #2E2422; }
    .bottom-section { position: relative; z-index: 10; display: flex; flex-direction: column; align-items: center; gap: 12px; width: 100%; }
    .stores-card {
      background: #FFFFFF; border: 1.5px solid rgba(197, 155, 39, 0.6); border-radius: 16px; padding: 12px 24px;
      display: flex; align-items: center; justify-content: space-around; width: 100%; max-width: 900px; box-shadow: 0 4px 16px rgba(46, 36, 34, 0.05);
    }
    .store-mini { display: flex; align-items: center; gap: 10px; text-align: left; }
    .store-text-col { display: flex; flex-direction: column; }
    .store-lbl { font-size: 9.5px; font-weight: 800; text-transform: uppercase; letter-spacing: 1.5px; color: #A3907C; }
    .store-tit { font-size: 13px; font-weight: 800; color: #2E2422; }
    .store-sub { font-weight: 600; color: #8C6D3B; }
    .footer-note { font-size: 12px; font-weight: 800; letter-spacing: 2.5px; color: #8C6D3B; text-transform: uppercase; }
  </style>
</head>
<body>
  <div class="gold-frame"></div>
  <div class="gold-frame-inner"></div>

  <div class="top-section">
    <img class="emblem-img" src="data:image/png;base64,${emblemB64}" alt="Emblema Sacro">
    <div class="top-badge">
      <div class="gold-dot"></div><span>CORO LLDM</span><div class="gold-dot"></div>
    </div>
  </div>

  <div class="middle-section">
    <span class="hymn-intro">Repertorio Coral</span>
    <h1 class="hymn-title">${OBRA.titulo}</h1>
    <span class="hymn-subtitle">${OBRA.subtitulo}</span>
    
    <div class="ornament-divider">
      <div class="ornament-line"></div><div class="ornament-diamond"></div><div class="ornament-line"></div>
    </div>

    <p class="hymn-verse-quote">${OBRA.cita}</p>

    <div class="info-card">
      <div class="info-grid">
        <div class="info-col">
          <span class="info-label">Autor</span>
          <span class="info-val">${OBRA.autor}</span>
        </div>
        ${arregloCol}
      </div>
    </div>
  </div>

  <div class="bottom-section">
    <div class="stores-card">
      <div class="store-mini">
        ${googlePlaySvg}
        <div class="store-text-col"><span class="store-lbl">Google Play</span><span class="store-tit">Coro LLDM <span class="store-sub">(audios por voces)</span></span></div>
      </div>
      <div class="store-mini">
        ${appleSvg}
        <div class="store-text-col"><span class="store-lbl">App Store</span><span class="store-tit">Coro LLDM</span></div>
      </div>
      <div class="store-mini">
        <img style="width:20px;height:20px;border-radius:4px;" src="data:image/png;base64,${iconB64}">
        <div class="store-text-col"><span class="store-lbl">Sitio Web</span><span class="store-tit store-sub">www.lldmcoro.com</span></div>
      </div>
    </div>
    <div class="footer-note">• CORO LLDM • WWW.LLDMCORO.COM •</div>
  </div>
</body>
</html>
  `;
}

function htmlFacebook1x1() {
  const arregloCol = OBRA.arreglo ? `
    <div class="info-col">
      <span class="info-label">Arreglo</span>
      <span class="info-val">${OBRA.arreglo}</span>
    </div>
  ` : '';

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  ${fontImports}
  <style>
    ${getCommonCSS()}
    body {
      width: 1080px; height: 1080px; display: flex; flex-direction: column;
      justify-content: space-between; align-items: center; padding: 44px 60px 36px; text-align: center;
    }
    .top-section { position: relative; z-index: 10; display: flex; flex-direction: column; align-items: center; gap: 10px; }
    .emblem-img { width: 72px; height: 72px; object-fit: contain; filter: drop-shadow(0 3px 10px rgba(197, 155, 39, 0.25)); }
    .top-badge {
      display: inline-flex; align-items: center; gap: 10px; background: #FFFFFF; border: 2px solid #C59B27;
      padding: 7px 26px; border-radius: 30px; font-size: 13px; font-weight: 900; letter-spacing: 3px;
      color: #C59B27; text-transform: uppercase;
    }
    .gold-dot { width: 6px; height: 6px; border-radius: 50%; background: #C59B27; }
    .middle-section { position: relative; z-index: 10; display: flex; flex-direction: column; align-items: center; gap: 16px; width: 100%; }
    .hymn-intro { font-size: 14px; font-weight: 800; letter-spacing: 3.5px; color: #8C6D3B; text-transform: uppercase; }
    .hymn-title { font-family: 'Cinzel', serif; font-size: 50px; font-weight: 900; line-height: 1.1; letter-spacing: 1.8px; color: #2E2422; }
    .hymn-subtitle { font-family: 'Playfair Display', serif; font-size: 24px; font-style: italic; color: #C59B27; font-weight: 700; margin-top: -6px; }
    .hymn-verse-quote { font-family: 'Playfair Display', serif; font-style: italic; font-size: 19px; font-weight: 600; line-height: 1.4; color: #59421A; max-width: 820px; }
    .info-card {
      background: #FFFFFF; border: 1.8px solid rgba(197, 155, 39, 0.6); border-radius: 16px; padding: 16px 36px;
      display: flex; flex-direction: column; gap: 10px; width: 100%; max-width: 800px; box-shadow: 0 4px 16px rgba(46, 36, 34, 0.05);
    }
    .info-grid { display: flex; justify-content: space-around; align-items: center; gap: 24px; }
    .info-col { display: flex; flex-direction: column; gap: 4px; }
    .info-label { font-size: 10px; font-weight: 800; text-transform: uppercase; letter-spacing: 1.5px; color: #A3907C; }
    .info-val { font-size: 15px; font-weight: 800; color: #2E2422; }
    .bottom-section { position: relative; z-index: 10; display: flex; flex-direction: column; align-items: center; gap: 10px; width: 100%; }
    .stores-card {
      background: #FFFFFF; border: 1.5px solid rgba(197, 155, 39, 0.6); border-radius: 14px; padding: 10px 22px;
      display: flex; align-items: center; justify-content: space-around; width: 100%; max-width: 860px;
    }
    .store-mini { display: flex; align-items: center; gap: 9px; text-align: left; }
    .store-lbl { font-size: 9px; font-weight: 800; text-transform: uppercase; letter-spacing: 1.2px; color: #A3907C; }
    .store-tit { font-size: 12.5px; font-weight: 800; color: #2E2422; }
    .footer-note { font-size: 11.5px; font-weight: 800; letter-spacing: 2px; color: #8C6D3B; text-transform: uppercase; }
  </style>
</head>
<body>
  <div class="gold-frame"></div>
  <div class="gold-frame-inner"></div>

  <div class="top-section">
    <img class="emblem-img" src="data:image/png;base64,${emblemB64}" alt="Emblema Sacro">
    <div class="top-badge">
      <div class="gold-dot"></div><span>CORO LLDM</span><div class="gold-dot"></div>
    </div>
  </div>

  <div class="middle-section">
    <span class="hymn-intro">Repertorio Coral</span>
    <h1 class="hymn-title">${OBRA.titulo}</h1>
    <span class="hymn-subtitle">${OBRA.subtitulo}</span>

    <div class="ornament-divider">
      <div class="ornament-line"></div><div class="ornament-diamond"></div><div class="ornament-line"></div>
    </div>

    <p class="hymn-verse-quote">${OBRA.cita}</p>

    <div class="info-card">
      <div class="info-grid">
        <div class="info-col"><span class="info-label">Autor</span><span class="info-val">${OBRA.autor}</span></div>
        ${arregloCol}
      </div>
    </div>
  </div>

  <div class="bottom-section">
    <div class="stores-card">
      <div class="store-mini">${googlePlaySvg}<div class="store-text-col"><span class="store-lbl">Google Play</span><span class="store-tit">Coro LLDM</span></div></div>
      <div class="store-mini">${appleSvg}<div class="store-text-col"><span class="store-lbl">App Store</span><span class="store-tit">Coro LLDM</span></div></div>
      <div class="store-mini"><img style="width:19px;height:19px;border-radius:4px;" src="data:image/png;base64,${iconB64}"><div class="store-text-col"><span class="store-lbl">Sitio Web</span><span class="store-tit" style="color:#8C6D3B;font-weight:600;">www.lldmcoro.com</span></div></div>
    </div>
    <div class="footer-note">• CORO LLDM • WWW.LLDMCORO.COM •</div>
  </div>
</body>
</html>
  `;
}

function htmlYouTube(voiceTitle) {
  const isEnsemble = !voiceTitle || voiceTitle === 'ENSAMBLE';
  const badgeText = isEnsemble ? 'AUDIOS POR VOCES · GUÍA CORAL' : `PISTA EN PIANO · VOZ ${voiceTitle}`;
  const pillText = isEnsemble ? 'ENSAMBLE CORAL COMPLETO' : `GUÍA DE ESTUDIO · ${voiceTitle}`;
  const arregloTag = OBRA.arreglo ? `<span class="meta-sep">•</span><span class="meta-tag-item">Arreglo: <strong>${OBRA.arreglo}</strong></span>` : '';

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  ${fontImports}
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      width: 1920px; height: 1080px; background: #FAF8F5; font-family: 'Montserrat', sans-serif;
      color: #2E2422; position: relative; overflow: hidden; display: flex; flex-direction: column;
      justify-content: space-between; align-items: center; padding: 45px 90px 40px; text-align: center; -webkit-font-smoothing: antialiased;
    }
    .gold-frame { position: absolute; top: 24px; left: 24px; right: 24px; bottom: 24px; border: 2px solid #C59B27; border-radius: 20px; pointer-events: none; z-index: 20; }
    .gold-frame-inner { position: absolute; top: 32px; left: 32px; right: 32px; bottom: 32px; border: 1px solid rgba(197, 155, 39, 0.35); border-radius: 15px; pointer-events: none; z-index: 20; }
    .top-section { position: relative; z-index: 10; display: flex; align-items: center; justify-content: center; gap: 16px; }
    .emblem-img { width: 72px; height: 72px; object-fit: contain; filter: drop-shadow(0 3px 8px rgba(197, 155, 39, 0.25)); }
    .top-badge {
      display: inline-flex; align-items: center; gap: 12px; background: #FFFFFF; border: 2px solid #C59B27;
      padding: 8px 32px; border-radius: 30px; font-size: 14px; font-weight: 900; letter-spacing: 3.5px;
      color: #C59B27; text-transform: uppercase; box-shadow: 0 4px 14px rgba(197, 155, 39, 0.12);
    }
    .gold-dot { width: 6px; height: 6px; border-radius: 50%; background: #C59B27; }
    .center-section { position: relative; z-index: 10; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 14px; width: 100%; max-width: 1680px; margin: auto 0; }
    .eyebrow { font-size: 18px; font-weight: 900; letter-spacing: 5px; color: #8C6D3B; text-transform: uppercase; }
    .hymn-title-huge { font-family: 'Cinzel', serif; font-size: 74px; font-weight: 900; line-height: 1.05; letter-spacing: 3px; color: #2E2422; text-shadow: 0 2px 10px rgba(46, 36, 34, 0.04); }
    .hymn-sub-huge { font-family: 'Playfair Display', serif; font-size: 34px; font-style: italic; color: #C59B27; font-weight: 700; }
    .ornament-divider { display: flex; align-items: center; justify-content: center; gap: 20px; width: 100%; margin: 4px 0; }
    .ornament-line { height: 1.5px; width: 220px; background: linear-gradient(90deg, transparent, #C59B27, transparent); }
    .ornament-diamond { width: 9px; height: 9px; background: #C59B27; transform: rotate(45deg); }
    .voice-strip {
      display: inline-flex; align-items: center; gap: 16px; background: #FFFFFF; border: 2px solid #C59B27;
      padding: 10px 42px; border-radius: 40px; box-shadow: 0 6px 20px rgba(197, 155, 39, 0.15); margin-top: 4px;
    }
    .voice-strip-txt { font-family: 'Cinzel', serif; font-size: 24px; font-weight: 900; letter-spacing: 3px; color: #8C6D3B; text-transform: uppercase; }
    .meta-tags-line { display: flex; align-items: center; gap: 24px; margin-top: 8px; }
    .meta-tag-item { font-size: 18px; font-weight: 700; color: #4A3C38; letter-spacing: 1px; }
    .meta-tag-item strong { color: #C59B27; font-weight: 800; }
    .meta-sep { color: #C59B27; font-size: 16px; }
    .bottom-section { position: relative; z-index: 10; display: flex; align-items: center; justify-content: space-between; width: 100%; max-width: 1720px; padding: 0 20px; }
    .stores-card-horiz {
      display: flex; align-items: center; gap: 24px; background: #FFFFFF; border: 1.5px solid rgba(197, 155, 39, 0.6);
      border-radius: 30px; padding: 8px 32px; box-shadow: 0 4px 16px rgba(46, 36, 34, 0.05);
    }
    .store-mini { display: flex; align-items: center; gap: 10px; text-align: left; }
    .store-lbl { font-size: 9.5px; font-weight: 800; text-transform: uppercase; letter-spacing: 1.2px; color: #A3907C; }
    .store-tit { font-size: 13px; font-weight: 800; color: #2E2422; }
    .store-sub { color: #8C6D3B; font-weight: 600; }
    .footer-note-right { font-size: 13px; font-weight: 800; letter-spacing: 2.5px; color: #8C6D3B; text-transform: uppercase; }
  </style>
</head>
<body>
  <div class="gold-frame"></div>
  <div class="gold-frame-inner"></div>

  <div class="top-section">
    <img class="emblem-img" src="data:image/png;base64,${emblemB64}" alt="Emblema Sacro">
    <div class="top-badge"><div class="gold-dot"></div><span>${badgeText}</span><div class="gold-dot"></div></div>
  </div>

  <div class="center-section">
    <span class="eyebrow">Repertorio Coral</span>
    <h1 class="hymn-title-huge">${OBRA.titulo}</h1>
    <span class="hymn-sub-huge">${OBRA.subtitulo}</span>

    <div class="ornament-divider">
      <div class="ornament-line"></div><div class="ornament-diamond"></div><div class="ornament-line"></div>
    </div>

    <div class="voice-strip"><span class="voice-strip-txt">${pillText}</span></div>

    <div class="meta-tags-line">
      <span class="meta-tag-item">Autor: <strong>${OBRA.autor}</strong></span>
      ${arregloTag}
    </div>
  </div>

  <div class="bottom-section">
    <div class="stores-card-horiz">
      <div class="store-mini">${googlePlaySvg}<div><div class="store-lbl">Google Play</div><div class="store-tit">Coro LLDM</div></div></div>
      <div class="store-mini">${appleSvg}<div><div class="store-lbl">App Store</div><div class="store-tit">Coro LLDM</div></div></div>
      <div class="store-mini"><img style="width:20px;height:20px;border-radius:4px;" src="data:image/png;base64,${iconB64}"><div><div class="store-lbl">Sitio Web</div><div class="store-tit store-sub">www.lldmcoro.com</div></div></div>
    </div>
    <div class="footer-note-right">• CORO LLDM • WWW.LLDMCORO.COM •</div>
  </div>
</body>
</html>
  `;
}

function htmlVideoFrame9x16() {
  const arregloTag = OBRA.arreglo ? `<span class="meta-separator">•</span><span class="meta-tag">Arreglo: <strong>${OBRA.arreglo}</strong></span>` : '';

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  ${fontImports}
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      width: 1080px; height: 1920px; background-color: #FFFFFF !important; font-family: 'Montserrat', sans-serif;
      color: #2E2422; position: relative; overflow: hidden; -webkit-font-smoothing: antialiased;
    }
    .outer-frame { position: absolute; top: 24px; left: 24px; right: 24px; bottom: 24px; border: 2px solid #C59B27; border-radius: 24px; pointer-events: none; z-index: 20; }
    .inner-frame { position: absolute; top: 34px; left: 34px; right: 34px; bottom: 34px; border: 1px solid rgba(197, 155, 39, 0.35); border-radius: 18px; pointer-events: none; z-index: 20; }
    .screen-layout { position: relative; z-index: 10; width: 100%; height: 1920px; display: flex; flex-direction: column; justify-content: space-between; align-items: center; }
    .header-safe-zone { margin-top: 80px; display: flex; flex-direction: column; align-items: center; text-align: center; width: 960px; gap: 12px; }
    .header-emblem-row { display: flex; align-items: center; gap: 16px; }
    .emblem-mini { width: 68px; height: 68px; object-fit: contain; filter: drop-shadow(0 3px 10px rgba(197, 155, 39, 0.25)); }
    .top-badge {
      display: inline-flex; align-items: center; gap: 10px; background: #FFFFFF; border: 2px solid #C59B27;
      padding: 8px 28px; border-radius: 30px; font-size: 14px; font-weight: 900; letter-spacing: 3.5px;
      color: #C59B27; text-transform: uppercase;
    }
    .gold-dot { width: 6px; height: 6px; border-radius: 50%; background: #C59B27; }
    .hymn-title { font-family: 'Cinzel', serif; font-size: 46px; font-weight: 900; color: #2E2422; letter-spacing: 1.8px; line-height: 1.12; }
    .hymn-subtitle { font-family: 'Playfair Display', serif; font-size: 26px; font-style: italic; color: #C59B27; font-weight: 700; margin-top: -4px; }
    .hymn-meta-row {
      display: flex; align-items: center; justify-content: center; gap: 18px; background: #FFFFFF;
      border: 1.5px solid rgba(197, 155, 39, 0.6); padding: 9px 32px; border-radius: 20px; box-shadow: 0 4px 14px rgba(46, 36, 34, 0.04); max-width: 920px;
    }
    .meta-tag { font-size: 13.5px; font-weight: 700; color: #2E2422; letter-spacing: 0.5px; }
    .meta-tag strong { color: #C59B27; font-weight: 800; }
    .meta-separator { color: #C59B27; font-size: 14px; }
    .footer-safe-zone { margin-bottom: 210px; display: flex; flex-direction: column; align-items: center; text-align: center; width: 900px; gap: 16px; }
    .stores-card {
      background: #FFFFFF; border: 1.5px solid rgba(197, 155, 39, 0.6); border-radius: 16px; padding: 12px 28px;
      display: flex; align-items: center; justify-content: space-around; width: 100%; box-shadow: 0 4px 16px rgba(46, 36, 34, 0.04);
    }
    .store-mini { display: flex; align-items: center; gap: 10px; text-align: left; }
    .store-text-col { display: flex; flex-direction: column; }
    .store-lbl { font-size: 9.5px; font-weight: 800; text-transform: uppercase; letter-spacing: 1.5px; color: #A3907C; }
    .store-tit { font-size: 13px; font-weight: 800; color: #2E2422; }
    .store-sub { font-weight: 600; color: #8C6D3B; }
    .footer-note { font-size: 12px; font-weight: 800; letter-spacing: 2.5px; color: #8C6D3B; text-transform: uppercase; }
  </style>
</head>
<body>
  <div class="outer-frame"></div>
  <div class="inner-frame"></div>

  <div class="screen-layout">
    <div class="header-safe-zone">
      <div class="header-emblem-row">
        <img class="emblem-mini" src="data:image/png;base64,${emblemB64}" alt="Emblema Sacro">
        <div class="top-badge"><div class="gold-dot"></div><span>PARTITURA CORAL · ESTUDIO VOCAL</span><div class="gold-dot"></div></div>
      </div>
      <h1 class="hymn-title">${OBRA.titulo}</h1>
      <span class="hymn-subtitle">${OBRA.subtitulo}</span>

      <div class="hymn-meta-row">
        <span class="meta-tag">Autor: <strong>${OBRA.autor}</strong></span>
        ${arregloTag}
      </div>
    </div>

    <!-- AREA CENTRAL 4:3 (y=555 a 1365 px) RESERVADA PARA EL VIDEO -->

    <div class="footer-safe-zone">
      <div class="stores-card">
        <div class="store-mini">${googlePlaySvg}<div class="store-text-col"><span class="store-lbl">Google Play</span><span class="store-tit">Coro LLDM <span class="store-sub">(audios por voces)</span></span></div></div>
        <div class="store-mini">${appleSvg}<div class="store-text-col"><span class="store-lbl">App Store</span><span class="store-tit">Coro LLDM</span></div></div>
        <div class="store-mini"><img style="width:20px;height:20px;border-radius:4px;" src="data:image/png;base64,${iconB64}"><div class="store-text-col"><span class="store-lbl">Sitio Web</span><span class="store-tit store-sub">www.lldmcoro.com</span></div></div>
      </div>
      <div class="footer-note">• CORO LLDM • WWW.LLDMCORO.COM •</div>
    </div>
  </div>
</body>
</html>
  `;
}

// =========================================================================
// RENDERIZADO PLAYWRIGHT + SHARP (JPG 96 4:4:4)
// =========================================================================
async function renderCard(browser, html, outputPath, w, h) {
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  await page.setContent(html, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await new Promise(r => setTimeout(r, 600));

  const pngBuffer = await page.screenshot({ type: 'png' });
  await page.close();

  await sharp(pngBuffer).jpeg({ quality: 96, chromaSubsampling: '4:4:4' }).toFile(outputPath);
  console.log(`[Gráfico] Generado: ${outputPath}`);
}

async function generarGraficos() {
  const browser = await chromium.launch({
    headless: true,
    executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
  });

  // 1. Fondo 9:16
  await renderCard(browser, htmlVideoFrame9x16(), path.join(outBaseDir, `fondo-video-${OBRA.slug}.jpg`), 1080, 1920);

  // 2. TikTok 3:4
  await renderCard(browser, htmlTikTok3x4(), path.join(outPortadasDir, `portada-tiktok-${OBRA.slug}-3x4.jpg`), 1080, 1440);

  // 3. Facebook 1:1
  await renderCard(browser, htmlFacebook1x1(), path.join(outPortadasDir, `portada-facebook-${OBRA.slug}-1x1.jpg`), 1080, 1080);

  // 4. YouTube Ensamble 16:9
  const ytMaster = path.join(outPortadasDir, `portada-youtube-${OBRA.slug}-16x9.jpg`);
  await renderCard(browser, htmlYouTube('ENSAMBLE'), ytMaster, 1920, 1080);
  fs.copyFileSync(ytMaster, path.join(outPortadasDir, `portada-youtube-${OBRA.slug}-ensamble-16x9.jpg`));

  // 5. YouTube Voces 16:9
  for (const voz of ['SOPRANO', 'CONTRALTO', 'TENOR', 'BAJO']) {
    await renderCard(browser, htmlYouTube(voz), path.join(outPortadasDir, `portada-youtube-${OBRA.slug}-${voz.toLowerCase()}-16x9.jpg`), 1920, 1080);
  }

  await browser.close();
}

async function main() {
  console.log(`Iniciando pipeline para: ${OBRA.titulo}`);
  procesarVideo();
  await generarGraficos();
  console.log(`Pipeline concluido exitosamente.`);
}

main().catch(console.error);
