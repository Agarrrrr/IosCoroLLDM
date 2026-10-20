import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createRequire} from 'node:module';
import {readCatalog,mergeCatalog,clearAsset,encodeDataUrl,validateAsset,writeTransaction,assetPath} from './catalog_safety.mjs';
import {createGestorPlugin} from './gestor_sync.mjs';
import {syncCatalogs} from './sync_catalogs.mjs';
const require=createRequire(import.meta.url);
const {PDFDocument}=require('pdf-lib');
const {Midi}=require('@tonejs/midi');
const doc=await PDFDocument.create();doc.addPage([200,300]);
const pdf=Buffer.from(await doc.save());
const midiDoc=new Midi();midiDoc.addTrack().addNote({midi:60,time:0,duration:1});
const midi=Buffer.from(midiDoc.toArray());
const row=(id,name='Un canto',archivo=`${id}.pdf`)=>({id,nombre:name,archivo,idioma:'es'});
const folders=[];
test.after(()=>{for(const dir of folders) fs.rmSync(dir,{recursive:true,force:true});});
function setup(pwa=[],ios=pwa,rep=[]) {
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'corolldm-safe-'));folders.push(dir);
  const roots={pwaAssetsDir:path.join(dir,'public'),iosAssetsDir:path.join(dir,'ios'),repertorioBcAssetsDir:path.join(dir,'rep')};
  for (const [root,rows,isPwa] of [[roots.pwaAssetsDir,pwa,true],[roots.iosAssetsDir,ios,false],[roots.repertorioBcAssetsDir,rep,false]]) {
    fs.mkdirSync(root,{recursive:true});
    const catalogDir=isPwa?path.join(root,'offline_assets'):root;fs.mkdirSync(catalogDir,{recursive:true});
    fs.writeFileSync(path.join(catalogDir,'catalogo.json'),JSON.stringify(rows));
    fs.writeFileSync(path.join(catalogDir,'catalogo_en.json'),'[]');
    if (!isPwa && root!==roots.repertorioBcAssetsDir) {
      fs.mkdirSync(path.join(root,'offline_assets'),{recursive:true});
      fs.copyFileSync(path.join(catalogDir,'catalogo.json'),path.join(root,'offline_assets/catalogo.json'));
    }
    if (root!==roots.repertorioBcAssetsDir) for (const song of rows) {
      if (/^https?:/.test(song.archivo)) continue;
      const target=assetPath(root,'pdf',song.archivo);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,pdf);
    }
  }
  let handler;createGestorPlugin(roots).configureServer({middlewares:{use(fn){handler=fn;}}});
  const request=body=>new Promise((resolve,reject)=>{
    const callbacks={};
    handler({url:'/__gestor_sync_catalog',method:'POST',headers:{},on(name,fn){callbacks[name]=fn;}},
      {writeHead(status){this.status=status;},end(body){resolve({status:this.status,result:JSON.parse(body)});}},reject);
    callbacks.data(JSON.stringify(body));callbacks.end();
  });
  return {...roots,dir,request,readIos:()=>readCatalog(path.join(roots.iosAssetsDir,'catalogo.json'))};
}
test('Distinct IDs retain distinct works even with identical titles',()=>{
  const merged=mergeCatalog([row('a')],[row('b')]);assert.equal(merged.length,2);assert.deepEqual(new Set(merged.map(s=>s.id)),new Set(['a','b']));
});
test('Older incoming versions and remote URLs cannot undo offline fixes',()=>{
  const fixed={...row('a','Gracia'),version:2};
  assert.equal(mergeCatalog([fixed],[{...fixed,version:1,archivo:'https://fixture.invalid/old.pdf'}])[0].archivo,'a.pdf');
  assert.equal(mergeCatalog([row('b')],[row('b','Un canto','https://fixture.invalid/b.pdf')])[0].archivo,'b.pdf');
  assert.throws(()=>mergeCatalog([fixed],[{...fixed,version:1}],{rejectOlder:true}));
});
test('Explicit alias migration is refused instead of silently replacing IDs',()=>{
  assert.throws(()=>mergeCatalog([row('legacy')],[{...row('uuid'),external_id:'legacy'}]));
});
test('Invalid and double-encrypted resources are rejected; valid PDF and MIDI accepted',async()=>{
  await validateAsset(pdf,'pdf');await validateAsset(midi,'midi');
  await assert.rejects(validateAsset(Buffer.from('hello'),'pdf'));
  await assert.rejects(validateAsset(Buffer.from('%PDF-1.7\nbroken'),'pdf'));
  await assert.rejects(validateAsset(midi.subarray(0,midi.length-1),'midi'));
  const encoded=await encodeDataUrl(`data:application/pdf;base64,${pdf.toString('base64')}`,'pdf');
  assert.deepEqual(clearAsset(encoded),pdf);
});
test('Transaction failure restores every previously changed file',()=>{
  const s=setup();const a=path.join(s.dir,'a'),b=path.join(s.dir,'b');fs.writeFileSync(a,'before-a');fs.writeFileSync(b,'before-b');
  const original=fs.renameSync;
  fs.renameSync=(from,to)=>{if(to===b)throw Error('Simulated failure');return original(from,to);};
  try {assert.throws(()=>writeTransaction([{path:a,bytes:Buffer.from('after-a')},{path:b,bytes:Buffer.from('after-b')}]));}
  finally{fs.renameSync=original;}
  assert.equal(fs.readFileSync(a,'utf8'),'before-a');assert.equal(fs.readFileSync(b,'utf8'),'before-b');
  assert(!fs.readdirSync(s.dir).some(name=>name.endsWith('.tmp')));
});
test('Upsert preserves same-title works and destination-exclusive songs',async()=>{
  const s=setup([row('a')],[row('a'),row('exclusive','Exclusive')],[row('rep-only','Exclusive rep')]);
  const result=await s.request({action:'upsert',canto:row('b'),archivoData:`data:application/pdf;base64,${pdf.toString('base64')}`});
  assert.equal(result.status,200);assert.equal(s.readIos().length,3);
  assert.equal(readCatalog(path.join(s.repertorioBcAssetsDir,'catalogo.json')).length,2);
});
test('Missing bytes and invalid PDF uploads leave catalogs untouched',async()=>{
  const s=setup([row('a')]);const before=fs.readFileSync(path.join(s.iosAssetsDir,'catalogo.json'));
  assert.equal((await s.request({action:'upsert',canto:row('missing')})).status,400);
  assert.equal((await s.request({action:'upsert',canto:row('invalid'),archivoData:'data:application/pdf;base64,aGVsbG8='})).status,400);
  assert.deepEqual(fs.readFileSync(path.join(s.iosAssetsDir,'catalogo.json')),before);
});
test('Metadata-only upsert copies an existing validated asset to every offline destination',async()=>{
  const s=setup([row('a')],[]);
  const result=await s.request({action:'upsert',canto:{...row('a'),temas:['Gracia']}});
  assert.equal(result.status,200);assert.deepEqual(clearAsset(fs.readFileSync(assetPath(s.iosAssetsDir,'pdf','a.pdf'))),pdf);
});
test('Metadata saves cannot revert another song version or its local PDF',async()=>{
  const s=setup([row('a'),row('fixed','Gracia','https://fixture.invalid/old.pdf')],[row('a'),{...row('fixed','Gracia'),version:2}]);
  assert.equal((await s.request({action:'upsert',canto:{...row('a'),temas:['Nuevo']}})).status,200);
  assert.equal(s.readIos().find(song=>song.id==='fixed').version,2);assert.equal(s.readIos().find(song=>song.id==='fixed').archivo,'fixed.pdf');
});
test('Explicit delete propagates the ID while keeping shared PDF files',async()=>{
  const s=setup([row('a'),row('b','Otro','a.pdf')]);
  assert.equal((await s.request({action:'delete',id:'a'})).status,200);
  assert.deepEqual(s.readIos().map(song=>song.id),['b']);assert(fs.existsSync(assetPath(s.iosAssetsDir,'pdf','a.pdf')));
});
test('Batch sync aborts on invalid mandatory JSON before touching any destination',async()=>{
  const s=setup([row('a')]);const before=fs.readFileSync(path.join(s.iosAssetsDir,'catalogo.json'));
  fs.writeFileSync(path.join(s.pwaAssetsDir,'offline_assets/catalogo_en.json'),'{bad');
  await assert.rejects(syncCatalogs({sourceRoot:s.pwaAssetsDir,targets:[s.iosAssetsDir]}));
  assert.deepEqual(fs.readFileSync(path.join(s.iosAssetsDir,'catalogo.json')),before);
});
test('Batch dry-run keeps catalog and asset bytes unchanged',async()=>{
  const s=setup([row('a')],[row('a'),row('local','Exclusive')]);const file=path.join(s.iosAssetsDir,'catalogo.json'),before=fs.readFileSync(file);
  const result=await syncCatalogs({sourceRoot:s.pwaAssetsDir,targets:[s.iosAssetsDir],dryRun:true});
  assert.equal(result.summary[0].after,2);assert.deepEqual(fs.readFileSync(file),before);
});
