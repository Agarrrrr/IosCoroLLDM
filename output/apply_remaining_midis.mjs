import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {readCatalog,validateCatalog,validateAsset,encodeDataUrl,assetPath,writeTransaction,catalogEntry} from 'file:///E:/proyectos/CoroLLDM/scripts/catalog_safety.mjs';
const out='E:/proyectos/IosCoroLLDM/output/remaining_midis/2026-10-12';
const read=f=>JSON.parse(fs.readFileSync(out+'/'+f,'utf8'));
const baseline=read('baseline.json'),payload=read('payload.json'),receipt=read('remote_receipt.json');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
if(payload.length!==30||receipt.results.length!==30)throw Error('Tanda incompleta');
for(const [file,digest] of Object.entries(baseline.assets))if(hash(fs.readFileSync(file))!==digest)throw Error('Archivo anterior alterado: '+file);
for(const [file,b] of Object.entries(baseline.catalogs))if(hash(fs.readFileSync(file))!==b.sha256)throw Error('Catalogo modificado durante preparacion');
const plans=[],records=[];
for(const p of payload){
 const r=receipt.results.find(r=>r.localId===p.localId);
 if(!r||r.midiKey!=='global/assets/midi/'+p.midiHash+'.enc')throw Error('Recibo incorrecto');
 const midi=Buffer.from(p.midiData.split(',')[1],'base64');
 await validateAsset(midi,'midi');
 if(hash(midi)!==p.sourceMidiHash||hash(fs.readFileSync(p.sourceMidi))!==p.sourceMidiHash)throw Error('MIDI fuente cambiado');
 const enc=await encodeDataUrl(p.midiData,'midi');
 for(const root of baseline.roots){
  const target=assetPath(root,'midi',r.midiKey);
  if(fs.existsSync(target)){if(hash(await validateAsset(fs.readFileSync(target),'midi'))!==p.midiHash)throw Error('Colision MIDI');}
  else plans.push({path:target,bytes:enc});
 }
 const pdfKey=p.newWork?r.pdfKey:p.appRow.archivo;
 if(p.newWork){
  const pdf=Buffer.from(p.pdfData.split(',')[1],'base64');
  await validateAsset(pdf,'pdf');if(hash(pdf)!==p.pdfHash||hash(fs.readFileSync(p.sourcePdf))!==p.pdfHash)throw Error('PDF fuente cambiado');
  const encrypted=await encodeDataUrl(p.pdfData,'pdf');
  for(const root of baseline.roots){
   const target=assetPath(root,'pdf',pdfKey);
   if(fs.existsSync(target)){if(hash(await validateAsset(fs.readFileSync(target),'pdf'))!==p.pdfHash)throw Error('Colision PDF');}
   else plans.push({path:target,bytes:encrypted});
  }
 }
 records.push({id:p.localId,name:p.title,remoteId:r.remoteId,newWork:p.newWork,existingPdf:pdfKey,pdfHash:p.pdfHash,midiKey:r.midiKey,midiHash:p.midiHash,sourceMidi:p.sourceMidi,sourcePdf:p.sourcePdf,sourceMidiHash:p.sourceMidiHash,activeTracks:p.sourceTracks.length,version:r.version});
}
const catalogReports=[];
for(const [file,b] of Object.entries(baseline.catalogs)){
 if(path.basename(file)!=='catalogo.json')continue;
 const rows=readCatalog(file);
 for(const p of payload){
  const r=receipt.results.find(r=>r.localId===p.localId);
  const index=rows.findIndex(row=>row.id===p.localId);
  const row={...(index<0?p.appRow:rows[index]),midi_archivo:r.midiKey,version:Math.max(Number(p.appRow.version||1),Number(r.version))};
  if(p.newWork)row.archivo=r.pdfKey;
  if(index<0)rows.push(row);else rows[index]=row;
 }
 validateCatalog(rows);
 for(let i=0;i<b.rows.length;i++){
  const before=b.rows[i],after=rows[i];
  if(before.id!==after.id)throw Error('ID u orden alterado');
  const changed=payload.find(p=>p.localId===before.id&&!p.newWork);
  for(const key of new Set([...Object.keys(before),...Object.keys(after)])){
   if(changed&&['midi_archivo','version'].includes(key))continue;
   if(JSON.stringify(before[key])!==JSON.stringify(after[key]))throw Error('Campo previo alterado '+before.id+' '+key);
  }
 }
 plans.push(catalogEntry(file,rows));
 catalogReports.push({path:file,before:b.rows.length,after:rows.length});
}
writeTransaction(plans);
const unchanged=Object.entries(baseline.assets).every(([f,d])=>hash(fs.readFileSync(f))===d);
if(!unchanged)throw Error('Integridad anterior fallida');
const docs='E:/proyectos/IosCoroLLDM/docs/repertorio/2026-10-12';
fs.writeFileSync(docs+'/incorporados_30.json',JSON.stringify({date:'2026-10-12',records,oldFilesUnchanged:Object.keys(baseline.assets).length,catalogs:catalogReports,excluded:['Coronadle Rey','Remembranza Gloriosa','Perfect (CMG)']},null,2));
console.log(JSON.stringify({incorporated:records.length,newWorks:records.filter(r=>r.newWork).length,oldFilesUnchanged:Object.keys(baseline.assets).length,catalogs:catalogReports}));
