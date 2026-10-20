from pathlib import Path
import shutil

root=Path('E:/proyectos/CoroLLDM')
stage=Path(__file__).parent
backup=Path('E:/proyectos/IosCoroLLDM/output/gestor_integrity/2026-10-10/fix/source-originals')
paths=['vite.config.js','scripts/sync_catalogs.mjs','src/api/remoteCatalogDB.js','src/gestor/partituras/partiturasPanel.js','tools/bulk_manager/server.js']
for name in paths:
    target=backup/name
    target.parent.mkdir(parents=True,exist_ok=True)
    if not target.exists(): shutil.copyfile(root/name,target)

for name in ['catalog_safety.mjs','gestor_sync.mjs','sync_catalogs.mjs']:
    shutil.copyfile(stage/name,root/'scripts'/name)

p=root/'vite.config.js'
s=p.read_text(encoding='utf-8')
start=s.index('function gestorLocalCmsPlugin()')
end=s.index('export default defineConfig',start)
s=s[:start]+'''function gestorLocalCmsPlugin() {
  const projectsDir = resolve(process.env.COROLLDM_PROJECTS_DIR || resolve(__dirname, '..'));
  return createGestorPlugin({
    pwaAssetsDir: resolve(__dirname, 'public'),
    iosAssetsDir: resolve(process.env.IOS_COROLLDM_ASSETS_DIR || join(projectsDir, 'IosCoroLLDM', 'assets')),
    repertorioBcAssetsDir: resolve(process.env.REPERTORIO_BC_ASSETS_DIR || join(projectsDir, 'repertorio_bc', 'assets')),
  });
}

'''+s[end:]
s="import { createGestorPlugin } from './scripts/gestor_sync.mjs';\n"+s
p.write_text(s,encoding='utf-8',newline='\n')

p=root/'src/api/remoteCatalogDB.js'
s=p.read_text(encoding='utf-8')
a=s.index('        // Búsqueda preventiva por nombre')
b=s.index('        if (!id) {',a)
s=s[:a]+s[b:]
s=s.replace('keyMap.get(row.id) || keyMap.get(row.external_id) || keyMap.get(normKey)',
            'keyMap.get(row.id) || (row.external_id ? keyMap.get(row.external_id) : null)')
# Populate explicit IDs, not names; no title matching or title-based ID mutation.
s=s.replace('            keyMap.set(normKey, row.id);','            keyMap.set(row.id, row.id);')
s=s.replace('                    keyMap.set(normKey, row.id);','                    keyMap.set(row.id, row.id);')
s=s.replace("    const encryptedBytes = await encryptAsset(bytes);", "    bytes = await clearAndValidateUpload(bytes, type);\n    const encryptedBytes = await encryptAsset(bytes);")
marker='async function encryptAsset(bytes) {'
helper='''async function clearAndValidateUpload(input, type) {
    let bytes = new Uint8Array(input);
    const hasHeader = data => {
        const head = String.fromCharCode(...data.subarray(0, 4));
        return type === 'pdf' ? head === '%PDF' : head === 'MThd';
    };
    if (!hasHeader(bytes)) {
        if (bytes.length < 28) throw new Error('Archivo incompleto.');
        const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode('repertorio-coral-lldm-key-2026'));
        const key = await crypto.subtle.importKey('raw', hash, {name:'AES-GCM'}, false, ['decrypt']);
        bytes = new Uint8Array(await crypto.subtle.decrypt({name:'AES-GCM', iv:bytes.slice(0,12)},key,bytes.slice(12)));
    }
    if (!hasHeader(bytes)) throw new Error(`El archivo seleccionado no es un ${type.toUpperCase()} válido.`);
    return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
}

async function syncLocalCatalog(payload) {
    const response = await fetch('/__gestor_sync_catalog', {
        method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || result.success !== true) throw new Error(result.error || 'No se pudo sincronizar el repertorio offline.');
    return result;
}

'''
s=s.replace(marker,helper+marker)
a=s.index("                await fetch('/__gestor_sync_catalog',",s.index('async saveCanto'))
b=s.index('\n            } catch (e)',a)
s=s[:a]+'''                await syncLocalCatalog({
                    action: 'upsert', canto: cantoGuardado, oldId: editingId,
                    archivoData: cantoData.archivo?.startsWith('data:') ? cantoData.archivo : null,
                    midiData: cantoData.midi_archivo?.startsWith('data:') ? cantoData.midi_archivo : null
                });'''+s[b:]
s=s.replace("                console.warn('[remoteCatalogDB] No se pudo persistir al JSON local (dev):', e.message);",
            "                this._cache = null;\n                throw new Error(`El cambio se guardó en la nube, pero la copia offline no se actualizó: ${e.message}`);")
marker="        this._cache = null;\n    },\n\n    async getPendingLocalSongs"
s=s.replace(marker,"        if (import.meta.env.DEV) await syncLocalCatalog({action:'delete', id});\n"+marker)
# Do not submit an inherited global key with missing bytes: the server validates/copies or refuses it.
p.write_text(s,encoding='utf-8',newline='\n')

p=root/'src/gestor/partituras/partiturasPanel.js'
s=p.read_text(encoding='utf-8')
s=s.replace('    form.onsubmit = async (e) => {','    let guardando = false;\n    form.onsubmit = async (e) => {')
s=s.replace('        e.preventDefault();\n        const btnGuardar', '        e.preventDefault();\n        if (guardando) return;\n        guardando = true;\n        const btnGuardar',1)
s=s.replace('            if (vinculoIdioma) {','            if (vinculoIdioma && !urlMidi) {',1)
s=s.replace('            window.mostrarToast("ERROR AL GUARDAR", "error");','            window.mostrarToast(error.message || "ERROR AL GUARDAR", "error");',1)
s=s.replace('            partiturasUI.mostrarCarga(btnGuardar, false);','            guardando = false;\n            partiturasUI.mostrarCarga(btnGuardar, false);',1)
p.write_text(s,encoding='utf-8',newline='\n')
print('Source fixes applied; catalog and asset files not written.')
