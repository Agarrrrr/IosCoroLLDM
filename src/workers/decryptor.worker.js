/**
 * DECRYPTOR WORKER — Off-thread AES-GCM decryption
 * 
 * Mueve fetch + crypto.subtle.decrypt al hilo de Worker para no bloquear
 * jamás el hilo principal de JavaScript (UI Thread) al abrir una partitura.
 * 
 * Protocolo de mensajes:
 *   → { id, url }                       Solicitud de desencriptado
 *   ← { id, buffer }  (Transferable)    Éxito — ArrayBuffer listo para uso
 *   ← { id, error }                     Fallo con mensaje de error
 */

// Caché interna del worker para no repetir fetch+decrypt de la misma URL
const cache = new Map(); // url → ArrayBuffer

self.onmessage = async ({ data }) => {
    const { id, url } = data;

    try {
        // Cache-hit: devolver inmediatamente sin re-desencriptar
        if (cache.has(url)) {
            const cached = cache.get(url);
            // Clonar para poder transferir (el original queda en la caché del worker)
            const clone = cached.slice(0);
            self.postMessage({ id, buffer: clone }, [clone]);
            return;
        }

        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP ${response.status} al descargar ${url}`);

        const encryptedBuffer = await response.arrayBuffer();

        // Verificar si el archivo ya viene sin encriptar (PDF o MIDI directo)
        const previewLength = Math.min(encryptedBuffer.byteLength, 1024);
        const headerBytes = new Uint8Array(encryptedBuffer, 0, previewLength);
        const headerStr = String.fromCharCode(...headerBytes);

        let resultBuffer;

        if (headerStr.includes('%PDF') || headerStr.startsWith('MThd')) {
            // Archivo limpio — devolver directamente (slice para poder transferir)
            resultBuffer = encryptedBuffer.slice(0);
        } else {
            // Desencriptar AES-GCM — idéntico al decryptor.js del hilo principal
            const rawKeyString = 'repertorio-coral-lldm-key-2026';
            const encoder = new TextEncoder();

            const hashBuffer = await self.crypto.subtle.digest(
                'SHA-256',
                encoder.encode(rawKeyString)
            );

            const cryptoKey = await self.crypto.subtle.importKey(
                'raw',
                hashBuffer,
                { name: 'AES-GCM' },
                false,
                ['decrypt']
            );

            const iv = encryptedBuffer.slice(0, 12);
            const dataWithTag = encryptedBuffer.slice(12);

            resultBuffer = await self.crypto.subtle.decrypt(
                { name: 'AES-GCM', iv: new Uint8Array(iv) },
                cryptoKey,
                dataWithTag
            );
        }

        // Guardar en caché interna del worker (para hot-swaps bilingüe / re-aperturas)
        // Máximo 3 entradas para no saturar la memoria del worker
        if (cache.size >= 3) {
            const firstKey = cache.keys().next().value;
            cache.delete(firstKey);
        }
        cache.set(url, resultBuffer.slice(0));

        // Transferir el buffer sin copia de memoria al hilo principal
        self.postMessage({ id, buffer: resultBuffer }, [resultBuffer]);

    } catch (err) {
        self.postMessage({ id, error: err.message || String(err) });
    }
};
