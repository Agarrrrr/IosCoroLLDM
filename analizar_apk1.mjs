import fs from 'fs';
import path from 'path';

const songsJsonPath = path.resolve('temp_xapk', 'apk1_unpacked', 'assets', 'flutter_assets', 'assets', 'data', 'songs.json');
const catalogoEsPath = path.resolve('public', 'offline_assets', 'catalogo.json');
const catalogoEnPath = path.resolve('public', 'offline_assets', 'catalogo_en.json');

try {
    const apkSongsRaw = JSON.parse(fs.readFileSync(songsJsonPath, 'utf8'));
    
    let apkNombres = [];
    if (Array.isArray(apkSongsRaw)) {
        apkNombres = apkSongsRaw.map(s => s.title || s.nombre || s.name);
    } else {
        apkNombres = Object.values(apkSongsRaw).map(s => s.title || s.nombre || s.name);
    }

    apkNombres = apkNombres.filter(Boolean);

    const catalogoEs = JSON.parse(fs.readFileSync(catalogoEsPath, 'utf8'));
    const catalogoEn = JSON.parse(fs.readFileSync(catalogoEnPath, 'utf8'));
    
    const normalize = (str) => str.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]/gi, "");

    const allLocalNombres = new Set();
    catalogoEs.forEach(c => c.nombre && allLocalNombres.add(normalize(c.nombre)));
    catalogoEn.forEach(c => c.nombre && allLocalNombres.add(normalize(c.nombre)));

    const faltantes = [];
    apkNombres.forEach(n => {
        const nom = normalize(n);
        if (!allLocalNombres.has(nom)) {
            faltantes.push(n);
        }
    });

    faltantes.sort((a,b) => a.localeCompare(b));
    fs.writeFileSync('faltantes_app1.txt', faltantes.join('\n'), 'utf8');

    console.log(`Guardados ${faltantes.length} faltantes en faltantes_app1.txt`);
} catch(e) {
    console.error(e);
}
