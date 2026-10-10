// Mock every remote operation, execute the actual frontend module in a VM.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const file='E:/proyectos/CoroLLDM/src/api/remoteCatalogDB.js';
const source=fs.readFileSync(file,'utf8').replace(/^import .*;\r?\n/gm,'')
  .replaceAll('import.meta.env','mockEnv').replace('export const remoteCatalogDB','const remoteCatalogDB');
const first='11111111-1111-4111-8111-111111111111';
const second='22222222-2222-4222-8222-222222222222';
const pdf='global/assets/pdf/'+'a'.repeat(64)+'.enc';
const results=[];
function instance(localRows,remoteRows=[]){
  const calls=[];
  const context=vm.createContext({
    mockEnv:{DEV:true,VITE_API_URL:'https://fixture.invalid'},
    crypto:crypto.webcrypto,TextEncoder,Uint8Array,URL,console:{log(){},warn(){}},
    localStorage:{getItem(){return 'es';}},navigator:{language:'es'},window:{},
    localDB:{async getAmbosCatalogos(){return localRows;},configureRemoteCatalog(){}},
    supabase:{
      auth:{async getSession(){return {data:{session:{access_token:'fixture-only'}}};},async getUser(){return {data:{user:{id:'fixture'}}};}},
      async rpc(name,args){calls.push({name,args});return {data:name==='catalogo_global_bilingue'?remoteRows:[{version:2}],error:null};}
    },
    fetch:async(url,options)=>{calls.push({url:String(url),method:options?.method});return {ok:false,status:500,async json(){return {error:'Simulated local disk failure'};}};},
  });
  vm.runInContext(source+'\nthis.db=remoteCatalogDB; this.encrypt=encryptAsset; this.upload=uploadDataUrl;',context);
  return {context,calls,db:context.db};
}
(async()=>{
  const original={id:first,nombre:'Un canto',archivo:pdf,idioma:'es'};
  const s=instance([original]);
  const saved=await s.db.saveCanto({nombre:'Un canto',archivo:pdf,idioma:'es'});
  assert.equal(saved.id,first);
  assert(s.calls.some(c=>c.url==='/__gestor_sync_catalog'));
  results.push({name:'Create resolves an existing UUID by title and calls cloud update for that work',reproduced:true,savedId:saved.id});
  results.push({name:'HTTP 500 from local synchronization does not stop saveCanto success',reproduced:true,saveReturnedSuccess:true});
  const merged=instance([original],[{id:second,nombre:'Un canto',archivo:'other-score.pdf',idioma:'es'}]);
  const rows=await merged.db.getAmbosCatalogos();
  assert.equal(rows.length,1); assert.equal(rows[0].id,first);assert.equal(rows[0].archivo,'other-score.pdf');
  results.push({name:'Local/remote same-title works with different UUIDs are collapsed and score replaced',reproduced:true,rows});
  const upload=instance([]);
  const clear=Buffer.from('%PDF-1.7\n'+ 'fixture contents'.repeat(3));
  const encrypted=await upload.context.encrypt(clear);
  let body;
  upload.context.fetch=async(url,options)=>{
    if(String(url).startsWith('/offline_assets/'))return {ok:true,async arrayBuffer(){return encrypted.buffer.slice(encrypted.byteOffset,encrypted.byteOffset+encrypted.byteLength);}};
    body=options.body;return {ok:true,async json(){return {object_key:pdf};}};
  };
  await upload.context.upload('existing-encrypted.pdf',first,'es','pdf',2,'fixture-only');
  const keyLiteral=fs.readFileSync('lib/core/security/file_crypto.dart','utf8').match(/_rawKey = '([^']+)'/)[1];
  const key=crypto.createHash('sha256').update(keyLiteral).digest();
  const buffer=Buffer.from(body);
  const decipher=crypto.createDecipheriv('aes-256-gcm',key,buffer.subarray(0,12));
  decipher.setAuthTag(buffer.subarray(-16));
  const once=Buffer.concat([decipher.update(buffer.subarray(12,-16)),decipher.final()]);
  assert.deepEqual(once,Buffer.from(encrypted));assert.notEqual(once.subarray(0,4).toString(),'%PDF');
  results.push({name:'Editing a bundled encrypted filename uploads double-encrypted content',reproduced:true,pdfHeaderAfterOneDecrypt:false});
  const out=path.resolve('output/gestor_integrity/2026-10-10');fs.mkdirSync(out,{recursive:true});
  fs.writeFileSync(path.join(out,'remote-isolated-reproductions.json'),JSON.stringify({source:file,allNetworkMocked:true,realDataModified:false,results},null,2));
  for(const r of results)console.log('CONFIRMED: '+r.name);
})().catch(e=>{console.error(e);process.exitCode=1;});
