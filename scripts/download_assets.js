import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';

// Parsear .env
const envPath = path.resolve('.env');
const envContent = fs.readFileSync(envPath, 'utf8');
const env = {};
envContent.split('\n').forEach(line => {
    const [key, ...values] = line.split('=');
    if (key && values.length > 0) {
        env[key.trim()] = values.join('=').trim();
    }
});

const supabaseUrl = env.VITE_SUPABASE_URL;
const supabaseKey = env.VITE_SUPABASE_ANON_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

// Directorios
const BASE_OUTPUT = path.resolve('offline_assets');
const PDF_DIR = path.join(BASE_OUTPUT, 'pdfs');
const MIDI_DIR = path.join(BASE_OUTPUT, 'midis');

// Crear carpetas si no existen
if (!fs.existsSync(BASE_OUTPUT)) fs.mkdirSync(BASE_OUTPUT, { recursive: true });
if (!fs.existsSync(PDF_DIR)) fs.mkdirSync(PDF_DIR, { recursive: true });
if (!fs.existsSync(MIDI_DIR)) fs.mkdirSync(MIDI_DIR, { recursive: true });

async function descargarArchivo(bucket, fileName, destPath) {
    if (!fileName) return;
    if (fs.existsSync(destPath)) {
        // console.log(`✓ Omitiendo (ya existe): ${fileName}`);
        return;
    }

    try {
        const { data, error } = await supabase.storage.from(bucket).download(fileName);
        if (error) {
            console.error(`❌ Error descargando ${fileName} de ${bucket}:`, error.message);
            return;
        }

        const buffer = Buffer.from(await data.arrayBuffer());
        fs.writeFileSync(destPath, buffer);
        console.log(`✅ Descargado: ${fileName}`);
    } catch (err) {
        console.error(`❌ Error inesperado descargando ${fileName}:`, err.message);
    }
}

async function main() {
    const jsonPath = path.resolve('cantos_con_midi.json');
    if (!fs.existsSync(jsonPath)) {
        console.error("No se encontró cantos_con_midi.json. Corre el primer script antes.");
        process.exit(1);
    }

    const cantos = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    console.log(`Iniciando descarga de ${cantos.length} cantos en /offline_assets...`);

    // Procesamos en lotes para no saturar la red (ej. 5 a la vez)
    const CONCURRENCY = 5;
    for (let i = 0; i < cantos.length; i += CONCURRENCY) {
        const batch = cantos.slice(i, i + CONCURRENCY);
        const promesas = [];

        for (const canto of batch) {
            if (canto.archivo) {
                const pdfPath = path.join(PDF_DIR, canto.archivo);
                promesas.push(descargarArchivo('partituras', canto.archivo, pdfPath));
            }
            if (canto.midi_archivo) {
                const midiPath = path.join(MIDI_DIR, canto.midi_archivo);
                promesas.push(descargarArchivo('midi_files', canto.midi_archivo, midiPath));
            }
        }

        await Promise.all(promesas);
        console.log(`[Progreso: ${Math.min(i + CONCURRENCY, cantos.length)} / ${cantos.length}]`);
    }

    // Copiamos el json también a la carpeta final
    const finalJsonPath = path.join(BASE_OUTPUT, 'catalogo.json');
    fs.copyFileSync(jsonPath, finalJsonPath);

    console.log(`\n🎉 ¡Todas las descargas han finalizado!`);
    console.log(`Tus recursos offline están listos en la carpeta: ${BASE_OUTPUT}`);
}

main();
