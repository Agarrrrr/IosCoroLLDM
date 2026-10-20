import fs from 'node:fs';import {writeTransaction,readCatalog,catalogEntry} from 'file:///E:/proyectos/CoroLLDM/scripts/catalog_safety.mjs';
const files=['E:/proyectos/IosCoroLLDM/assets/catalogo.json','E:/proyectos/IosCoroLLDM/assets/offline_assets/catalogo.json','E:/proyectos/CoroLLDM/public/offline_assets/catalogo.json','E:/proyectos/repertorio_bc/assets/catalogo.json'];
const plans=[],before=[];
for(const file of files){const rows=readCatalog(file);const i=rows.findIndex(r=>r.id==='usmc_b44ea5087d4ed58cc6');if(i<0||rows[i].midi_archivo!=='global/assets/midi/efe363ad079239e8a810efa9da6a3ad8b5954452cd770c6689e7317bd3069132.enc')throw Error('Asignacion inesperada');before.push({file,row:rows[i]});const updated={...rows[i],version:5};delete updated.midi_archivo;rows[i]=updated;plans.push(catalogEntry(file,rows));}
writeTransaction(plans);
const out='E:/proyectos/IosCoroLLDM/docs/repertorio/2026-10-12';
fs.writeFileSync(out+'/rectificacion_satb.json',JSON.stringify({date:'2026-10-12',quarantined:[{id:'usmc_b44ea5087d4ed58cc6',name:'No Puedo Imaginar',midiKey:'global/assets/midi/efe363ad079239e8a810efa9da6a3ad8b5954452cd770c6689e7317bd3069132.enc',reason:'Dos pistas largas agrupadas y tres fragmentarias; no cuatro partes vocales completas',pdfPreserved:true,sourcePreserved:true,version:5}],before},null,2));
console.log(JSON.stringify({localCatalogsCorrected:files.length,pdfPreserved:true}));
