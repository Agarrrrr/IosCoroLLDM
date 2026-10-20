import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execFileSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const rootDir = path.resolve(__dirname, '..');
const projectsDir = process.env.COROLLDM_PROJECTS_DIR
    ? path.resolve(process.env.COROLLDM_PROJECTS_DIR)
    : path.resolve(rootDir, '..');
const localAssetsDir = path.join(rootDir, 'public', 'offline_assets');
const iosAssetsDir = process.env.IOS_COROLLDM_ASSETS_DIR
    ? path.resolve(process.env.IOS_COROLLDM_ASSETS_DIR)
    : path.join(projectsDir, 'IosCoroLLDM', 'assets');
const iosOfflineAssetsDir = path.join(iosAssetsDir, 'offline_assets');
const repertorioBcAssetsDir = process.env.REPERTORIO_BC_ASSETS_DIR
    ? path.resolve(process.env.REPERTORIO_BC_ASSETS_DIR)
    : path.join(projectsDir, 'repertorio_bc', 'assets');
const repertorioBcRootDir = path.dirname(repertorioBcAssetsDir);
const restoreSafeBaseline = process.argv.includes('--restore-safe-baseline');

console.log('=== Sincronizador de Catálogos JSON ===');

function loadJson(filePath) {
    if (!fs.existsSync(filePath)) return [];
    try {
        return JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch (e) {
        console.error(`Error leyendo ${filePath}:`, e.message);
        return [];
    }
}

function saveJson(filePath, data) {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
    console.log(`[OK] Guardado: ${filePath} (${data.length} cantos)`);
}

function normalizedSongKey(song, fallbackLanguage) {
    const language = song.idioma || song._idioma || fallbackLanguage;
    const name = String(song.nombre || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ' ')
        .trim();
    return `${language}:${name}`;
}

// Sustituye entradas legacy por su equivalente global sin perder cantos
// exclusivos del proyecto destino. También incorpora cantos globales nuevos.
function mergeGlobalCatalog(existing, globalCatalog, language) {
    const globalById = new Map(
        globalCatalog.filter(song => song.id).map(song => [song.id, song])
    );
    const globalByExternalId = new Map(
        globalCatalog.filter(song => song.external_id).map(song => [song.external_id, song])
    );
    const globalByKey = new Map(
        globalCatalog.map(song => [normalizedSongKey(song, language), song])
    );
    const consumed = new Set();
    const merged = existing.map(song => {
        const key = normalizedSongKey(song, language);
        const global = globalById.get(song.id)
            || globalByExternalId.get(song.id)
            || (song.external_id ? globalByExternalId.get(song.external_id) : null)
            || globalByKey.get(key);
        if (!global) return song;
        consumed.add(normalizedSongKey(global, language));
        const strongMatch = song.id === global.id
            || song.id === global.external_id
            || (song.external_id && song.external_id === global.external_id);

        if (strongMatch) {
            return { ...song, ...global, idioma: language, _idioma: language };
        }

        // Una coincidencia solo por nombre no es suficiente para sustituir un
        // arreglo local. Únicamente completa un MIDI que todavía no exista.
        return {
            ...song,
            midi_archivo: song.midi_archivo || global.midi_archivo || null,
            idioma: language,
            _idioma: language,
        };
    });

    for (const global of globalCatalog) {
        const key = normalizedSongKey(global, language);
        if (!consumed.has(key)) {
            merged.push({ ...global, idioma: language, _idioma: language });
        }
    }

    // Si el destino ya contenía una sombra legacy y también la fila global
    // canónica, conserva una sola. Los cantos exclusivos sin equivalente
    // global no se tocan.
    const canonicalIds = new Set(globalCatalog.map(song => song.id).filter(Boolean));
    const deduplicated = new Map();
    for (const song of merged) {
        const key = normalizedSongKey(song, language);
        const current = deduplicated.get(key);
        if (!current || (canonicalIds.has(song.id) && !canonicalIds.has(current.id))) {
            deduplicated.set(key, song);
        }
    }

    return [...deduplicated.values()].sort((a, b) => String(a.nombre || '').localeCompare(
        String(b.nombre || ''),
        language,
        { sensitivity: 'base', numeric: true }
    ));
}

function loadCommittedCatalog(relativePath) {
    return JSON.parse(execFileSync('git', ['show', `HEAD:${relativePath}`], {
        cwd: repertorioBcRootDir,
        encoding: 'utf8',
    }));
}

// 1. Cargar catálogos locales principales
const catEsPath = path.join(localAssetsDir, 'catalogo.json');
const catEnPath = path.join(localAssetsDir, 'catalogo_en.json');

const cantosEs = loadJson(catEsPath);
const cantosEn = loadJson(catEnPath);

console.log(`Catálogo Español en Web/PWA: ${cantosEs.length} cantos`);
console.log(`Catálogo Inglés en Web/PWA: ${cantosEn.length} cantos`);

// 2. Normalizar campos e idiomas
cantosEs.forEach(c => { c._idioma = 'es'; c.idioma = 'es'; });
cantosEn.forEach(c => { c._idioma = 'en'; c.idioma = 'en'; });

// 3. Sincronizar en proyecto iOS si el directorio existe
if (fs.existsSync(iosAssetsDir)) {
    console.log(`Sincronizando con proyecto iOS (${iosAssetsDir})...`);
    saveJson(path.join(iosAssetsDir, 'catalogo.json'), cantosEs);
    saveJson(path.join(iosAssetsDir, 'catalogo_en.json'), cantosEn);

    if (fs.existsSync(iosOfflineAssetsDir)) {
        saveJson(path.join(iosOfflineAssetsDir, 'catalogo.json'), cantosEs);
        saveJson(path.join(iosOfflineAssetsDir, 'catalogo_en.json'), cantosEn);
    }
    console.log('✔ Catálogos sincronizados exitosamente con iOS.');
} else {
    console.warn(`Ruta iOS no encontrada: ${iosAssetsDir}`);
}

// 4. Sincronizar el proyecto Flutter repertorio_bc. Este catálogo conservaba
// cientos de IDs legacy y por eso no reflejaba los MIDI globales nuevos.
if (fs.existsSync(repertorioBcAssetsDir)) {
    const flutterEsPath = path.join(repertorioBcAssetsDir, 'catalogo.json');
    const flutterEnPath = path.join(repertorioBcAssetsDir, 'catalogo_en.json');
    const flutterEsBase = restoreSafeBaseline
        ? loadCommittedCatalog('assets/catalogo.json')
        : loadJson(flutterEsPath);
    const flutterEnBase = restoreSafeBaseline
        ? loadCommittedCatalog('assets/catalogo_en.json')
        : loadJson(flutterEnPath);
    const flutterEs = mergeGlobalCatalog(flutterEsBase, cantosEs, 'es');
    const flutterEn = mergeGlobalCatalog(flutterEnBase, cantosEn, 'en');
    saveJson(flutterEsPath, flutterEs);
    saveJson(flutterEnPath, flutterEn);
    console.log('✔ Catálogos retroactivos sincronizados con repertorio_bc.');
} else {
    console.warn(`Ruta repertorio_bc no encontrada: ${repertorioBcAssetsDir}`);
}

// 5. Asegurar que public/offline_assets de este proyecto esté actualizado
saveJson(catEsPath, cantosEs);
saveJson(catEnPath, cantosEn);

console.log('=== Sincronización completada exitosamente ===');
