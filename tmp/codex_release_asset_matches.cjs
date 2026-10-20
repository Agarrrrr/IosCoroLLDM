const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const keySource = fs.readFileSync('lib/core/security/file_crypto.dart', 'utf8').match(/_rawKey = '([^']+)'/)[1];
const key = crypto.createHash('sha256').update(keySource).digest();
const missing = new Map();
for (const catalog of ['assets/catalogo.json','assets/catalogo_en.json']) {
  for (const song of JSON.parse(fs.readFileSync(catalog,'utf8'))) {
    for (const kind of ['pdf','midi']) {
      const ref = song[kind === 'pdf' ? 'archivo' : 'midi_archivo'];
      if (!ref?.endsWith('.enc')) continue;
      const target = `assets/offline_assets/${kind}s/${ref}`;
      if (!fs.existsSync(target)) missing.set(path.basename(ref,'.enc'),target);
    }
  }
}
const matches = {};
function scan(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir,{withFileTypes:true})) {
    const source=path.join(dir,entry.name);
    if(entry.isDirectory()){scan(source);continue;}
    const raw=fs.readFileSync(source);
    for (let mode=0;mode<2;mode++) {
      try {
        let bytes=raw;
        if(mode===1){
          const cipher=crypto.createDecipheriv('aes-256-gcm',key,raw.subarray(0,12));
          cipher.setAuthTag(raw.subarray(-16));
          bytes=Buffer.concat([cipher.update(raw.subarray(12,-16)),cipher.final()]);
        }
        const hash=crypto.createHash('sha256').update(bytes).digest('hex');
        if(missing.has(hash)) matches[missing.get(hash)]=source;
      }catch{}
    }
  }
}
for(const root of ['assets/offline_assets','E:/proyectos/CoroLLDM/public/offline_assets','E:/proyectos/repertorio_bc/assets/offline_assets']) scan(root);
fs.writeFileSync('tmp/codex_release_asset_matches.json',JSON.stringify(matches,null,2));
console.log(JSON.stringify(matches,null,2));
