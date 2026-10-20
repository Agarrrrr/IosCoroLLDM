from pathlib import Path
root=Path('E:/proyectos/CoroLLDM')
p=root/'src/api/remoteCatalogDB.js'
s=p.read_text(encoding='utf-8')
s=s.replace('async function uploadDataUrl(dataUrl, cantoId, language, type, version, token)',
            'async function uploadDataUrl(dataUrl, cantoId, language, type, version, token, offlineCopies = null)')
s=s.replace('    // Calcular SHA-256 del contenido original', '    bytes = await clearAndValidateUpload(bytes, type);\n\n    // Calcular SHA-256 del contenido original',1)
s=s.replace('    bytes = await clearAndValidateUpload(bytes, type);\n    const encryptedBytes', '    const encryptedBytes',1)
s=s.replace('    return (await upload.json()).object_key;', '''    const objectKey = (await upload.json()).object_key;
    if (offlineCopies) {
        let binary = '';
        const clear = new Uint8Array(bytes);
        for (let offset = 0; offset < clear.length; offset += 8192)
            binary += String.fromCharCode(...clear.subarray(offset, offset + 8192));
        offlineCopies[type] = `data:application/octet-stream;base64,${btoa(binary)}`;
    }
    return objectKey;''',1)
s=s.replace('        const uploadToken = await accessToken();','        const uploadToken = await accessToken();\n        const offlineCopies = {};',1)
# Only saveCanto upload calls use the collector.
start=s.index('    async saveCanto(')
end=s.index('    async deleteCanto(',start)
part=s[start:end].replace('            uploadToken\n','            uploadToken,\n            offlineCopies\n').replace('                uploadToken\n','                uploadToken,\n                offlineCopies\n')
part=part.replace("archivoData: cantoData.archivo?.startsWith('data:') ? cantoData.archivo : null,", "archivoData: offlineCopies.pdf || (cantoData.archivo?.startsWith('data:') ? cantoData.archivo : null),")
part=part.replace("midiData: cantoData.midi_archivo?.startsWith('data:') ? cantoData.midi_archivo : null", "midiData: offlineCopies.midi || (cantoData.midi_archivo?.startsWith('data:') ? cantoData.midi_archivo : null)")
s=s[:start]+part+s[end:]
p.write_text(s,encoding='utf-8',newline='\n')

p=root/'tools/bulk_manager/server.js'
s=p.read_text(encoding='utf-8')
s=s.replace('app.use(cors());',"app.use(cors({ origin: /^https?:\\/\\/(localhost|127\\.0\\.0\\.1)(:\\d+)?$/, methods: ['GET', 'HEAD'] }));\n// Legacy editor has no transactional sync or revision control. Use the main gestor for writes.\napp.use((req, res, next) => {\n    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method) && req.path.startsWith('/api/'))\n        return res.status(409).json({ error: 'Este editor antiguo es de solo lectura. Guarda los cambios desde el gestor principal.' });\n    next();\n});")
s=s.replace('app.listen(PORT, () => {', "app.listen(PORT, '127.0.0.1', () => {")
p.write_text(s,encoding='utf-8',newline='\n')
print('Upload clear-content hash and offline copies fixed; legacy destructive editor guarded.')
