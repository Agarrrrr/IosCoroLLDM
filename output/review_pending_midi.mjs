import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire('E:/proyectos/CoroLLDM/package.json');
const {Midi}=require('@tonejs/midi');
const root='E:/proyectos/IosCoroLLDM',out=root+'/docs/repertorio/2026-10-12';
fs.mkdirSync(out,{recursive:true});
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const norm=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
const done=new Set(read(root+'/docs/repertorio/2026-10-11/midis_confirmados.json').records.map(r=>norm(r.name)));
const registry=read('E:/Audios Octubre/Candidatos revisados - 2026-10-10/registro.json').records;

function rawTracks(buf,header){
 const result=[];let pos=8+buf.readUInt32BE(4),count=buf.readUInt16BE(10);
 for(let track=0;track<count;track++){
  const size=buf.readUInt32BE(pos+4),data=buf.subarray(pos+8,pos+8+size);pos+=8+size;
  let p=0,tick=0,running=0,name='',programs=new Set(),notes=[],active=new Map(),hanging=0;
  const vlq=()=>{let v=0,b;do{b=data[p++];v=v*128+(b&127);}while(b&128);return v;};
  while(p<data.length){
   tick+=vlq();let status=data[p];if(status<128)status=running;else p++;
   if(status===255){const type=data[p++],len=vlq(),s=data.subarray(p,p+len);p+=len;if(type===3)name=s.toString('utf8');continue;}
   if(status===240||status===247){p+=vlq();continue;}
   running=status;const kind=status>>4,ch=status&15,a=data[p++],b=(kind===12||kind===13)?0:data[p++];
   if(kind===12)programs.add(a);
   if(kind===9&&b>0){const key=ch+':'+a;if(!active.has(key))active.set(key,[]);active.get(key).push({ticks:tick,midi:a,velocity:b});}
   else if(kind===8||(kind===9&&b===0)){const key=ch+':'+a,q=active.get(key);if(q?.length){const n=q.shift();notes.push({...n,durationTicks:tick-n.ticks,time:header.ticksToSeconds(n.ticks),duration:header.ticksToSeconds(tick)-header.ticksToSeconds(n.ticks)});}}
  }
  for(const q of active.values())hanging+=q.length;
  if(notes.length||hanging)result.push({name,notes,instrument:{name:[...programs].map(p=>'GM '+(p+1)).join(', ')},rawTrack:track+1,hangingNotes:hanging,programs:[...programs]});
 }
 return result;
}

const rows=[];
for(const r of registry){
 if(done.has(norm(r.title)))continue;
 try{
 const midi=new Midi(fs.readFileSync(r.source));
 const tracks=rawTracks(fs.readFileSync(r.source),midi.header).filter(t=>t.notes.length).map(t=>{
  const notes=t.notes,first=Math.min(...notes.map(n=>n.ticks)),lastOn=Math.max(...notes.map(n=>n.ticks)),lastEnd=Math.max(...notes.map(n=>n.ticks+n.durationTicks));
  const pitch=notes.map(n=>n.midi).sort((a,b)=>a-b);
  let overlap=0;const sorted=[...notes].sort((a,b)=>a.ticks-b.ticks);let end=-1;
  for(const n of sorted){if(n.ticks<end-1)overlap++;end=Math.max(end,n.ticks+n.durationTicks);}
  return {name:t.name,rawTrack:t.rawTrack,hangingNotes:t.hangingNotes,programs:t.programs,instrument:t.instrument.name,notes:notes.length,firstTick:first,lastOnTick:lastOn,lastEndTick:lastEnd,firstSec:Math.min(...notes.map(n=>n.time)),lastOnSec:Math.max(...notes.map(n=>n.time)),lastEndSec:Math.max(...notes.map(n=>n.time+n.duration)),pitchMin:pitch[0],pitchMax:pitch.at(-1),pitchMedian:pitch[Math.floor(pitch.length/2)],overlapNotes:overlap,overlapPercent:100*overlap/notes.length};
 });
 const last=tracks.map(t=>t.lastEndTick),spread=Math.max(...last)-Math.min(...last),ppq=midi.header.ppq;
 rows.push({...r,tracks,ppq,endSpreadBeats:spread/ppq,endSpreadSec:Math.max(...tracks.map(t=>t.lastEndSec))-Math.min(...tracks.map(t=>t.lastEndSec)),exactFour:tracks.length===4,similarEnding:tracks.length===4&&spread<=ppq,headerTimeSignatures:midi.header.timeSignatures});
 }catch(e){rows.push({...r,error:e.message});}
}
fs.writeFileSync(out+'/revision_midis.json',JSON.stringify(rows,null,2));
let lines=['# Revisi\u00f3n de pistas MIDI \u2014 2026-10-12','','Solo lectura. No se renombraron instrumentos, modificaron originales ni incorporaron audios.','','Se revisa el registro completo de pendientes: 33 t\u00edtulos y 5 archivos sin identidad (hay variantes del mismo canto). La cifra anterior de 29 no est\u00e1 respaldada por ese registro.','','Criterio cuantitativo: cuatro pistas con notas y diferencia de final de sonido de hasta una negra. Se mide la \u00faltima nota real, no el fin del archivo MIDI. Entradas diferentes son v\u00e1lidas. Esta coincidencia NO demuestra por s\u00ed sola que sean SATB ni que coincidan con el PDF.','','## Resumen por archivo','','| Canto / archivo | Pistas con notas | Finales separados (negras) | Finales separados (s) | Observaci\u00f3n |','|---|---:|---:|---:|---|'];
for(const r of rows){
 const name=r.title+' \u2014 '+r.source.split('\\').at(-1);
 const warning=r.error||(!r.exactFour?'No son cuatro pistas':!r.similarEnding?'Finales desiguales':r.tracks.some(t=>t.overlapPercent>10)?'Cuatro y finales similares; revisar polifon\u00eda':'Cuatro y finales similares; identificar voces');
 lines.push('| '+name+' | '+(r.tracks?.length??'?')+' | '+(r.endSpreadBeats?.toFixed(2)??'?')+' | '+(r.endSpreadSec?.toFixed(2)??'?')+' | '+warning+' |');
}
lines.push('','## Detalle de las pistas','');
for(const r of rows){
 lines.push('### '+r.title+' \u2014 '+r.source.split('\\').at(-1),'','Origen: '+r.source,'','| Pista | Instrumento | Notas | Entrada (s) | \u00daltimo ataque (s) | Fin de sonido (s) | MIDI min\u2013max / mediana | Notas solapadas |','|---|---|---:|---:|---:|---:|---|---:|');
 for(const t of r.tracks??[])lines.push('| '+[t.name||'(sin nombre)',t.instrument,t.notes,t.firstSec.toFixed(2),t.lastOnSec.toFixed(2),t.lastEndSec.toFixed(2),t.pitchMin+'\u2013'+t.pitchMax+' / '+t.pitchMedian,t.overlapPercent.toFixed(1)+'%'].join(' | ')+' |');
 lines.push('');
}
fs.writeFileSync(out+'/revision_midis.md',lines.join('\n'));
console.log(JSON.stringify({files:rows.length,titles:new Set(rows.filter(r=>!r.category.startsWith('04')).map(r=>r.title)).size,four:rows.filter(r=>r.exactFour).length,similar:rows.filter(r=>r.similarEnding).length},null,2));
for(const r of rows)console.log(JSON.stringify({title:r.title,file:r.source.split('\\').at(-1),tracks:r.tracks?.length,spread:r.endSpreadBeats?.toFixed(2),names:r.tracks?.map(t=>t.name),medians:r.tracks?.map(t=>t.pitchMedian),overlap:r.tracks?.map(t=>Math.round(t.overlapPercent))}));
