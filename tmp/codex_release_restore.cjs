const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const rawKey=fs.readFileSync('lib/core/security/file_crypto.dart','utf8').match(/_rawKey = '([^']+)'/)[1];
const key=crypto.createHash('sha256').update(rawKey).digest();
const matches=JSON.parse(fs.readFileSync('tmp/codex_release_asset_matches.json','utf8'));
for(const [target,source] of Object.entries(matches)){
  let bytes=fs.readFileSync(source);
  const header=bytes.subarray(0,4).toString('ascii');
  if(header==='%PDF'||header==='MThd'){
    const iv=crypto.randomBytes(12);
    const cipher=crypto.createCipheriv('aes-256-gcm',key,iv);
    bytes=Buffer.concat([iv,cipher.update(bytes),cipher.final(),cipher.getAuthTag()]);
  }
  const resolved=path.resolve(target);
  if(!resolved.startsWith(path.resolve('assets/offline_assets')+path.sep))throw Error('Target outside offline assets');
  fs.mkdirSync(path.dirname(resolved),{recursive:true});
  fs.writeFileSync(resolved,bytes);
}
console.log(`Restored ${Object.keys(matches).length} verified assets`);
