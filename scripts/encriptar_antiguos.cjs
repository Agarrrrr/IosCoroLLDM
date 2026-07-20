const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ENCRYPTION_KEY = crypto.createHash('sha256').update('repertorio-coral-lldm-key-2026').digest();

function encryptBuffer(buffer) {
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', ENCRYPTION_KEY, iv);
    const encrypted = Buffer.concat([cipher.update(buffer), cipher.final()]);
    const authTag = cipher.getAuthTag();
    return Buffer.concat([iv, encrypted, authTag]);
}

async function encryptDirectory(dir) {
    const files = fs.readdirSync(dir);
    let count = 0;
    
    for (const file of files) {
        if (file.endsWith('.pdf') || file.endsWith('.mid')) {
            const filePath = path.join(dir, file);
            
            // Si el archivo ya fue encriptado (para evitar re-encriptar por accidente)
            // Chequeamos si mágicamente no parece ser un PDF o MIDI válido.
            const buffer = fs.readFileSync(filePath);
            
            // PDF empieza con %PDF
            // MIDI empieza con MThd
            const isPdf = buffer.slice(0, 4).toString() === '%PDF';
            const isMidi = buffer.slice(0, 4).toString() === 'MThd';
            
            if (isPdf || isMidi) {
                console.log(`Encriptando: ${file}`);
                const encrypted = encryptBuffer(buffer);
                fs.writeFileSync(filePath, encrypted);
                count++;
            } else {
                console.log(`Saltando (Ya parece estar encriptado): ${file}`);
            }
        }
    }
    return count;
}

async function main() {
    const pdfsDir = path.resolve(__dirname, '../public/offline_assets/pdfs');
    const midisDir = path.resolve(__dirname, '../public/offline_assets/midis');
    
    console.log("Iniciando encriptación de PDFs...");
    const pdfCount = await encryptDirectory(pdfsDir);
    
    console.log("\nIniciando encriptación de MIDIs...");
    const midiCount = await encryptDirectory(midisDir);
    
    console.log(`\n¡Listo! Se encriptaron ${pdfCount} PDFs y ${midiCount} MIDIs.`);
}

main().catch(console.error);
