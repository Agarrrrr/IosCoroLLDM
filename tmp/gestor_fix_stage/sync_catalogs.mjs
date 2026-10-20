import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {readCatalog,mergeCatalog,planAsset,catalogEntry,writeTransaction} from './catalog_safety.mjs';

export async function syncCatalogs({sourceRoot,targets,dryRun=false}) {
  // Parse both mandatory sources before planning any filesystem writes.
  const catalogs=['catalogo.json','catalogo_en.json'].map(file=>({file,rows:readCatalog(path.join(sourceRoot,'offline_assets',file))}));
  const writes=[];
  const planned=new Set();
  const summary=[];
  for (const root of targets.filter(dir=>fs.existsSync(dir))) for (const {file,rows} of catalogs) {
    const target=path.join(root,file);
    const existing=readCatalog(target);
    const merged=mergeCatalog(existing,rows);
    for (const song of merged) {
      if (!fs.existsSync(path.join(root,'offline_assets'))) continue;
      for (const [type,key] of [['pdf',song.archivo],['midi',song.midi_archivo]]) {
        if (!key || planned.has(`${root}:${type}:${key}`)) continue;
        writes.push(await planAsset(root,type,key,[sourceRoot,...targets]));
        planned.add(`${root}:${type}:${key}`);
      }
    }
    writes.push(catalogEntry(target,merged));
    const offlineCopy=path.join(root,'offline_assets',file);
    if (fs.existsSync(offlineCopy)) writes.push(catalogEntry(offlineCopy,merged));
    summary.push({file:target,before:existing.length,after:merged.length,removed:0});
  }
  if (!dryRun) writeTransaction(writes);
  return {dryRun,summary,plannedFiles:writes.length};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    if (process.argv.includes('--restore-safe-baseline')) throw new Error('La restauración desde HEAD no se aplica automáticamente: conservar el repertorio actual requiere una migración explícita.');
    const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
    const projects=path.resolve(process.env.COROLLDM_PROJECTS_DIR || path.join(root,'..'));
    const result=await syncCatalogs({sourceRoot:path.join(root,'public'),targets:[
      path.resolve(process.env.IOS_COROLLDM_ASSETS_DIR || path.join(projects,'IosCoroLLDM','assets')),
      path.resolve(process.env.REPERTORIO_BC_ASSETS_DIR || path.join(projects,'repertorio_bc','assets')),
    ],dryRun:process.argv.includes('--dry-run')});
    console.log(JSON.stringify(result,null,2));
  } catch(error) {console.error(`Sincronización cancelada: ${error.message}`);process.exitCode=1;}
}
