import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import {readCatalog,validateCatalog,validateAsset,encodeDataUrl,assetPath,writeTransaction,catalogEntry} from 'file:///E:/proyectos/CoroLLDM/scripts/catalog_safety.mjs';
const out='E:/proyectos/IosCoroLLDM/output/priority_midis/2026-10-11';
const baseline=JSON.parse(fs.readFileSync(path.join(out,'baseline.json'),'utf8'));
const payload=JSON.parse(fs.readFileSync(path.join(out,'payload.json'),'utf8'));
const receipt=JSON.parse(fs.readFileSync(path.join(out,'remote_receipt.json'),'utf8'));
const wanted=process.argv[2];
const items=receipt.results.filter(r=>!wanted||r.localId===wanted);
if(!items.length)throw Error('Sin incorporación remota confirmada');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const esFiles=Object.keys(baseline.catalogs).filter(f=>path.basename(f)==='catalogo.json');
for(const item of items){
 const p=payload.find(p=>p.localId===item.localId);
 if(!p||item.midiKey!=='global/assets/midi/'+p.midiHash+'.enc')throw Error('Correspondencia no confirmada');
 const clear=Buffer.from(p.midiData.split(',')[1],'base64');
 await validateAsset(clear,'midi');
 if(hash(clear)!==p.midiHash)throw Error('Contenido MIDI alterado');
 const plans=[];
 let encrypted;
 for(const root of baseline.roots){
  const target=assetPath(root,'midi',item.midiKey);
  if(fs.existsSync(target)){
   if(hash(await validateAsset(fs.readFileSync(target),'midi'))!==p.midiHash)throw Error('Existe un audio distinto en el destino');
  }else{
   encrypted??=await encodeDataUrl(p.midiData,'midi');
   plans.push({path:target,bytes:encrypted});
  }
 }
 for(const file of esFiles){
  const old=baseline.catalogs[file].rows;
  const rows=readCatalog(file);
  if(rows.length!==old.length||rows.some((r,i)=>r.id!==old[i].id))throw Error('Se alteraron IDs u orden del catálogo');
  const index=rows.findIndex(r=>r.id===item.localId);
  if(index<0)throw Error('Falta el ID original en '+file);
  const prior=old[index];
  const row=rows[index];
  for(const k of new Set([...Object.keys(prior),...Object.keys(row)])){
   if(['midi_archivo','version'].includes(k))continue;
   if(JSON.stringify(prior[k])!==JSON.stringify(row[k]))throw Error('Cambió un campo ajeno a la incorporación: '+k);
  }
  if(row.midi_archivo&&row.midi_archivo!==item.midiKey)throw Error('No reemplazar un audio existente');
  rows[index]={...row,midi_archivo:item.midiKey,version:Math.max(Number(row.version||1),Number(item.version))};
  validateCatalog(rows);
  plans.push(catalogEntry(file,rows));
 }
 writeTransaction(plans);
 console.log(JSON.stringify({title:p.title,localId:item.localId,midiKey:item.midiKey,plannedWrites:plans.length}));
}
