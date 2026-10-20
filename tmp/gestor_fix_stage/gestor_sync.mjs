import fs from 'node:fs';
import path from 'node:path';
import {readCatalog, mergeCatalog, planAsset, validateAsset, assetPath, writeTransaction, catalogEntry} from './catalog_safety.mjs';

export function createGestorPlugin({pwaAssetsDir, iosAssetsDir, repertorioBcAssetsDir}) {
  const roots = [pwaAssetsDir,iosAssetsDir,repertorioBcAssetsDir].filter(dir => fs.existsSync(dir));
  const fileFor = language => language === 'en' ? 'catalogo_en.json' : 'catalogo.json';
  let queue = Promise.resolve();
  const catalogTargets = (language) => roots.flatMap(root => {
    const entries = [{root,file:path.join(root === pwaAssetsDir ? path.join(root,'offline_assets') : root,fileFor(language))}];
    if (root !== pwaAssetsDir && fs.existsSync(path.join(root,'offline_assets',fileFor(language))))
      entries.push({root,file:path.join(root,'offline_assets',fileFor(language))});
    return entries;
  });
  async function upsert(body) {
    const {canto,oldId,archivoData,midiData}=body;
    if (!canto || (oldId && oldId !== canto.id)) throw new Error('No se puede cambiar el ID de una obra al guardar.');
    const language=canto._idioma || canto.idioma || 'es';
    if (!['es','en'].includes(language)) throw new Error('Idioma inválido.');
    const update={...canto,idioma:language};
    delete update._idioma;delete update._nombre_norm;delete update._autor_norm;
    const writes=[];
    const planned=new Set();
    for (const {root,file} of catalogTargets(language)) {
      const rows=mergeCatalog(readCatalog(file),[update],{rejectOlder:true});
      const saved=rows.find(row=>row.id===update.id);
      // The online-only sibling has no offline folder; do not invent an offline setup.
      if (root !== repertorioBcAssetsDir || fs.existsSync(path.join(root,'offline_assets'))) {
        for (const [type,key,data] of [['pdf',saved.archivo,archivoData],['midi',saved.midi_archivo,midiData]]) {
          if (!key || planned.has(`${root}:${type}:${key}`)) continue;
          const inputKey=type==='pdf'?canto.archivo:canto.midi_archivo;
          writes.push(await planAsset(root,type,key,roots,data && key===inputKey?data:null));
          planned.add(`${root}:${type}:${key}`);
        }
      }
      writes.push(catalogEntry(file,rows));
    }
    writeTransaction(writes);
    return {success:true,id:canto.id};
  }
  async function remove(body) {
    if (typeof body.id !== 'string' || !body.id.trim()) throw new Error('Falta el ID del canto.');
    const writes=[];
    for (const language of ['es','en']) for (const {file} of catalogTargets(language)) {
      const rows=readCatalog(file);
      writes.push(catalogEntry(file,rows.filter(row=>row.id!==body.id)));
    }
    // Shared assets are deliberately retained; only an explicit ID is removed.
    writeTransaction(writes);
    return {success:true,id:body.id};
  }
  async function syncRemote(body) {
    const {rows,apiUrl,accessToken}=body;
    if (!Array.isArray(rows) || !accessToken) throw new Error('Falta la sesión autenticada para sincronizar.');
    const url=new URL(apiUrl);
    if (url.protocol !== 'https:') throw new Error('La API de archivos debe usar HTTPS.');
    const results=[];
    for (const row of rows) for (const [type,key] of [['pdf',row.archivo],['midi',row.midi_archivo]]) {
      if (!key || !key.startsWith('global/')) continue;
      try {
        const offlineRoots=roots.filter(root=>root!==repertorioBcAssetsDir || fs.existsSync(path.join(root,'offline_assets')));
        let valid=true;
        for (const root of offlineRoots) {
          try {await validateAsset(fs.readFileSync(assetPath(root,type,key)),type);} catch {valid=false;break;}
        }
        let bytes;
        if (!valid) {
          const response=await fetch(`${apiUrl.replace(/\/+$/,'')}/v1/files/${encodeURIComponent(row.id)}/${type}`,{
            headers:{Authorization:`Bearer ${accessToken}`},signal:AbortSignal.timeout(30000)});
          if (!response.ok) throw new Error(`El servicio de archivos respondió ${response.status}.`);
          bytes=Buffer.from(await response.arrayBuffer());await validateAsset(bytes,type);
        }
        const writes=bytes?offlineRoots.map(root=>({path:assetPath(root,type,key),bytes})):[];
        // A resolved new object key must be reflected in catalogs as well as on disk.
        for (const language of ['es','en']) for (const {file} of catalogTargets(language)) {
          const catalog=readCatalog(file);const existing=catalog.find(song=>song.id===row.id);
          const field=type==='pdf'?'archivo':'midi_archivo';
          if (existing && existing[field] !== key) {
            const changed=catalog.map(song=>song.id===row.id?{...song,[field]:key}:song);
            writes.push(catalogEntry(file,changed));
          }
        }
        writeTransaction(writes);
        results.push({id:row.id,type,objectKey:key,ok:true,skipped:valid});
      } catch(error) {results.push({id:row.id,type,objectKey:key,ok:false,error:error.message});}
    }
    return {success:results.every(item=>item.ok),synced:results.filter(item=>item.ok&&!item.skipped).length,
      skipped:results.filter(item=>item.ok&&item.skipped).length,failed:results.filter(item=>!item.ok).length,results};
  }
  return {name:'gestor-local-cms',configureServer(server){
    server.middlewares.use((req,res,next)=>{
      if (!['/__gestor_sync','/__gestor_sync_catalog'].includes(req.url) || req.method!=='POST') return next();
      const reply=(status,body)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(body));};
      const origin=req.headers?.origin;
      if (origin && new URL(origin).host !== req.headers.host) return reply(403,{error:'Origen no permitido.'});
      let raw='',size=0,tooLarge=false;
      req.on('data',chunk=>{size+=Buffer.byteLength(chunk);if(size>64*1024*1024)tooLarge=true;else raw+=chunk.toString();});
      req.on('end',()=>{
        const operation=async()=>{
          try {
            if (tooLarge) return reply(413,{error:'La carga supera el límite de 64 MB.'});
            const body=JSON.parse(raw);
            let result;
            if (body.action==='delete') result=await remove(body);
            else if (body.action==='upsert') result=await upsert(body);
            else if (body.action==='sync_remote_assets') result=await syncRemote(body);
            else throw new Error('Acción desconocida.');
            reply(200,result);
          } catch(error){reply(400,{error:error.message});}
        };
        queue=queue.then(operation,operation);
      });
    });
  }};
}
