export async function decryptArrayBuffer(encryptedBuffer) {
    const previewLength = Math.min(encryptedBuffer.byteLength, 1024);
    const headerBytes = new Uint8Array(encryptedBuffer, 0, previewLength);
    const headerStr = String.fromCharCode(...headerBytes);
    
    if (headerStr.includes('%PDF') || headerStr.startsWith('MThd')) {
        return encryptedBuffer; // No estaba encriptado, es un PDF o MIDI limpio
    }
    
    const rawKeyString = "repertorio-coral-lldm-key-2026";
    const encoder = new TextEncoder();
    
    const hashBuffer = await window.crypto.subtle.digest('SHA-256', encoder.encode(rawKeyString));
    
    const cryptoKey = await window.crypto.subtle.importKey(
        "raw",
        hashBuffer,
        { name: "AES-GCM" },
        false,
        ["decrypt"]
    );
    
    const iv = encryptedBuffer.slice(0, 12);
    const dataWithTag = encryptedBuffer.slice(12);
    
    const decryptedBuffer = await window.crypto.subtle.decrypt(
        { name: "AES-GCM", iv: new Uint8Array(iv) },
        cryptoKey,
        dataWithTag
    );
    
    return decryptedBuffer;
}

export async function decryptFileFromUrl(url) {
    try {
        const urlFinal = encodeURI(url);
        const response = await fetch(urlFinal);
        if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
        
        const encryptedBuffer = await response.arrayBuffer();
        return await decryptArrayBuffer(encryptedBuffer);
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
