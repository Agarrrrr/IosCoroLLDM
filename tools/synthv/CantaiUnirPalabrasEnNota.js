// Obtain every Spanish syllable with the engine's '+' distribution, then put
// the complete phoneme string on the original note. Original timing is untouched.
var TITLE="Cantai - Unir palabras en una nota",KEY="cantai.joinNoteLyrics.v3";
function getClientInfo(){return {name:TITLE,author:"Cantai",versionNumber:4,minEditorVersion:0x020101};}
function trim(s){return s.replace(/^\s+|\s+$/g,"");}
function natural(text){var s=trim(text);return !!s&&s.charAt(0)!=="."&&/[a-záéíóúüñ]/i.test(s)&&!/(^|\s)(?:[-+]|br|sil|pau|cl)(?=\s|$)/i.test(s);}
function joinedLyrics(text){return natural(text)?trim(text).replace(/\s+/g,""):text;}
function phones(s){return trim(s||"").split(/\s+/).filter(function(t){return !!t&&t!=="sil"&&t!=="pau";});}
function missingSuffix(current,complete){var a=phones(current),b=phones(complete);if(a.length>=b.length)return false;for(var i=0;i<a.length;i++)if(a[i]!==b[i])return false;return b.length>0;}
function collect(scope){
 var editor=SV.getMainEditor(),project=SV.getProject(),entries=[],seen={};
 function add(ref,selection){
  if(!ref||ref.isInstrumental())return;var group=ref.getTarget(),id=group.getUUID();if(seen[id])return;seen[id]=true;
  var notes=selection||[];if(!selection)for(var n=0;n<group.getNumNotes();n++)notes.push(group.getNote(n));
  if(notes.length)entries.push({ref:ref,group:group,notes:notes});
 }
 function track(t){if(t)for(var g=0;g<t.getNumGroups();g++)add(t.getGroupReference(g),null);}
 if(scope===0){var selected=editor.getSelection().getSelectedNotes();if(selected.length)add(editor.getCurrentGroup(),selected);}
 else if(scope===1)add(editor.getCurrentGroup(),null);else if(scope===2)track(editor.getCurrentTrack());
 else for(var t=0;t<project.getNumTracks();t++)track(project.getTrack(t));return entries;
}
function main(){
 var result=SV.showCustomDialog({title:TITLE,buttons:"OkCancel",
  message:"Version 3.1 - ESPANOL. Incluye textos ya unidos: yoes -> y o e s.\nObtiene TODOS los fonemas y los coloca en la misma nota.\nConserva notas, tiempos y dinamicas. Ctrl+Z deshace.",
  widgets:[{name:"operation",type:"ComboBox",label:"Operacion",default:0,choices:["Unir espacios y completar pronunciaciones cortadas","Forzar pronunciacion completa SOLO en notas seleccionadas"]},
   {name:"scope",type:"ComboBox",label:"Aplicar a (primera operacion)",default:SV.getMainEditor().getSelection().getSelectedNotes().length?0:3,choices:["Notas seleccionadas","Grupo abierto","Pista actual","Todo el proyecto"]}]});
 if(!result.status){SV.finish();return;}
 var force=result.answers.operation===1,entries=collect(force?0:result.answers.scope),project=SV.getProject();
 if(!entries.length){SV.showMessageBox(TITLE,"No hay notas en el alcance elegido. Selecciona notas en el piano roll o elige Grupo abierto / Todo el proyecto.");SV.finish();return;}
 var targets=[],blocks=[],wordMap={},tempUUID=null,tempRef=null,done=false,skippedPlus=0;
 function cleanup(){if(tempUUID){var g=project.getNoteGroup(tempUUID),index=g?g.getIndexInParent():null;tempRef=null;g=null;tempUUID=null;if(index!==null)project.removeNoteGroup(index);}}
 function report(message){SV.showMessageBoxAsync(TITLE,message,function(){SV.finish();});}
 function fail(e){if(done)return;done=true;try{cleanup();}catch(ignore){}report("No se pudo completar la consulta de fonemas.\n"+String(e)+"\nNo se reemplazaron las pronunciaciones pendientes.");}
 function load(index,attempt){
  if(index>=entries.length){makeProbe();return;}
  try{
   var entry=entries[index],computed=SV.getPhonemesForGroup(entry.ref);
   if((!computed||computed.length<entry.group.getNumNotes())&&attempt<40){SV.setTimeout(150,function(){load(index,attempt+1);});return;}
   if(!computed||computed.length<entry.group.getNumNotes())throw new Error("El motor no devolvio los fonemas del grupo.");
   for(var i=0;i<entry.notes.length;i++){
    var note=entry.notes[i],before=note.getLyrics();if(!natural(before))continue;var ni=note.getIndexInParent();
    if(ni+1<entry.group.getNumNotes()&&trim(entry.group.getNote(ni+1).getLyrics())==="+"){skippedPlus++;continue;}
    var after=joinedLyrics(before),key="$"+after,bi=wordMap[key];if(typeof bi==="undefined"){bi=blocks.length;wordMap[key]=bi;blocks.push({text:after});}
    targets.push({note:note,before:before,after:after,block:bi,current:note.getPhonemes()||computed[ni]||""});
   }
   load(index+1,0);
  }catch(e){fail(e);}
 }
 function makeProbe(){
  try{
   if(!targets.length){done=true;SV.showMessageBox(TITLE,"No se encontraron letras normales para revisar.");SV.finish();return;}
   var group=SV.create("NoteGroup"),q=0;group.setName("Cantai TEMP fonemas completos");
   function add(text){var n=SV.create("Note");n.setPitch(60);n.setLanguageOverride("spanish");n.setTimeRange(q,SV.QUARTER);n.setLyrics(text);group.addNote(n);q+=SV.QUARTER;}
   for(var b=0;b<blocks.length;b++){
    var block=blocks[b],vowels=(block.text.match(/[aeiouáéíóúü]/gi)||[]).length;block.start=group.getNumNotes();block.slots=Math.max(4,vowels+2);add(block.text);
    for(var j=1;j<block.slots;j++)add("+");q+=SV.QUARTER;
   }
   var gi=project.addNoteGroup(group);tempUUID=project.getNoteGroup(gi).getUUID();var ref=SV.create("NoteGroupReference");ref.setTarget(project.getNoteGroup(gi));ref.setMuted(true);
   var track=entries[0].ref.getParent(),ri=track.addGroupReference(ref);tempRef=track.getGroupReference(ri);group=null;ref=null;SV.setTimeout(300,startProbe);
  }catch(e){fail(e);}
 }
 function startProbe(){readProbe(0);}
 function readProbe(attempt){
  try{
   var data=SV.getPhonemesForGroup(tempRef),total=tempRef.getTarget().getNumNotes();
   if((!data||data.length<total)&&attempt<60){SV.setTimeout(150,function(){readProbe(attempt+1);});return;}
   if(!data||data.length<total)throw new Error("Tiempo agotado esperando los fonemas completos.");
   for(var b=0;b<blocks.length;b++){
    var block=blocks[b],all=[],ended=false;
    for(var j=0;j<block.slots;j++){var part=phones(data[block.start+j]);if(!part.length){ended=true;break;}all=all.concat(part);}
    block.complete=ended&&all.length?all.join(" "):null;
   }
   cleanup();apply();
  }catch(e){fail(e);}
 }
 function apply(){
  var changed=0,already=0,manual=0,unavailable=0,examples=[];
  for(var i=0;i<targets.length;i++){
   var t=targets[i],full=blocks[t.block].complete;if(!full){unavailable++;continue;}
   if(t.before===t.after&&!force&&!missingSuffix(t.current,full)){if(phones(t.current).join(" ")===full)already++;else manual++;continue;}
   if(t.note.getLyrics()!==t.before){manual++;continue;}
   var mark={beforeLyrics:t.before,beforePhones:t.note.getPhonemes(),beforeLanguage:t.note.getLanguageOverride(),beforePhonemeAttributes:t.note.getAttributes().phonemes||[],afterLyrics:t.after,completePhones:full};
   t.note.setScriptData(KEY,mark);t.note.setLyrics(t.after);t.note.setLanguageOverride("spanish");t.note.setPhonemes(full);t.note.setAttributes({phonemes:[]});changed++;
   if(examples.length<6)examples.push(t.after+" -> "+full);
  }
  done=true;report("Notas revisadas: "+targets.length+"\nPronunciaciones completadas: "+changed+"\nYa completas: "+already+"\nFonemas distintos o ediciones conservadas: "+manual+"\nSin resultado completo: "+unavailable+"\nCon continuacion + conservadas: "+skippedPlus+(examples.length?"\n\n"+examples.join("\n"):"")+"\n\nLas notas originales conservan tono, inicio y duracion. Ctrl+Z deshace.");
 }
 load(0,0);
}
