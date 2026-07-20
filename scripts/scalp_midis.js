import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';

// Read .env file manually since we are running a pure node script without dotenv
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

if (!supabaseUrl || !supabaseKey) {
    console.error("No se encontraron las variables de entorno de Supabase en .env");
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
    console.log("Conectando a Supabase para extraer cantos con MIDI...");

    // Fetch cantos that have a midi_archivo
    const { data, error } = await supabase
        .from('cantos')
        .select('id, nombre, archivo, midi_archivo, temas, es_privado')
        .not('midi_archivo', 'is', null)
        .order('nombre');

    if (error) {
        console.error("Error al obtener datos:", error);
        return;
    }

    // Filtrar los que tengan midi_archivo vacío
    const cantosConMidi = data.filter(c => c.midi_archivo && c.midi_archivo.trim() !== '');

    console.log(`Se encontraron ${cantosConMidi.length} cantos con MIDI integrado.`);

    // Guardar en un JSON en la carpeta del proyecto
    const outputPath = path.resolve('cantos_con_midi.json');
    fs.writeFileSync(outputPath, JSON.stringify(cantosConMidi, null, 2));

    console.log(`\n¡Extracción completada!`);
    console.log(`Los resultados se han guardado en: ${outputPath}`);
    
    // Opcional: mostrar los primeros 5
    console.log("\nPrimeros 5 cantos encontrados:");
    cantosConMidi.slice(0, 5).forEach(c => {
        console.log(`- ${c.nombre} (PDF: ${c.archivo}, MIDI: ${c.midi_archivo})`);
    });
}

main();
