// Run the real manager middleware against an in-memory filesystem, without network.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = 'E:/proyectos/CoroLLDM';
const out = path.resolve('output/gestor_integrity/2026-10-10');
const source = fs.readFileSync(path.join(root, 'vite.config.js'), 'utf8');
const start = source.indexOf('function gestorLocalCmsPlugin()');
const end = source.indexOf('export default defineConfig', start);
assert(start >= 0 && end > start);
const pluginSource = source.slice(start, end);
const results = [];
const song = (id, nombre, archivo = `${id}.pdf`) => ({id, nombre, archivo, idioma: 'es'});

function sandbox(pwa, ios = pwa, repertoire = []) {
  const base = path.join(out, 'virtual');
  const manager = path.join(base, 'CoroLLDM');
  const pwaDir = path.join(manager, 'public', 'offline_assets');
  const iosDir = path.join(base, 'IosCoroLLDM', 'assets');
  const repDir = path.join(base, 'repertorio_bc', 'assets');
  const store = new Map();
  const dirs = new Set([iosDir, path.join(iosDir, 'offline_assets'), repDir]);
  for (const [dir, rows] of [[pwaDir,pwa],[iosDir,ios],[path.join(iosDir,'offline_assets'),ios],[repDir,repertoire]]) {
    store.set(path.join(dir,'catalogo.json'), JSON.stringify(rows));
    store.set(path.join(dir,'catalogo_en.json'), '[]');
  }
  let failAsset = false;
  const fakeFs = {
    existsSync: file => store.has(file) || dirs.has(file),
    readFileSync: file => {if (!store.has(file)) throw Error('Not found'); return store.get(file);},
    writeFileSync: (file, data) => {
      if (failAsset && file.includes(`${path.sep}pdfs${path.sep}`) && file.startsWith(iosDir)) throw Error('Simulated disk failure');
      store.set(file, Buffer.isBuffer(data) ? data : String(data));
    },
    mkdirSync: file => dirs.add(file),
  };
  const context = vm.createContext({
    ...path, fs:fakeFs, crypto, Buffer, __dirname:manager,
    process:{env:{}}, console:{log(){},error(){}},
    fetch:async()=>{throw Error('Network forbidden in audit');}, AbortSignal,
  });
  vm.runInContext(pluginSource + '\nthis.plugin = gestorLocalCmsPlugin();', context);
  let middleware;
  context.plugin.configureServer({middlewares:{use(fn){middleware=fn;}}});
  return {
    store, pwaDir, iosDir, repDir,
    failAsset(){failAsset=true;},
    rows(dir){return JSON.parse(store.get(path.join(dir,'catalogo.json')));},
    async request(body, url='/__gestor_sync_catalog') {
      return new Promise((resolve,reject)=>{
        const handlers = {};
        const req = {url,method:'POST',on(event,fn){handlers[event]=fn;}};
        const res = {status:200,writeHead(status){this.status=status;},end(text){resolve({status:this.status,body:JSON.parse(text)});}};
        Promise.resolve(middleware(req,res,()=>reject(Error('Unexpected next')))).catch(reject);
        handlers.data(JSON.stringify(body));
        Promise.resolve(handlers.end()).catch(reject);
      });
    }
  };
}

async function test(name, action) {
  const result = await action();
  assert(result.reproduced, `Not reproduced: ${name}`);
  results.push({name,...result});
  console.log(`CONFIRMED: ${name}`);
}

(async()=>{
  await test('Same title and different IDs: upsert overwrites an independent work', async()=>{
    const s=sandbox([song('first','Un canto')]);
    const response=await s.request({action:'upsert',canto:song('second','Un canto','different.pdf')});
    return {reproduced:response.status===200 && s.rows(s.pwaDir).length===1 && s.rows(s.pwaDir)[0].id==='second',remaining:s.rows(s.pwaDir)};
  });
  await test('Metadata save replaces the entire iOS catalog and removes an exclusive song', async()=>{
    const s=sandbox([song('first','Primero')],[song('first','Primero'),song('exclusive','Otro arreglo')]);
    await s.request({action:'upsert',canto:{...song('first','Primero'),temas:['Gracia']}});
    return {reproduced:!s.rows(s.iosDir).some(row=>row.id==='exclusive'),iosIds:s.rows(s.iosDir).map(row=>row.id)};
  });
  await test('A successful upsert accepts a PDF reference with no bundled bytes', async()=>{
    const s=sandbox([]);
    const response=await s.request({action:'upsert',canto:song('new','Nuevo','global/assets/pdf/missing.enc')});
    return {reproduced:response.status===200 && s.rows(s.iosDir).length===1 && !s.store.has(path.join(s.iosDir,'offline_assets','pdfs','global/assets/pdf/missing.enc')),status:response.status};
  });
  await test('Invalid PDF bytes are encrypted and accepted as a successful upload', async()=>{
    const s=sandbox([]);
    const response=await s.request({action:'upsert',canto:song('bad','Archivo inválido'),archivoData:'data:application/pdf;base64,aGVsbG8='});
    const raw=s.store.get(path.join(s.iosDir,'offline_assets','pdfs','bad.pdf'));
    return {reproduced:response.status===200 && Buffer.isBuffer(raw) && raw.length===33,status:response.status,encryptedLength:raw?.length};
  });
  await test('Disk failure after iOS catalog write leaves the failed change persisted', async()=>{
    const s=sandbox([]); s.failAsset();
    const response=await s.request({action:'upsert',canto:song('partial','Parcial'),archivoData:'data:application/pdf;base64,JVBERi0xLjc='});
    return {reproduced:response.status===500 && s.rows(s.iosDir).some(row=>row.id==='partial'),status:response.status,iosIds:s.rows(s.iosDir).map(row=>row.id)};
  });
  await test('Repertoire merge still deletes distinct works having the same normalized title', async()=>{
    const s=sandbox([song('global','Un canto')],[],[song('local','Un canto','local-arrangement.pdf'),song('global','Un canto')]);
    await s.request({action:'upsert',canto:song('global','Un canto')});
    return {reproduced:s.rows(s.repDir).length===1 && s.rows(s.repDir)[0].id==='global',remaining:s.rows(s.repDir)};
  });
  await test('Local delete removes PWA entry but leaves both iOS catalogs untouched', async()=>{
    const s=sandbox([song('delete','Eliminar')]);
    const response=await s.request({action:'delete',id:'delete'},'/__gestor_sync');
    return {reproduced:response.status===200 && s.rows(s.pwaDir).length===0 && s.rows(s.iosDir).length===1,status:response.status};
  });
  await test('Real PWA metadata sync reintroduces the remote Pecador route and downgrades repaired PDF version', async()=>{
    const pwa=JSON.parse(fs.readFileSync(path.join(root,'public/offline_assets/catalogo.json'),'utf8'));
    const ios=JSON.parse(fs.readFileSync(path.resolve('assets/catalogo.json'),'utf8'));
    const s=sandbox(pwa,ios);
    await s.request({action:'upsert',canto:{...pwa.find(row=>!row.archivo.startsWith('http')),temas:['Audit fixture only']}});
    const after=s.rows(s.iosDir);
    const pecador=after.find(row=>row.id==='c35b5fd9-8d99-445f-89e3-21dd998a3e92');
    const gracia=after.find(row=>row.id==='9c7eeee3-d5d7-4cd1-8f77-96ce435ac5f2');
    return {reproduced:pecador?.archivo.startsWith('http') && (gracia?.version||1)<2,pecadorRemote:pecador?.archivo.startsWith('http'),graciaVersion:gracia?.version||1};
  });
  const batchSource=fs.readFileSync(path.join(root,'scripts/sync_catalogs.mjs'),'utf8');
  await test('Batch sync interprets invalid source JSON as an empty catalog', async()=>{
    const loadSource=batchSource.slice(batchSource.indexOf('function loadJson('),batchSource.indexOf('function saveJson('));
    const context=vm.createContext({fs:{existsSync(){return true;},readFileSync(){return '{ invalid JSON';}},console:{error(){}}});
    const rows=vm.runInContext(loadSource+'\nloadJson("fixture")',context);
    return {reproduced:Array.isArray(rows)&&rows.length===0,parsedSourceRows:rows.length};
  });
  await test('Batch sync merges and drops different arrangements sharing a title', async()=>{
    const mergeSource=batchSource.slice(batchSource.indexOf('function normalizedSongKey('),batchSource.indexOf('function loadCommittedCatalog('));
    const context=vm.createContext({});
    vm.runInContext(mergeSource+'\nthis.merge=mergeGlobalCatalog;',context);
    const rows=context.merge([song('local','Un canto','local.pdf'),song('global','Un canto')],[song('global','Un canto')],'es');
    return {reproduced:rows.length===1&&rows[0].id==='global',remaining:rows};
  });
  fs.mkdirSync(out,{recursive:true});
  fs.writeFileSync(path.join(out,'isolated-reproductions.json'),JSON.stringify({source:path.join(root,'vite.config.js'),networkUsed:false,realCatalogsModified:false,results},null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
