import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {clearAsset} from './catalog_safety.mjs';
const require=createRequire(import.meta.url);
const {PDFDocument}=require('pdf-lib');const {Midi}=require('@tonejs/midi');
const original=fs.readFileSync(new URL('../src/api/remoteCatalogDB.js',import.meta.url),'utf8');
const source=original.replace(/^import .*;\r?\n/gm,'').replaceAll('import.meta.env','mockEnv')
  .replace("await import('pdf-lib')",'({PDFDocument})').replace("await import('@tonejs/midi')",'({Midi})')
  .replace('export const remoteCatalogDB','const remoteCatalogDB');
const first='11111111-1111-4111-8111-111111111111',second='22222222-2222-4222-8222-222222222222';
const objectKey='global/assets/pdf/'+'a'.repeat(64)+'.enc';
const originalRow={id:first,nombre:'Un canto',archivo:objectKey,idioma:'es'};
function setup(local=[originalRow],remote=[],localStatus=200){
  const calls=[];
  const context=vm.createContext({mockEnv:{DEV:true,VITE_API_URL:'https://fixture.invalid'},
    crypto:crypto.webcrypto,TextEncoder,Uint8Array,URL,PDFDocument,Midi,btoa,console:{log(){},warn(){}},
    localStorage:{getItem(){return 'es';}},navigator:{language:'es'},window:{},
    localDB:{async getAmbosCatalogos(){return local;},configureRemoteCatalog(){}},
    supabase:{auth:{async getSession(){return {data:{session:{access_token:'fixture'}}};},async getUser(){return {data:{user:{id:'fixture'}}};}},
      async rpc(name,args){calls.push({name,args});return {data:name==='catalogo_global_bilingue'?remote:[{version:2}],error:null};}},
    fetch:async(url,options)=>{calls.push({url:String(url),options});return {ok:localStatus===200,status:localStatus,async json(){return {success:localStatus===200,error:'Fixture sync failure'};}};}
  });
  vm.runInContext(source+'\nthis.db=remoteCatalogDB;this.upload=uploadDataUrl;this.encrypt=encryptAsset;this.validate=clearAndValidateUpload;',context);
  return {context,calls,db:context.db};
}
test('New work with the same title gets a different ID, never updates the old work',async()=>{
  const s=setup();const saved=await s.db.saveCanto({nombre:'Un canto',archivo:objectKey,idioma:'es'});
  assert.notEqual(saved.id,first);assert(s.calls.some(call=>call.name==='gestionar_canto_global'&&call.args.p_id===saved.id));
});
test('Distinct local and remote UUIDs with the same title remain two works',async()=>{
  const s=setup([originalRow],[{...originalRow,id:second,archivo:'other.pdf'}]);
  const rows=await s.db.getAmbosCatalogos();assert.equal(rows.length,2);assert.equal(rows.find(r=>r.id===first).archivo,objectKey);
});
test('A failed local sync reports cloud success and offline failure, not full success',async()=>{
  const s=setup([originalRow],[],500);
  await assert.rejects(s.db.saveCanto({nombre:'Un canto',archivo:objectKey,idioma:'es'},first),/nube.*offline/);
});
test('Encrypted local PDF is uploaded with one encryption and a clear-content hash; offline bytes supplied',async()=>{
  const s=setup();const doc=await PDFDocument.create();doc.addPage();const clear=Buffer.from(await doc.save());
  const encrypted=await s.context.encrypt(clear);let upload;
  s.context.fetch=async(url,options)=>{
    if (String(url).startsWith('/offline_assets/'))return {ok:true,async arrayBuffer(){return encrypted.buffer.slice(encrypted.byteOffset,encrypted.byteOffset+encrypted.byteLength);}};
    upload=options;return {ok:true,async json(){return {object_key:objectKey};}};
  };
  const copies={};await s.context.upload('existing.pdf',first,'es','pdf',2,'fixture',copies);
  assert.deepEqual(clearAsset(Buffer.from(upload.body)),clear);
  assert.equal(upload.headers['X-Content-SHA256'],crypto.createHash('sha256').update(clear).digest('hex'));
  assert.deepEqual(Buffer.from(copies.pdf.split(',')[1],'base64'),clear);
});
test('Invalid PDF is rejected before remote upload',async()=>{
  const s=setup();await assert.rejects(s.context.validate(Buffer.from('%PDF-1.7\nbroken'),'pdf'));
  assert(!s.calls.length);
});
test('Delete explicitly propagates only the requested ID to local synchronization',async()=>{
  const s=setup();s.context.supabase.rpc=async()=>({data:true,error:null});
  await s.db.deleteCanto(first);
  const request=s.calls.find(call=>call.url==='/__gestor_sync_catalog');assert.deepEqual(JSON.parse(request.options.body),{action:'delete',id:first});
});
