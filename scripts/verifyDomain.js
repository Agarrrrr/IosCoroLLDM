import fs from 'fs';
import path from 'path';

const OFFICIAL_DOMAIN = 'www.lldmcorobc.com';

const filesToCheck = [
  'twa-manifest.json',
  'app/build.gradle',
  'public/manifest.json'
];

let errors = 0;

console.log('🔍 Verificando consistencia del dominio oficial en manifiestos...');

for (const file of filesToCheck) {
  const filePath = path.resolve(process.cwd(), file);
  if (fs.existsSync(filePath)) {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    
    lines.forEach((line, index) => {
      // Si la línea tiene el dominio, pero NO tiene "www.", es un error
      if (line.includes('lldmcorobc.com') && !line.includes(OFFICIAL_DOMAIN)) {
        console.error(`❌ ERROR en ${file}:${index + 1}`);
        console.error(`   Línea: ${line.trim()}`);
        console.error(`   Motivo: Uso del dominio sin 'www.'. Android TWA requiere coincidencia exacta para delegar permisos de notificaciones.`);
        errors++;
      }
    });

    // Validar que los archivos críticos SÍ contengan el dominio oficial
    if (file === 'twa-manifest.json' || file === 'app/build.gradle') {
      if (!content.includes(OFFICIAL_DOMAIN)) {
        console.error(`❌ ERROR en ${file}: No se encontró el dominio oficial '${OFFICIAL_DOMAIN}'.`);
        errors++;
      }
    }
  }
}

if (errors > 0) {
  console.error(`\n🚨 Verificación fallida: Se encontraron ${errors} errores de dominio.`);
  console.error(`Por favor, usa estrictamente '${OFFICIAL_DOMAIN}' para no romper la PWA/TWA.\n`);
  process.exit(1);
} else {
  console.log(`✅ Verificación de dominio correcta. Todo en orden.`);
}
