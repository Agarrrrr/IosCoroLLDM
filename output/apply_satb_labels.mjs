import fs from 'node:fs';
import {writeTransaction,readCatalog,catalogEntry,encodeDataUrl,validateAsset,assetPath} from 'file:///E:/proyectos/CoroLLDM/scripts/catalog_safety.mjs';
const p=JSON.parse(fs.readFileSync('output/satb_correction/2026-10-12/sombra_patch.json','utf8'));
const files=['E:/proyectos/IosCoroLLDM/assets/catalogo.json','E:/proyectos/IosCoroLLDM/assets/offline_assets/catalogo.json','E:/proyectos/CoroLLDM/public/offline_assets/catalogo.json','E:/proyectos/repertorio_bc/assets/catalogo.json'];
const roots=['E:/proyectos/IosCoroLLDM/assets','E:/proyectos/CoroLLDM/public','E:/proyectos/repertorio_bc/assets'];
const encrypted=await encodeDataUrl(p.midiData,'midi'),plans=[];
for(const root of roots){const dest=assetPath(root,'midi',p.midiKey);if(fs.existsSync(dest))throw Error('Destino existente');plans.push({path:dest,bytes:encrypted});}
for(const file of files){const rows=readCatalog(file),i=rows.findIndex(r=>r.id===p.localId);if(i<0||rows[i].midi_archivo!==p.oldMidiKey)throw Error('Audio inesperado');rows[i]={...rows[i],midi_archivo:p.midiKey,version:6};plans.push(catalogEntry(file,rows));}
writeTransaction(plans);
const doc='docs/repertorio/2026-10-12/';
const rect=JSON.parse(fs.readFileSync(doc+'rectificacion_satb.json','utf8'));
rect.labelCorrections=[{...p,midiData:undefined,version:6,mainRoles:[{track:0,role:'Soprano',notes:205},{track:1,role:'Alto',notes:242},{track:3,role:'Tenor',notes:236},{track:4,role:'Bajo',notes:232}],evidence:'Editable MuseScore con partes Soprano, Alto, Tenor y Bajo; mismos pitches y entradas de las cuatro pistas principales'}];
fs.writeFileSync(doc+'rectificacion_satb.json',JSON.stringify(rect,null,2));
const m=JSON.parse(fs.readFileSync(doc+'incorporados_30.json','utf8'));
m.records=m.records.filter(r=>r.id!==rect.quarantined[0].id).map(r=>r.id===p.localId?{...r,midiKey:p.midiKey,midiHash:p.midiHash,version:6}:r);
m.currentlyAssigned=29;m.rectification='rectificacion_satb.json';
fs.writeFileSync(doc+'incorporacion_actual.json',JSON.stringify(m,null,2));
console.log(JSON.stringify({assignedFromLastBatch:29,labelCorrection:p.name,mainRoles:4}));
