export async function decryptFileFromUrl(url) {
    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
        
        const encryptedBuffer = await response.arrayBuffer();
        
        // Verificar si es un archivo plano (PDF o MIDI sin encriptar) por fallback
        // El estándar PDF permite que %PDF-1.x esté en los primeros 1024 bytes.
        const previewLength = Math.min(encryptedBuffer.byteLength, 1024);
        const headerBytes = new Uint8Array(encryptedBuffer, 0, previewLength);
        const headerStr = String.fromCharCode(...headerBytes);
        
        if (headerStr.includes('%PDF') || headerStr.startsWith('MThd')) {
            return encryptedBuffer; // No estaba encriptado, es un PDF o MIDI limpio
        }
        
        // El key usado para encriptar: sha256('repertorio-coral-lldm-key-2026')
        const rawKeyString = "repertorio-coral-lldm-key-2026";
        const encoder = new TextEncoder();
        
        // Crear el hash SHA-256 de la contraseña (idéntico al de NodeJS)
        const hashBuffer = await window.crypto.subtle.digest('SHA-256', encoder.encode(rawKeyString));
        
        // Importar como AES-GCM Key
        const cryptoKey = await window.crypto.subtle.importKey(
            "raw",
            hashBuffer,
            { name: "AES-GCM" },
            false,
            ["decrypt"]
        );
        
        // Extraer partes (12 bytes IV + Payload + 16 bytes Tag)
        // En AES-GCM estándar WebCrypto, el Tag va al final del ciphertext.
        // Node.js lo concatena así: [IV][Ciphertext][Tag]
        const iv = encryptedBuffer.slice(0, 12);
        const dataWithTag = encryptedBuffer.slice(12);
        
        const decryptedBuffer = await window.crypto.subtle.decrypt(
            { name: "AES-GCM", iv: new Uint8Array(iv) },
            cryptoKey,
            dataWithTag
        );
        
        return decryptedBuffer;
    } catch (e) {
        console.error("Error al desencriptar el archivo:", e);
        throw e;
    }
}

let _decryptWorker = null;
let _decryptPendingReqs = new Map();
let _decryptReqId = 0;

export function getDecryptWorker() {
    if (_decryptWorker) return _decryptWorker;
    try {
        _decryptWorker = new Worker(
            new URL('../workers/decryptor.worker.js', import.meta.url),
            { type: 'module' }
        );
        _decryptWorker.onmessage = ({ data }) => {
            const handler = _decryptPendingReqs.get(data.id);
            if (!handler) return;
            _decryptPendingReqs.delete(data.id);
            if (data.error) handler.reject(new Error(data.error));
            else handler.resolve(data.buffer);
        };
        _decryptWorker.onerror = (e) => {
            console.error('[DecryptWorker] Error fatal:', e.message);
            _decryptWorker = null;
        };
    } catch (e) {
        console.warn('[DecryptWorker] No se pudo instanciar, usando fallback síncrono:', e.message);
        _decryptWorker = null;
    }
    return _decryptWorker;
}

export async function decryptOffThread(url) {
    const worker = getDecryptWorker();
    if (!worker) {
        return decryptFileFromUrl(url);
    }
    return new Promise((resolve, reject) => {
        const id = ++_decryptReqId;
        _decryptPendingReqs.set(id, { resolve, reject });
        worker.postMessage({ id, url });
    });
}
